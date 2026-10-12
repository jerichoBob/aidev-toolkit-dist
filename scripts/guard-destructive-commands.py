#!/usr/bin/env python3
"""PreToolUse hook (matcher: Bash): block destructive shell commands before they run.

Installed by scripts/install.sh into ~/.claude/settings.json as:
    python3 -I ~/.claude/aidev-toolkit/scripts/guard-destructive-commands.py

Reads the hook JSON on stdin ({"tool_input": {"command": ...}, "cwd": ...}).
Exit 2 with a message on stderr blocks the command and tells Claude why.

Blocked:
  - every rm (also unlink, rmdir), in any spelling: sudo/command/env/xargs/nice wrappers, \\rm, /bin/rm,
    sh -c "...", eval, $(...), backticks, find -exec rm, find -delete
  - python deletes (shutil.rmtree, os.remove, os.unlink, os.rmdir, Path.unlink)
  - shred, srm
  - git clean -f, git reset --hard, git push --force / -f / --force-with-lease
  - dd of=...
A blocked rm lists the files it would have removed, so the person can review and delete them
(the optional rm-review mod, modules/rm-review/, shows that list in a side panel).

--analyze: print a JSON analysis of the command on stdin (used by the rm-review mod) and exit 0.

Turning it off is for the person, not for Claude: set AIDEV_DESTRUCTIVE_GUARD=off in the environment
Claude Code starts with (a shell export, or the "env" block of ~/.claude/settings.json). A command
cannot switch it off for itself, because the variable is read from the hook's own environment.

This is a guardrail, not a security boundary: text matching cannot catch every way to delete a file.
If the analysis itself fails, a crude pattern still blocks obvious rm/shred/delete commands.
"""
import glob
import json
import os
import re
import shlex
import sys

MAX_LISTED = 200
MAX_DIR_ITEMS = 1000
MAX_DEPTH = 4

WRAPPERS = {
    "sudo", "doas", "command", "builtin", "exec", "env", "nice", "nohup", "time", "timeout",
    "xargs", "ionice", "caffeinate", "stdbuf", "chronic", "unbuffer",
}
SHELLS = {"sh", "bash", "zsh", "dash", "ksh", "fish"}
RM_FAMILY = {"rm", "unlink", "rmdir"}
SHRED_FAMILY = {"shred", "srm"}
OPERATORS = {";", "&&", "||", "|", "&", "|&", "(", ")", ";;"}

SYSTEM_PATHS = {
    "/", "/bin", "/sbin", "/usr", "/etc", "/var", "/opt", "/dev", "/System", "/Library", "/Applications",
    "/Users", "/private", "/Volumes", "/home", "/root", "/tmp", "/cores",
}
PY_DELETE = re.compile(
    r"shutil\s*\.\s*rmtree|\bos\s*\.\s*(remove|unlink|rmdir|removedirs)\s*\(|\.unlink\s*\(|\.rmdir\s*\(|\brimraf\b"
)
CRUDE = re.compile(r"(^|[^A-Za-z0-9_.-])(rm|unlink|rmdir|shred|srm)([^A-Za-z0-9_-]|$)|rmtree|-delete\b")


def base(token):
    return os.path.basename(token)


