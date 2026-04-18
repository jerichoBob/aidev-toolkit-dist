#!/bin/bash
#
# aidev toolkit Documentation Inventory Test
#
# Verifies every skill appears in docs/aid-help.md
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HELP_DOC="$REPO_DIR/docs/aid-help.md"
PASS=0
FAIL=0

# Helper functions
pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

# Extract skill name from file
get_skill_name() {
    local file="$1"
    local filename=$(basename "$file" .md)
    echo "$filename"
}

# Check if skill is documented
check_documented() {
    local skill_name="$1"

    # Check if skill name appears in help doc (case-insensitive)
    if grep -qi "/$skill_name" "$HELP_DOC" || grep -qi "$skill_name\.md" "$HELP_DOC"; then
        pass "$skill_name is documented"
    else
        fail "$skill_name is NOT documented"
    fi
}

echo ""
echo "aidev toolkit Documentation Inventory"
echo "====================================="

# Check help doc exists
if [ ! -f "$HELP_DOC" ]; then
    echo "ERROR: Help documentation not found at $HELP_DOC"
    exit 1
fi

echo ""
echo "Checking core skills..."

# Find all core skill files (excluding template)
CORE_SKILLS=$(find "$REPO_DIR/skills" -name "*.md" -not -name "SKILL-TEMPLATE.md" 2>/dev/null || true)

if [ -n "$CORE_SKILLS" ]; then
    while IFS= read -r skill_file; do
        skill_name=$(get_skill_name "$skill_file")
        check_documented "$skill_name"
    done <<< "$CORE_SKILLS"
fi

echo ""
echo "Checking module skills..."

# Find all module skill files (excluding templates)
MODULE_SKILLS=$(find "$REPO_DIR/modules" -type f -path "*/skills/*.md" -not -name "TEMPLATE.md" 2>/dev/null || true)

if [ -n "$MODULE_SKILLS" ]; then
    while IFS= read -r skill_file; do
        skill_name=$(get_skill_name "$skill_file")
        check_documented "$skill_name"
    done <<< "$MODULE_SKILLS"
fi

# Summary
echo ""
echo "====================================="
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
