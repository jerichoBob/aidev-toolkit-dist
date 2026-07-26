#!/bin/bash
#
# tests/test-installer-copies.sh
#
# Verifies that install.sh copies skill files as real files (not symlinks)
# so that tools like Ollama can import from ~/.claude/skills without errors.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_HOME=$(mktemp -d)
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

check() {
    if eval "$1"; then
        pass "$2"
    else
        fail "$2"
    fi
}

cleanup() {
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

echo ""
echo "Installer Portability Tests (copy-not-symlink)"
echo "==============================================="
echo "Test HOME: $TEST_HOME"
echo ""

if [ -z "${GH_TOKEN:-}" ]; then
    GH_TOKEN="$(gh auth token 2>/dev/null || true)"
    export GH_TOKEN
fi

export HOME="$TEST_HOME"
mkdir -p "$TEST_HOME/.claude"
cp -r "$REPO_DIR" "$TEST_HOME/.claude/aidev-toolkit"

"$REPO_DIR/scripts/install.sh" --quiet > /dev/null

# Test 1: No symlinks anywhere in skills/ or commands/
echo "Test 1: Zero symlinks after install..."
SYMLINKS=$(find "$TEST_HOME/.claude/commands" "$TEST_HOME/.claude/skills" -type l 2>/dev/null | wc -l | tr -d ' ')
check '[ "$SYMLINKS" -eq 0 ]' "No symlinks in commands/ (found: $SYMLINKS)"
SYMLINKS_S=$(find "$TEST_HOME/.claude/skills" -type l 2>/dev/null | wc -l | tr -d ' ')
check '[ "$SYMLINKS_S" -eq 0 ]' "No symlinks in skills/ (found: $SYMLINKS_S)"

# Test 2: Spot-check that key skills are real regular files
echo ""
echo "Test 2: Skill files are real regular files..."
for skill in aid.md commit.md sdd-code.md sdd-spec.md lint.md screenshots.md; do
    check '[ -f "$TEST_HOME/.claude/skills/'"$skill"'" ] && [ ! -L "$TEST_HOME/.claude/skills/'"$skill"'" ]' "$skill is a real file in skills/"
    check '[ -f "$TEST_HOME/.claude/commands/'"$skill"'" ] && [ ! -L "$TEST_HOME/.claude/commands/'"$skill"'" ]' "$skill is a real file in commands/"
done

# Test 3: Re-install over symlinks replaces them with real files
echo ""
echo "Test 3: Re-install replaces any pre-existing symlinks..."
DUMMY=$(mktemp)
echo "old content" > "$DUMMY"
rm -f "$TEST_HOME/.claude/skills/aid.md" "$TEST_HOME/.claude/commands/aid.md"
ln -s "$DUMMY" "$TEST_HOME/.claude/skills/aid.md"
ln -s "$DUMMY" "$TEST_HOME/.claude/commands/aid.md"
check '[ -L "$TEST_HOME/.claude/skills/aid.md" ]' "Pre-existing symlink planted in skills/"
check '[ -L "$TEST_HOME/.claude/commands/aid.md" ]' "Pre-existing symlink planted in commands/"
"$REPO_DIR/scripts/install.sh" --quiet > /dev/null
check '[ -f "$TEST_HOME/.claude/skills/aid.md" ] && [ ! -L "$TEST_HOME/.claude/skills/aid.md" ]' "Symlink in skills/ replaced with real file"
check '[ -f "$TEST_HOME/.claude/commands/aid.md" ] && [ ! -L "$TEST_HOME/.claude/commands/aid.md" ]' "Symlink in commands/ replaced with real file"
rm -f "$DUMMY"

# Test 4: File content matches source (not a stale copy)
echo ""
echo "Test 4: Copied file content matches source..."
SOURCE_HASH=$(md5 -q "$REPO_DIR/skills/aid.md" 2>/dev/null || md5sum "$REPO_DIR/skills/aid.md" | awk '{print $1}')
DEST_HASH=$(md5 -q "$TEST_HOME/.claude/skills/aid.md" 2>/dev/null || md5sum "$TEST_HOME/.claude/skills/aid.md" | awk '{print $1}')
check '[ "$SOURCE_HASH" = "$DEST_HASH" ]' "aid.md content matches source"

# Summary
echo ""
echo "==============================================="
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
