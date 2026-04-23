#!/bin/bash
#
# aidev toolkit test-docs-inventory.sh Test Suite
#
# Tests the documentation inventory checker using fixture skill/doc directories.
# Verifies pass, fail-on-missing-skill, and error-on-missing-docs cases.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REAL_SCRIPT="$REPO_DIR/scripts/test-docs-inventory.sh"

PASS=0
FAIL=0
BLOCKED=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
skip_blocked() { echo "  ⊘ $1 [BLOCKED: $2]"; ((BLOCKED++)) || true; }

TEST_HOME=$(mktemp -d)
cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

# Build a fixture repo directory with a scripts/ subdir so the script can
# derive REPO_DIR correctly from its own location.
setup_fixture_repo() {
    local fixture="$1"
    mkdir -p "$fixture/scripts" "$fixture/skills" "$fixture/modules/sdd/skills" "$fixture/docs"

    # Copy the real script into fixture scripts/ so REPO_DIR resolves correctly
    cp "$REAL_SCRIPT" "$fixture/scripts/test-docs-inventory.sh"
    chmod +x "$fixture/scripts/test-docs-inventory.sh"
}

echo ""
echo "aidev toolkit test-docs-inventory.sh Tests"
echo "==========================================="

# ─── Test 1: Real repo — all skills documented (integration) ───────────────

echo ""
echo "Test: real repo — all skills documented..."

set +e; output=$(bash "$REAL_SCRIPT" 2>&1); exit_code=$?; set -e

if [ "$exit_code" -eq 0 ]; then
    pass "real repo passes documentation inventory check"
else
    # Show which skills are undocumented
    missing=$(echo "$output" | grep "✗" | head -5)
    fail "real repo has undocumented skills: $missing"
fi

# ─── Test 2: Missing docs file → error ─────────────────────────────────────

echo ""
echo "Test: missing docs file exits with error..."

FIXTURE1="$TEST_HOME/fixture-nodocs"
setup_fixture_repo "$FIXTURE1"

# Create one skill but NO docs/aid-help.md
echo "---
name: test-skill
description: A test skill
---" > "$FIXTURE1/skills/test-skill.md"
# docs/ exists but aid-help.md does not

set +e; output=$(bash "$FIXTURE1/scripts/test-docs-inventory.sh" 2>&1); exit_code=$?; set -e

if [ "$exit_code" -ne 0 ]; then
    pass "missing docs file exits non-zero"
else
    fail "missing docs file should exit non-zero (got 0)"
fi

if echo "$output" | grep -qi "not found\|ERROR\|No such"; then
    pass "missing docs file produces error message"
else
    fail "missing docs file: expected error message, got: $output"
fi

# ─── Test 3: Skill missing from docs → fail with skill name ────────────────

echo ""
echo "Test: skill missing from docs — fails with skill name..."

FIXTURE2="$TEST_HOME/fixture-missing"
setup_fixture_repo "$FIXTURE2"

# Create two skills
echo "---
name: documented-skill
description: A documented skill
---" > "$FIXTURE2/skills/documented-skill.md"

echo "---
name: undocumented-skill
description: A skill NOT in docs
---" > "$FIXTURE2/skills/undocumented-skill.md"

# Create docs/aid-help.md that mentions only documented-skill
cat > "$FIXTURE2/docs/aid-help.md" << 'EOF'
# Help

## Commands

/documented-skill — does something useful
documented-skill.md is here
EOF

set +e; output=$(bash "$FIXTURE2/scripts/test-docs-inventory.sh" 2>&1); exit_code=$?; set -e

if [ "$exit_code" -ne 0 ]; then
    pass "missing skill causes non-zero exit"
else
    fail "missing skill should cause non-zero exit (got 0)"
fi

if echo "$output" | grep -qi "undocumented-skill"; then
    pass "missing skill name appears in output"
else
    fail "missing skill name not in output: $output"
fi

# ─── Test 4: All skills documented → passes ───────────────────────────────

echo ""
echo "Test: all skills documented — passes..."

FIXTURE3="$TEST_HOME/fixture-all-documented"
setup_fixture_repo "$FIXTURE3"

echo "---
name: skill-alpha
description: First skill
---" > "$FIXTURE3/skills/skill-alpha.md"

echo "---
name: skill-beta
description: Second skill
---" > "$FIXTURE3/modules/sdd/skills/skill-beta.md"

cat > "$FIXTURE3/docs/aid-help.md" << 'EOF'
# Help

/skill-alpha — does alpha things
/skill-beta — does beta things
skill-alpha.md
skill-beta.md
EOF

set +e; output=$(bash "$FIXTURE3/scripts/test-docs-inventory.sh" 2>&1); exit_code=$?; set -e

if [ "$exit_code" -eq 0 ]; then
    pass "all-documented fixture passes"
else
    failing=$(echo "$output" | grep "✗" | head -3)
    fail "all-documented fixture failed: $failing"
fi

echo ""
echo "==========================================="
printf "Results: %d passed, %d failed, %d blocked (skipped)\n" $PASS $FAIL $BLOCKED
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-docs-inventory PASSED"
    exit 0
else
    echo "✗ test-docs-inventory FAILED"
    exit 1
fi
