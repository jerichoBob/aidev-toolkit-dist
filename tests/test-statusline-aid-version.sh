#!/bin/bash
#
# Integration tests for the aid_version statusline component (v74)
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
echo "Test: aid_version statusline component (v74)"

TMPDIR_HOME=$(mktemp -d)
trap 'rm -rf "$TMPDIR_HOME"' EXIT

INPUT_JSON='{"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":42}}'
CONFIG="$TMPDIR_HOME/.claude/statusline-config.json"
VERSION_FILE="$TMPDIR_HOME/.claude/aidev-toolkit/VERSION"
mkdir -p "$(dirname "$VERSION_FILE")"

# Bootstrap config
HOME="$TMPDIR_HOME" bash "$STATUSLINE" <<< "$INPUT_JSON" >/dev/null 2>&1 || true

# Test 1: component present when aid_version=true and VERSION file exists
echo "1.2.3" > "$VERSION_FILE"
tmp=$(mktemp)
jq '.components.aid_version = true' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
output=$(HOME="$TMPDIR_HOME" bash "$STATUSLINE" <<< "$INPUT_JSON" 2>&1 || true)
if echo "$output" | grep -q "aid:1.2.3"; then
    pass "Enabled + VERSION present: shows aid:1.2.3"
else
    fail "Enabled + VERSION present: expected aid:1.2.3, got: $output"
fi

# Test 2: component absent when aid_version=false
tmp=$(mktemp)
jq '.components.aid_version = false' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
output=$(HOME="$TMPDIR_HOME" bash "$STATUSLINE" <<< "$INPUT_JSON" 2>&1 || true)
if ! echo "$output" | grep -q "aid:"; then
    pass "Disabled: aid_version absent from output"
else
    fail "Disabled: expected no aid: segment, got: $output"
fi

# Test 3: component silently skipped when VERSION file missing
rm -f "$VERSION_FILE"
tmp=$(mktemp)
jq '.components.aid_version = true' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
output=$(HOME="$TMPDIR_HOME" bash "$STATUSLINE" <<< "$INPUT_JSON" 2>&1 || true)
if ! echo "$output" | grep -q "aid:"; then
    pass "Missing VERSION file: silently skipped, no error"
else
    fail "Missing VERSION file: expected no aid: segment, got: $output"
fi

# Test 4: color pulses between dim gray (90m) and bright white (97m) on a 10s cadence
echo "1.2.3" > "$VERSION_FILE"
color_a=$(HOME="$TMPDIR_HOME" bash "$STATUSLINE" <<< "$INPUT_JSON" 2>&1 | grep -o $'\033\[9[07]m' || true)
if [[ "$color_a" == $'\033[90m' || "$color_a" == $'\033[97m' ]]; then
    pass "Pulse: renders in dim-gray or bright-white"
else
    fail "Pulse: expected 90m or 97m color code, got: $(printf '%q' "$color_a")"
fi

# Test 5: pulse phase is a pure function of wall-clock time (deterministic given epoch)
# Avoid flaking near a 10s boundary by nudging past it before sampling.
now=$(date +%s)
if (( now % 10 >= 8 )); then
    sleep $(( 10 - (now % 10) ))
fi
epoch=$(date +%s)
color_b=$(HOME="$TMPDIR_HOME" bash "$STATUSLINE" <<< "$INPUT_JSON" 2>&1 | grep -o $'\033\[9[07]m' || true)
epoch_bucket=$(( (epoch / 10) % 2 ))
if [[ "$epoch_bucket" -eq 0 && "$color_b" == $'\033[97m' ]] || [[ "$epoch_bucket" -eq 1 && "$color_b" == $'\033[90m' ]]; then
    pass "Pulse: color matches expected 10s time bucket"
else
    fail "Pulse: color/time bucket mismatch (bucket=$epoch_bucket, color=$(printf '%q' "$color_b"))"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
