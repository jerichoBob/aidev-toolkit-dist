#!/bin/bash
#
# aidev toolkit Frontmatter Validation Tests
#
# Validates YAML frontmatter in all skill files
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0

# Helper functions
pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

# Extract frontmatter field value
get_frontmatter_field() {
    local file="$1"
    local field="$2"

    # Extract only the YAML frontmatter block (lines 2 through the closing ---)
    awk 'NR==1{next} /^---$/{exit} {print}' "$file" | \
    grep "^${field}:" | head -1 | \
    sed "s/^${field}:[[:space:]]*//" | \
    sed 's/^["\047]//' | sed 's/["\047]$//'
}

# Validate a single skill file
validate_skill() {
    local file="$1"
    local filename=$(basename "$file")

    echo ""
    echo "Validating $filename..."

    # Check file has frontmatter delimiters
    if ! grep -q '^---$' "$file"; then
        fail "Missing frontmatter delimiters"
        return
    fi

    # Extract fields
    local name=$(get_frontmatter_field "$file" "name")
    local description=$(get_frontmatter_field "$file" "description")
    local allowed_tools=$(get_frontmatter_field "$file" "allowed-tools")

    # Validate name field
    if [ -z "$name" ]; then
        fail "Missing 'name' field"
    elif [[ ! "$name" =~ ^[a-z0-9-]+$ ]]; then
        fail "Invalid 'name' format (must be lowercase alphanumeric with hyphens): $name"
    else
        pass "Valid 'name' field: $name"
    fi

    # Validate description field
    if [ -z "$description" ]; then
        fail "Missing 'description' field"
    else
        pass "Valid 'description' field"
    fi

    # Validate allowed-tools field (optional but must be valid if present)
    if [ -n "$allowed_tools" ]; then
        # Known tool name prefixes (Bash may have path constraints like Bash(path:*))
        local known_prefixes="Bash Read Write Edit Glob Grep Task AskUserQuestion WebFetch WebSearch Skill EnterPlanMode ExitPlanMode all"
        local valid=true
        # Split on commas (allowing optional spaces), check each token starts with a known prefix
        IFS=',' read -ra tools <<< "$allowed_tools"
        for tool in "${tools[@]}"; do
            tool="${tool#"${tool%%[![:space:]]*}"}"  # trim leading spaces
            local matched=false
            for prefix in $known_prefixes; do
                if [[ "$tool" == "$prefix" || "$tool" == "$prefix("* ]]; then
                    matched=true
                    break
                fi
            done
            if [ "$matched" = false ]; then
                fail "Unrecognized tool in allowed-tools: '$tool'"
                valid=false
            fi
        done
        [ "$valid" = true ] && pass "Valid 'allowed-tools' field"
    fi
}

echo ""
echo "aidev toolkit Frontmatter Validation"
echo "===================================="

# Find all skill files
CORE_SKILLS=$(find "$REPO_DIR/skills" -name "*.md" -not -name "SKILL-TEMPLATE.md" 2>/dev/null || true)
MODULE_SKILLS=$(find "$REPO_DIR/modules" -type f -path "*/skills/*.md" -not -name "TEMPLATE.md" 2>/dev/null || true)

# Validate core skills
if [ -n "$CORE_SKILLS" ]; then
    echo ""
    echo "Core Skills:"
    while IFS= read -r skill; do
        validate_skill "$skill"
    done <<< "$CORE_SKILLS"
fi

# Validate module skills
if [ -n "$MODULE_SKILLS" ]; then
    echo ""
    echo "Module Skills:"
    while IFS= read -r skill; do
        validate_skill "$skill"
    done <<< "$MODULE_SKILLS"
fi

# Summary
echo ""
echo "===================================="
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
