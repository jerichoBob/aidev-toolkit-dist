#!/bin/bash
#
# aidev toolkit measure-command-baseline.sh Test Suite
#
# Real invocation of the perf harness — no mocks. Runs the actual proxy
# command sequences (lightweight, non-mutating) and checks the TSV output.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HARNESS="$REPO_DIR/.claude/scripts/measure-command-baseline.sh"

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

echo ""
echo "aidev toolkit measure-command-baseline.sh Tests"
echo "================================================="

if [ ! -x "$HARNESS" ]; then
    fail "harness script not found or not executable: $HARNESS"
    echo ""
    echo "Results: $PASS passed, $FAIL failed"
    exit 1
fi

echo ""
echo "Test: list subcommand enumerates in-scope commands..."
LIST_OUTPUT=$(bash "$HARNESS" list)
if echo "$LIST_OUTPUT" | grep -q "^sdd-specs$"; then
    pass "list includes sdd-specs"
else
    fail "list missing sdd-specs: $LIST_OUTPUT"
fi
if echo "$LIST_OUTPUT" | grep -q "^commit-push$"; then
    pass "list includes commit-push"
else
    fail "list missing commit-push"
fi

echo ""
echo "Test: run subcommand executes real proxy sequences and writes TSV..."
TMP_OUT=$(mktemp)
(cd "$REPO_DIR" && bash "$HARNESS" run "$TMP_OUT" >/dev/null 2>&1)

if [ -s "$TMP_OUT" ]; then
    pass "run produced a non-empty output file"
else
    fail "run produced no output"
fi

if head -1 "$TMP_OUT" | grep -q $'command\twallclock_seconds\tbash_calls\ttoken_in\ttoken_out\ttoken_cache'; then
    pass "TSV header has expected columns"
else
    fail "TSV header incorrect: $(head -1 "$TMP_OUT")"
fi

ROW_COUNT=$(($(wc -l < "$TMP_OUT") - 1))
if [ "$ROW_COUNT" -eq 8 ]; then
    pass "TSV has one row per in-scope command (8)"
else
    fail "expected 8 command rows, got $ROW_COUNT"
fi

if grep -q "^sdd-specs" "$TMP_OUT"; then
    pass "sdd-specs row present with real measured data"
else
    fail "sdd-specs row missing"
fi

rm -f "$TMP_OUT"

echo ""
echo "================================================="
printf "Results: %d passed, %d failed\n" "$PASS" "$FAIL"
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-command-perf-baseline PASSED"
    exit 0
else
    echo "✗ test-command-perf-baseline FAILED"
    exit 1
fi
