#!/bin/bash
# Test: spec v120 — /aid-login says up front that access is a private-beta allowlist.
# Runs the real scripts. `auth.sh login` opens a browser, so it is checked from the source (the notice must come before the
# browser-open line); status, logout and refresh are run for real with HOME pointed at an empty directory so no real
# credentials are read or removed. No mocks.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTH="$REPO_DIR/scripts/auth.sh"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
has() { case "$1" in *"$2"*) return 0;; *) return 1;; esac; }
check() { if has "$2" "$3"; then pass "$1"; else fail "$1 (missing: $3)"; fi; }
check_not() { if has "$2" "$3"; then fail "$1 (unexpected: $3)"; else pass "$1"; fi; }

[ -f "$AUTH" ] || { echo "auth.sh not found"; exit 1; }
SRC="$(cat "$AUTH")"
# body of cmd_login: from its definition to the next top-level function
LOGIN="$(awk '/^cmd_login\(\) \{/{f=1} f{print} f && /^}/{exit}' "$AUTH")"

echo ""
echo "Test: login prints the private-beta notice before the browser opens (AC-1)"
check "login body prints a private-beta notice" "$LOGIN" "Private beta:"
check "notice carries the request-access link" "$LOGIN" '${REQUEST_ACCESS_URL}'
NOTICE_LINE=$(echo "$LOGIN" | grep -n "Private beta:" | head -1 | cut -d: -f1)
OPEN_LINE=$(echo "$LOGIN" | grep -n 'open "\$login_url"' | head -1 | cut -d: -f1)
if [ -n "$NOTICE_LINE" ] && [ -n "$OPEN_LINE" ] && [ "$NOTICE_LINE" -lt "$OPEN_LINE" ]; then
    pass "notice comes before the browser-open line"
else
    fail "notice is not before the browser-open line (notice=$NOTICE_LINE open=$OPEN_LINE)"
fi

echo ""
echo "Test: one shared request-access URL, v97 message unchanged (AC-4)"
check "URL defined once as a variable" "$SRC" 'REQUEST_ACCESS_URL="https://github.com/jerichoBob/aidev-toolkit-dist/issues/new"'
check "v97 message reuses the variable" "$SRC" '  ${REQUEST_ACCESS_URL}'
check "v97 rejection check still present" "$SRC" "not on the access list"
COUNT=$(grep -c "aidev-toolkit-dist/issues/new" "$AUTH")
[ "$COUNT" -eq 1 ] && pass "the issues URL appears exactly once (no duplicated string)" || fail "issues URL appears $COUNT times"

echo ""
echo "Test: status, logout and refresh do not print the notice (AC-5)"
EMPTY_HOME=$(mktemp -d)
for sub in status logout refresh; do
    OUT=$(HOME="$EMPTY_HOME" bash "$AUTH" "$sub" 2>&1 </dev/null)
    check_not "$sub prints no private-beta notice" "$OUT" "Private beta:"
done

echo ""
echo "Test: skill, installer and docs mention the requirement (AC-2, AC-3)"
check "skill has a Private beta section" "$(cat "$REPO_DIR/skills/aid-login.md")" "## Private beta"
check "skill links the issue tracker" "$(cat "$REPO_DIR/skills/aid-login.md")" "aidev-toolkit-dist/issues/new"
check "installer hint (command list) mentions the requirement" "$(cat "$REPO_DIR/scripts/install.sh")" "Authenticate with GitHub (private beta: access list required)"
check "installer hint (optional step) mentions the requirement" "$(cat "$REPO_DIR/scripts/install.sh")" "private beta: access list required; opens browser"
check "aid-help mentions the requirement" "$(cat "$REPO_DIR/docs/aid-help.md")" "private beta: your account must be on the access list"
check "README auth row mentions the requirement" "$(cat "$REPO_DIR/README.md")" "private beta: access list required"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
