#!/bin/bash
#
# Integration tests for scripts/statusline.sh
# Runs the real script against a temp HOME fixture — no mocks, no stubs.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATUSLINE="$REPO_DIR/scripts/statusline.sh"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

if [ ! -f "$STATUSLINE" ]; then
    echo "BLOCKED: scripts/statusline.sh not found"
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "BLOCKED: jq not available — required for statusline.sh tests"
    exit 0
fi

echo ""
echo "Test: scripts/statusline.sh integration (v68)"

# Set up temp HOME
TMPDIR_HOME=$(mktemp -d)
trap 'rm -rf "$TMPDIR_HOME"' EXIT

INPUT_JSON='{"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":42}}'

# Test 1: Bootstrap default config if absent
CONFIG="$TMPDIR_HOME/.claude/statusline-config.json"
output=$(HOME="$TMPDIR_HOME" bash "$STATUSLINE" <<< "$INPUT_JSON" 2>&1 || true)
if [ -f "$CONFIG" ]; then
    pass "Bootstrap: creates config on first run"
else
    fail "Bootstrap: config not created"
fi

# Test 2: Bootstrapped config is valid JSON
if jq empty "$CONFIG" 2>/dev/null; then
    pass "Bootstrap: created config is valid JSON"
else
    fail "Bootstrap: created config is not valid JSON"
fi

# Test 3: Bootstrapped config has enabled=true by default
ENABLED=$(jq -r '.enabled' "$CONFIG")
if [ "$ENABLED" = "true" ]; then
    pass "Bootstrap: default enabled=true"
else
    fail "Bootstrap: expected enabled=true, got $ENABLED"
fi

# Test 4: Produces output when enabled
if [ -n "$output" ]; then
    pass "Enabled: produces non-empty output"
else
    fail "Enabled: expected output, got empty string"
fi

# Test 5: Disabled mode produces no output
printf '%s' "$(jq '.enabled = false' "$CONFIG")" > "$CONFIG"
output_disabled=$(HOME="$TMPDIR_HOME" bash "$STATUSLINE" <<< "$INPUT_JSON" 2>&1 || true)
if [ -z "$output_disabled" ]; then
    pass "Disabled: produces no output when enabled=false"
else
    fail "Disabled: expected empty output, got: $output_disabled"
fi

# Test 6: Re-enable is idempotent (re-enable twice, still works)
printf '%s' "$(jq '.enabled = true' "$CONFIG")" > "$CONFIG"
printf '%s' "$(jq '.enabled = true' "$CONFIG")" > "$CONFIG"
output_re=$(HOME="$TMPDIR_HOME" bash "$STATUSLINE" <<< "$INPUT_JSON" 2>&1 || true)
if [ -n "$output_re" ]; then
    pass "Idempotent: repeated enable still produces output"
else
    fail "Idempotent: re-enabled but no output"
fi

# Test 7: Missing settings.json is handled gracefully (statusline.sh doesn't write settings.json, just reads config)
rm -f "$CONFIG"
output_fresh=$(HOME="$TMPDIR_HOME" bash "$STATUSLINE" <<< "$INPUT_JSON" 2>&1 || true)
if [ -f "${TMPDIR_HOME}/.claude/statusline-config.json" ]; then
    pass "Fresh: missing config is recreated on next run"
else
    fail "Fresh: missing config was not recreated"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
