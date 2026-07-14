#!/bin/bash
#
# Integration tests for the /sdd-code rename and /sdd-code-spec deprecation wrapper (v88)
# Reads the real skill files — no mocks, no stubs.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SDD_CODE="$REPO_DIR/modules/sdd/skills/sdd-code.md"
SDD_CODE_SPEC="$REPO_DIR/modules/sdd/skills/sdd-code-spec.md"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

get_field() {
    local file="$1"
    local field="$2"
    awk 'NR==1{next} /^---$/{exit} {print}' "$file" | \
    grep "^${field}:" | head -1 | \
    sed "s/^${field}:[[:space:]]*//"
}

echo ""
echo "Test: /sdd-code rename and /sdd-code-spec deprecation wrapper (v88)"

# Test 1: sdd-code.md exists at the renamed path
if [ -f "$SDD_CODE" ]; then
    pass "modules/sdd/skills/sdd-code.md exists"
else
    fail "modules/sdd/skills/sdd-code.md not found"
fi

# Test 2: sdd-code.md has name: sdd-code
name=$(get_field "$SDD_CODE" "name")
if [ "$name" = "sdd-code" ]; then
    pass "sdd-code.md frontmatter name: sdd-code"
else
    fail "sdd-code.md frontmatter name is '$name', expected 'sdd-code'"
fi

# Test 3: sdd-code.md has the full implementation workflow (not a stub)
if grep -q "Implement all remaining phases and tasks" "$SDD_CODE" 2>/dev/null; then
    pass "sdd-code.md contains the full implementation workflow"
else
    fail "sdd-code.md missing expected workflow content"
fi

# Test 4: sdd-code-spec.md exists as the deprecation wrapper
if [ -f "$SDD_CODE_SPEC" ]; then
    pass "modules/sdd/skills/sdd-code-spec.md (wrapper) exists"
else
    fail "modules/sdd/skills/sdd-code-spec.md not found"
fi

# Test 5: wrapper is marked deprecated: true
deprecated=$(get_field "$SDD_CODE_SPEC" "deprecated")
if [ "$deprecated" = "true" ]; then
    pass "sdd-code-spec.md frontmatter deprecated: true"
else
    fail "sdd-code-spec.md deprecated field is '$deprecated', expected 'true'"
fi

# Test 6: wrapper shows the deprecation warning
if grep -q "is deprecated. Use \`/sdd-code\` instead" "$SDD_CODE_SPEC" 2>/dev/null; then
    pass "sdd-code-spec.md contains the deprecation warning text"
else
    fail "sdd-code-spec.md missing deprecation warning text"
fi

# Test 7: wrapper forwards to /sdd-code via the Skill tool
if grep -q "Forward all arguments to \`/sdd-code\`" "$SDD_CODE_SPEC" 2>/dev/null && \
   grep -q "^allowed-tools: Skill$" "$SDD_CODE_SPEC" 2>/dev/null; then
    pass "sdd-code-spec.md forwards to /sdd-code via the Skill tool"
else
    fail "sdd-code-spec.md missing forwarding instructions or Skill tool permission"
fi

# Test 8: install.sh SDD_SKILLS array includes both sdd-code.md and sdd-code-spec.md
if grep -q '"sdd-code.md"' "$REPO_DIR/scripts/install.sh" && grep -q '"sdd-code-spec.md"' "$REPO_DIR/scripts/install.sh"; then
    pass "scripts/install.sh SDD_SKILLS array includes sdd-code.md and sdd-code-spec.md"
else
    fail "scripts/install.sh SDD_SKILLS array missing sdd-code.md or sdd-code-spec.md"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
