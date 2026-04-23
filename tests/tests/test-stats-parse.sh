#!/bin/bash
#
# aidev toolkit stats-parse.sh Test Suite
#
# Tests all 6 subcommands against a fixture README containing known task-meta
# HTML comments. Tests run in an isolated temp directory — no mutation to the
# real specs/README.md.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATS_PARSE="$REPO_DIR/modules/sdd/scripts/stats-parse.sh"

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

TEST_HOME=$(mktemp -d)
cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

# Create fixture README with task-meta comments for two specs
# Spec v1: 2 tasks, known token counts
# Spec v2: 1 task, different counts
setup_fixture_readme() {
    mkdir -p "$TEST_HOME/specs"
    cat > "$TEST_HOME/specs/README.md" << 'EOF'
## Quick Status

| Spec | Name | Progress | Status | Owner |
| ---- | ---- | -------- | ------ | ----- |
| v1   | Alpha Spec  | 2/2 | ✅ Complete | — |
| v2   | Beta Spec   | 1/1 | ✅ Complete | — |

---

## v1: Alpha Spec

- [x] Task one
<!-- task-meta: v=1,t=1,in=1000,out=200,cache=5000,start=2026-01-01T10:00:00Z,end=2026-01-01T10:05:00Z,commit=abc1234 -->
- [x] Task two
<!-- task-meta: v=1,t=2,in=2000,out=400,cache=3000,start=2026-01-01T10:10:00Z,end=2026-01-01T10:20:00Z,commit=def5678 -->

---

## v2: Beta Spec

- [x] Task one
<!-- task-meta: v=2,t=1,in=500,out=100,cache=1000,start=2026-01-02T09:00:00Z,end=2026-01-02T09:02:00Z,commit=ghi9012 -->

---
EOF
}

# Run stats-parse from TEST_HOME so relative path specs/README.md resolves
run_stats() {
    (cd "$TEST_HOME" && bash "$STATS_PARSE" "$@")
}

echo ""
echo "aidev toolkit stats-parse.sh Test Suite"
echo "========================================"

setup_fixture_readme

# ─── Test: extract-spec outputs correct TSV rows ───────────────────────────

echo ""
echo "Test: extract-spec with fixture README..."

output=$(run_stats extract-spec 1)
rows=$(echo "$output" | grep -c "^[0-9]" || true)

if [ "$rows" -eq 2 ]; then
    pass "extract-spec v1 returns 2 rows"
else
    fail "extract-spec v1: expected 2 rows, got $rows"
fi

# Verify field values for task 1: task_num=1 in=1000 out=200 cache=5000
first_row=$(echo "$output" | head -1)
if echo "$first_row" | grep -qE "^1\t1000\t200\t5000\t"; then
    pass "extract-spec row 1: correct token fields"
else
    fail "extract-spec row 1 unexpected: '$first_row'"
fi

# extract-spec for v2 returns 1 row
output2=$(run_stats extract-spec 2)
rows2=$(echo "$output2" | grep -c "^[0-9]" || true)
if [ "$rows2" -eq 1 ]; then
    pass "extract-spec v2 returns 1 row"
else
    fail "extract-spec v2: expected 1 row, got $rows2"
fi

# ─── Test: aggregate-spec sums token totals ────────────────────────────────

echo ""
echo "Test: aggregate-spec computes correct totals..."

# v1: in=1000+2000=3000, out=200+400=600, cache=5000+3000=8000, tasks=2
stats=$(run_stats aggregate-spec 1)
read -r total_in total_out total_cache total_dur task_count <<< "$stats"

if [ "$total_in" -eq 3000 ]; then
    pass "aggregate-spec v1: in_tokens = 3000"
else
    fail "aggregate-spec v1: in_tokens expected 3000, got $total_in"
fi

if [ "$total_out" -eq 600 ]; then
    pass "aggregate-spec v1: out_tokens = 600"
else
    fail "aggregate-spec v1: out_tokens expected 600, got $total_out"
fi

if [ "$task_count" -eq 2 ]; then
    pass "aggregate-spec v1: task_count = 2"
else
    fail "aggregate-spec v1: task_count expected 2, got $task_count"
fi

# ─── Test: aggregate-all combines all specs ────────────────────────────────

echo ""
echo "Test: aggregate-all combines all specs..."

output=$(run_stats aggregate-all)
spec_lines=$(echo "$output" | grep -c "^v" || true)

if [ "$spec_lines" -ge 2 ]; then
    pass "aggregate-all returns rows for both specs"
else
    fail "aggregate-all: expected ≥2 rows, got $spec_lines"
fi

if echo "$output" | grep -q "^v1"; then
    pass "aggregate-all includes v1"
