#!/bin/bash
#
# aidev toolkit test-aid-bedrock-topic.sh Test Suite
#
# Verifies that docs/aid-help.md contains the required Bedrock routing
# configuration fields as specified by spec v82 AC-1 through AC-4.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HELP_FILE="$REPO_DIR/docs/aid-help.md"

PASS=0
FAIL=0
BLOCKED=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
skip_blocked() { echo "  ⊘ $1 [BLOCKED: $2]"; ((BLOCKED++)) || true; }

echo ""
echo "aidev toolkit test-aid-bedrock-topic.sh Tests"
echo "==============================================="

# ─── Prerequisite: help file exists ─────────────────────────────────────────

echo ""
echo "Test: docs/aid-help.md exists..."

if [ -f "$HELP_FILE" ]; then
    pass "docs/aid-help.md found"
else
    echo "  ✗ docs/aid-help.md not found — cannot continue"
    echo ""
    echo "==============================================="
    echo "Results: 0 passed, 1 failed, 0 blocked"
    echo ""
    echo "✗ test-aid-bedrock-topic FAILED"
    exit 1
fi

# ─── AC-2: Required config fields present ───────────────────────────────────

echo ""
echo "Test: CLAUDE_CODE_USE_BEDROCK=1 is documented..."

if grep -q "CLAUDE_CODE_USE_BEDROCK" "$HELP_FILE"; then
    pass "CLAUDE_CODE_USE_BEDROCK env var documented"
else
    fail "CLAUDE_CODE_USE_BEDROCK not found in docs/aid-help.md"
fi

echo ""
echo "Test: ANTHROPIC_MODEL is documented..."

if grep -q "ANTHROPIC_MODEL" "$HELP_FILE"; then
    pass "ANTHROPIC_MODEL env var documented"
else
    fail "ANTHROPIC_MODEL not found in docs/aid-help.md"
fi

echo ""
echo "Test: example Bedrock cross-region inference profile ID present..."

if grep -q "global\.anthropic\." "$HELP_FILE"; then
    pass "cross-region inference profile ID format documented"
else
    fail "cross-region inference profile ID (global.anthropic.*) not found"
fi

echo ""
echo "Test: note about cross-region inference profile format present..."

if grep -qi "cross-region inference" "$HELP_FILE"; then
    pass "cross-region inference profile note documented"
else
    fail "cross-region inference profile note not found in docs/aid-help.md"
fi

# ─── AC-4: Bedrock/AWS Routing section exists ───────────────────────────────

echo ""
echo "Test: ## Bedrock / AWS Routing section present..."

if grep -q "## Bedrock / AWS Routing" "$HELP_FILE"; then
    pass "Bedrock / AWS Routing section header found"
else
    fail "## Bedrock / AWS Routing section not found in docs/aid-help.md"
fi

# ─── AC-1 / AC-2: bedrock argument section exists ───────────────────────────

echo ""
echo "Test: section handler for 'bedrock' argument present..."

if grep -q '"bedrock"' "$HELP_FILE"; then
    pass "bedrock argument section handler found"
else
    fail "bedrock argument handler not found in docs/aid-help.md"
fi

echo ""
echo "Test: section handler for 'model' argument present..."

if grep -q '"model"' "$HELP_FILE"; then
    pass "model argument section handler found"
else
    fail "model argument handler not found in docs/aid-help.md"
fi

# ─── AC-3: Main /aid output references bedrock topic ────────────────────────

echo ""
echo "Test: main /aid output references /aid bedrock..."

# The main output section is between the first <!-- OUTPUT --> and <!-- /OUTPUT -->
main_section=$(awk '/^<!-- OUTPUT -->/{found=1} found{print} /^<!-- \/OUTPUT -->/{found=0}' "$HELP_FILE" | head -60)

if echo "$main_section" | grep -q "bedrock"; then
    pass "main /aid output references bedrock topic"
else
    fail "main /aid output does not reference bedrock topic"
fi

# ─── settings.json snippet is present ───────────────────────────────────────

echo ""
echo "Test: settings.json snippet with env block present..."

if grep -q '"env"' "$HELP_FILE" && grep -q "CLAUDE_CODE_USE_BEDROCK" "$HELP_FILE"; then
    pass "settings.json env snippet documented"
else
    fail "settings.json env snippet not found in docs/aid-help.md"
fi

echo ""
echo "==============================================="
printf "Results: %d passed, %d failed, %d blocked (skipped)\n" $PASS $FAIL $BLOCKED
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-aid-bedrock-topic PASSED"
    exit 0
else
    echo "✗ test-aid-bedrock-topic FAILED"
    exit 1
fi
