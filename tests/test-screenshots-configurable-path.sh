#!/bin/bash
#
# aidev toolkit screenshots.sh Configurable Path Test Suite
#
# Tests AIDEV_SCREENSHOTS_DIR / AIDEV_SCREENSHOTS_PATTERN env var support:
# custom dir/pattern usage, fallback to ~/Desktop defaults, and error on a
# nonexistent configured directory.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_DIR/scripts/screenshots.sh"

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

TEST_HOME=$(mktemp -d)
cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

echo ""
echo "aidev toolkit screenshots.sh Configurable Path Tests"
echo "======================================================"

# ─── Test 1: custom AIDEV_SCREENSHOTS_DIR is used ──────────────────────────

echo ""
echo "Test: custom AIDEV_SCREENSHOTS_DIR..."

CUSTOM_DIR="$TEST_HOME/Pictures/Screenshots"
mkdir -p "$CUSTOM_DIR"
touch "$CUSTOM_DIR/Screenshot 2026-01-01 at 09.00.00.png"

output=$(HOME="$TEST_HOME" AIDEV_SCREENSHOTS_DIR="$CUSTOM_DIR" bash "$SCRIPT" 2>/dev/null)
if echo "$output" | grep -q "$CUSTOM_DIR"; then
    pass "AIDEV_SCREENSHOTS_DIR is used as the source directory"
else
    fail "AIDEV_SCREENSHOTS_DIR was not used (output: '$output')"
fi

# ─── Test 2: custom AIDEV_SCREENSHOTS_PATTERN is used ──────────────────────

echo ""
echo "Test: custom AIDEV_SCREENSHOTS_PATTERN..."

PATTERN_DIR="$TEST_HOME/CustomPattern"
mkdir -p "$PATTERN_DIR"
touch "$PATTERN_DIR/Capture-001.png"
touch "$PATTERN_DIR/Screenshot 2026-01-01 at 09.00.00.png"

output=$(HOME="$TEST_HOME" AIDEV_SCREENSHOTS_DIR="$PATTERN_DIR" AIDEV_SCREENSHOTS_PATTERN="Capture*.png" bash "$SCRIPT" 2>/dev/null)
if echo "$output" | grep -q "Capture-001.png"; then
    pass "AIDEV_SCREENSHOTS_PATTERN matches custom pattern file"
else
    fail "AIDEV_SCREENSHOTS_PATTERN did not match expected file (output: '$output')"
fi
if echo "$output" | grep -q "Screenshot 2026"; then
    fail "AIDEV_SCREENSHOTS_PATTERN incorrectly matched a file outside the pattern"
else
    pass "AIDEV_SCREENSHOTS_PATTERN correctly excludes non-matching files"
fi

# ─── Test 3: fallback to ~/Desktop when env vars unset ─────────────────────

echo ""
echo "Test: fallback to ~/Desktop when unset..."

mkdir -p "$TEST_HOME/Desktop"
touch "$TEST_HOME/Desktop/Screenshot 2026-01-01 at 09.00.00.png"

unset AIDEV_SCREENSHOTS_DIR
unset AIDEV_SCREENSHOTS_PATTERN
output=$(HOME="$TEST_HOME" bash "$SCRIPT" 2>/dev/null)
if echo "$output" | grep -q "$TEST_HOME/Desktop"; then
    pass "falls back to ~/Desktop when env vars unset"
else
    fail "did not fall back to ~/Desktop (output: '$output')"
fi

# ─── Test 4: error on nonexistent configured directory ─────────────────────

echo ""
echo "Test: error on nonexistent configured directory..."

BOGUS_DIR="$TEST_HOME/does-not-exist"
error_output=$(HOME="$TEST_HOME" AIDEV_SCREENSHOTS_DIR="$BOGUS_DIR" bash "$SCRIPT" 2>&1 || true)
if echo "$error_output" | grep -q "$BOGUS_DIR"; then
    pass "error message names the configured (nonexistent) path"
else
    fail "error message did not name the configured path (output: '$error_output')"
fi
HOME="$TEST_HOME" AIDEV_SCREENSHOTS_DIR="$BOGUS_DIR" bash "$SCRIPT" >/dev/null 2>&1 \
    && fail "nonexistent configured dir should exit non-zero" \
    || pass "nonexistent configured dir exits non-zero"

echo ""
echo "======================================================"
printf "Results: %d passed, %d failed\n" $PASS $FAIL
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-screenshots-configurable-path PASSED"
    exit 0
else
    echo "✗ test-screenshots-configurable-path FAILED"
    exit 1
fi
