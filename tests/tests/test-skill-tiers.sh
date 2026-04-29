#!/bin/bash
#
# aidev toolkit Skill Tier Tests
#
# Validates that tier: frontmatter field is correctly parsed and
# that skills default to 'extended' when the field is absent.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

get_tier() {
    local file="$1"
    awk 'NR==1{next} /^---$/{exit} {print}' "$file" | \
    grep "^tier:" | head -1 | \
    sed "s/^tier:[[:space:]]*//"
}

echo ""
echo "Skill Tier Tests"
echo "================"

# --- Fixture: skill with tier: core ---
CORE_FIXTURE=$(mktemp /tmp/test-skill-tier-core-XXXXXX.md)
cat > "$CORE_FIXTURE" <<'EOF'
---
name: test-core-skill
tier: core
description: A test skill with tier core
allowed-tools: Read
---

# Test Core Skill
EOF

tier=$(get_tier "$CORE_FIXTURE")
if [ "$tier" = "core" ]; then
    pass "skill with tier: core is recognized as core"
else
    fail "skill with tier: core returned '$tier', expected 'core'"
fi
rm -f "$CORE_FIXTURE"

# --- Fixture: skill with tier: extended ---
EXT_FIXTURE=$(mktemp /tmp/test-skill-tier-ext-XXXXXX.md)
cat > "$EXT_FIXTURE" <<'EOF'
---
name: test-extended-skill
tier: extended
description: A test skill with tier extended
allowed-tools: Read
---

# Test Extended Skill
EOF

tier=$(get_tier "$EXT_FIXTURE")
if [ "$tier" = "extended" ]; then
    pass "skill with tier: extended is recognized as extended"
else
    fail "skill with tier: extended returned '$tier', expected 'extended'"
fi
rm -f "$EXT_FIXTURE"

# --- Fixture: skill with no tier (defaults to extended) ---
NO_TIER_FIXTURE=$(mktemp /tmp/test-skill-notier-XXXXXX.md)
cat > "$NO_TIER_FIXTURE" <<'EOF'
---
name: test-no-tier-skill
description: A test skill with no tier field
allowed-tools: Read
---

# Test No-Tier Skill
EOF

tier=$(get_tier "$NO_TIER_FIXTURE")
effective_tier="${tier:-extended}"
if [ "$effective_tier" = "extended" ]; then
    pass "skill with no tier defaults to extended"
else
    fail "skill with no tier defaulted to '$effective_tier', expected 'extended'"
fi
rm -f "$NO_TIER_FIXTURE"

# --- Verify real skills have valid tier values ---
echo ""
echo "Verifying real skill tier values..."

INVALID=0
for file in "$REPO_DIR/skills"/*.md "$REPO_DIR/modules/sdd/skills"/*.md; do
    [ -f "$file" ] || continue
    name=$(basename "$file" .md)
    [ "$name" = "SKILL-TEMPLATE" ] && continue
    tier=$(get_tier "$file")
    if [ -n "$tier" ] && [ "$tier" != "core" ] && [ "$tier" != "extended" ]; then
        fail "$(basename $file) has invalid tier value: '$tier'"
        ((INVALID++)) || true
    fi
done

if [ "$INVALID" -eq 0 ]; then
    pass "All skills with tier field have valid values (core or extended)"
fi

# --- Verify known core skills are marked core ---
KNOWN_CORE="commit commit-push lint inspect arch-review gmail-digest remember aid aid-update aid-feedback"
for name in $KNOWN_CORE; do
    f="$REPO_DIR/skills/${name}.md"
    [ -f "$f" ] || continue
    tier=$(get_tier "$f")
    if [ "$tier" = "core" ]; then
        pass "$name is marked tier: core"
    else
        fail "$name should be tier: core, got '${tier:-<missing>}'"
    fi
done

# --- Verify known extended skills are marked extended ---
KNOWN_EXTENDED="aws-costs deal-desk browser-harness screenshots test-run test-status"
for name in $KNOWN_EXTENDED; do
    f="$REPO_DIR/skills/${name}.md"
    [ -f "$f" ] || continue
    tier=$(get_tier "$f")
    if [ "$tier" = "extended" ]; then
        pass "$name is marked tier: extended"
    else
        fail "$name should be tier: extended, got '${tier:-<missing>}'"
    fi
done

# --- Summary ---
echo ""
echo "================"
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
