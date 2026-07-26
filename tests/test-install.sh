#!/bin/bash
#
# aidev toolkit Installation Tests
#
# Validates install/uninstall scripts work correctly using an isolated test environment.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_HOME=$(mktemp -d)
PASS=0
FAIL=0

# Helper functions
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
echo "aidev toolkit Installation Tests"
echo "==============================="
echo "Test HOME: $TEST_HOME"
echo ""

# Export current gh token so install.sh auth check passes under overridden HOME
# (macOS stores gh credentials in Keychain, not in ~/.config/gh, so HOME override
# would otherwise trigger an interactive gh auth login prompt)
if [ -z "${GH_TOKEN:-}" ]; then
    GH_TOKEN="$(gh auth token 2>/dev/null || true)"
    export GH_TOKEN
fi

ORIGINAL_HOME="$HOME"

# Override HOME for testing
export HOME="$TEST_HOME"

# For testing, copy local repo instead of cloning from GitHub
# This allows testing uncommitted changes
mkdir -p "$TEST_HOME/.claude"
cp -r "$REPO_DIR" "$TEST_HOME/.claude/aidev-toolkit"

# Test 1: Fresh install — files are real copies, not symlinks
echo "Test 1: Fresh install..."
"$REPO_DIR/scripts/install.sh" --quiet > /dev/null
check '[ -d "$TEST_HOME/.claude/aidev-toolkit" ]' "Toolkit directory created"
check '[ -f "$TEST_HOME/.claude/commands/aid.md" ] && [ ! -L "$TEST_HOME/.claude/commands/aid.md" ]' "aid.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/inspect.md" ] && [ ! -L "$TEST_HOME/.claude/commands/inspect.md" ]' "inspect.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/arch-review.md" ] && [ ! -L "$TEST_HOME/.claude/commands/arch-review.md" ]' "arch-review.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/should-i-trust-it.md" ] && [ ! -L "$TEST_HOME/.claude/commands/should-i-trust-it.md" ]' "should-i-trust-it.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/commit.md" ] && [ ! -L "$TEST_HOME/.claude/commands/commit.md" ]' "commit.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/commit-push.md" ] && [ ! -L "$TEST_HOME/.claude/commands/commit-push.md" ]' "commit-push.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/code-stats.md" ] && [ ! -L "$TEST_HOME/.claude/commands/code-stats.md" ]' "code-stats.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/aid-update.md" ] && [ ! -L "$TEST_HOME/.claude/commands/aid-update.md" ]' "aid-update.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/aid-feedback.md" ] && [ ! -L "$TEST_HOME/.claude/commands/aid-feedback.md" ]' "aid-feedback.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/aid-login.md" ] && [ ! -L "$TEST_HOME/.claude/commands/aid-login.md" ]' "aid-login.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/docs-update.md" ] && [ ! -L "$TEST_HOME/.claude/commands/docs-update.md" ]' "docs-update.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/sdlc-plan.md" ] && [ ! -L "$TEST_HOME/.claude/commands/sdlc-plan.md" ]' "sdlc-plan.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/deal-desk.md" ] && [ ! -L "$TEST_HOME/.claude/commands/deal-desk.md" ]' "deal-desk.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/lint.md" ] && [ ! -L "$TEST_HOME/.claude/commands/lint.md" ]' "lint.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/screenshots.md" ] && [ ! -L "$TEST_HOME/.claude/commands/screenshots.md" ]' "screenshots.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/sdd-code.md" ] && [ ! -L "$TEST_HOME/.claude/commands/sdd-code.md" ]' "sdd-code.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/sdd-code-spec.md" ] && [ ! -L "$TEST_HOME/.claude/commands/sdd-code-spec.md" ]' "sdd-code-spec.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/sdd-spec.md" ] && [ ! -L "$TEST_HOME/.claude/commands/sdd-spec.md" ]' "sdd-spec.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/sdd-specs.md" ] && [ ! -L "$TEST_HOME/.claude/commands/sdd-specs.md" ]' "sdd-specs.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/sdd-specs-update.md" ] && [ ! -L "$TEST_HOME/.claude/commands/sdd-specs-update.md" ]' "sdd-specs-update.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/sdd-spec-tagging.md" ] && [ ! -L "$TEST_HOME/.claude/commands/sdd-spec-tagging.md" ]' "sdd-spec-tagging.md copied (not symlinked)"
check '[ -f "$TEST_HOME/.claude/commands/sdd-specs-doctor.md" ] && [ ! -L "$TEST_HOME/.claude/commands/sdd-specs-doctor.md" ]' "sdd-specs-doctor.md copied (not symlinked)"

