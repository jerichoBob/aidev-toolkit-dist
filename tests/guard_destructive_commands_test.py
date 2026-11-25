#!/usr/bin/env python3
"""Tests for scripts/guard-destructive-commands.py and its install/uninstall wiring.

Run: python3 -I tests/guard_destructive_commands_test.py   (tests/test-guard-destructive-commands.sh wraps it)

These only ANALYZE command text. No test executes a delete: the "files that would be removed" are
throwaway files in a temp dir, and the guard never removes anything itself. No mocks: the installer
function and the uninstaller block are extracted from the real scripts and run against a real
temporary HOME.
"""
import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
SCRIPT = os.path.join(REPO, "scripts", "guard-destructive-commands.py")
INSTALL = os.path.join(REPO, "scripts", "install.sh")
UNINSTALL = os.path.join(REPO, "scripts", "uninstall.sh")

sys.dont_write_bytecode = True  # keep the repo free of __pycache__ from this test
spec = importlib.util.spec_from_file_location("guard", SCRIPT)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

CWD = tempfile.gettempdir()


def blocked(cmd):
    return guard.analyze(cmd, CWD)["blocked"]


class Blocks(unittest.TestCase):
    def test_every_delete_spelling(self):
        for cmd in [
            "rm file", "rm -f file", "rm -rf build", "rm -fr build", "rm -Rf build", "rm --force x", "rm -r -f x",
            "\\rm file", "/bin/rm file", "/usr/bin/rm -f file", "sudo rm file", "sudo -u root rm file",
            "command rm file", "env FOO=1 rm file", "FOO=1 rm file", "nice rm file",
            "ls | xargs rm", "ls | xargs -n1 rm -f",
            "echo hi && rm file", "echo hi; rm file", "echo hi\nrm file", "true || rm file",
            "bash -c 'rm file'", "sh -c \"rm -rf x\"", "zsh -lc 'cd x && rm file'", "eval 'rm file'",
            "echo $(rm file)", "echo `rm file`",
            "find . -name '*.tmp' -exec rm {} \\;", "find . -name '*.tmp' -delete",
            "unlink file", "rmdir dir", "shred -u secret",
            "git clean -fd", "git clean -f", "git clean --force -d",
            "git reset --hard", "git reset --hard HEAD~1",
            "git push --force", "git push -f origin main", "git push --force-with-lease",
            "dd if=/dev/zero of=/dev/disk2", "dd if=/dev/zero of=/dev/null count=1",
            "python3 -c 'import shutil; shutil.rmtree(\"x\")'", "python3 -c 'import os; os.remove(\"x\")'",
            "node -e \"require('rimraf')\"",
        ]:
            with self.subTest(cmd=cmd):
                self.assertTrue(blocked(cmd), cmd)

    def test_unparseable_text_with_rm_still_blocks(self):
        self.assertTrue(blocked("echo 'unterminated; rm file"))

    def test_system_and_wildcard_targets_are_reasoned(self):
        for cmd in ["rm -rf /", "rm -rf ~", "rm -rf /usr", "rm -r *", "rm -rf $HOME/x", "rm -rf ."]:
            with self.subTest(cmd=cmd):
                r = guard.analyze(cmd, CWD)
                self.assertTrue(r["blocked"])
                self.assertTrue(r["reasons"], cmd)


class Allows(unittest.TestCase):
    def test_ordinary_commands_pass(self):
        for cmd in [
            "ls -la", "git status", "git rm tracked.txt", "git push origin main", "git reset HEAD file",
            "git clean -n", "echo 'rm is dangerous'", "grep -r rm .", "docker rm container", "npm run build",
            "python3 -I scripts/x.py", "mv a b", "cp -r a b", "cat rm.txt", "ls ./rm",
            "dd if=/dev/zero bs=1 count=1",
        ]:
            with self.subTest(cmd=cmd):
                self.assertFalse(blocked(cmd), cmd)


NL = "\n"


def heredoc(head, *body, word="EOF", quote="'", tail=""):
    """Build `head <<'EOF'` + body lines + terminator (+ tail) without a heredoc in this source."""
    return head + f" <<{quote}{word}{quote}" + NL + NL.join(body) + NL + word + (NL + tail if tail else "")