else
    fail "aggregate-all missing v1"
fi

if echo "$output" | grep -q "^v2"; then
    pass "aggregate-all includes v2"
else
    fail "aggregate-all missing v2"
fi

# ─── Test: format-tokens renders correctly ─────────────────────────────────

echo ""
echo "Test: format-tokens renders correctly..."

result=$(bash "$STATS_PARSE" format-tokens 1500)
if echo "$result" | grep -qE "1,500|1500"; then
    pass "format-tokens 1500 → '$result'"
else
    fail "format-tokens 1500 unexpected: '$result'"
fi

result=$(bash "$STATS_PARSE" format-tokens 0)
if [ "$result" = "0" ]; then
    pass "format-tokens 0 → 0"
else
    fail "format-tokens 0 unexpected: '$result'"
fi

# ─── Test: format-duration renders correctly ───────────────────────────────

echo ""
echo "Test: format-duration renders correctly..."

result=$(bash "$STATS_PARSE" format-duration 90)
if echo "$result" | grep -qE "^1:30$"; then
    pass "format-duration 90s → 1:30"
else
    fail "format-duration 90s unexpected: '$result'"
fi

result=$(bash "$STATS_PARSE" format-duration 3661)
if echo "$result" | grep -qE "^1:01:01$"; then
    pass "format-duration 3661s → 1:01:01"
else
    fail "format-duration 3661s unexpected: '$result'"
fi

result=$(bash "$STATS_PARSE" format-duration 0)
if echo "$result" | grep -qE "^0:00$"; then
    pass "format-duration 0 → 0:00"
else
    fail "format-duration 0 unexpected: '$result'"
fi

# ─── Test: calculate-cost computes expected value ──────────────────────────

echo ""
echo "Test: calculate-cost computes cost..."

# 1M input at $3.00/M = $3.00
result=$(bash "$STATS_PARSE" calculate-cost 1000000 0 0)
if echo "$result" | grep -qE "^3\.00$"; then
    pass "calculate-cost 1M input = \$3.00"
else
    fail "calculate-cost 1M input unexpected: '$result'"
fi

# 100K output at $15.00/M = $1.50
result=$(bash "$STATS_PARSE" calculate-cost 0 100000 0)
if echo "$result" | grep -qE "^1\.50$"; then
    pass "calculate-cost 100K output = \$1.50"
else
    fail "calculate-cost 100K output unexpected: '$result'"
fi

result=$(bash "$STATS_PARSE" calculate-cost 0 0 0)
if echo "$result" | grep -qE "^0\.00$"; then
    pass "calculate-cost all zeros = \$0.00"
else
    fail "calculate-cost zeros unexpected: '$result'"
fi

# ─── Test: missing README exits with error ─────────────────────────────────

echo ""
echo "Test: missing README exits with error..."

EMPTY_DIR="$TEST_HOME/empty"
mkdir -p "$EMPTY_DIR"

set +e; output=$((cd "$EMPTY_DIR" && bash "$STATS_PARSE" extract-spec 1) 2>&1); exit_code=$?; set -e
if [ "$exit_code" -ne 0 ]; then
    pass "missing README exits non-zero"
else
    fail "missing README should exit non-zero"
fi

if echo "$output" | grep -qi "ERROR\|not found"; then
    pass "missing README produces error message"
else
    fail "missing README: expected error message, got: $output"
fi

# ─── Test: README with no metadata returns empty (no crash) ────────────────

echo ""
echo "Test: no-metadata README returns empty output (no crash)..."

NOMETA_DIR="$TEST_HOME/nometa"
mkdir -p "$NOMETA_DIR/specs"
cat > "$NOMETA_DIR/specs/README.md" << 'EOF'
## Quick Status

| Spec | Name | Progress | Status | Owner |
| ---- | ---- | -------- | ------ | ----- |
| v1   | Plain Spec | 2/2 | ✅ Complete | — |

---

## v1: Plain Spec

- [x] Task with no metadata
- [x] Another task

---
EOF

set +e; output=$((cd "$NOMETA_DIR" && bash "$STATS_PARSE" extract-spec 1) 2>&1); exit_code=$?; set -e
if [ "$exit_code" -eq 0 ]; then
    pass "no-metadata README exits cleanly (exit 0)"
else
    fail "no-metadata README should exit 0, got: $exit_code"
fi

if [ -z "$output" ]; then
    pass "no-metadata README returns empty output"
else
    fail "no-metadata README: expected empty output, got: $output"
fi

echo ""
echo "========================================"
printf "Results: %d passed, %d failed\n" $PASS $FAIL
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-stats-parse PASSED"
    exit 0
else
    echo "✗ test-stats-parse FAILED"
    exit 1
fi
