#!/bin/bash
#
# Tests for v71: /status-footer health check and ctx% color documentation
#
# Verifies:
# 1. skills/status-footer.md contains the health check step
# 2. The health check warns on inline statusLine commands
# 3. The auto-correct sets the correct statusLine value
# 4. The menu output documents ctx% color thresholds
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

echo ""
echo "Test: /status-footer health check and ctx% color documentation (v71)"

SKILL="$REPO_DIR/skills/status-footer.md"

if [ ! -f "$SKILL" ]; then
    fail "skills/status-footer.md does not exist"
    exit 1
fi

# Test 1: Health check step exists
if grep -q "Health Check\|health.check\|statusline\.sh" "$SKILL" 2>/dev/null; then
    pass "Health check step references statusline.sh"
else
    fail "Health check step not found"
fi

# Test 2: Health check warns on inline command mismatch
if grep -q "statusLine.*not pointing\|color coding is inactive\|Auto-correct" "$SKILL" 2>/dev/null; then
    pass "Health check warns on misconfigured statusLine"
else
    fail "Health check warning text not found"
fi

# Test 3: Auto-correct logic sets correct command
EXPECTED='bash ~/.claude/aidev-toolkit/scripts/statusline.sh'
if grep -q "$EXPECTED" "$SKILL" 2>/dev/null; then
    pass "Auto-correct sets correct statusline.sh command path"
else
    fail "Auto-correct command path not found in skill"
fi

# Test 4: Color legend present in menu output
if grep -q "🟢.*🟡.*🔴\|0–59.*60–79.*80\|color.*ctx\|ctx.*color" "$SKILL" 2>/dev/null; then
    pass "ctx% color legend present in menu output"
else
    fail "ctx% color legend not found in menu"
fi

# Test 5: Auto-compact threshold documented as ~85% (not 95%)
if grep -q "85%\|~85\|auto-compact.*85" "$SKILL" 2>/dev/null; then
    pass "Auto-compact threshold documented as ~85%"
else
    fail "Auto-compact threshold (85%) not mentioned in skill"
fi

# Test 6: No stale 95% auto-compact references across skills/
STALE=$(grep -rn "auto.compact.*95%\|95%.*auto.compact" "$REPO_DIR/skills/" "$REPO_DIR/modules/" 2>/dev/null | grep -v ".git" || true)
if [ -z "$STALE" ]; then
    pass "No stale 95% auto-compact references found"
else
    fail "Stale 95% auto-compact references found: $STALE"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
