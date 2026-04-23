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

# Test 1: Fresh install (symlink creation)
echo "Test 1: Fresh install..."
"$REPO_DIR/scripts/install.sh" --quiet > /dev/null
check '[ -d "$TEST_HOME/.claude/aidev-toolkit" ]' "Toolkit directory created"
check '[ -L "$TEST_HOME/.claude/commands/aid.md" ]' "aid.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/inspect.md" ]' "inspect.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/arch-review.md" ]' "arch-review.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/should-i-trust-it.md" ]' "should-i-trust-it.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/commit.md" ]' "commit.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/commit-push.md" ]' "commit-push.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/code-stats.md" ]' "code-stats.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/aid-update.md" ]' "aid-update.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/aid-feedback.md" ]' "aid-feedback.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/aid-login.md" ]' "aid-login.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/docs-update.md" ]' "docs-update.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/sdlc-plan.md" ]' "sdlc-plan.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/deal-desk.md" ]' "deal-desk.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/lint.md" ]' "lint.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/screenshots.md" ]' "screenshots.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/sdd-code.md" ]' "sdd-code.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/sdd-code-phase.md" ]' "sdd-code-phase.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/sdd-code-spec.md" ]' "sdd-code-spec.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/sdd-next.md" ]' "sdd-next.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/sdd-next-phase.md" ]' "sdd-next-phase.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/sdd-spec.md" ]' "sdd-spec.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/sdd-specs.md" ]' "sdd-specs.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/sdd-specs-update.md" ]' "sdd-specs-update.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/sdd-spec-tagging.md" ]' "sdd-spec-tagging.md symlink created"
check '[ -L "$TEST_HOME/.claude/commands/sdd-specs-doctor.md" ]' "sdd-specs-doctor.md symlink created"

# Test 2: Symlinks point to real files
echo ""
echo "Test 2: Symlinks resolve to files..."
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/aid.md")" ]' "aid.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/inspect.md")" ]' "inspect.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/arch-review.md")" ]' "arch-review.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/should-i-trust-it.md")" ]' "should-i-trust-it.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/commit.md")" ]' "commit.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/commit-push.md")" ]' "commit-push.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/code-stats.md")" ]' "code-stats.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/aid-update.md")" ]' "aid-update.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/aid-feedback.md")" ]' "aid-feedback.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/aid-login.md")" ]' "aid-login.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/docs-update.md")" ]' "docs-update.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/sdlc-plan.md")" ]' "sdlc-plan.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/deal-desk.md")" ]' "deal-desk.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/lint.md")" ]' "lint.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/screenshots.md")" ]' "screenshots.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/sdd-code.md")" ]' "sdd-code.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/sdd-code-phase.md")" ]' "sdd-code-phase.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/sdd-code-spec.md")" ]' "sdd-code-spec.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/sdd-next.md")" ]' "sdd-next.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/sdd-next-phase.md")" ]' "sdd-next-phase.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/sdd-spec.md")" ]' "sdd-spec.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/sdd-specs.md")" ]' "sdd-specs.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/sdd-specs-update.md")" ]' "sdd-specs-update.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/sdd-spec-tagging.md")" ]' "sdd-spec-tagging.md resolves"
check '[ -f "$(readlink -f "$TEST_HOME/.claude/commands/sdd-specs-doctor.md")" ]' "sdd-specs-doctor.md resolves"

# Test 3: Idempotency - run install again
echo ""
echo "Test 3: Idempotent install..."
"$REPO_DIR/scripts/install.sh" --quiet > /dev/null
check '[ -L "$TEST_HOME/.claude/commands/aid.md" ]' "Symlinks still valid after re-install"

# Test 4: Uninstall
echo ""
echo "Test 4: Uninstall..."
"$REPO_DIR/scripts/uninstall.sh" --quiet
check '[ ! -L "$TEST_HOME/.claude/commands/aid.md" ]' "aid.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/inspect.md" ]' "inspect.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/arch-review.md" ]' "arch-review.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/should-i-trust-it.md" ]' "should-i-trust-it.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/commit.md" ]' "commit.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/commit-push.md" ]' "commit-push.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/code-stats.md" ]' "code-stats.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/aid-update.md" ]' "aid-update.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/aid-feedback.md" ]' "aid-feedback.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/aid-login.md" ]' "aid-login.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/docs-update.md" ]' "docs-update.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/sdlc-plan.md" ]' "sdlc-plan.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/deal-desk.md" ]' "deal-desk.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/lint.md" ]' "lint.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/screenshots.md" ]' "screenshots.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/sdd-code.md" ]' "sdd-code.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/sdd-code-phase.md" ]' "sdd-code-phase.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/sdd-code-spec.md" ]' "sdd-code-spec.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/sdd-next.md" ]' "sdd-next.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/sdd-next-phase.md" ]' "sdd-next-phase.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/sdd-spec.md" ]' "sdd-spec.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/sdd-specs.md" ]' "sdd-specs.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/sdd-specs-update.md" ]' "sdd-specs-update.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/sdd-spec-tagging.md" ]' "sdd-spec-tagging.md symlink removed"
check '[ ! -L "$TEST_HOME/.claude/commands/sdd-specs-doctor.md" ]' "sdd-specs-doctor.md symlink removed"
check '[ ! -d "$TEST_HOME/.claude/aidev-toolkit" ]' "Toolkit directory removed"

# Summary
echo ""
echo "==============================="
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
