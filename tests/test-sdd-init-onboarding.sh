#!/bin/bash
#
# aidev toolkit — sdd-init Onboarding Scaffold Tests (spec-v100)
#
# Verifies the docs/ONBOARDING.md scaffold behavior documented in
# modules/sdd/skills/sdd-init.md Step 5: create when missing, skip when
# present (no --force), overwrite when present (--force). Exercises the
# actual mkdir/cp commands against a real temp project dir and the real
# shipped template — no mocks.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$REPO_DIR/modules/sdd/templates/ONBOARDING-TEMPLATE.md"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

echo ""
echo "sdd-init Onboarding Scaffold Tests"
echo "===================================="

if [ -f "$TEMPLATE" ]; then
    pass "ONBOARDING-TEMPLATE.md exists in modules/sdd/templates/"
else
    fail "ONBOARDING-TEMPLATE.md missing: $TEMPLATE"
    exit 1
fi

grep -q '\[project-specific\]' "$TEMPLATE" && pass "Template preserves [project-specific] placeholders" || fail "Template missing [project-specific] placeholders"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# --- Case A: docs/ONBOARDING.md does not exist -> created ---
PROJECT_A="$TMPDIR/project-a"
mkdir -p "$PROJECT_A"
(
  cd "$PROJECT_A"
  mkdir -p docs
  cp "$TEMPLATE" docs/ONBOARDING.md
)

if [ -f "$PROJECT_A/docs/ONBOARDING.md" ]; then
    pass "Case A: docs/ONBOARDING.md created when missing"
else
    fail "Case A: docs/ONBOARDING.md was not created"
fi

if diff -q "$TEMPLATE" "$PROJECT_A/docs/ONBOARDING.md" > /dev/null 2>&1; then
    pass "Case A: created file matches shipped template exactly"
else
    fail "Case A: created file differs from shipped template"
fi

# --- Case B: docs/ONBOARDING.md exists, FORCE=false -> skipped, untouched ---
PROJECT_B="$TMPDIR/project-b"
mkdir -p "$PROJECT_B/docs"
echo "# Customized onboarding doc — do not overwrite" > "$PROJECT_B/docs/ONBOARDING.md"
ORIGINAL_CONTENT="$(cat "$PROJECT_B/docs/ONBOARDING.md")"

FORCE=false
(
  cd "$PROJECT_B"
  if [ -f docs/ONBOARDING.md ] && [ "$FORCE" = "false" ]; then
      : # skip silently, matching sdd-init.md Step 5 behavior
  else
      mkdir -p docs
      cp "$TEMPLATE" docs/ONBOARDING.md
  fi
)

AFTER_CONTENT="$(cat "$PROJECT_B/docs/ONBOARDING.md")"
if [ "$ORIGINAL_CONTENT" = "$AFTER_CONTENT" ]; then
    pass "Case B: existing docs/ONBOARDING.md left untouched without --force"
else
    fail "Case B: existing docs/ONBOARDING.md was modified without --force"
fi

# --- Case C: docs/ONBOARDING.md exists, FORCE=true -> overwritten ---
PROJECT_C="$TMPDIR/project-c"
mkdir -p "$PROJECT_C/docs"
echo "# Stale onboarding doc — should be overwritten" > "$PROJECT_C/docs/ONBOARDING.md"

FORCE=true
(
  cd "$PROJECT_C"
  if [ -f docs/ONBOARDING.md ] && [ "$FORCE" = "false" ]; then
      :
  else
      mkdir -p docs
      cp "$TEMPLATE" docs/ONBOARDING.md
  fi
)

if diff -q "$TEMPLATE" "$PROJECT_C/docs/ONBOARDING.md" > /dev/null 2>&1; then
    pass "Case C: --force overwrites existing docs/ONBOARDING.md with current template"
else
    fail "Case C: --force did not overwrite docs/ONBOARDING.md correctly"
fi

# --- Verify skill instructions document all three cases ---
SDD_INIT="$REPO_DIR/modules/sdd/skills/sdd-init.md"
grep -q "docs/ONBOARDING.md" "$SDD_INIT" && pass "sdd-init.md documents docs/ONBOARDING.md scaffolding" || fail "sdd-init.md missing docs/ONBOARDING.md step"
grep -q "skip silently.*specs/TEMPLATE.md\|matches.*specs/TEMPLATE.md\|consistent with .specs/TEMPLATE.md" "$SDD_INIT" && pass "sdd-init.md documents skip-if-exists semantics matching specs/TEMPLATE.md" || fail "sdd-init.md missing skip-if-exists semantics note"
grep -q "Overwrote docs/ONBOARDING.md" "$SDD_INIT" && pass "sdd-init.md documents --force overwrite reporting" || fail "sdd-init.md missing --force overwrite reporting"

echo ""
echo "===================================="
echo "Results: $PASS passed, $FAIL failed"
echo "===================================="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

exit 0
