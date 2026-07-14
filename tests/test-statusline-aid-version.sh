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

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
