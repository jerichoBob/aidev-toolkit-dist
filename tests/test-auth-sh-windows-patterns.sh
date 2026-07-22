#!/bin/bash
#
# aidev toolkit auth.sh Windows/Git Bash Pattern Test Suite
#
# Verifies the shell patterns fixed for strict `set -euo pipefail` compatibility:
#   - `local port` -> `local port=""` (no unbound variable under set -u)
#   - `(( bind_wait++ ))` -> `bind_wait=$(( bind_wait + 1 ))` (no exit-1-on-zero under set -e)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTH_SCRIPT="$REPO_DIR/scripts/auth.sh"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

echo ""
echo "aidev toolkit auth.sh Windows/Git Bash Pattern Tests"
echo "======================================================"

# ── Test: no bare `(( var++ ))` patterns remain in auth.sh ──────────────────
echo ""
echo "Test: no unsafe (( var++ )) arithmetic patterns..."
if grep -qE '\(\( *[a-zA-Z_]+(\+\+|--) *\)\)' "$AUTH_SCRIPT"; then
    fail "auth.sh still contains (( var++ )) or (( var-- )) patterns"
else
    pass "auth.sh contains no (( var++ )) or (( var-- )) patterns"
fi

# ── Test: no bare uninitialised `local` declarations remain ────────────────
echo ""
echo "Test: no uninitialised local declarations..."
if grep -qE '^\s*local [a-zA-Z_]+\s*$' "$AUTH_SCRIPT"; then
    fail "auth.sh still contains uninitialised local declarations"
else
    pass "auth.sh contains no uninitialised local declarations"
fi

# ── Test: arithmetic increment-from-zero pattern does not exit under set -e ─
echo ""
echo "Test: increment-from-zero survives set -euo pipefail..."
if bash -euo pipefail -c '
    bind_wait=0
    bind_wait=$(( bind_wait + 1 ))
    echo "$bind_wait"
' > /dev/null 2>&1; then
    pass "bind_wait=\$(( bind_wait + 1 )) survives set -euo pipefail from zero"
else
    fail "bind_wait=\$(( bind_wait + 1 )) exited non-zero under set -euo pipefail"
fi

# ── Test: initialised local survives set -u ─────────────────────────────────
echo ""
echo "Test: local var=\"\" survives set -u..."
if bash -euo pipefail -c '
    local_fn() {
        local port=""
        port="12345"
        echo "$port"
    }
    local_fn
' > /dev/null 2>&1; then
    pass "local port=\"\" survives set -u"
else
    fail "local port=\"\" failed under set -u"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "======================================================"
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
