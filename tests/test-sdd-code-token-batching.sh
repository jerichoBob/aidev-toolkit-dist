#!/bin/bash
#
# aidev toolkit sdd-code token-tracking batching test (spec-v108, Phase 3)
#
# Verifies the alternating-snapshot-file pattern documented in
# modules/sdd/skills/sdd-code.md: a task's "after" snapshot doubles as the
# next task's "before" snapshot, using real token-tracker.sh snapshot/delta
# calls against a fixture stats-cache.json — no mocks.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TRACKER="$REPO_DIR/modules/sdd/scripts/token-tracker.sh"

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

TEST_HOME=$(mktemp -d)
cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

FAKE_CLAUDE_DIR="$TEST_HOME/.claude"
mkdir -p "$FAKE_CLAUDE_DIR"

write_stats() {
    local in="$1" out="$2" cache="$3"
    cat > "$FAKE_CLAUDE_DIR/stats-cache.json" << EOF
{
  "modelUsage": {
    "claude-sonnet": {
      "inputTokens": $in,
      "outputTokens": $out,
      "cacheReadInputTokens": $cache
    }
  }
}
EOF
}

echo ""
echo "aidev toolkit sdd-code token-batching Tests"
echo "============================================="

if ! command -v jq &>/dev/null; then
    echo "  jq not installed — skipping (blocked, jq required for real delta math)"
    exit 0
fi

A="$TEST_HOME/phase-1-a.json"
B="$TEST_HOME/phase-1-b.json"

# Task 1 in the phase: before -> A (real snapshot), after -> B (real snapshot)
write_stats 1000 100 500
HOME="$TEST_HOME" bash "$TRACKER" snapshot "$A"

write_stats 1400 250 700
HOME="$TEST_HOME" bash "$TRACKER" snapshot "$B"

task1_delta=$(bash "$TRACKER" delta "$A" "$B")
read -r t1_in t1_out t1_cache <<< "$task1_delta"

if [ "$t1_in" -eq 400 ] && [ "$t1_out" -eq 150 ] && [ "$t1_cache" -eq 200 ]; then
    pass "task 1 delta correct (in=400 out=150 cache=200)"
else
    fail "task 1 delta wrong: $task1_delta"
fi

# Task 2: reuse B as "before" (no new snapshot call — this is the batching
# optimization) and snapshot "after" into A (alternating).
write_stats 1900 400 1100
HOME="$TEST_HOME" bash "$TRACKER" snapshot "$A"

task2_delta=$(bash "$TRACKER" delta "$B" "$A")
read -r t2_in t2_out t2_cache <<< "$task2_delta"

if [ "$t2_in" -eq 500 ] && [ "$t2_out" -eq 150 ] && [ "$t2_cache" -eq 400 ]; then
    pass "task 2 delta correct using alternating file, no extra before-snapshot (in=500 out=150 cache=400)"
else
    fail "task 2 delta wrong: $task2_delta"
fi

# Task 3: reuse A as "before", snapshot "after" into B.
write_stats 2200 500 1300
HOME="$TEST_HOME" bash "$TRACKER" snapshot "$B"

task3_delta=$(bash "$TRACKER" delta "$A" "$B")
read -r t3_in t3_out t3_cache <<< "$task3_delta"

if [ "$t3_in" -eq 300 ] && [ "$t3_out" -eq 100 ] && [ "$t3_cache" -eq 200 ]; then
    pass "task 3 delta correct (in=300 out=100 cache=200)"
else
    fail "task 3 delta wrong: $task3_delta"
fi

# Sum of per-task deltas must equal one big before/after delta across all 3 tasks.
FULL_BEFORE="$TEST_HOME/full-before.json"
FULL_AFTER="$TEST_HOME/full-after.json"
write_stats 1000 100 500
HOME="$TEST_HOME" bash "$TRACKER" snapshot "$FULL_BEFORE"
write_stats 2200 500 1300
HOME="$TEST_HOME" bash "$TRACKER" snapshot "$FULL_AFTER"
full_delta=$(bash "$TRACKER" delta "$FULL_BEFORE" "$FULL_AFTER")
read -r f_in f_out f_cache <<< "$full_delta"

sum_in=$((t1_in + t2_in + t3_in))
sum_out=$((t1_out + t2_out + t3_out))
sum_cache=$((t1_cache + t2_cache + t3_cache))

if [ "$sum_in" -eq "$f_in" ] && [ "$sum_out" -eq "$f_out" ] && [ "$sum_cache" -eq "$f_cache" ]; then
    pass "per-task deltas sum to the full-phase delta (no off-by-one from alternating files)"
else
    fail "per-task sum ($sum_in/$sum_out/$sum_cache) != full delta ($f_in/$f_out/$f_cache)"
fi

echo ""
echo "============================================="
printf "Results: %d passed, %d failed\n" "$PASS" "$FAIL"
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-sdd-code-token-batching PASSED"
    exit 0
else
    echo "✗ test-sdd-code-token-batching FAILED"
    exit 1
fi
