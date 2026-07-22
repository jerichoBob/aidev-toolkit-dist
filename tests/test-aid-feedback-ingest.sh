#!/bin/bash
#
# test-aid-feedback-ingest.sh — aid-feedback dual-repo ingest tests
#
# Verifies that skills/aid-feedback.md correctly implements dual-repo ingest:
# both repos queried, issues tagged with repo field, labels created on both
# repos, processed label applied to correct repo, spec frontmatter updated.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$REPO_DIR/skills/aid-feedback.md"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

check() {
    if eval "$1" 2>/dev/null; then pass "$2"; else fail "$2"; fi
}

echo ""
echo "aid-feedback Ingest Tests"
echo "========================="

echo ""
echo "Phase 1: Both repos queried in Step 1..."

check 'grep -q "gh issue list --repo jerichoBob/aidev-toolkit " "$SKILL_FILE"' \
    "Step 1 queries jerichoBob/aidev-toolkit"

check 'grep -q "gh issue list --repo jerichoBob/aidev-toolkit-dist" "$SKILL_FILE"' \
    "Step 1 queries jerichoBob/aidev-toolkit-dist"

check 'grep -q '"'"'repo.*jerichoBob/aidev-toolkit-dist'"'"' "$SKILL_FILE"' \
    "dist repo issues tagged with repo field"

check 'grep -q '"'"'"repo": "jerichoBob/aidev-toolkit"'"'"' "$SKILL_FILE"' \
    "source repo issues tagged with repo field"

echo ""
echo "Phase 2: Labels created on both repos..."

check 'grep -c "gh label create feedback --repo jerichoBob" "$SKILL_FILE" | grep -q "^2$"' \
    "feedback label created on both repos (2 create commands)"

check 'grep -c "gh label create processed --repo jerichoBob" "$SKILL_FILE" | grep -q "^2$"' \
    "processed label created on both repos (2 create commands)"

check 'grep -q "gh label create feedback --repo jerichoBob/aidev-toolkit-dist" "$SKILL_FILE"' \
    "feedback label create targets jerichoBob/aidev-toolkit-dist"

check 'grep -q "gh label create processed --repo jerichoBob/aidev-toolkit-dist" "$SKILL_FILE"' \
    "processed label create targets jerichoBob/aidev-toolkit-dist"

echo ""
echo "Phase 3: Spec frontmatter records source repo..."

check 'grep -q "github_issue_repo" "$SKILL_FILE"' \
    "github_issue_repo field added to spec frontmatter instructions"

check 'grep -q "gh issue close {number} --repo {repo}" "$SKILL_FILE"' \
    "close-issue task uses per-issue repo variable"

echo ""
echo "Phase 4: processed label applied to correct repo..."

check 'grep -q "gh issue edit {number} --repo {repo}" "$SKILL_FILE"' \
    "Step 8 uses {repo} field for gh issue edit"

check '! grep -A2 "add the \`processed\` label" "$SKILL_FILE" | grep -q "jerichoBob/aidev-toolkit --add-label"' \
    "Step 8 no longer hardcodes jerichoBob/aidev-toolkit"

echo ""
echo "========================="
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
