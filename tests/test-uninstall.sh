#!/bin/bash
#
# Integration tests for scripts/uninstall.sh
# Runs the real script against a temp HOME fixture — no mocks, no stubs.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
UNINSTALL="$REPO_DIR/scripts/uninstall.sh"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

if [ ! -f "$UNINSTALL" ]; then
    echo "BLOCKED: scripts/uninstall.sh not found"
    exit 0
fi

echo ""
echo "Test: scripts/uninstall.sh integration (v68)"

# Set up temp HOME with a fake aidev-toolkit installation
TMPDIR_HOME=$(mktemp -d)
trap 'rm -rf "$TMPDIR_HOME"' EXIT

FAKE_TOOLKIT="$TMPDIR_HOME/.claude/aidev-toolkit"
FAKE_SKILLS_SRC="$FAKE_TOOLKIT/skills"
COMMANDS_DIR="$TMPDIR_HOME/.claude/commands"
SKILLS_DIR="$TMPDIR_HOME/.claude/skills"

mkdir -p "$FAKE_SKILLS_SRC" "$COMMANDS_DIR" "$SKILLS_DIR"

# Create fake skill files in the toolkit
echo "# fake skill" > "$FAKE_SKILLS_SRC/aid.md"
echo "# fake skill" > "$FAKE_SKILLS_SRC/inspect.md"

# Create toolkit symlinks in commands/ and skills/
ln -s "$FAKE_SKILLS_SRC/aid.md" "$COMMANDS_DIR/aid.md"
ln -s "$FAKE_SKILLS_SRC/inspect.md" "$COMMANDS_DIR/inspect.md"
ln -s "$FAKE_SKILLS_SRC/aid.md" "$SKILLS_DIR/aid.md"
ln -s "$FAKE_SKILLS_SRC/inspect.md" "$SKILLS_DIR/inspect.md"

# Create a non-toolkit decoy file in commands/ (should NOT be removed)
echo "# decoy" > "$COMMANDS_DIR/my-custom-skill.md"
echo "# decoy" > "$SKILLS_DIR/my-custom-skill.md"

# Test 1: Toolkit symlinks exist before uninstall
if [ -L "$COMMANDS_DIR/aid.md" ] && [ -L "$SKILLS_DIR/aid.md" ]; then
    pass "Pre-condition: toolkit symlinks exist in commands/ and skills/"
else
    fail "Pre-condition: toolkit symlinks not set up correctly"
fi

# Run uninstall
HOME="$TMPDIR_HOME" bash "$UNINSTALL" --quiet 2>&1

# Test 2: Toolkit symlinks removed from commands/
if [ ! -e "$COMMANDS_DIR/aid.md" ] && [ ! -e "$COMMANDS_DIR/inspect.md" ]; then
    pass "commands/: toolkit symlinks removed"
else
    fail "commands/: toolkit symlinks still present"
fi

# Test 3: Toolkit symlinks removed from skills/
if [ ! -e "$SKILLS_DIR/aid.md" ] && [ ! -e "$SKILLS_DIR/inspect.md" ]; then
    pass "skills/: toolkit symlinks removed"
else
    fail "skills/: toolkit symlinks still present"
fi

# Test 4: Decoy files preserved in commands/
if [ -f "$COMMANDS_DIR/my-custom-skill.md" ]; then
    pass "commands/: decoy file preserved"
else
    fail "commands/: decoy file was incorrectly removed"
fi

# Test 5: Decoy files preserved in skills/
if [ -f "$SKILLS_DIR/my-custom-skill.md" ]; then
    pass "skills/: decoy file preserved"
else
    fail "skills/: decoy file was incorrectly removed"
fi

# Test 6: Parent directories (commands/ and skills/) preserved
if [ -d "$COMMANDS_DIR" ] && [ -d "$SKILLS_DIR" ]; then
    pass "Parent directories commands/ and skills/ preserved"
else
    fail "Parent directories removed (should be preserved)"
fi

# Test 7: Toolkit directory removed
if [ ! -d "$FAKE_TOOLKIT" ]; then
    pass "Toolkit directory removed"
else
    fail "Toolkit directory still present after uninstall"
fi

# Test 8: Idempotent — second run is a no-op (no errors)
HOME="$TMPDIR_HOME" bash "$UNINSTALL" --quiet 2>&1 && idempotent_ok=true || idempotent_ok=false
if [ "$idempotent_ok" = "true" ]; then
    pass "Idempotent: second uninstall run exits cleanly"
else
    fail "Idempotent: second uninstall run errored"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
