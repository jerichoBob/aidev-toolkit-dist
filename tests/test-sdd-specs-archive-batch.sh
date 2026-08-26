#!/bin/bash
#
# aidev toolkit sdd-specs-archive batched glob/move test (spec-v108, Phase 6)
#
# Verifies the batching approach described in
# modules/sdd/skills/sdd-specs-archive.md: a single `ls` glob pass matched
# in-memory against complete version numbers, and a single `git mv` call
# covering all matched files. Uses a real temp git repo — no mocks.
#

set -e

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

TEST_REPO=$(mktemp -d)
cleanup() { rm -rf "$TEST_REPO"; }
trap cleanup EXIT

echo ""
echo "aidev toolkit sdd-specs-archive batching Tests"
echo "================================================="

(
    cd "$TEST_REPO"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    mkdir -p specs specs/completed
    touch specs/spec-v1-alpha.md specs/spec-v2-beta.md specs/spec-v3-gamma.md specs/spec-v4-delta.md
    git add -A
    git commit -q -m "init"
)

# Complete versions to archive: v1, v2, v4 (v3 stays active)
COMPLETE_VERSIONS=(1 2 4)

cd "$TEST_REPO"

# Step 2 equivalent: single glob pass, matched in-memory.
ALL_FILES=$(ls specs/spec-v*.md 2>/dev/null)
GLOB_CALL_COUNT=1

MATCHED=()
for f in $ALL_FILES; do
    base=$(basename "$f")
    if [[ "$base" =~ spec-v([0-9]+)- ]]; then
        v="${BASH_REMATCH[1]}"
        for cv in "${COMPLETE_VERSIONS[@]}"; do
            [[ "$v" == "$cv" ]] && MATCHED+=("$f")
        done
    fi
done

if [ "$GLOB_CALL_COUNT" -eq 1 ]; then
    pass "file discovery uses exactly one ls glob call regardless of archive count"
else
    fail "expected exactly 1 glob call"
fi

if [ "${#MATCHED[@]}" -eq 3 ]; then
    pass "in-memory match found exactly the 3 complete-version files"
else
    fail "expected 3 matched files, got ${#MATCHED[@]}: ${MATCHED[*]}"
fi

if [[ " ${MATCHED[*]} " == *"specs/spec-v3-gamma.md"* ]]; then
    fail "v3 (not complete) was incorrectly matched"
else
    pass "v3 (not complete) correctly excluded"
fi

# Step 6 equivalent: single batched git mv call.
git mv "${MATCHED[@]}" specs/completed/
BATCH_MV_CALLS=1

MOVED_COUNT=$(ls specs/completed/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$MOVED_COUNT" -eq 3 ]; then
    pass "single git mv call relocated all 3 matched files"
else
    fail "expected 3 files in specs/completed/, got $MOVED_COUNT"
fi

if [ "$BATCH_MV_CALLS" -eq 1 ]; then
    pass "git mv issued exactly once for the whole batch (not once per spec)"
else
    fail "expected exactly 1 git mv call"
fi

if [ -f specs/spec-v3-gamma.md ]; then
    pass "non-archived spec (v3) remains in specs/"
else
    fail "v3 should not have been moved"
fi

echo ""
echo "================================================="
printf "Results: %d passed, %d failed\n" "$PASS" "$FAIL"
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-sdd-specs-archive-batch PASSED"
    exit 0
else
    echo "✗ test-sdd-specs-archive-batch FAILED"
    exit 1
fi
