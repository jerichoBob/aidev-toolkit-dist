#!/usr/bin/env bash
# fix-spec-links.sh — repair markdown links to spec files after /sdd-specs-archive moves them.
# Usage: fix-spec-links.sh [--root DIR] [--dry-run] fix [MOVED_FILE...]
#        fix-spec-links.sh [--root DIR] verify
# fix:    rewrite inline links whose target is a spec file (spec-v*.md) that no longer resolves
#         from the linking file, to the file's real location. Anchors and link text are kept.
#         MOVED_FILE args (basenames or paths) restrict the rewrite to those spec files.
# verify: list every spec link that does not resolve (file:line); exit 1 if any.
# Scope: README.md, specs/**/*.md, docs/**/*.md. Targets escaping the root are reported, not changed.
# Output lines are structured: key=value pairs, one event per line.
set -u
ROOT="$PWD"; DRY=0; MODE=""; MOVED=()
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    fix|verify) MODE="$1"; shift ;;
    -h|--help) sed -n 2,11p "$0"; exit 0 ;;
    *) MOVED+=("$1"); shift ;;
  esac
done
[ -n "$MODE" ] || { echo "fix-spec-links step=args outcome=fail detail=mode (fix|verify) required" >&2; exit 2; }
[ -d "$ROOT" ] || { echo "fix-spec-links step=args outcome=fail detail=root not a directory: $ROOT" >&2; exit 2; }
export FSL_ROOT="$ROOT" FSL_DRY="$DRY" FSL_MODE="$MODE"
export FSL_MOVED="$(printf '%s\n' "${MOVED[@]+"${MOVED[@]}"}")"
exec python3 -I - <<'PY'
import os, re, sys, glob
root = os.path.realpath(os.environ["FSL_ROOT"])
dry = os.environ["FSL_DRY"] == "1"
mode = os.environ["FSL_MODE"]
moved = {os.path.basename(m) for m in os.environ["FSL_MOVED"].split("\n") if m}
SPEC = re.compile(r"^spec-v\d+[^/]*\.md$")
LINK = re.compile(r"\[([^\]]*)\]\(([^)]*)\)")

# index of real spec files by basename
index = {}
for p in glob.glob(os.path.join(root, "specs", "**", "spec-v*.md"), recursive=True):
    index.setdefault(os.path.basename(p), []).append(p)

files = []
for pat in ("README.md", "specs/**/*.md", "docs/**/*.md"):
    files += glob.glob(os.path.join(root, pat), recursive=True)
files = sorted(set(os.path.realpath(f) for f in files if os.path.isfile(f)))

rewritten = unresolved = unparseable = errors = 0
def rel(f): return os.path.relpath(f, root)
def log(**kw): print("fix-spec-links " + " ".join(f"{k}={v}" for k, v in kw.items()))

for f in files:
    try:
        text = open(f, encoding="utf-8").read()
    except (OSError, UnicodeDecodeError) as e:
        errors += 1; log(step="read", outcome="fail", file=rel(f), detail=str(e).replace(" ", "_")); continue
    lines = text.split("\n"); changed = False; fence = False
    for i, line in enumerate(lines):
        if line.lstrip().startswith(("```", "~~~")):
            fence = not fence; continue
        if fence: continue
        def sub(m):
            global rewritten, unresolved, unparseable
            raw = m.group(2).strip()
            title = ""
            tm = re.match(r'^(\S+)(\s+"[^"]*")$', raw)
            if tm: raw, title = tm.group(1), tm.group(2)
            if re.match(r"^[a-z][a-z0-9+.-]*:", raw, re.I) or raw.startswith("#") or not raw:
                return m.group(0)
            path, hash_, anchor = raw.partition("#")
            base = os.path.basename(path)
            if " " in raw and ".md" in raw and "spec-v" in raw:
                unparseable += 1; log(step="link", outcome="unparseable", file=f"{rel(f)}:{i+1}", target=raw.replace(" ", "%20")); return m.group(0)
            if not SPEC.match(base): return m.group(0)
            if moved and base not in moved and mode == "fix": return m.group(0)
            target = os.path.realpath(os.path.join(os.path.dirname(f), path))
            if not (target == root or target.startswith(root + os.sep)):
                unparseable += 1; log(step="link", outcome="escapes-root", file=f"{rel(f)}:{i+1}", target=path); return m.group(0)
            if os.path.exists(target): return m.group(0)
            cands = index.get(base, [])
            if mode == "fix" and len(cands) == 1:
                new = os.path.relpath(cands[0], os.path.dirname(f))
                rewritten += 1
                log(step="rewrite", outcome="dry-run" if dry else "ok", file=f"{rel(f)}:{i+1}", old=path, new=new)
                return f"[{m.group(1)}]({new}{hash_}{anchor}{title})"
            unresolved += 1
            log(step="link", outcome="unresolved", file=f"{rel(f)}:{i+1}", target=path)
            return m.group(0)
        new_line = LINK.sub(sub, line)
        if new_line != line: lines[i] = new_line; changed = True
    if changed and not dry and mode == "fix":
        try: open(f, "w", encoding="utf-8").write("\n".join(lines))
        except OSError as e:
            errors += 1; log(step="write", outcome="fail", file=rel(f), detail=str(e).replace(" ", "_"))

if mode == "fix":
    # unresolved count after the rewrite is what verify reports; in dry-run, count what would remain
    print(f"fix-spec-links step=summary mode=fix rewritten={rewritten} unresolved={unresolved} unparseable={unparseable} errors={errors} dry_run={int(dry)}")
    sys.exit(1 if errors else 0)
print(f"fix-spec-links step=summary mode=verify unresolved={unresolved} unparseable={unparseable} errors={errors}")
sys.exit(1 if (unresolved or unparseable or errors) else 0)
PY
