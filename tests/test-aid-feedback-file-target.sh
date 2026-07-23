#!/bin/bash
#
# test-aid-feedback-file-target.sh — aid-feedback new-issue filing target tests
#
# Verifies that skills/aid-feedback.md Step 4 files new feedback issues to
# jerichoBob/aidev-toolkit-dist (the public repo every gh-authenticated user
# can reach), not the private jerichoBob/aidev-toolkit source repo.
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
echo "aid-feedback File-Target Tests"
echo "==============================="

echo ""
echo "Phase 1: Step 4 issue creation targets dist repo..."

check 'grep -q -- "--repo jerichoBob/aidev-toolkit-dist" "$SKILL_FILE"' \
    "Step 4 gh issue create targets jerichoBob/aidev-toolkit-dist"

check '! grep -Eq -- "--repo jerichoBob/aidev-toolkit[[:space:]]*$" "$SKILL_FILE"' \
    "no gh issue create call targets the bare private repo jerichoBob/aidev-toolkit"

check 'grep -q "^  --repo jerichoBob/aidev-toolkit-dist \\\\\$" "$SKILL_FILE"' \
    "gh issue create --repo line is exactly jerichoBob/aidev-toolkit-dist"

echo ""
echo "Phase 2: Confirmation message names dist repo..."

check 'grep -q "Feedback submitted to jerichoBob/aidev-toolkit-dist" "$SKILL_FILE"' \
    "Step 5 confirmation message names jerichoBob/aidev-toolkit-dist"

echo ""
echo "Phase 3: Label bootstrap still creates labels on both repos..."

check 'grep -q "gh label create feedback --repo jerichoBob/aidev-toolkit-dist" "$SKILL_FILE"' \
    "Step 0b creates feedback label on dist repo"

check 'grep -q "gh label create feedback --repo jerichoBob/aidev-toolkit " "$SKILL_FILE"' \
    "Step 0b still creates feedback label on private repo (for ingestion-side labeling)"

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