class Heredocs(unittest.TestCase):
    """v133: rm that is only heredoc body text is allowed; anything that could run it stays blocked."""

    def test_repro_cases_a_to_e(self):
        gh = 'gh issue create --body "$(cat <<\'EOF\'' + NL
        cases = {
            "A mid-line rm": (gh + "the word rm appears here" + NL + "EOF" + NL + ')"', False),
            "B body line starts with rm": (gh + "rm is mentioned" + NL + "EOF" + NL + ')"', False),
            "C apostrophes in body": (gh + "it's about rm and the user's files" + NL + "EOF" + NL + ')"', False),
            "D echo with quoted rm": ('echo "rm -rf is dangerous"', False),
            "E real rm": ("rm -rf /tmp/aidev-repro-x", True),
        }
        for label, (cmd, want) in cases.items():
            with self.subTest(case=label):
                self.assertEqual(blocked(cmd), want, label)

    def test_data_sinks_allow_rm_text_in_the_body(self):
        for cmd in [
            heredoc("cat", "rm -rf /"),
            heredoc("cat > notes.md", "rm file", "sudo rm -rf x"),
            heredoc("tee notes.md", "rm file"),
            heredoc("gh issue create --title t --body-file -", "rm file"),
            heredoc("git commit -F -", "fix: rm handling", "", "it's fine"),
            heredoc('git commit -m "$(cat', "rm is only text", tail=')"'),
            heredoc("cat", "rm file", quote=""),  # unquoted, but no substitution in the body
            heredoc("cat", "rm file", quote='"'),
            heredoc("cat", "it's", "rm", "isn't", word="END"),
        ]:
            with self.subTest(cmd=cmd):
                self.assertFalse(blocked(cmd), cmd)

    def test_interpreter_heredocs_are_still_analysed(self):
        for cmd in [
            heredoc("bash", "rm file"),
            heredoc("sh", "echo hi", "rm file"),
            heredoc("zsh", "rm -rf x"),
            heredoc("python3", "import os", "os.remove('x')"),
            heredoc("sudo bash", "rm file"),
            heredoc("source /dev/stdin", "rm file"),
            heredoc('bash -c "$(cat', "rm file", tail=')"'),
            heredoc('eval "$(cat', "rm file", tail=')"'),
            heredoc('sh -c "$(cat', "rm file", tail=')"'),
        ]:
            with self.subTest(cmd=cmd):
                self.assertTrue(blocked(cmd), cmd)

    def test_unknown_receiver_fails_closed(self):
        self.assertTrue(blocked(heredoc("somecmd", "rm file")))
        self.assertTrue(blocked(heredoc("ssh host", "rm file")))

    def test_piping_or_chaining_the_body_onward_keeps_it_in_scope(self):
        self.assertTrue(blocked(heredoc("cat", "rm file").replace("<<'EOF'", "<<'EOF' | bash")))
        self.assertTrue(blocked(heredoc("cat", "rm file").replace("<<'EOF'", "<<'EOF' | sh -s")))
        self.assertTrue(blocked(heredoc("cat", "echo hi", tail="rm file")))

    def test_unquoted_heredoc_with_substitution_is_not_skipped(self):
        # An unquoted heredoc expands $( ) and backticks, so those would run.
        self.assertTrue(blocked(heredoc("cat", "$(rm file)", quote="")))
        self.assertTrue(blocked(heredoc("cat", "`rm file`", quote="")))
        # A quoted one does not expand them.
        self.assertFalse(blocked(heredoc("cat", "$(rm file)")))

    def test_missing_terminator_is_not_skipped(self):
        self.assertTrue(blocked("cat <<'EOF'" + NL + "rm file"))

    def test_marker_inside_a_quoted_string_is_not_a_heredoc(self):
        self.assertTrue(blocked('echo "<<EOF"' + NL + "rm file" + NL + "EOF"))
        self.assertTrue(blocked("echo '<<EOF'" + NL + "rm file" + NL + "EOF"))

    def test_real_delete_after_or_around_the_heredoc_still_blocks(self):
        self.assertTrue(blocked(heredoc("cat", "just text", tail="rm file")))
        self.assertTrue(blocked("rm file && " + heredoc("cat", "just text")))
        self.assertTrue(blocked(heredoc("cat", "just text") + " && rm file"))

    def test_dash_heredoc_with_tab_indented_terminator(self):
        cmd = "cat <<-EOF" + NL + "\trm file" + NL + "\tEOF"
        self.assertFalse(blocked(cmd))

    def test_crude_fallback_ignores_identified_heredoc_bodies_only(self):
        # An unbalanced quote in a real command still hits the crude pattern.
        self.assertTrue(blocked("echo 'unterminated; rm file"))
        # An apostrophe inside a recognised data body does not.
        self.assertFalse(blocked(heredoc("cat", "it's about rm", "the user's files")))

    def test_analyze_output_keeps_its_shape(self):
        keys = {"blocked", "reasons", "rm"}
        self.assertEqual(set(guard.analyze(heredoc("cat", "rm file"), CWD)), keys)
        r = guard.analyze(heredoc("bash", "rm file"), CWD)
        self.assertEqual(set(r), keys)
        self.assertTrue(r["blocked"])
        self.assertIsNotNone(r["rm"])


