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


def _installer_function():
    with open(INSTALL) as f:
        text = f.read()
    m = re.search(r"^configure_destructive_guard_hook\(\) \{.*?^\}", text, re.S | re.M)
    assert m, "configure_destructive_guard_hook not found in install.sh"
    return m.group(0)


def _uninstall_python():
    with open(UNINSTALL) as f:
        text = f.read()
    section = text.split("# Remove destructive-command guard hook from settings.json", 1)[1].split("# Remove toolkit directory", 1)[0]
    m = re.search(r"<< 'PYTHON_SCRIPT'\n(.*?)\nPYTHON_SCRIPT", section, re.S)
    assert m, "uninstall python block not found"
    return m.group(1)


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


class InstallAndUninstall(unittest.TestCase):
    def install(self, home):
        return subprocess.run(
            ["bash", "-c", _installer_function() + "\nconfigure_destructive_guard_hook"],
            env={**os.environ, "HOME": home}, capture_output=True, text=True, timeout=30,
        )

    def settings(self, home):
        with open(os.path.join(home, ".claude", "settings.json")) as f:
            return json.load(f)

    def write_settings(self, home, data):
        os.makedirs(os.path.join(home, ".claude"), exist_ok=True)
        with open(os.path.join(home, ".claude", "settings.json"), "w") as f:
            json.dump(data, f)

    def guard_commands(self, s):
        return [h["command"] for e in s["hooks"]["PreToolUse"] for h in e["hooks"] if "guard-destructive-commands.py" in h["command"]]

    def test_install_into_existing_settings_keeps_everything_and_adds_one_hook(self):
        with tempfile.TemporaryDirectory() as home:
            self.write_settings(home, json.loads(json.dumps(EXISTING)))
            p = self.install(home)
            self.assertEqual(p.returncode, 0, p.stderr)
            s = self.settings(home)
            self.assertEqual(s["env"], {"X": "1"})
            self.assertEqual(s["hooks"]["UserPromptSubmit"], EXISTING["hooks"]["UserPromptSubmit"])
            self.assertEqual(s["hooks"]["PreToolUse"][1], EXISTING["hooks"]["PreToolUse"][1])
            bash = s["hooks"]["PreToolUse"][0]
            self.assertEqual(bash["hooks"][0], EXISTING["hooks"]["PreToolUse"][0]["hooks"][0])
            self.assertEqual(
                self.guard_commands(s), ["python3 -I ~/.claude/aidev-toolkit/scripts/guard-destructive-commands.py"]
            )

    def test_install_is_idempotent(self):
        with tempfile.TemporaryDirectory() as home:
            self.write_settings(home, json.loads(json.dumps(EXISTING)))
            self.install(home)
            self.install(home)
            self.assertEqual(len(self.guard_commands(self.settings(home))), 1)

    def test_install_with_no_settings_file_creates_one(self):
        with tempfile.TemporaryDirectory() as home:
            os.makedirs(os.path.join(home, ".claude"))
            p = self.install(home)
            self.assertEqual(p.returncode, 0, p.stderr)
            s = self.settings(home)
            self.assertEqual(s["hooks"]["PreToolUse"][0]["matcher"], "Bash")
            self.assertEqual(len(self.guard_commands(s)), 1)

    def test_uninstall_removes_only_the_guard(self):
        with tempfile.TemporaryDirectory() as home:
            self.write_settings(home, json.loads(json.dumps(EXISTING)))
            self.install(home)
            p = subprocess.run([sys.executable, "-c", _uninstall_python()], env={**os.environ, "HOME": home},
                               capture_output=True, text=True, timeout=30)
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertEqual(self.settings(home), EXISTING)

    def test_uninstall_drops_an_entry_it_leaves_empty(self):
        with tempfile.TemporaryDirectory() as home:
            os.makedirs(os.path.join(home, ".claude"))
            self.install(home)
            subprocess.run([sys.executable, "-c", _uninstall_python()], env={**os.environ, "HOME": home},
                           capture_output=True, text=True, timeout=30, check=True)
            self.assertNotIn("PreToolUse", self.settings(home).get("hooks", {}))

    def test_uninstall_without_settings_is_a_no_op(self):
        with tempfile.TemporaryDirectory() as home:
            p = subprocess.run([sys.executable, "-c", _uninstall_python()], env={**os.environ, "HOME": home},
                               capture_output=True, text=True, timeout=30)
            self.assertEqual(p.returncode, 0, p.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=1)
