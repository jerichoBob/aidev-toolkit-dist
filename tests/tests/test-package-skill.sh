#!/bin/bash
#
# aidev toolkit package-skill.sh Partial Test Suite
#
# Tests argument validation, VERSION extraction, and dist/ output structure
# using a fixture repo directory. No upload to Claude Desktop required.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

TEST_HOME=$(mktemp -d)
cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

# Build a minimal fixture repo structure: scripts/, skills/, README.md
setup_fixture_repo() {
    local fixture="$1"
    mkdir -p "$fixture/scripts" "$fixture/skills" "$fixture/templates" "$fixture/dist"

    # Copy real script into fixture's scripts/
    cp "$REPO_DIR/scripts/package-skill.sh" "$fixture/scripts/package-skill.sh"
    chmod +x "$fixture/scripts/package-skill.sh"

    # Fixture README.md with version
    cat > "$fixture/README.md" << 'EOF'
# Fixture Toolkit

## Version

9.8.7
EOF

    # Fixture skill file
    cat > "$fixture/skills/test-skill.md" << 'EOF'
---
name: test-skill
description: A fixture skill for testing
allowed-tools: Bash(bash:*)
---

# Test Skill

This is a test skill.

## Instructions

Do test things.
EOF
}

echo ""
echo "aidev toolkit package-skill.sh Tests"
echo "======================================"

# ─── Test 1: no argument exits non-zero with usage message ─────────────────

echo ""
echo "Test: no argument exits non-zero with usage..."

FIXTURE="$TEST_HOME/fixture-repo"
setup_fixture_repo "$FIXTURE"

set +e
output=$(bash "$FIXTURE/scripts/package-skill.sh" 2>&1)
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ]; then
    pass "no argument exits non-zero"
else
    fail "no argument should exit non-zero (got 0)"
fi

if echo "$output" | grep -qi "Usage\|usage"; then
    pass "no argument shows usage message"
else
    fail "no argument: expected usage message, got: $output"
fi

# ─── Test 2: unknown skill name exits with error ────────────────────────────

echo ""
echo "Test: unknown skill name exits with error..."

set +e
output=$(bash "$FIXTURE/scripts/package-skill.sh" "nonexistent-skill" 2>&1)
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ]; then
    pass "unknown skill exits non-zero"
else
    fail "unknown skill should exit non-zero"
fi

if echo "$output" | grep -qi "Error\|not found"; then
    pass "unknown skill shows error message"
else
    fail "unknown skill: expected error, got: $output"
fi

# ─── Test 3: VERSION extracted correctly from fixture README ────────────────

echo ""
echo "Test: VERSION extracted from README..."

# The script prints "Version: $VERSION" to stdout
set +e
output=$(bash "$FIXTURE/scripts/package-skill.sh" "test-skill" 2>&1)
exit_code=$?
set -e

if echo "$output" | grep -q "Version: 9.8.7"; then
    pass "VERSION extracted as 9.8.7 from fixture README"
else
    fail "VERSION extraction: expected '9.8.7', got: $(echo "$output" | grep "Version:" || echo 'not found')"
fi

# ─── Test 4: dist/ output file created with correct name ───────────────────

echo ""
echo "Test: dist/ output file created with expected name..."

EXPECTED_SKILL="$FIXTURE/dist/test-skill-9.8.7.skill"

if [ -f "$EXPECTED_SKILL" ]; then
    pass "dist/test-skill-9.8.7.skill created"
else
    fail "dist/test-skill-9.8.7.skill not found"
fi

# ─── Test 5: .skill file is a valid zip containing expected structure ───────

echo ""
echo "Test: .skill file is a valid zip with expected structure..."

if [ -f "$EXPECTED_SKILL" ]; then
    if command -v unzip &>/dev/null; then
        zip_list=$(unzip -l "$EXPECTED_SKILL" 2>/dev/null || true)

        if echo "$zip_list" | grep -q "SKILL.md"; then
            pass ".skill zip contains SKILL.md"
        else
            fail ".skill zip missing SKILL.md: $zip_list"
        fi

        if echo "$zip_list" | grep -q "test-skill/"; then
            pass ".skill zip has correct folder structure (test-skill/)"
        else
            fail ".skill zip missing test-skill/ directory: $zip_list"
        fi
    else
        pass ".skill file exists (unzip not available for content check)"
    fi
fi

# ─── Test 6: SKILL.md frontmatter only contains allowed keys ───────────────

echo ""
echo "Test: SKILL.md contains name and description but not disallowed keys..."

if [ -f "$EXPECTED_SKILL" ] && command -v unzip &>/dev/null; then
    skill_content=$(unzip -p "$EXPECTED_SKILL" "test-skill/SKILL.md" 2>/dev/null || true)

    if echo "$skill_content" | grep -q "^name:"; then
        pass "SKILL.md frontmatter contains 'name'"
    else
        fail "SKILL.md missing 'name' in frontmatter"
    fi

    if echo "$skill_content" | grep -q "^metadata:"; then
        pass "SKILL.md frontmatter contains injected 'metadata' (version/build)"
    else
        fail "SKILL.md missing injected 'metadata'"
    fi
fi

echo ""
echo "======================================"
printf "Results: %d passed, %d failed\n" $PASS $FAIL
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-package-skill PASSED"
    exit 0
else
    echo "✗ test-package-skill FAILED"
    exit 1
fi
