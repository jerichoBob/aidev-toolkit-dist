#!/bin/bash
#
# aidev toolkit test-sdd-spec.sh Test Suite
#
# /sdd-spec is a Claude-driven skill, so the LLM's final judgment is not
# testable here. These tests exercise the real deterministic heuristic helper
# (modules/sdd/scripts/slicing-check.sh) that seeds Step 2.45's horizontal
# slicing check: it must fire for bundled logic+UI phases with a missing-infra
# reference (AC-1/AC-2) and stay silent otherwise (AC-4/AC-5).
#

set -e

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK="$SCRIPT_DIR/../modules/sdd/scripts/slicing-check.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "slicing-check.sh"

# Fixture 1: logic phase + UI phase that depends on an authenticated-fetch layer
cat > "$WORK/bundled.md" <<'EOF'
## v1: Report Export

### Phase 1: Backend export service

- [ ] Add export API endpoint
- [ ] Add database query for report rows

### Phase 2: Admin UI

- [ ] Add export button to the admin page — requires the shared authenticated-fetch layer
- [ ] Render download progress
EOF
out=$("$CHECK" "$WORK/bundled.md")
if printf '%s' "$out" | grep -q '^WARN	.*Admin UI	'; then pass "warns for bundled logic+UI phase with missing infra"; else fail "expected WARN for bundled phases, got: '$out'"; fi
if printf '%s' "$out" | grep -qi 'authenticated'; then pass "warning names the missing infra"; else fail "warning should name authenticated-fetch infra, got: '$out'"; fi

# Fixture 2: logic-only spec (AC-4)
cat > "$WORK/logic-only.md" <<'EOF'
### Phase 1: Backend service

- [ ] Add API endpoint — requires the database schema

### Phase 2: Tests

- [ ] Add integration tests
EOF
out=$("$CHECK" "$WORK/logic-only.md")
if [ -z "$out" ]; then pass "silent for logic-only spec (AC-4)"; else fail "expected no output for logic-only spec, got: '$out'"; fi

# Fixture 3: logic + UI but UI has no infra reference (AC-4)
cat > "$WORK/self-contained.md" <<'EOF'
### Phase 1: Backend service

- [ ] Add API endpoint

### Phase 2: Frontend page

- [ ] Add a static page that lists results
EOF
out=$("$CHECK" "$WORK/self-contained.md")
if [ -z "$out" ]; then pass "silent when UI phase has no missing-infra reference"; else fail "expected no output, got: '$out'"; fi

# Fixture 4: ambiguous heading matches both logic and UI keywords (AC-5)
cat > "$WORK/ambiguous.md" <<'EOF'
### Phase 1: Backend service

- [ ] Add API endpoint

### Phase 2: API and UI wiring

- [ ] Hook things up — requires the shared api client
EOF
out=$("$CHECK" "$WORK/ambiguous.md")
if [ -z "$out" ]; then pass "silent for ambiguous phase heading (AC-5)"; else fail "expected no output for ambiguous phase, got: '$out'"; fi

# Fixture 5: word-boundary — "build"/"guide" must not count as "ui"
cat > "$WORK/boundary.md" <<'EOF'
### Phase 1: Backend service

- [ ] Add API endpoint

### Phase 2: Build guide

- [ ] Write docs — requires the shared api client
EOF
out=$("$CHECK" "$WORK/boundary.md")
if [ -z "$out" ]; then pass "does not misclassify 'Build guide' as UI"; else fail "word-boundary match failed, got: '$out'"; fi

# stdin mode
out=$("$CHECK" - < "$WORK/bundled.md")
if printf '%s' "$out" | grep -q '^WARN'; then pass "reads draft from stdin"; else fail "stdin mode failed, got: '$out'"; fi

# error handling
if "$CHECK" "$WORK/does-not-exist.md" 2>/dev/null; then fail "missing file should exit nonzero"; else pass "exits nonzero for unreadable file"; fi
if "$CHECK" 2>/dev/null; then fail "missing argument should exit nonzero"; else pass "exits nonzero with no argument"; fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