class Listing(unittest.TestCase):
    def test_lists_what_rm_would_remove_including_globs_and_dirs(self):
        with tempfile.TemporaryDirectory() as d:
            for name in ("a.tmp", "b.tmp", "keep.txt"):
                with open(os.path.join(d, name), "w") as f:
                    f.write("x" * 10)
            os.mkdir(os.path.join(d, "sub"))
            with open(os.path.join(d, "sub", "inner.txt"), "w") as f:
                f.write("y")
            r = guard.analyze("rm *.tmp sub missing.txt", d)
            files = {os.path.basename(f["path"]): f for f in r["rm"]["files"]}
            self.assertEqual(set(files), {"a.tmp", "b.tmp", "sub", "missing.txt"})
            self.assertEqual((files["a.tmp"]["kind"], files["a.tmp"]["size"]), ("file", 10))
            self.assertEqual((files["sub"]["kind"], files["sub"]["items"]), ("dir", 1))
            self.assertEqual(files["missing.txt"]["kind"], "missing")
            self.assertTrue(os.path.exists(os.path.join(d, "a.tmp")), "analysis must not remove anything")

    def test_variable_targets_are_reported_unresolved(self):
        self.assertEqual(guard.analyze("rm $TARGET", CWD)["rm"]["unresolved"], ["$TARGET"])


class CommandLine(unittest.TestCase):
    def run_hook(self, command, *flags, env=None):
        payload = json.dumps({"tool_input": {"command": command}, "cwd": CWD})
        e = {**os.environ, **(env or {})}
        return subprocess.run([sys.executable, "-I", SCRIPT, *flags], input=payload, capture_output=True,
                              text=True, timeout=30, env=e)

    def test_blocked_exits_2_with_message_on_stderr(self):
        p = self.run_hook("rm -rf build")
        self.assertEqual(p.returncode, 2)
        self.assertIn("BLOCKED", p.stderr)
        self.assertIn("Nothing was run", p.stderr)
        self.assertEqual(p.stdout, "")

    def test_allowed_exits_0_silently(self):
        p = self.run_hook("ls -la")
        self.assertEqual((p.returncode, p.stdout, p.stderr), (0, "", ""))

    def test_analyze_prints_json_and_exits_0(self):
        p = self.run_hook("rm -f x", "--analyze")
        self.assertEqual(p.returncode, 0)
        out = json.loads(p.stdout)
        self.assertTrue(out["blocked"])
        self.assertTrue(out["rm"]["force"])

    def test_garbage_input_does_not_block(self):
        p = subprocess.run([sys.executable, "-I", SCRIPT], input="not json", capture_output=True, text=True, timeout=30)
        self.assertEqual(p.returncode, 0)

    def test_missing_command_does_not_block(self):
        p = subprocess.run([sys.executable, "-I", SCRIPT], input=json.dumps({"tool_input": {}}), capture_output=True,
                           text=True, timeout=30)
        self.assertEqual(p.returncode, 0)

    def test_the_person_can_switch_it_off_from_the_environment(self):
        p = self.run_hook("rm -rf build", env={"AIDEV_DESTRUCTIVE_GUARD": "off"})
        self.assertEqual(p.returncode, 0)

    def test_a_command_cannot_switch_it_off_for_itself(self):
        p = self.run_hook("AIDEV_DESTRUCTIVE_GUARD=off rm -rf build", env={"AIDEV_DESTRUCTIVE_GUARD": ""})
        self.assertEqual(p.returncode, 2)

    def test_analyze_still_works_when_switched_off(self):
        p = self.run_hook("rm x", "--analyze", env={"AIDEV_DESTRUCTIVE_GUARD": "off"})
        self.assertTrue(json.loads(p.stdout)["blocked"])


def _configure_functions():
    """Every configure_* function defined in install.sh, keyed by name (real source text)."""
    with open(INSTALL) as f:
        text = f.read()
    found = dict(
        (m.group(1), m.group(0))
        for m in re.finditer(r"^(configure_[A-Za-z0-9_]+)\(\) \{.*?^\}", text, re.S | re.M)
    )
    assert found, "no configure_* functions found in install.sh"
    return found


GUARD_SCRIPT = "guard-destructive-commands.py"

EXISTING = {
    "env": {"X": "1"},
    "hooks": {
        "PreToolUse": [
            {"matcher": "Bash", "hooks": [{"type": "command", "command": "jq . >> /tmp/log.txt"}]},
            {"matcher": "Write|Edit", "hooks": [{"type": "command", "command": "echo edit"}]},
        ],
        "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "echo hi"}]}],
    },
}


