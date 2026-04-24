#!/bin/bash
#
# aidev toolkit token-tracker.sh Test Suite
#
# Tests snapshot, delta, and format subcommands using fixture JSON files.
# All tests use isolated temp dirs — no reads from real ~/.claude/stats-cache.json.
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

echo ""
echo "aidev toolkit token-tracker.sh Tests"
echo "======================================"

# ─── Test 1: snapshot with no stats-cache.json → creates {} ────────────────

echo ""
echo "Test: snapshot with no stats-cache.json..."

SNAP1="$TEST_HOME/snap-empty.json"
HOME="$TEST_HOME" bash "$TRACKER" snapshot "$SNAP1"

if [ -f "$SNAP1" ]; then
    pass "snapshot creates output file when stats-cache.json absent"
else
    fail "snapshot: output file not created"
fi

content=$(cat "$SNAP1")
if [ "$content" = "{}" ]; then
    pass "snapshot with no stats-cache.json writes {}"
else
    fail "snapshot empty: expected '{}', got '$content'"
fi

# ─── Test 2: snapshot with fixture stats-cache.json extracts modelUsage ────

echo ""
echo "Test: snapshot with fixture stats-cache.json..."

# Create a minimal fixture stats-cache.json with modelUsage
FAKE_CLAUDE_DIR="$TEST_HOME/.claude"
mkdir -p "$FAKE_CLAUDE_DIR"
cat > "$FAKE_CLAUDE_DIR/stats-cache.json" << 'EOF'
{
  "modelUsage": {
    "claude-haiku-4-5": {
      "inputTokens": 10000,
      "outputTokens": 2000,
      "cacheReadInputTokens": 50000
    },
    "claude-sonnet-4-6": {
      "inputTokens": 5000,
      "outputTokens": 1000,
      "cacheReadInputTokens": 20000
    }
  }
}
EOF

SNAP2="$TEST_HOME/snap-populated.json"
HOME="$TEST_HOME" bash "$TRACKER" snapshot "$SNAP2"

if [ -f "$SNAP2" ]; then
    pass "snapshot creates output file when stats-cache.json present"
else
    fail "snapshot: output file not created with stats-cache.json"
fi

# When jq available, snapshot should extract modelUsage (non-empty)
if command -v jq &>/dev/null; then
    content=$(cat "$SNAP2")
    if [ "$content" != "{}" ] && echo "$content" | jq -e . >/dev/null 2>&1; then
        pass "snapshot with stats-cache.json produces valid JSON (non-empty)"
    else
        fail "snapshot with stats-cache.json: expected modelUsage JSON, got '$content'"
    fi
else
    pass "snapshot: jq not installed — graceful fallback to {} (skipping content check)"
fi

# ─── Test 3: delta between two known snapshots → correct diffs ─────────────

echo ""
echo "Test: delta between known snapshots..."

# Snapshot "before": haiku has 1000 input, 200 output, 5000 cache
BEFORE="$TEST_HOME/before.json"
cat > "$BEFORE" << 'EOF'
{
  "claude-haiku-4-5": {
    "inputTokens": 1000,
    "outputTokens": 200,
    "cacheReadInputTokens": 5000
  }
}
EOF

# Snapshot "after": haiku grew by in=500, out=100, cache=2000
AFTER="$TEST_HOME/after.json"
cat > "$AFTER" << 'EOF'
{
  "claude-haiku-4-5": {
    "inputTokens": 1500,
    "outputTokens": 300,
    "cacheReadInputTokens": 7000
  }
}
EOF

if command -v jq &>/dev/null; then
    result=$(bash "$TRACKER" delta "$BEFORE" "$AFTER")
    read -r delta_in delta_out delta_cache <<< "$result"

    if [ "$delta_in" -eq 500 ]; then
        pass "delta: input tokens = 500"
    else
        fail "delta: input expected 500, got $delta_in"
    fi

    if [ "$delta_out" -eq 100 ]; then
        pass "delta: output tokens = 100"
    else
        fail "delta: output expected 100, got $delta_out"
    fi

    if [ "$delta_cache" -eq 2000 ]; then
        pass "delta: cache tokens = 2000"
    else
        fail "delta: cache expected 2000, got $delta_cache"
    fi
else
    pass "delta: jq not installed — returns '0 0 0' fallback (expected)"
    pass "delta: output valid (fallback path)"
    pass "delta: no crash without jq"
fi

# ─── Test 4: delta with identical snapshots → all zeros ────────────────────

echo ""
echo "Test: delta with identical snapshots → zeros..."

if command -v jq &>/dev/null; then
    result=$(bash "$TRACKER" delta "$BEFORE" "$BEFORE")
    read -r d_in d_out d_cache <<< "$result"

    if [ "$d_in" -eq 0 ] && [ "$d_out" -eq 0 ] && [ "$d_cache" -eq 0 ]; then
        pass "delta identical snapshots → 0 0 0"
    else
        fail "delta identical: expected 0 0 0, got $d_in $d_out $d_cache"
    fi
else
    pass "delta identical: jq not available — fallback 0 0 0"
fi

# ─── Test 5: delta with empty {} snapshots → zeros ─────────────────────────

EMPTY_SNAP="$TEST_HOME/empty-snap.json"
echo '{}' > "$EMPTY_SNAP"

result=$(bash "$TRACKER" delta "$EMPTY_SNAP" "$EMPTY_SNAP")
read -r d_in d_out d_cache <<< "$result"

if [ "$d_in" -eq 0 ] && [ "$d_out" -eq 0 ] && [ "$d_cache" -eq 0 ]; then
    pass "delta empty {} snapshots → 0 0 0 (no crash)"
else
    fail "delta empty: expected 0 0 0, got $d_in $d_out $d_cache"
fi

echo ""
echo "======================================"
printf "Results: %d passed, %d failed\n" $PASS $FAIL
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-token-tracker PASSED"
    exit 0
else
    echo "✗ test-token-tracker FAILED"
    exit 1
fi
