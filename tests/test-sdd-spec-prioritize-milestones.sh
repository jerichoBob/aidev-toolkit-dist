#!/bin/bash
#
# aidev toolkit /sdd-spec-prioritize Milestone Weighting Integration Tests
#
# Validates that modules/sdd/skills/sdd-spec-prioritize.md documents the
# ## Milestones section format, the on-path/off-path distinction, the
# "Milestone Path" rubric factor, the opt-in legacy fallback, and the
# blocker-detection heuristic + output format introduced by spec-v107.
#
# Note: /sdd-spec-prioritize is a Claude-driven skill, not a deterministic
# binary, so this test validates the skill instructions statically (same
# approach as test-ap007-arch-review.sh) rather than invoking Claude against
# fixture spec trees. A manual verification step (below) covers the
# LLM-judgment-dependent behavior.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

SKILL="$REPO_DIR/modules/sdd/skills/sdd-spec-prioritize.md"
SDD_TEMPLATE="$REPO_DIR/modules/sdd/templates/TEMPLATE.md"
SPECS_TEMPLATE="$REPO_DIR/specs/TEMPLATE.md"

echo ""
echo "/sdd-spec-prioritize Milestone Weighting Tests"
echo "================================================"

if [ -f "$SKILL" ]; then
    pass "sdd-spec-prioritize.md exists"
else
    fail "sdd-spec-prioritize.md does not exist: $SKILL"
fi

echo ""
echo "Checking ## Milestones section format is documented..."

grep -q "## Milestones" "$SDD_TEMPLATE" && pass "Milestones format documented in modules/sdd/templates/TEMPLATE.md" || fail "Missing Milestones format in modules/sdd/templates/TEMPLATE.md"
grep -q "## Milestones" "$SPECS_TEMPLATE" && pass "Milestones format documented in specs/TEMPLATE.md" || fail "Missing Milestones format in specs/TEMPLATE.md"
grep -q "## Milestones" "$SKILL" && pass "Milestones section format referenced in skill" || fail "Skill does not reference ## Milestones section"

echo ""
echo "Checking opt-in fallback behavior (AC-2)..."

grep -qi "AskUserQuestion" "$SKILL" && pass "AskUserQuestion used for milestone opt-in prompt" || fail "Missing AskUserQuestion for milestone opt-in"
grep -qi "legacy" "$SKILL" && pass "Legacy fallback behavior documented" || fail "Missing legacy fallback documentation"
grep -qi "fully opt-in" "$SKILL" && pass "Feature explicitly documented as fully opt-in" || fail "Missing explicit opt-in statement"

echo ""
echo "Checking on-path/off-path distinction and Milestone Path rubric factor..."

grep -qi "on-path" "$SKILL" && pass "on-path terminology present" || fail "Missing on-path terminology"
grep -qi "off-path" "$SKILL" && pass "off-path terminology present" || fail "Missing off-path terminology"
grep -q "Milestone Path" "$SKILL" && pass "Milestone Path rubric factor documented" || fail "Missing Milestone Path rubric factor"
grep -qi "transitive" "$SKILL" && pass "transitive dependency-chain build documented" || fail "Missing transitive dependency-chain logic"
grep -qi "break ties\|tie-break\|tie-breaker" "$SKILL" && pass "tie-breaking behavior within path group documented" || fail "Missing tie-breaking documentation"

echo ""
echo "Checking blocker-detection heuristic and output format..."

for kw in confirm approval "waiting on" stakeholder access credentials "pending decision from"; do
    grep -qi "$kw" "$SKILL" && pass "Blocker keyword documented: $kw" || fail "Missing blocker keyword: $kw"
done

grep -q "Blocked by:" "$SKILL" && pass "Explicit 'Blocked by:' line heuristic documented" || fail "Missing 'Blocked by:' heuristic"
grep -q "Real priority:" "$SKILL" && pass "'Real priority:' output format documented" || fail "Missing 'Real priority:' output format"
grep -q "Open Questions" "$SKILL" && pass "Open Questions section referenced as blocker scan source" || fail "Missing Open Questions reference"

echo ""
echo "Checking AC-7 (off-path candidates still fill remaining N slots)..."

grep -qi "remaining N slot\|remaining N" "$SKILL" && pass "AC-7 backfill behavior documented" || fail "Missing AC-7 backfill documentation"

echo ""
echo "================================================"
echo "Results: $PASS passed, $FAIL failed"
echo "================================================"

echo ""
echo "MANUAL VERIFICATION (not automatable — exercises LLM judgment):"
echo "  1. Create a fixture specs/README.md with a '## Milestones' section"
echo "     defining a chain (e.g. M2: v6, v7, v8) and one on-path spec file"
echo "     with a stakeholder-blocked 'Open Questions' entry (e.g. 'Waiting"
echo "     on stakeholder approval for SDK access')."
echo "  2. Run /sdd-spec-prioritize against that fixture and confirm the"
echo "     '⚠ Real priority:' line appears above the Top N ranking, and that"
echo "     on-path specs are listed ahead of off-path specs."
echo "  3. Run /sdd-spec-prioritize against a project with no '## Milestones'"
echo "     section and confirm the legacy feasibility-only ranking/prompting"
echo "     behavior is unchanged."

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

exit 0
