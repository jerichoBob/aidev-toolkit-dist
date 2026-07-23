#!/bin/bash
#
# test-status-footer-jq-requirement.sh — /status-footer jq dependency guard tests
#
# Verifies that skills/status-footer.md hard-requires jq via an upfront
# `command -v jq` check that runs before any jq call site, with an
# actionable install-hint error message, and that the config file is
# actually created with defaults on first run.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$REPO_DIR/skills/status-footer.md"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

check() {
    if eval "$1" 2>/dev/null; then pass "$2"; else fail "$2"; fi
}

echo ""
echo "status-footer jq Requirement Tests"
echo "==================================="

echo ""
echo "Phase 1: Upfront jq guard exists and runs first..."

check 'grep -q "command -v jq" "$SKILL_FILE"' \
    "a command -v jq guard exists in the skill file"

check '[[ $(grep -n "command -v jq" "$SKILL_FILE" | head -1 | cut -d: -f1) -lt $(grep -n "^### 0b\." "$SKILL_FILE" | head -1 | cut -d: -f1) ]]' \
    "jq guard appears before Step 0b (health check)"

check '[[ $(grep -n "command -v jq" "$SKILL_FILE" | head -1 | cut -d: -f1) -lt $(grep -n "^jq " "$SKILL_FILE" | head -1 | cut -d: -f1) ]]' \
    "jq guard appears before the first jq call site"

echo ""
echo "Phase 2: Error message includes install hints for all platforms..."

check 'grep -q "brew install jq" "$SKILL_FILE"' \
    "error message includes macOS (brew) install hint"

check 'grep -q "winget install jqlang.jq" "$SKILL_FILE"' \
    "error message includes Windows (winget) install hint"

check 'grep -q "apt install jq" "$SKILL_FILE"' \
    "error message includes Linux (apt) install hint"

echo ""
echo "Phase 3: First-run config creation..."

check 'grep -q "mkdir -p" "$SKILL_FILE"' \
    "config directory is created if missing"

check 'grep -qE "if \[\[ ! -f \"\\\$CONFIG\" \]\]" "$SKILL_FILE"' \
    "config file is written with defaults when missing, not just echoed"

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
