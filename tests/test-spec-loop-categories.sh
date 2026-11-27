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
echo "Test: spec-digest.py prints one line per spec, completed marked (AC-13)"
DG=$(python3 "$SCRIPTS/spec-digest.py" --specs-dir "$CF/render/specs" 2>/dev/null)
check "open spec has no star" "$DG" "v1 |"
check "completed spec is starred" "$DG" "v2* |"
check "title, tags and problem statement appear" "$DG" "Demo Spec | tags: [sdd, demo] | As a dev, I want a digest"
check "one line per spec (4)" "$(echo "$DG" | wc -l | tr -d ' ')" "4"

echo ""
echo "Test: spec-categories-render.py (AC-5, AC-6, AC-13)"
R="$SCRIPTS/spec-categories-render.py"
OUTF=$(mktemp)
python3 "$R" --grouping "$CF/grouping-ok.json" --specs-dir "$CF/render/specs" --out "$OUTF" --date 2026-01-01 2>/dev/null; RC=$?
[ "$RC" -eq 0 ] && pass "valid grouping renders (exit 0)" || fail "render exit $RC"
T=$(cat "$OUTF")
check "completed spec starred in the table" "$T" "v1, v2*"
check "count column computed" "$T" "| v3, v4 | 2 |"
check "new category uses the JSON value" "$T" "| 2 |"
check "observations rendered" "$T" "- One observation."
check "scope line counts completed and open" "$T" "4 specs: 1 completed"
python3 "$SCRIPTS/spec-loop-queue.py" --check-categories --specs-dir "$CF/render/specs" --categories-file "$OUTF" --config "$CF/none.yaml" 2>/dev/null | sed -n 1p | grep -q fresh \
    && pass "rendered file passes --check-categories (fresh)" || fail "rendered file is not fresh"
# existing Value is kept over the JSON value
KEEP=$(mktemp); cp "$CF/fresh/categories.md" "$KEEP"
python3 "$R" --grouping "$CF/grouping-ok.json" --specs-dir "$CF/render/specs" --out "$KEEP" 2>/dev/null
check "existing category keeps its Value (4, not the JSON 1)" "$(grep '^| Core' "$KEEP")" "| 4 |"
# refusals write nothing
for g in missing dup; do
    NEW="$OUTF.$g"
    python3 "$R" --grouping "$CF/grouping-$g.json" --specs-dir "$CF/render/specs" --out "$NEW" >/dev/null 2>"$OUTF.err"; RC=$?
    [ "$RC" -eq 1 ] && pass "$g grouping refused (exit 1)" || fail "$g grouping exit $RC"
    [ ! -e "$NEW" ] && pass "$g grouping wrote nothing" || fail "$g grouping wrote a file"
done
python3 "$R" --grouping "$CF/grouping-missing.json" --specs-dir "$CF/render/specs" --out "$OUTF.x" >/dev/null 2>"$OUTF.err"
check "refusal names the unlisted spec" "$(cat "$OUTF.err")" "v2 is in no category"
python3 "$R" --grouping "$CF/grouping-dup.json" --specs-dir "$CF/render/specs" --out "$OUTF.y" >/dev/null 2>"$OUTF.err"
check "refusal names the double-listed spec" "$(cat "$OUTF.err")" "v2 listed twice"
python3 "$R" --grouping "$CF/nope.json" --specs-dir "$CF/render/specs" --out "$OUTF.z" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 2 ] && pass "unreadable grouping exits 2" || fail "unreadable grouping exit $RC"

echo ""
echo "Test: skill and docs describe the check and analysis step (AC-3, AC-11)"
SK="$REPO_DIR/modules/sdd/skills/sdd-spec-loop.md"
if grep -q -- "--check-categories" "$SK" 2>/dev/null; then
    check "skill runs the check" "$(cat "$SK")" "--check-categories"
    check "skill runs the analysis only on missing or stale" "$(cat "$SK")" "stale"
    check "skill preserves edited Values" "$(cat "$SK")" "keep"
    check "modules/sdd/README describes it" "$(cat "$REPO_DIR/modules/sdd/README.md")" "check-categories"
    check "skill calls the digest script" "$(cat "$SK")" "spec-digest.py"
    check "skill calls the renderer" "$(cat "$SK")" "spec-categories-render.py"
    check "aid-help describes it" "$(cat "$REPO_DIR/docs/aid-help.md")" "spec-categories.md"
else
    fail "skill does not mention --check-categories yet (Phase 2 pending)"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
