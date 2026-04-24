#!/bin/bash
#
# aidev toolkit screenshots.sh Test Suite
#
# Tests argument validation and file-listing logic using fixture Desktop directories.
# All tests use isolated temp directories — no dependency on real ~/Desktop.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_DIR/scripts/screenshots.sh"

PASS=0
FAIL=0
BLOCKED=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
skip_blocked() { echo "  ⊘ $1 [BLOCKED: $2]"; ((BLOCKED++)) || true; }

TEST_HOME=$(mktemp -d)
cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

echo ""
echo "aidev toolkit screenshots.sh Tests"
echo "==================================="

# ─── Test 1: Argument validation ───────────────────────────────────────────

echo ""
echo "Test: argument validation..."

# Non-integer argument
if HOME="$TEST_HOME" bash "$SCRIPT" "abc" 2>&1 | grep -q "Error"; then
    pass "non-integer argument produces error"
else
    fail "non-integer argument: expected error"
fi
HOME="$TEST_HOME" bash "$SCRIPT" "abc" >/dev/null 2>&1 && fail "non-integer should exit non-zero" || pass "non-integer exits non-zero"

# Zero is not a positive integer
if HOME="$TEST_HOME" bash "$SCRIPT" "0" 2>&1 | grep -q "Error"; then
    pass "zero argument produces error"
else
    fail "zero argument: expected error"
fi
HOME="$TEST_HOME" bash "$SCRIPT" "0" >/dev/null 2>&1 && fail "zero should exit non-zero" || pass "zero exits non-zero"

# Negative integer
if HOME="$TEST_HOME" bash "$SCRIPT" "-1" 2>&1 | grep -q "Error"; then
    pass "negative argument produces error"
else
    fail "negative argument: expected error"
fi
HOME="$TEST_HOME" bash "$SCRIPT" "-1" >/dev/null 2>&1 && fail "negative should exit non-zero" || pass "negative exits non-zero"

# ─── Test 2: Missing Desktop directory ─────────────────────────────────────

echo ""
echo "Test: missing Desktop directory..."

# TEST_HOME has no Desktop dir
if HOME="$TEST_HOME" bash "$SCRIPT" 2>&1 | grep -q "Error"; then
    pass "missing Desktop produces error message"
else
    fail "missing Desktop: expected error message"
fi
HOME="$TEST_HOME" bash "$SCRIPT" >/dev/null 2>&1 && fail "missing Desktop should exit non-zero" || pass "missing Desktop exits non-zero"

# ─── Test 3: Empty Desktop (no screenshots) ────────────────────────────────

echo ""
echo "Test: Desktop with no screenshots..."

mkdir -p "$TEST_HOME/Desktop"
# No Screenshot*.png files present

if HOME="$TEST_HOME" bash "$SCRIPT" 2>&1 | grep -q "Error\|no screenshots"; then
    pass "empty Desktop produces error message"
else
    fail "empty Desktop: expected error message"
fi
HOME="$TEST_HOME" bash "$SCRIPT" >/dev/null 2>&1 && fail "empty Desktop should exit non-zero" || pass "empty Desktop exits non-zero"

# ─── Test 4: Screenshots present — output contains paths ───────────────────

echo ""
echo "Test: Desktop with screenshots returns paths..."

DESKTOP_DIR="$TEST_HOME/Desktop"

# Create fixture screenshot files with different timestamps
touch -t 202601010900 "$DESKTOP_DIR/Screenshot 2026-01-01 at 09.00.00.png"
sleep 0.1
touch -t 202601010910 "$DESKTOP_DIR/Screenshot 2026-01-01 at 09.10.00.png"
sleep 0.1
touch -t 202601010920 "$DESKTOP_DIR/Screenshot 2026-01-01 at 09.20.00.png"
# Add a non-screenshot file to verify it's ignored
touch "$DESKTOP_DIR/not-a-screenshot.txt"

output=$(HOME="$TEST_HOME" bash "$SCRIPT" 3 2>/dev/null)
count=$(echo "$output" | grep -c "Screenshot" || true)

if [ "$count" -ge 1 ]; then
    pass "output contains screenshot paths ($count found)"
else
    fail "output contains no screenshot paths"
fi

# Verify non-screenshot files are not included
if echo "$output" | grep -q "not-a-screenshot"; then
    fail "non-screenshot file incorrectly included in output"
else
    pass "non-screenshot files excluded from output"
fi

# Verify paths are absolute
first_path=$(echo "$output" | head -1)
if [[ "$first_path" == /* ]]; then
    pass "output paths are absolute"
else
    fail "output paths are not absolute: '$first_path'"
fi

# ─── Test 5: Default N=1 behaviour ─────────────────────────────────────────

echo ""
echo "Test: default N=1..."

output=$(HOME="$TEST_HOME" bash "$SCRIPT" 2>/dev/null)
if [ -n "$output" ]; then
    pass "default (no arg) produces output"
else
    fail "default (no arg) produced no output"
fi

echo ""
echo "==================================="
printf "Results: %d passed, %d failed, %d blocked (skipped)\n" $PASS $FAIL $BLOCKED
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-screenshots PASSED"
    exit 0
else
    echo "✗ test-screenshots FAILED"
    exit 1
fi
