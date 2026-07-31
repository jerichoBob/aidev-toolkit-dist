#!/bin/bash
#
# Integration tests for /sdd-spec template resolution order (v89)
# Reads the real skill file — no mocks, no stubs.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SDD_SPEC="$REPO_DIR/modules/sdd/skills/sdd-spec.md"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

echo ""
echo "Test: /sdd-spec template resolution order (v89)"

# Test 1: skill file exists
if [ -f "$SDD_SPEC" ]; then
    pass "modules/sdd/skills/sdd-spec.md exists"
else
    fail "modules/sdd/skills/sdd-spec.md not found"
    echo ""
    echo "Results: $PASS passed, $FAIL failed"
    exit 1
fi

# Test case 1: Local template exists -> used (local path checked before global)
local_line=$(grep -n "specs/TEMPLATE.md" "$SDD_SPEC" | head -1 | cut -d: -f1)
global_line=$(grep -n "modules/sdd/templates/TEMPLATE.md" "$SDD_SPEC" | head -1 | cut -d: -f1)
if [ -n "$local_line" ] && [ -n "$global_line" ] && [ "$local_line" -lt "$global_line" ]; then
    pass "specs/TEMPLATE.md (local) is checked before the global fallback"
else
    fail "local template path is not checked before the global fallback"
fi

# Test case 2: No local template -> global fallback used
if grep -q "Global fallback.*specs/templates/TEMPLATE.md\|Global fallback.*used only if" "$SDD_SPEC" 2>/dev/null || \
   grep -q "used only if \`specs/TEMPLATE.md\` does not exist" "$SDD_SPEC" 2>/dev/null; then
    pass "global fallback is explicitly conditioned on local template absence"
else
    fail "global fallback condition on local-template-absence not found"
fi

# Test case 3: Local template malformed -> skill reports error, no silent fallback
if grep -q "do NOT silently fall back to the global template" "$SDD_SPEC" 2>/dev/null; then
    pass "skill instructs failing loudly on malformed local template (no silent fallback)"
else
    fail "no instruction found preventing silent fallback on malformed local template"
fi

# Template source logging present in both flows' reports
log_count=$(grep -c "Template source" "$SDD_SPEC" 2>/dev/null || true)
if [ "$log_count" -ge 2 ]; then
    pass "template source is logged in the report ($log_count occurrences)"
else
    fail "template source logging missing or incomplete (found $log_count occurrences, expected >= 2)"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
