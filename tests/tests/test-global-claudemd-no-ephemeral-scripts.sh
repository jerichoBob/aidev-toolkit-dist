#!/bin/bash
#
# Tests for v70: NO EPHEMERAL SCRIPTS rule in Global CLAUDE.md Template
#
# Verifies that templates/global-claude.md includes the NO EPHEMERAL SCRIPTS
# rule with proper guidance on script and data persistence.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

echo ""
echo "Test: NO EPHEMERAL SCRIPTS rule in global CLAUDE.md template (v70)"

TEMPLATE="$REPO_DIR/templates/global-claude.md"

if [ ! -f "$TEMPLATE" ]; then
    fail "templates/global-claude.md does not exist"
    exit 1
fi

# Test 1: NO EPHEMERAL SCRIPTS rule header exists
if grep -q "NO EPHEMERAL SCRIPTS\|Ephemeral Scripts" "$TEMPLATE" 2>/dev/null; then
    pass "NO EPHEMERAL SCRIPTS section header found"
else
    fail "NO EPHEMERAL SCRIPTS section header not found"
fi

# Test 2: Scripts persistence path mentioned (.claude/scripts/)
if grep -q "\.claude/scripts\|claude/scripts" "$TEMPLATE" 2>/dev/null; then
    pass "Script persistence path (.claude/scripts/) mentioned"
else
    fail "Script persistence path not mentioned"
fi

# Test 3: Data persistence path mentioned (.claude/data/)
if grep -q "\.claude/data\|claude/data" "$TEMPLATE" 2>/dev/null; then
    pass "Data persistence path (.claude/data/) mentioned"
else
    fail "Data persistence path not mentioned"
fi

# Test 4: Fallback fallback paths mentioned (~/.claude/scripts/, ~/.claude/data/)
if grep -q "~.*claude\|home.*claude" "$TEMPLATE" 2>/dev/null; then
    pass "Fallback home directory paths mentioned"
else
    fail "Fallback home directory paths not mentioned"
fi

# Test 5: "work product" or "tokens" or "reuse" rationale present
if grep -q "[Ww]ork product\|paid.*tokens\|reuse\|user can find it" "$TEMPLATE" 2>/dev/null; then
    pass "Rationale (work product/tokens/reuse/findability) present"
else
    fail "Rationale not clearly stated"
fi

# Test 6: Verify install.sh copies the template (optional but good practice)
if grep -q "global-claude.md\|templates/global-claude.md" "$REPO_DIR/scripts/install.sh" 2>/dev/null; then
    pass "install.sh references the template file"
else
    fail "install.sh does not reference the template"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