def tokenize(command):
    """Split into simple commands (lists of tokens) at ; && || | & and newlines."""
    text = command.replace("\r", "").replace("\n", " ; ")
    lex = shlex.shlex(text, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""
    simple, current = [], []
    for tok in lex:
        if tok in OPERATORS or (tok and set(tok) <= set(";&|()")):
            if current:
                simple.append(current)
            current = []
        else:
            current.append(tok)
    if current:
        simple.append(current)
    return simple


def nested_strings(command):
    """Command text inside $(...) and backticks."""
    found = re.findall(r"\$\(([^()]*)\)", command)
    found += re.findall(r"`([^`]*)`", command)
    return found


def empty_analysis():
    return {"blocked": False, "reasons": [], "rm": None, "_rm_calls": []}


def analyze_rm(args, via_xargs):
    force = recursive = False
    targets, past_flags = [], False
    for a in args:
        if not past_flags and a == "--":
            past_flags = True
        elif not past_flags and a.startswith("--"):
            force = force or a == "--force"
            recursive = recursive or a == "--recursive"
        elif not past_flags and a.startswith("-") and len(a) > 1:
            force = force or "f" in a[1:]
            recursive = recursive or "r" in a[1:] or "R" in a[1:]
        else:
            targets.append(a)
    return {"force": force, "recursive": recursive, "targets": targets, "from_stdin": via_xargs and not targets}


def is_system_target(target, cwd):
    if any(c in target for c in "$`"):
        return "target uses a variable or substitution, so it cannot be checked"
    expanded = os.path.expanduser(target)
    if target in {"*", ".", "..", "./*", "../*", "~", "~/", "~/*", "/*"}:
        return f"target {target!r} would remove a whole directory's contents"
    absolute = os.path.normpath(os.path.join(cwd, expanded))
    home = os.path.expanduser("~")
    real = os.path.realpath(absolute)
    for p in (absolute, real):
        if p in SYSTEM_PATHS or p == home or (home.startswith(p.rstrip("/") + "/") and p != "/"):
            return f"target {target!r} is a system or home directory"
    return None


def scan(command, cwd, result, depth=0):
    if depth > MAX_DEPTH:
        result["reasons"].append("command nesting is too deep to check")
        result["blocked"] = True
        return
    try:
        simple = tokenize(command)
    except ValueError:
        # Unbalanced quotes etc.: fall back to the crude pattern.
        if CRUDE.search(command):
            result["blocked"] = True
            result["reasons"].append("a delete command in text that could not be parsed")
        return

    if PY_DELETE.search(command):
        result["blocked"] = True
        result["reasons"].append("a scripted delete (shutil.rmtree, os.remove, os.unlink, Path.unlink, ...)")

    for inner in nested_strings(command):
        scan(inner, cwd, result, depth + 1)

    for toks in simple:
        # Skip leading VAR=value assignments.
        while toks and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", toks[0]):
            toks = toks[1:]
        if not toks:
            continue
        head = base(toks[0])
        wrapped = head in WRAPPERS
        window = toks[:10] if wrapped else toks[:1]

        # shells and eval: recurse into the command string
        if head in SHELLS or head == "eval":
            if head == "eval":
                scan(" ".join(toks[1:]), cwd, result, depth + 1)
            for i, t in enumerate(toks[:-1]):
                if t.startswith("-") and "c" in t[1:] and not t.startswith("--"):
                    scan(toks[i + 1], cwd, result, depth + 1)
            continue

        names = [base(t) for t in window]
        rm_at = next((i for i, n in enumerate(names) if n in RM_FAMILY), None)
        if rm_at is not None:
            via_xargs = "xargs" in names[:rm_at]
            call = analyze_rm(toks[rm_at + 1:], via_xargs)
            call["command"] = names[rm_at]
            result["_rm_calls"].append(call)
            result["blocked"] = True
            if call["force"]:
                result["reasons"].append("rm with --force / -f")
            if call["from_stdin"]:
                result["reasons"].append("rm fed from stdin (xargs): the targets are not known in advance")
            for t in call["targets"]:
                why = is_system_target(t, cwd)
                if why:
                    result["reasons"].append(why)
            continue

        if head in SHRED_FAMILY:
            result["blocked"] = True
            result["reasons"].append(f"{head} destroys file contents")
        elif head == "find":
            if "-delete" in toks:
                result["blocked"] = True
                result["reasons"].append("find -delete")
            for i, t in enumerate(toks):
                if t in ("-exec", "-execdir", "-ok", "-okdir") and i + 1 < len(toks) and base(toks[i + 1]) in RM_FAMILY | SHRED_FAMILY:
                    result["blocked"] = True
                    result["reasons"].append(f"find {t} {base(toks[i + 1])}")
        elif head == "git" and len(toks) > 1:
            sub = next((t for t in toks[1:] if not t.startswith("-")), "")
            rest = toks[toks.index(sub) + 1:] if sub in toks else []

            def short(a):
                return a.startswith("-") and not a.startswith("--") and "f" in a[1:]

            if sub == "clean" and any(a == "--force" or short(a) for a in rest):
                result["blocked"] = True
                result["reasons"].append("git clean -f deletes untracked files")
            elif sub == "reset" and "--hard" in rest:
                result["blocked"] = True
                result["reasons"].append("git reset --hard discards uncommitted work")
            elif sub == "push" and any(a in ("--force", "--force-with-lease") or a.startswith("--force-with-lease=") or short(a) for a in rest):
                result["blocked"] = True
                result["reasons"].append("git push --force rewrites remote history")
        elif head == "dd" and any(t.startswith("of=") for t in toks[1:]):
            result["blocked"] = True
            result["reasons"].append("dd of= overwrites its target")


def describe_target(path):
    import stat as _stat

    try:
        st = os.lstat(path)
    except OSError:
        return {"path": path, "kind": "missing", "size": 0, "items": 0}
    if _stat.S_ISLNK(st.st_mode):
        return {"path": path, "kind": "link", "size": st.st_size, "items": 0}
    if _stat.S_ISDIR(st.st_mode):
        items = 0
        try:
            with os.scandir(path) as it:
                for _ in it:
                    items += 1
                    if items >= MAX_DIR_ITEMS:
                        break
        except OSError:
            pass
        return {"path": path, "kind": "dir", "size": 0, "items": items}
    return {"path": path, "kind": "file", "size": st.st_size, "items": 0}


def resolve_targets(calls, cwd):
    """Expand globs and ~ the way a shell would, and describe what exists."""
    listed, unresolved, truncated = [], [], False
    seen = set()
    for call in calls:
        for t in call["targets"]:
            if any(c in t for c in "$`"):
                unresolved.append(t)
                continue
            expanded = os.path.expanduser(t)
            pattern = expanded if os.path.isabs(expanded) else os.path.join(cwd, expanded)
            matches = sorted(glob.glob(pattern)) if any(c in t for c in "*?[") else [pattern]
            for m in matches:
                m = os.path.normpath(m)
                if m in seen:
                    continue
                seen.add(m)
                if len(listed) >= MAX_LISTED:
                    truncated = True
                    continue
                listed.append(describe_target(m))
    return listed, unresolved, truncated


def analyze(command, cwd):
    result = empty_analysis()
    scan(command, cwd, result)
    calls = result.pop("_rm_calls")
    if calls:
        listed, unresolved, truncated = resolve_targets(calls, cwd)
        result["rm"] = {
            "force": any(c["force"] for c in calls),
            "recursive": any(c["recursive"] for c in calls),
            "from_stdin": any(c["from_stdin"] for c in calls),
            "files": listed,
            "unresolved": unresolved,
            "truncated": truncated,
        }
    result["reasons"] = list(dict.fromkeys(result["reasons"]))  # de-duplicate, keep order
    return result


def human_size(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024


def message(result):
    lines = ["BLOCKED by the aidev-toolkit destructive-command guard (scripts/guard-destructive-commands.py). Nothing was run or removed."]
    if result["reasons"]:
        lines.append("Why: " + "; ".join(result["reasons"]) + ".")
    rm = result["rm"]
    if rm:
        files = [f for f in rm["files"] if f["kind"] != "missing"]
        lines.append(f"The rm would have removed {len(files)} existing item(s):")
        for f in files:
            detail = f"{f['items']}{'+' if f['items'] >= MAX_DIR_ITEMS else ''} entries" if f["kind"] == "dir" else human_size(f["size"])
            lines.append(f"  - {f['path']} ({f['kind']}, {detail})")
        if rm["truncated"]:
            lines.append(f"  ... and more (list cut at {MAX_LISTED}).")
        for u in rm["unresolved"]:
            lines.append(f"  - {u} (uses a variable or substitution; could not be listed)")
    lines.append(
        "Do not retry with another spelling or tool. Tell the user what should be removed and why; they delete it "
        "themselves (the rm-review panel lists these files with a Move to Trash button when that mod is loaded)."
    )
    return "\n".join(lines)


def main(argv):
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0  # not a hook payload; nothing to judge
    command = (payload.get("tool_input") or {}).get("command") or ""
    cwd = payload.get("cwd") or os.getcwd()
    if "--analyze" not in argv and os.environ.get("AIDEV_DESTRUCTIVE_GUARD", "").lower() == "off":
        return 0  # switched off by the person who starts Claude Code
    try:
        result = analyze(command, cwd)
    except Exception as exc:  # fail closed on obvious deletes, open otherwise
        if CRUDE.search(command):
            print(f"BLOCKED: delete-looking command and the checker failed ({type(exc).__name__}). Nothing was run.", file=sys.stderr)
            return 2
        return 0
    if "--analyze" in argv:
        print(json.dumps(result))
        return 0
    if result["blocked"]:
        print(message(result), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
