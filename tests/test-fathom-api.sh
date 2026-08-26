#!/bin/bash
#
# fathom-api.sh Test Suite
#
# Tests config-file resolution and the "check" gate against fixture configs.
# Real API calls require a live Fathom account/key — those are marked blocked.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FATHOM_SCRIPT="$REPO_DIR/scripts/fathom-api.sh"
TEST_HOME=$(mktemp -d)
PASS=0
FAIL=0
BLOCKED=0

pass()    { echo "  ✓ $1"; ((PASS++)) || true; }
fail()    { echo "  ✗ $1"; ((FAIL++)) || true; }
blocked() { echo "  ⊘ $1 [BLOCKED: $2]"; ((BLOCKED++)) || true; }

cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

echo "=== fathom-api.sh Test Suite ==="
echo ""

# ── check: no config file ────────────────────────────────────────────────────
OUT=$(HOME="$TEST_HOME" "$FATHOM_SCRIPT" check 2>/dev/null) || true
if [[ "$OUT" == "missing" ]]; then
    pass "check reports 'missing' when no config file exists"
else
    fail "check should report 'missing' with no config file (got: $OUT)"
fi

# ── check: config file exists but key is empty ──────────────────────────────
mkdir -p "$TEST_HOME/.config/fathom"
echo 'FATHOM_API_KEY=' > "$TEST_HOME/.config/fathom/config"
OUT=$(HOME="$TEST_HOME" "$FATHOM_SCRIPT" check 2>/dev/null) || true
if [[ "$OUT" == "missing" ]]; then
    pass "check reports 'missing' when FATHOM_API_KEY is empty"
else
    fail "check should report 'missing' with empty key (got: $OUT)"
fi

# ── check: valid config file ────────────────────────────────────────────────
echo 'FATHOM_API_KEY=test-key-12345' > "$TEST_HOME/.config/fathom/config"
OUT=$(HOME="$TEST_HOME" "$FATHOM_SCRIPT" check 2>/dev/null) || true
if [[ "$OUT" == "ok" ]]; then
    pass "check reports 'ok' when config file has a key set"
else
    fail "check should report 'ok' with a valid key (got: $OUT)"
fi

# ── endpoint call: no config file exits non-zero with a clear message ──────
rm -rf "$TEST_HOME/.config"
if HOME="$TEST_HOME" "$FATHOM_SCRIPT" "meetings?limit=1" >/dev/null 2>/tmp/fathom-test-err; then
    fail "endpoint call should fail without a config file"
else
    if grep -q "Missing config file" /tmp/fathom-test-err; then
        pass "endpoint call fails with a clear message when config is missing"
    else
        fail "endpoint call failure message was unclear: $(cat /tmp/fathom-test-err)"
    fi
fi
rm -f /tmp/fathom-test-err

# ── live API call ────────────────────────────────────────────────────────────
blocked "list meetings against the real Fathom API" "requires a live FATHOM_API_KEY; not available in CI/test env"

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $BLOCKED blocked ==="
[[ $FAIL -eq 0 ]]
