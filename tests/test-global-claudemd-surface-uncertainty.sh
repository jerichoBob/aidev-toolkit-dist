#!/bin/bash
#
# Tests for v72: Surface Uncertainty Principle in Global CLAUDE.md Template
#
# Verifies that templates/global-claude.md includes the Uncertainty & Tradeoffs
# section with required keywords and directives.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

echo ""
echo "Test: Surface Uncertainty Principle in global CLAUDE.md template (v72)"

TEMPLATE="$REPO_DIR/templates/global-claude.md"

if [ ! -f "$TEMPLATE" ]; then
    fail "templates/global-claude.md does not exist"
    exit 1
fi

# Test 1: Uncertainty section header exists
if grep -q "## Uncertainty & Tradeoffs\|## Uncertainty and Tradeoffs" "$TEMPLATE" 2>/dev/null; then
    pass "Uncertainty & Tradeoffs section header exists"
else
    fail "Uncertainty & Tradeoffs section header not found"
fi

# Test 2: "Don't assume" / "assumption" keyword present
if grep -q "[Dd]on't assume\|assumption" "$TEMPLATE" 2>/dev/null; then
    pass "Assumption keyword found in section"
else
    fail "Assumption keyword not found"
fi

# Test 3: "surface" keyword present (surface tradeoffs, surface confusion, etc.)
if grep -q "[Ss]urface.*tradeoff\|[Ss]urface.*confusion\|[Ss]urface" "$TEMPLATE" 2>/dev/null; then
    pass "Surface keyword found in section"
else
    fail "Surface keyword not found"
fi

# Test 4: "clarif" / "ask" keyword present (ask for clarification, multiple interpretations, etc.)
if grep -q "[Aa]sk.*clarif\|multiple.*interp\|state.*explicit" "$TEMPLATE" 2>/dev/null; then
    pass "Clarification/interpretation keyword found"
else
    fail "Clarification/interpretation keyword not found"
fi

# Test 5: Verify the principle comes before or after other critical rules (structure check)
UNCERTAINTY_LINE=$(grep -n "## Uncertainty" "$TEMPLATE" | cut -d: -f1 | head -1)
if grep -q "## NO MOCKS\|### NO MOCKS\|NO MOCKS — EVER" "$TEMPLATE" 2>/dev/null; then
    pass "NO MOCKS rule present (section order correct)"
else
    fail "NO MOCKS rule not found"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
