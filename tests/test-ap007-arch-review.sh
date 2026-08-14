#!/bin/bash
#
# aidev toolkit AP-007 / arch-review Integration Tests
#
# Validates that architecture-principles/07-runtime-observability.md is complete
# and that /arch-review has been wired up to check AP-006 and AP-007.
#
# Note: /arch-review is a Claude-driven skill, not a deterministic binary, so
# this test validates the skill instructions and principle documents statically
# (same approach as test-frontmatter.sh) rather than invoking Claude against
# fixture codebases.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

AP007="$REPO_DIR/architecture-principles/07-runtime-observability.md"
AP006="$REPO_DIR/architecture-principles/06-supply-chain-integrity.md"
ARCH_REVIEW="$REPO_DIR/skills/arch-review.md"
AID_HELP="$REPO_DIR/docs/aid-help.md"

echo ""
echo "AP-007 / arch-review Integration Tests"
echo "======================================="

echo ""
echo "Checking architecture-principles/07-runtime-observability.md..."

if [ -f "$AP007" ]; then
    pass "File exists"
else
    fail "File does not exist: $AP007"
fi

grep -q "^id: AP-007$" "$AP007" && pass "Frontmatter id: AP-007" || fail "Missing frontmatter id: AP-007"
grep -q "^severity: required$" "$AP007" && pass "Frontmatter severity: required" || fail "Missing frontmatter severity: required"
grep -q "^category: observability$" "$AP007" && pass "Frontmatter category: observability" || fail "Missing frontmatter category: observability"

for level in silent normal verbose debug trace; do
    grep -qi "\`$level\`" "$AP007" && pass "Verbosity level documented: $level" || fail "Missing verbosity level: $level"
done

grep -q "obs_level" "$AP007" && pass "obs_level field documented" || fail "Missing obs_level field"
grep -q "X-Obs-Level" "$AP007" && pass "X-Obs-Level header documented" || fail "Missing X-Obs-Level header"
grep -q "REDACTED" "$AP007" && pass "Secret redaction documented" || fail "Missing secret redaction guidance"
grep -q "Audit Trail" "$AP007" && pass "Audit trail requirement documented" || fail "Missing audit trail requirement"
grep -q "## Validation Checklist" "$AP007" && pass "Validation checklist present" || fail "Missing validation checklist"

echo ""
echo "Checking skills/arch-review.md wiring..."

if [ -f "$ARCH_REVIEW" ]; then
    pass "arch-review.md exists"
else
    fail "arch-review.md does not exist: $ARCH_REVIEW"
fi

grep -q "07-runtime-observability.md" "$ARCH_REVIEW" && pass "AP-007 loaded in Step 1" || fail "AP-007 not loaded in Step 1"
grep -q "06-supply-chain-integrity.md" "$ARCH_REVIEW" && pass "AP-006 loaded in Step 1" || fail "AP-006 not loaded in Step 1"
grep -q "#### AP-007:" "$ARCH_REVIEW" && pass "AP-007 checklist section present" || fail "Missing AP-007 checklist section"
grep -q "#### AP-006:" "$ARCH_REVIEW" && pass "AP-006 checklist section present" || fail "Missing AP-006 checklist section"

# AP-007 search patterns from AC-8: config persistence, audit trail, obs_level, UI banner
AP007_SECTION=$(awk '/^#### AP-007:/{flag=1; next} flag && /^#### |^### /{exit} flag' "$ARCH_REVIEW")
echo "$AP007_SECTION" | grep -qi "obs_level" && pass "AP-007 checks obs_level in logs" || fail "AP-007 section missing obs_level check"
echo "$AP007_SECTION" | grep -qi "audit" && pass "AP-007 checks audit trail" || fail "AP-007 section missing audit trail check"
echo "$AP007_SECTION" | grep -qi "banner" && pass "AP-007 checks UI banner" || fail "AP-007 section missing UI banner check"
echo "$AP007_SECTION" | grep -qi "internal/obs\|verbosity" && pass "AP-007 checks config/level-control endpoint" || fail "AP-007 section missing config/endpoint check"

echo ""
echo "Checking docs/aid-help.md reference list..."

grep -q "AP-006" "$AID_HELP" && pass "AP-006 listed in aid-help.md" || fail "AP-006 not listed in aid-help.md"
grep -q "AP-007" "$AID_HELP" && pass "AP-007 listed in aid-help.md" || fail "AP-007 not listed in aid-help.md"

echo ""
echo "======================================="
echo "Results: $PASS passed, $FAIL failed"
echo "======================================="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

exit 0
