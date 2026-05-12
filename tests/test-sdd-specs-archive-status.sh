#!/bin/bash
#
# Tests for v69: sdd-specs-archive status mismatch fix
#
# Verifies:
# 1. sdd-specs-archive.md no longer contains the step that changes status to 🗄 Archived
# 2. sdd-specs.md no longer contains the F4 remap rule
# 3. specs/README.md contains no 🗄 Archived rows in the Quick Status table
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

echo ""
echo "Test: sdd-specs-archive — status mismatch fix (v69)"

# Test 1: sdd-specs-archive.md must NOT change status to 🗄 Archived
ARCHIVE_SKILL="$REPO_DIR/modules/sdd/skills/sdd-specs-archive.md"
if grep -q "change the Status column.*🗄 Archived\|Status.*from.*Complete.*to.*Archived\|marked 🗄 Archived" "$ARCHIVE_SKILL" 2>/dev/null; then
    fail "sdd-specs-archive.md still contains step that marks rows as 🗄 Archived"
else
    pass "sdd-specs-archive.md does not mark rows as 🗄 Archived"
fi

# Test 2: sdd-specs-archive.md should mention retaining ✅ Complete
if grep -q "retained.*Complete\|retain.*Complete\|status retained" "$ARCHIVE_SKILL" 2>/dev/null; then
    pass "sdd-specs-archive.md mentions retaining ✅ Complete status"
else
    fail "sdd-specs-archive.md missing 'status retained' language"
fi

# Test 3: sdd-specs.md must NOT contain the F4 remap rule
SPECS_SKILL="$REPO_DIR/modules/sdd/skills/sdd-specs.md"
if grep -q "display.*🗄 Archived.*rows as.*✅ Complete\|replace the archive icon with the green check" "$SPECS_SKILL" 2>/dev/null; then
    fail "sdd-specs.md still contains F4 remap rule (🗄 Archived → ✅ Complete)"
else
    pass "sdd-specs.md F4 remap rule removed"
fi

# Test 4: specs/README.md Quick Status table must contain no 🗄 Archived rows
README="$REPO_DIR/specs/README.md"
# Extract just the Quick Status table (between ## Quick Status and the first ---)
TABLE=$(awk '/## Quick Status/{found=1} found && /^---/{exit} found{print}' "$README")
if echo "$TABLE" | grep -q "🗄 Archived"; then
    ARCHIVED_COUNT=$(echo "$TABLE" | grep -c "🗄 Archived")
    fail "specs/README.md Quick Status table still has $ARCHIVED_COUNT rows with 🗄 Archived"
else
    pass "specs/README.md Quick Status table has no 🗄 Archived rows"
fi

# Test 5: specs/README.md should have ✅ Complete rows (archived specs are now Complete)
if grep -q "✅ Complete" "$README" 2>/dev/null; then
    COUNT=$(grep -c "✅ Complete" "$README")
    pass "specs/README.md has $COUNT ✅ Complete rows (includes previously archived specs)"
else
    fail "specs/README.md has no ✅ Complete rows — migration may have failed"
fi

# Test 6: --archived filter in sdd-specs.md should still reference ✅ Complete
if grep -q "\-\-archived.*✅ Complete\|✅ Complete.*\-\-archived" "$SPECS_SKILL" 2>/dev/null; then
    pass "sdd-specs.md --archived filter references ✅ Complete"
else
    fail "sdd-specs.md --archived filter may not handle ✅ Complete rows"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
