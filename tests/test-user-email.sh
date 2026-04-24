#!/bin/bash
#
# aidev toolkit user-email.sh Test Suite
#
# Tests get/set/ensure and the JWT-over-.user-email priority chain.
# All tests use isolated temp directories — no mutations to real ~/.claude/aidev-toolkit/.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
USER_EMAIL_SCRIPT="$REPO_DIR/modules/sdd/scripts/user-email.sh"
TEST_HOME=$(mktemp -d)
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

check() {
    if eval "$1" 2>/dev/null; then pass "$2"; else fail "$2"; fi
}

cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

# All sub-calls run under overridden HOME so real config is untouched
export HOME="$TEST_HOME"
TOOLKIT_DIR="$TEST_HOME/.claude/aidev-toolkit"
EMAIL_FILE="$TOOLKIT_DIR/.user-email"
AUTH_FILE="$TOOLKIT_DIR/.auth"
mkdir -p "$TOOLKIT_DIR"

# ── JWT Fixture ──────────────────────────────────────────────────────────────
b64url_encode() {
    python3 -c "import base64,sys; d=sys.stdin.buffer.read(); print(base64.urlsafe_b64encode(d).rstrip(b'=').decode())"
}

make_jwt() {
    local email="$1" expires_at="$2"
    local header payload
    header=$(printf '{"alg":"HS256","typ":"JWT"}' | b64url_encode)
    payload=$(python3 -c "
import json,base64
d={'github_login':'jwtuser','name':'JWT User','github_email':'$email','issued_at':1000000,'expires_at':$expires_at}
print(base64.urlsafe_b64encode(json.dumps(d).encode()).rstrip(b'=').decode())
")
    echo "${header}.${payload}.dummysig"
}

NOW=$(date +%s)
FUTURE=$(( NOW + 2592000 ))
PAST=$(( NOW - 1 ))

echo ""
echo "aidev toolkit user-email.sh Tests"
echo "=================================="

# ── Test: get with no files returns empty ────────────────────────────────────
echo ""
echo "Test: get — no files..."
rm -f "$EMAIL_FILE" "$AUTH_FILE"
result=$("$USER_EMAIL_SCRIPT" get 2>/dev/null || true)
check '[ -z "$result" ]' "get returns empty when no .user-email and no .auth"

# ── Test: set + get round-trip ───────────────────────────────────────────────
echo ""
echo "Test: set + get round-trip..."
rm -f "$EMAIL_FILE" "$AUTH_FILE"
"$USER_EMAIL_SCRIPT" set "bob@example.com"
result=$("$USER_EMAIL_SCRIPT" get)
check '[ "$result" = "bob@example.com" ]' "get returns value written by set"
_perms=$(stat -f %Mp%Lp "$EMAIL_FILE" 2>/dev/null || stat -c %a "$EMAIL_FILE" 2>/dev/null || true)
check '[[ "$_perms" == "600" || "$_perms" == "0600" ]]' ".user-email has chmod 600"

# ── Test: ensure with .user-email already set — silent, no prompt ────────────
echo ""
echo "Test: ensure — .user-email set, no prompt needed..."
"$USER_EMAIL_SCRIPT" set "bob@example.com"
rm -f "$AUTH_FILE"
result=$("$USER_EMAIL_SCRIPT" ensure 2>/dev/null)
check '[ "$result" = "bob@example.com" ]' "ensure returns stored email silently"

# ── Test: JWT priority over .user-email ──────────────────────────────────────
echo ""
echo "Test: get — valid JWT overrides .user-email..."
"$USER_EMAIL_SCRIPT" set "file@example.com"
make_jwt "jwt@example.com" "$FUTURE" > "$AUTH_FILE"
chmod 600 "$AUTH_FILE"
result=$("$USER_EMAIL_SCRIPT" get)
check '[ "$result" = "jwt@example.com" ]' "get returns JWT email when valid .auth present"

# ── Test: expired JWT falls back to .user-email ──────────────────────────────
echo ""
echo "Test: get — expired JWT falls back to .user-email..."
"$USER_EMAIL_SCRIPT" set "file@example.com"
make_jwt "jwt@example.com" "$PAST" > "$AUTH_FILE"
chmod 600 "$AUTH_FILE"
result=$("$USER_EMAIL_SCRIPT" get)
check '[ "$result" = "file@example.com" ]' "get falls back to .user-email when JWT expired"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=================================="
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