# Test 2: Verify skills/ dir also gets real files
echo ""
echo "Test 2: Skills dir has real files..."
check '[ -f "$TEST_HOME/.claude/skills/aid.md" ] && [ ! -L "$TEST_HOME/.claude/skills/aid.md" ]' "aid.md in skills/ (not symlinked)"
check '[ -f "$TEST_HOME/.claude/skills/sdd-code.md" ] && [ ! -L "$TEST_HOME/.claude/skills/sdd-code.md" ]' "sdd-code.md in skills/ (not symlinked)"
check '[ -f "$TEST_HOME/.claude/skills/commit.md" ] && [ ! -L "$TEST_HOME/.claude/skills/commit.md" ]' "commit.md in skills/ (not symlinked)"

# Test 3: No symlinks at all in skills/ or commands/ after install
echo ""
echo "Test 3: No symlinks in installed dirs..."
SYMLINKS=$(find "$TEST_HOME/.claude/commands" "$TEST_HOME/.claude/skills" -type l 2>/dev/null | wc -l | tr -d ' ')
check '[ "$SYMLINKS" -eq 0 ]' "Zero symlinks in commands/ and skills/ (found: $SYMLINKS)"

# Test 4: Idempotency — re-install replaces files cleanly
echo ""
echo "Test 4: Idempotent install..."
"$REPO_DIR/scripts/install.sh" --quiet > /dev/null
check '[ -f "$TEST_HOME/.claude/commands/aid.md" ] && [ ! -L "$TEST_HOME/.claude/commands/aid.md" ]' "Files still real after re-install"
SYMLINKS2=$(find "$TEST_HOME/.claude/commands" "$TEST_HOME/.claude/skills" -type l 2>/dev/null | wc -l | tr -d ' ')
check '[ "$SYMLINKS2" -eq 0 ]' "Still zero symlinks after re-install"

# Test 5: Symlink migration — if a symlink exists before install, it gets replaced with a real file
echo ""
echo "Test 5: Replaces pre-existing symlinks with real files..."
DUMMY=$(mktemp)
echo "dummy" > "$DUMMY"
rm -f "$TEST_HOME/.claude/commands/aid.md"
ln -s "$DUMMY" "$TEST_HOME/.claude/commands/aid.md"
check '[ -L "$TEST_HOME/.claude/commands/aid.md" ]' "Pre-existing symlink planted for aid.md"
"$REPO_DIR/scripts/install.sh" --quiet > /dev/null
check '[ -f "$TEST_HOME/.claude/commands/aid.md" ] && [ ! -L "$TEST_HOME/.claude/commands/aid.md" ]' "Symlink replaced with real file by re-install"
rm -f "$DUMMY"

# Test 6: Uninstall
echo ""
echo "Test 6: Uninstall..."
"$REPO_DIR/scripts/uninstall.sh" --quiet
check '[ ! -e "$TEST_HOME/.claude/commands/aid.md" ]' "aid.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/inspect.md" ]' "inspect.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/arch-review.md" ]' "arch-review.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/should-i-trust-it.md" ]' "should-i-trust-it.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/commit.md" ]' "commit.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/commit-push.md" ]' "commit-push.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/code-stats.md" ]' "code-stats.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/aid-update.md" ]' "aid-update.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/aid-feedback.md" ]' "aid-feedback.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/aid-login.md" ]' "aid-login.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/docs-update.md" ]' "docs-update.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/sdlc-plan.md" ]' "sdlc-plan.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/deal-desk.md" ]' "deal-desk.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/lint.md" ]' "lint.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/screenshots.md" ]' "screenshots.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/sdd-code.md" ]' "sdd-code.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/sdd-code-spec.md" ]' "sdd-code-spec.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/sdd-spec.md" ]' "sdd-spec.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/sdd-specs.md" ]' "sdd-specs.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/sdd-specs-update.md" ]' "sdd-specs-update.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/sdd-spec-tagging.md" ]' "sdd-spec-tagging.md removed"
check '[ ! -e "$TEST_HOME/.claude/commands/sdd-specs-doctor.md" ]' "sdd-specs-doctor.md removed"
check '[ ! -d "$TEST_HOME/.claude/aidev-toolkit" ]' "Toolkit directory removed"

# Summary
echo ""
echo "==============================="
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
