#!/bin/bash
#
# aidev toolkit version-bump Author Attribution Tests
#
# Validates the author-email resolution logic documented in
# skills/version-bump.md Step 6 (user-email.sh get -> git config user.email
# fallback -> unset) and the resulting release-header format. Runs the exact
# resolution snippet from the skill file against isolated HOME/git config —
# no mocks, no real ~/.claude/aidev-toolkit mutation.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
USER_EMAIL_SCRIPT="$REPO_DIR/modules/sdd/scripts/user-email.sh"

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

TEST_HOME=$(mktemp -d)
cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

export HOME="$TEST_HOME"
TOOLKIT_DIR="$TEST_HOME/.claude/aidev-toolkit"
mkdir -p "$TOOLKIT_DIR"

# Resolution snippet — exact logic from skills/version-bump.md Step 6
resolve_author() {
    local author_email
    author_email=$("$USER_EMAIL_SCRIPT" get 2>/dev/null)
    [ -z "$author_email" ] && author_email=$(git config user.email 2>/dev/null || true)
    echo "$author_email"
}

# Header-format helper — mirrors the skill's template logic from AC-1/AC-2
render_header() {
    local version="$1" date="$2" author="$3"
    if [ -n "$author" ]; then
        echo "#### v${version} (${date}) — author: ${author}"
    else
        echo "#### v${version} (${date})"
    fi
}

echo ""
echo "aidev toolkit version-bump Author Attribution Tests"
echo "====================================================="

# ── Test: email resolved via user-email.sh ──────────────────────────────────
echo ""
echo "Test: author resolved via user-email.sh get..."
"$USER_EMAIL_SCRIPT" set "toolkit-user@example.com"
git config --global user.email "gitconfig-user@example.com" 2>/dev/null || true
result=$(resolve_author)
if [ "$result" = "toolkit-user@example.com" ]; then
    pass "user-email.sh value takes priority over git config"
else
    fail "expected toolkit-user@example.com, got '$result'"
fi

header=$(render_header "1.2.3" "2026-09-01" "$result")
if [ "$header" = "#### v1.2.3 (2026-09-01) — author: toolkit-user@example.com" ]; then
    pass "release header includes user-email.sh author"
else
    fail "unexpected header: $header"
fi

# ── Test: git config fallback when user-email.sh has none ───────────────────
echo ""
echo "Test: author resolved via git config user.email fallback..."
rm -f "$TOOLKIT_DIR/.user-email" "$TOOLKIT_DIR/.auth"
result=$(resolve_author)
if [ "$result" = "gitconfig-user@example.com" ]; then
    pass "falls back to git config user.email when user-email.sh is empty"
else
    fail "expected gitconfig-user@example.com, got '$result'"
fi

header=$(render_header "1.2.4" "2026-09-01" "$result")
if [ "$header" = "#### v1.2.4 (2026-09-01) — author: gitconfig-user@example.com" ]; then
    pass "release header includes git-config fallback author"
else
    fail "unexpected header: $header"
fi

# ── Test: no email available anywhere — suffix omitted ──────────────────────
echo ""
echo "Test: no email available — header omits author suffix..."
rm -f "$TOOLKIT_DIR/.user-email" "$TOOLKIT_DIR/.auth"
GIT_CONFIG_GLOBAL="$TEST_HOME/empty-gitconfig" git config --global --unset user.email 2>/dev/null || true
HOME="$TEST_HOME" git config --global --unset user.email 2>/dev/null || true
result=$(resolve_author)
if [ -z "$result" ]; then
    pass "resolve_author returns empty when no source has an email"
else
    fail "expected empty result, got '$result'"
fi

header=$(render_header "1.2.5" "2026-09-01" "$result")
if [ "$header" = "#### v1.2.5 (2026-09-01)" ]; then
    pass "release header omits author suffix entirely (no blank/placeholder)"
else
    fail "unexpected header: $header"
fi

# ── Test: older entries without author suffix remain untouched (AC-3) ───────
echo ""
echo "Test: existing changelog entries without author suffix untouched..."
CHANGELOG="$TEST_HOME/CHANGELOG.md"
cat > "$CHANGELOG" <<'EOF'
#### v1.2.2 (2026-08-01)

- fix: Old entry with no author suffix [`abc1234`]
EOF
before_old_section=$(cat "$CHANGELOG")
new_header=$(render_header "1.2.6" "2026-09-01" "toolkit-user@example.com")
{ echo "$new_header"; echo ""; echo "$before_old_section"; } > "$CHANGELOG.new"
mv "$CHANGELOG.new" "$CHANGELOG"
if grep -q '^#### v1.2.2 (2026-08-01)$' "$CHANGELOG"; then
    pass "older entry retains original header with no author suffix"
else
    fail "older entry was rewritten unexpectedly"
fi

echo ""
echo "====================================================="
echo "Results: $PASS passed, $FAIL failed"
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-version-bump PASSED"
    exit 0
else
    echo "✗ test-version-bump FAILED"
    exit 1
fi
