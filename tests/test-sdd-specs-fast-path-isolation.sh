#!/bin/bash
#
# aidev toolkit sdd-specs Fast Path isolation test (spec-v108, AC-8)
#
# Non-regression check: the default Fast Path section of sdd-specs.md must
# never instruct any Bash/tool call beyond reading specs/README.md. This is
# a static check against the actual skill file content — real file read,
# no mocks.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$REPO_DIR/modules/sdd/skills/sdd-specs.md"

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

echo ""
echo "aidev toolkit sdd-specs Fast Path isolation Tests"
echo "===================================================="

if [ ! -f "$SKILL_FILE" ]; then
    fail "skill file not found: $SKILL_FILE"
    echo "Results: $PASS passed, $FAIL failed"
    exit 1
fi

# Extract the Fast Path section: from "## Fast Path" up to the next "## " heading.
FAST_PATH_SECTION=$(awk '/^## Fast Path/{flag=1; print; next} /^## /{if (flag) exit} flag' "$SKILL_FILE")

if [ -z "$FAST_PATH_SECTION" ]; then
    fail "could not locate '## Fast Path' section in sdd-specs.md"
else
    pass "Fast Path section located"
fi

echo ""
echo "Test: Fast Path section contains no bash code blocks..."
if echo "$FAST_PATH_SECTION" | grep -q '```bash'; then
    fail "Fast Path section contains a bash code block — violates read-only invariant"
else
    pass "no bash code blocks found in Fast Path section"
fi

echo ""
echo "Test: Fast Path section references only specs/README.md as a read target..."
# Any "Read " instruction line should mention specs/README.md, not another file.
BAD_READS=$(echo "$FAST_PATH_SECTION" | grep -E "^Read " | grep -v "specs/README.md" || true)
if [ -n "$BAD_READS" ]; then
    fail "Fast Path references a read target other than specs/README.md: $BAD_READS"
else
    pass "all Read instructions in Fast Path target specs/README.md only"
fi

echo ""
echo "Test: Fast Path explicitly states the STOP invariant..."
if echo "$FAST_PATH_SECTION" | grep -qi "STOP here"; then
    pass "Fast Path contains an explicit STOP-here invariant statement"
else
    fail "Fast Path missing explicit STOP-here invariant statement"
fi

echo ""
echo "Test: non-regression invariant note references this spec's isolation test..."
if grep -q "test-sdd-specs-fast-path-isolation.sh" "$SKILL_FILE"; then
    pass "skill file documents the isolation test that guards this invariant"
else
    fail "skill file does not reference the isolation test"
fi

echo ""
echo "===================================================="
printf "Results: %d passed, %d failed\n" "$PASS" "$FAIL"
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-sdd-specs-fast-path-isolation PASSED"
    exit 0
else
    echo "✗ test-sdd-specs-fast-path-isolation FAILED"
    exit 1
fi
