#!/bin/bash
#
# aidev toolkit auth.sh Test Suite
#
# Tests auth.sh subcommands against real fixture JWTs.
# auth.sh login and refresh require a live Worker — those tests are marked blocked.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTH_SCRIPT="$REPO_DIR/scripts/auth.sh"
TEST_HOME=$(mktemp -d)
PASS=0
FAIL=0
BLOCKED=0

pass()    { echo "  ✓ $1"; ((PASS++)) || true; }
fail()    { echo "  ✗ $1"; ((FAIL++)) || true; }
blocked() { echo "  ⊘ $1 [BLOCKED: $2]"; ((BLOCKED++)) || true; }

check() {
    if eval "$1" 2>/dev/null; then pass "$2"; else fail "$2"; fi
}

cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

# ── JWT Fixture Factory ──────────────────────────────────────────────────────
# Produces a structurally valid base64url-encoded JWT payload with known fields.
# Signature is a dummy — auth.sh decodes but does NOT verify signature client-side.

b64url_encode() {
    python3 -c "
import base64, sys
data = sys.stdin.buffer.read()
print(base64.urlsafe_b64encode(data).rstrip(b'=').decode())
"
}

make_jwt() {
    local login="$1" name="$2" email="$3" issued_at="$4" expires_at="$5"
    local header payload sig
    header=$(printf '{"alg":"HS256","typ":"JWT"}' | b64url_encode)
    payload=$(python3 -c "
import json, sys
print(json.dumps({
    'github_login': '$login',
    'name':         '$name',
    'github_email': '$email',
    'issued_at':    $issued_at,
    'expires_at':   $expires_at
}))
" | b64url_encode)
    sig="dummysignature"
    echo "${header}.${payload}.${sig}"
}

NOW=$(date +%s)
FUTURE=$(( NOW + 2592000 ))   # 30 days ahead
PAST=$(( NOW - 1 ))            # 1 second ago (expired)

VALID_JWT=$(make_jwt "testuser" "Test User" "test@example.com" "$NOW" "$FUTURE")
EXPIRED_JWT=$(make_jwt "testuser" "Test User" "test@example.com" "$(( NOW - 2592000 ))" "$PAST")

AUTH_FILE="$TEST_HOME/.claude/aidev-toolkit/.auth"

export HOME="$TEST_HOME"
mkdir -p "$TEST_HOME/.claude/aidev-toolkit"

echo ""
echo "aidev toolkit auth.sh Tests"
echo "==========================="

# ── Test: status with no .auth file ─────────────────────────────────────────
echo ""
echo "Test: status — no .auth file..."
rm -f "$AUTH_FILE"
status_output=$("$AUTH_SCRIPT" status 2>&1 || true)
check 'echo "$status_output" | grep -qi "not logged in\|No such file\|Error"' \
    "status with no .auth exits with error message"

# ── Test: status with expired JWT ───────────────────────────────────────────
echo ""
echo "Test: status — expired JWT..."
echo "$EXPIRED_JWT" > "$AUTH_FILE"
chmod 600 "$AUTH_FILE"
expired_output=$("$AUTH_SCRIPT" status 2>&1 || true)
check 'echo "$expired_output" | grep -qi "expired\|Error"' \
    "status with expired JWT reports expiry"

# ── Test: status with valid JWT ──────────────────────────────────────────────
echo ""
echo "Test: status — valid JWT..."
echo "$VALID_JWT" > "$AUTH_FILE"
chmod 600 "$AUTH_FILE"
valid_output=$("$AUTH_SCRIPT" status 2>&1)
check 'echo "$valid_output" | grep -q "testuser"' \
    "status shows github_login from JWT"
check 'echo "$valid_output" | grep -q "Test User"' \
    "status shows name from JWT"
check 'echo "$valid_output" | grep -q "test@example.com"' \
    "status shows email from JWT"
check 'echo "$valid_output" | grep -qi "logged in"' \
    "status shows logged-in confirmation"

# ── Test: token ──────────────────────────────────────────────────────────────
echo ""
echo "Test: token..."
echo "$VALID_JWT" > "$AUTH_FILE"
chmod 600 "$AUTH_FILE"
token_output=$("$AUTH_SCRIPT" token 2>&1)
check '[ "$token_output" = "$VALID_JWT" ]' \
    "token prints raw JWT verbatim"

# ── Test: logout ─────────────────────────────────────────────────────────────
echo ""
echo "Test: logout..."
echo "$VALID_JWT" > "$AUTH_FILE"
chmod 600 "$AUTH_FILE"
"$AUTH_SCRIPT" logout > /dev/null 2>&1
check '[ ! -f "$AUTH_FILE" ]' \
    "logout removes .auth file"

# ── Blocked tests ────────────────────────────────────────────────────────────
echo ""
blocked "auth.sh login"   "requires live Cloudflare Worker + browser"
blocked "auth.sh refresh" "requires live Cloudflare Worker with valid JWT"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "==========================="
echo "Results: $PASS passed, $FAIL failed, $BLOCKED blocked (skipped)"
[ $FAIL -eq 0 ] && exit 0 || exit 1
