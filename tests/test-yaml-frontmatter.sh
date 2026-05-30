#!/bin/bash
#
# test-yaml-frontmatter.sh — YAML Frontmatter Parse Validation
#
# Verifies that every skill file's frontmatter is valid YAML and that
# argument-hint values are strings (not arrays) when present.
#
# Requires: node (for js-yaml) — skips YAML parse tests if js-yaml unavailable.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0
SKIP=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
skip() { echo "  ⊘ $1 [SKIP]"; ((SKIP++)) || true; }

echo "YAML Frontmatter Parse Validation"
echo "=================================="

cd "$REPO_DIR"

# ── Find js-yaml ──────────────────────────────────────────────────────────────
JSYAML_PATH=""
for candidate in \
    "$(find /Users -name "js-yaml" -type d -path "*/node_modules/js-yaml" 2>/dev/null | grep -v ".pnpm" | head -1)" \
    "$(find /usr/local -name "js-yaml" -type d -path "*/node_modules/js-yaml" 2>/dev/null | head -1)"; do
    if [ -n "$candidate" ] && [ -d "$candidate" ]; then
        JSYAML_PATH="$candidate"
        break
    fi
done

if [ -z "$JSYAML_PATH" ]; then
    skip "js-yaml not found on this system — YAML parse tests skipped"
    echo ""
    echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
    exit 0
fi

# ── Collect all skill files ───────────────────────────────────────────────────
SKILL_FILES=$(find skills modules/sdd/skills -name "*.md" -type f 2>/dev/null | sort)
FILE_COUNT=$(echo "$SKILL_FILES" | wc -l | tr -d ' ')

echo ""
echo "Scanning ${FILE_COUNT} skill files..."
echo ""

# ── Run YAML parse + semantic checks via node ─────────────────────────────────
RESULTS=$(node -e "
const yaml = require('${JSYAML_PATH}');
const fs = require('fs');

const files = \`${SKILL_FILES}\`.trim().split('\n').filter(Boolean);
const results = [];

files.forEach(f => {
  let content;
  try { content = fs.readFileSync(f, 'utf8'); } catch(e) { return; }

  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) {
    results.push('NO_FM:' + f);
    return;
  }

  let parsed;
  try {
    parsed = yaml.load(match[1]);
  } catch(e) {
    results.push('PARSE_FAIL:' + f + ':' + e.message.split('\n')[0]);
    return;
  }

  // Semantic check: argument-hint must be a string if present
  if (parsed && parsed['argument-hint'] !== undefined) {
    if (typeof parsed['argument-hint'] !== 'string') {
      results.push('SEMANTIC_FAIL:' + f + ':argument-hint is ' + JSON.stringify(parsed['argument-hint']));
      return;
    }
  }

  results.push('OK:' + f);
});

console.log(results.join('\n'));
" 2>/dev/null)

# ── Tally results ─────────────────────────────────────────────────────────────
while IFS= read -r line; do
    [ -z "$line" ] && continue
    type="${line%%:*}"
    rest="${line#*:}"
    file="${rest%%:*}"
    detail="${rest#*:}"

    case "$type" in
        OK)
            pass "$file — parses OK"
            ;;
        NO_FM)
            # No frontmatter is not an error (some skill files are pure markdown)
            pass "$file — no frontmatter (OK)"
            ;;
        PARSE_FAIL)
            fail "$file — YAML parse error: $detail"
            ;;
        SEMANTIC_FAIL)
            fail "$file — $detail"
            ;;
    esac
done <<< "$RESULTS"

# ── Targeted regression: sdlc-plan.md @ character ────────────────────────────
echo ""
echo "Regression: sdlc-plan.md argument-hint @ character"
echo "---------------------------------------------------"

SDLC_HINT=$(awk 'NR==1{next} /^---$/{exit} /^argument-hint:/{print}' skills/sdlc-plan.md)
if echo "$SDLC_HINT" | grep -q '^argument-hint:[[:space:]]*"'; then
    pass "sdlc-plan.md argument-hint is quoted"
else
    fail "sdlc-plan.md argument-hint is NOT quoted: $SDLC_HINT"
fi

# ── Check no unquoted [ at start of argument-hint values ─────────────────────
echo ""
echo "Regression: unquoted [ in argument-hint values"
echo "-----------------------------------------------"
UNQUOTED=$(grep -rn "^argument-hint: \[" skills/*.md modules/*/skills/*.md 2>/dev/null || true)
if [ -z "$UNQUOTED" ]; then
    pass "No unquoted [ argument-hint values found"
else
    while IFS= read -r line; do
        fail "Unquoted [ value: $line"
    done <<< "$UNQUOTED"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
echo ""

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
