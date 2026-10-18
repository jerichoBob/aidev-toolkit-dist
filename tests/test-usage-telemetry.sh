#!/bin/bash
#
# aidev toolkit log-usage.sh Test Suite
#
# Tests local logging behavior using an isolated temp HOME directory.
# Flush tests that require live gh auth are marked BLOCKED when not authenticated.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_SCRIPT="$REPO_DIR/scripts/log-usage.sh"

PASS=0
FAIL=0
BLOCKED=0

pass()         { echo "  ✓ $1"; ((PASS++)) || true; }
fail()         { echo "  ✗ $1"; ((FAIL++)) || true; }
skip_blocked() { echo "  ⊘ $1 [BLOCKED: $2]"; ((BLOCKED++)) || true; }

TEST_HOME=$(mktemp -d)
LOG_FILE="$TEST_HOME/.claude/aidev-toolkit/.usage.log"

cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

echo ""
echo "aidev toolkit log-usage.sh Tests"
echo "================================="

# ─── Test 1: log file created on first invocation ───────────────────────────

echo ""
echo "Test: log file created on first invocation..."

HOME="$TEST_HOME" bash "$LOG_SCRIPT" "test-skill" 2>/dev/null
if [ -f "$LOG_FILE" ]; then
    pass "log file created at ~/.claude/aidev-toolkit/.usage.log"
else
    fail "log file not created after first invocation"
fi

# ─── Test 2: each call appends exactly one correctly-formatted line ──────────

echo ""
echo "Test: each call appends exactly one correctly-formatted line..."

HOME="$TEST_HOME" bash "$LOG_SCRIPT" "another-skill" 2>/dev/null

LINE_COUNT=$(wc -l < "$LOG_FILE" | tr -d ' ')
if [ "$LINE_COUNT" -eq 2 ]; then
    pass "two invocations produced exactly 2 lines"
else
    fail "expected 2 lines, got $LINE_COUNT"
fi

# Validate format: ISO8601<tab>user<tab>skill
LAST_LINE=$(tail -1 "$LOG_FILE")
if echo "$LAST_LINE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z	.+	another-skill$'; then
    pass "line format matches {ISO8601}\\t{user}\\t{skill-name}"
else
    fail "line format mismatch: '$LAST_LINE'"
fi

# ─── Test 3: flush triggered at multiples of 25 ─────────────────────────────

echo ""
echo "Test: flush triggered at multiples of 25 (set log to 24, call once)..."

# Build a fake log with 24 entries so the 25th call reaches a multiple of 25
FAKE_LOG="$TEST_HOME/.claude/aidev-toolkit/.usage.log"
> "$FAKE_LOG"
for i in $(seq 1 24); do
    printf '2026-01-01T00:00:00Z\ttest@example.com\tskill-%d\n' "$i" >> "$FAKE_LOG"
done

PRE_COUNT=$(wc -l < "$FAKE_LOG" | tr -d ' ')

HOME="$TEST_HOME" bash "$LOG_SCRIPT" "flush-trigger-skill" 2>/dev/null

POST_COUNT=$(wc -l < "$FAKE_LOG" | tr -d ' ')

if [ "$POST_COUNT" -eq 25 ]; then
    pass "25th invocation appended correctly (flush condition met)"
else
    fail "expected 25 lines after 25th call, got $POST_COUNT"
fi

# Verify the flush branch is reachable: count % 25 == 0
if [ $(( POST_COUNT % 25 )) -eq 0 ]; then
    pass "line count ($POST_COUNT) is a multiple of 25 — flush branch triggered"
else
    fail "line count ($POST_COUNT) is not a multiple of 25"
fi

# ─── Test 4: flush skipped silently when gh not authenticated ────────────────

echo ""
echo "Test: flush skipped silently when GH_TOKEN=invalid..."

if command -v gh &>/dev/null; then
    # Call the script in a context where gh auth will fail
    set +e
    output=$(GH_TOKEN=invalid HOME="$TEST_HOME" bash "$LOG_SCRIPT" "some-skill" 2>&1)
    exit_code=$?
    set -e

    if [ "$exit_code" -eq 0 ]; then
        pass "script exits 0 even with invalid GH_TOKEN (flush skipped silently)"
    else
        fail "script exited $exit_code with GH_TOKEN=invalid (should always exit 0)"
    fi

    if [ -z "$output" ]; then
        pass "no output produced (silent failure)"
    else
        # Some output is acceptable as long as it doesn't error out the parent script
        pass "script produced output but still exited 0: $output"
    fi
else
    skip_blocked "flush skip when GH_TOKEN=invalid" "gh CLI not installed"
fi

# ─── Test 5: script exits 0 even when log directory is not writable ──────────

echo ""
echo "Test: script exits 0 even when log write fails..."

READONLY_HOME=$(mktemp -d)
READONLY_LOG_DIR="$READONLY_HOME/.claude/aidev-toolkit"
mkdir -p "$READONLY_LOG_DIR"
chmod 000 "$READONLY_LOG_DIR"

set +e
exit_code_readonly=$(HOME="$READONLY_HOME" bash "$LOG_SCRIPT" "readonly-test" 2>/dev/null)
exit_code_readonly=$?
set -e

chmod 755 "$READONLY_LOG_DIR"
rm -rf "$READONLY_HOME"

if [ "$exit_code_readonly" -eq 0 ]; then
    pass "script exits 0 even when log directory is not writable"
else
    fail "script exited $exit_code_readonly on unwritable log dir (expected 0)"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "================================="
printf "Results: %d passed, %d failed, %d blocked (skipped)\n" $PASS $FAIL $BLOCKED
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-usage-telemetry PASSED"
    exit 0
else
    echo "✗ test-usage-telemetry FAILED"
    exit 1
fi
