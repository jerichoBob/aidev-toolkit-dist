#!/bin/bash
# Test: spec v139 — `spec-loop-queue.py --check-categories` and completed-spec markers in the categories table.
# Runs the real script against committed fixture directories — no mocks, no stubs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS="$REPO_DIR/modules/sdd/scripts"
CF="$SCRIPT_DIR/fixtures/spec-loop-categories"
PF="$SCRIPT_DIR/fixtures/spec-loop-priority"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
has() { case "$1" in *"$2"*) return 0;; *) return 1;; esac; }
check() { # check <label> <haystack> <needle>
    if has "$2" "$3"; then pass "$1"; else fail "$1 (missing: $3)"; fi
}
check_not() {
    if has "$2" "$3"; then fail "$1 (unexpected: $3)"; else pass "$1"; fi
}

command -v python3 >/dev/null || { echo "python3 not available — blocked"; exit 0; }

# chk <fixture dir> [extra args] — run the check against a fixture; prints stdout, sets RC
chk() {
    local d="$1"; shift
    python3 "$SCRIPTS/spec-loop-queue.py" --check-categories --specs-dir "$CF/$d/specs" \
        --categories-file "$CF/$d/categories.md" --config "$CF/none.yaml" "$@" 2>/dev/null
}

echo ""
echo "Test: check reports fresh when every spec (open and completed) is listed (AC-1, AC-2)"
OUT=$(chk fresh); RC=$?
check "outcome is fresh" "$(echo "$OUT" | sed -n 1p)" "fresh"
check "no unlisted" "$OUT" "unlisted: "$'\n'
[ "$RC" -eq 0 ] && pass "exit 0" || fail "exit $RC"

echo ""
echo "Test: check reports stale with unlisted (incl. completed, dotted) and dangling (AC-1, AC-2)"
OUT=$(chk stale); RC=$?
check "outcome is stale" "$(echo "$OUT" | sed -n 1p)" "stale"
check "open spec v3 is unlisted" "$(echo "$OUT" | grep '^unlisted')" "v3"
check "completed dotted spec v38.5 is unlisted" "$(echo "$OUT" | grep '^unlisted')" "v38.5"
check_not "listed completed spec v2* is not unlisted" "$(echo "$OUT" | grep '^unlisted')" "v2"
check "row naming a spec with no file is dangling (v9)" "$(echo "$OUT" | grep '^dangling')" "v9"
[ "$RC" -eq 0 ] && pass "stale exits 0" || fail "stale exit $RC"
JS=$(chk stale --json)
check "json carries the outcome" "$JS" '"outcome": "stale"'

echo ""
echo "Test: missing categories file or no table (AC-1, AC-9)"
OUT=$(python3 "$SCRIPTS/spec-loop-queue.py" --check-categories --specs-dir "$CF/nofile/specs" --categories-file "$CF/nofile/nope.md" --config "$CF/none.yaml" 2>/dev/null); RC=$?
check "no file reports missing" "$(echo "$OUT" | sed -n 1p)" "missing"
check "every spec is then unlisted" "$(echo "$OUT" | grep '^unlisted')" "v1"
[ "$RC" -eq 0 ] && pass "missing exits 0" || fail "missing exit $RC"
OUT=$(python3 "$SCRIPTS/spec-loop-queue.py" --check-categories --specs-dir "$CF/nospecs/specs" --categories-file "$CF/nospecs/nope.md" --config "$CF/none.yaml" 2>/dev/null); RC=$?
check "no specs and no file reports missing without error" "$(echo "$OUT" | sed -n 1p)" "missing"
[ "$RC" -eq 0 ] && pass "no-specs exits 0" || fail "no-specs exit $RC"

echo ""
echo "Test: the check never writes (AC-1, AC-8)"
BEFORE=$(cksum "$CF/stale/categories.md" "$CF/stale/specs/spec-v3-new.md")
chk stale >/dev/null
AFTER=$(cksum "$CF/stale/categories.md" "$CF/stale/specs/spec-v3-new.md")
[ "$BEFORE" = "$AFTER" ] && pass "check leaves files unchanged" || fail "check changed files"

echo ""
echo "Test: a completed marker (v11*) in the Specs column still scores the spec (AC-5)"
ORD=$(python3 "$SCRIPTS/spec-loop-queue.py" --specs-dir "$PF/specs" --owner me@x.org --json --config "$PF/none.yaml" --priority roi --categories-file "$CF/completed-marker.md" 2>/dev/null \
    | python3 -c 'import json,sys; q=json.load(sys.stdin)["queue"]; print(" ".join(x["version"] for x in q), {x["version"]:x["value_source"] for x in q}["v11"])')
check "order unchanged with a completed marker" "$ORD" "v11 v10 v12"
check "v11* still takes its category value" "$ORD" "category"

echo ""
echo "Test: skill and docs describe the check and analysis step (AC-3, AC-11)"
SK="$REPO_DIR/modules/sdd/skills/sdd-spec-loop.md"
if grep -q -- "--check-categories" "$SK" 2>/dev/null; then
    check "skill runs the check" "$(cat "$SK")" "--check-categories"
    check "skill runs the analysis only on missing or stale" "$(cat "$SK")" "stale"
    check "skill preserves edited Values" "$(cat "$SK")" "keep"
    check "modules/sdd/README describes it" "$(cat "$REPO_DIR/modules/sdd/README.md")" "check-categories"
    check "aid-help describes it" "$(cat "$REPO_DIR/docs/aid-help.md")" "spec-categories.md"
else
    fail "skill does not mention --check-categories yet (Phase 2 pending)"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