class InstallerLeavesGuardOut(unittest.TestCase):
    """v136: the toolkit installer and uninstaller no longer wire this guard into settings.json.

    Real install.sh functions run against a real temporary HOME. The uninstaller keeps one cleanup
    step (spec v136 Open Question 3): it removes a toolkit guard entry an earlier install wrote, and
    nothing else. /aid-update does not remove it.
    """

    def run_function(self, name, home):
        fns = _configure_functions()
        return subprocess.run(
            ["bash", "-c", fns[name] + "\n" + name],
            env={**os.environ, "HOME": home}, capture_output=True, text=True, timeout=60,
        )

    def settings(self, home):
        with open(os.path.join(home, ".claude", "settings.json")) as f:
            return json.load(f)

    def write_settings(self, home, data):
        os.makedirs(os.path.join(home, ".claude"), exist_ok=True)
        with open(os.path.join(home, ".claude", "settings.json"), "w") as f:
            json.dump(data, f)

    def hook_commands(self, s):
        return [h.get("command", "") for entries in s.get("hooks", {}).values() for e in entries for h in e.get("hooks", [])]

    def test_install_has_no_guard_function_or_step(self):
        with open(INSTALL) as f:
            text = f.read()
        self.assertNotIn("configure_destructive_guard_hook", text)
        self.assertNotIn(GUARD_SCRIPT, text)
        self.assertNotIn("Configuring destructive-command guard hook", text)

    def run_uninstall_guard_block(self, home):
        with open(UNINSTALL) as f:
            text = f.read()
        marker = "Removing destructive-command guard hook"
        self.assertIn(marker, text)
        block = text.split(marker, 1)[1].split("<< 'PYTHON_SCRIPT'\n", 1)[1].split("\nPYTHON_SCRIPT", 1)[0]
        return subprocess.run(
            ["python3", "-I", "-c", block],
            env={**os.environ, "HOME": home}, capture_output=True, text=True, timeout=60,
        )

    def test_uninstall_removes_only_the_toolkit_guard_entry(self):
        toolkit = {"type": "command", "command": "python3 ~/.claude/aidev-toolkit/scripts/" + GUARD_SCRIPT}
        with tempfile.TemporaryDirectory() as home:
            data = json.loads(json.dumps(EXISTING))
            data["hooks"]["PreToolUse"].append({"matcher": "Bash", "hooks": [toolkit]})
            self.write_settings(home, data)
            p = self.run_uninstall_guard_block(home)
            self.assertEqual(p.returncode, 0, p.stderr)
            s = self.settings(home)
            self.assertFalse([c for c in self.hook_commands(s) if GUARD_SCRIPT in c])
            self.assertEqual(s, EXISTING)  # the maintainer's own hooks are untouched

    def test_uninstall_leaves_settings_alone_when_no_toolkit_guard_entry(self):
        with tempfile.TemporaryDirectory() as home:
            self.write_settings(home, json.loads(json.dumps(EXISTING)))
            p = self.run_uninstall_guard_block(home)
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertEqual(self.settings(home), EXISTING)

    def test_uninstall_without_settings_file_is_a_no_op(self):
        with tempfile.TemporaryDirectory() as home:
            p = self.run_uninstall_guard_block(home)
            self.assertEqual(p.returncode, 0, p.stderr)

    def test_every_configure_function_leaves_the_guard_out(self):
        for name in _configure_functions():
            with self.subTest(function=name):
                with tempfile.TemporaryDirectory() as home:
                    self.write_settings(home, json.loads(json.dumps(EXISTING)))
                    p = self.run_function(name, home)
                    self.assertEqual(p.returncode, 0, p.stderr)
                    s = self.settings(home)
                    self.assertFalse([c for c in self.hook_commands(s) if GUARD_SCRIPT in c], name)
                    # The maintainer's own hooks are left exactly as they were.
                    for entry in EXISTING["hooks"]["PreToolUse"]:
                        for hook in entry["hooks"]:
                            self.assertIn(hook["command"], self.hook_commands(s))

    def test_a_fresh_home_gets_no_guard_hook_from_any_function(self):
        with tempfile.TemporaryDirectory() as home:
            os.makedirs(os.path.join(home, ".claude"))
            for name in _configure_functions():
                self.run_function(name, home)
            path = os.path.join(home, ".claude", "settings.json")
            if os.path.exists(path):
                self.assertFalse([c for c in self.hook_commands(self.settings(home)) if GUARD_SCRIPT in c])

    def test_the_failure_test_lists_exactly_the_functions_install_defines(self):
        with open(os.path.join(HERE, "test-install-configure-failure.sh")) as f:
            text = f.read()
        listed = set(re.findall(r"configure_[A-Za-z0-9_]+", text.split("for fn in", 1)[1].split("; do", 1)[0]))
        self.assertEqual(listed, set(_configure_functions()))


if __name__ == "__main__":
    unittest.main(verbosity=1)
