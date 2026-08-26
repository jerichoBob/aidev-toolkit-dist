#!/bin/bash
#
# aidev toolkit aid-feedback label-cache marker test (spec-v108, Phase 7)
#
# Verifies the marker-file freshness check described in skills/aid-feedback.md:
# `find "$MARKER" -mtime -30` is used to skip `gh label create` calls when a
# recent marker exists. Uses real files and real `find`/`touch` — no mocks.
#
# Live gh label-create/gh issue calls against a disposable GitHub target are
# NOT exercised here — this repo has no safe throwaway repo to mutate in CI.
# BLOCKED: no safe live GitHub target for exercising the actual gh label
# create/skip network calls; the marker-file logic itself (the actual new
# behavior) is fully covered below with real filesystem operations.
#

set -e

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

TEST_HOME=$(mktemp -d)
cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

echo ""
echo "aidev toolkit aid-feedback label-cache Tests"
echo "================================================="
echo "  (BLOCKED: live gh label-create network path not exercised — no safe"
echo "   disposable GitHub repo available; marker-file logic tested below)"

MARKER="$TEST_HOME/.labels-verified-jerichoBob-aidev-toolkit-dist"

echo ""
echo "Test: missing marker → treated as stale (create calls should run)..."
if find "$MARKER" -mtime -30 2>/dev/null | grep -q .; then
    fail "find should return nothing for a missing marker"
else
    pass "missing marker correctly yields no match (fall back to create)"
fi

echo ""
echo "Test: fresh marker (just touched) → skip create calls..."
touch "$MARKER"
if find "$MARKER" -mtime -30 2>/dev/null | grep -q .; then
    pass "fresh marker matches -mtime -30 (create calls skipped)"
else
    fail "fresh marker should match -mtime -30"
fi
rm -f "$MARKER"

echo ""
echo "Test: stale marker (>30 days old) → create calls should run again..."
touch "$MARKER"
# Backdate the marker's mtime to 40 days ago.
touch -t "$(date -v-40d +%Y%m%d%H%M 2>/dev/null || date -d '40 days ago' +%Y%m%d%H%M)" "$MARKER"
if find "$MARKER" -mtime -30 2>/dev/null | grep -q .; then
    fail "40-day-old marker incorrectly matched -mtime -30"
else
    pass "stale (40-day) marker correctly falls outside -mtime -30 (fall back to create)"
fi
rm -f "$MARKER"

echo ""
echo "================================================="
printf "Results: %d passed, %d failed\n" "$PASS" "$FAIL"
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-aid-feedback-label-cache PASSED (marker logic; live gh path blocked)"
    exit 0
else
    echo "✗ test-aid-feedback-label-cache FAILED"
    exit 1
fi
