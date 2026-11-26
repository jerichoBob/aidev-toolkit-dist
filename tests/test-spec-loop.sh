#!/bin/bash
#
# Integration tests for the spec loop scripts (spec v137): queue, budget meter, gate classifier.
# Runs the real scripts against fixture files — no mocks, no stubs.
#

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS="$REPO_DIR/modules/sdd/scripts"
FIX="$SCRIPT_DIR/fixtures/spec-loop"
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

echo ""
echo "Test: spec-loop-queue.py (AC-1, AC-2)"
out=$(python3 "$SCRIPTS/spec-loop-queue.py" --specs-dir "$FIX/specs" --owner me@x.org 2>/dev/null)
elig=${out%%Excluded*}
check "in-progress spec ranks first" "$(echo "$elig" | sed -n 2p)" "v2"
check "draft with fewer tasks ranks before bigger" "$(echo "$elig" | grep -n 'v5\|v9' | head -1)" "v5"
check "next task shown" "$elig" "next: b second"
check_not "complete spec not eligible" "$elig" "v1	"
check "complete excluded with reason" "$out" "v1	complete"
check "other owner excluded" "$out" "v3	owned by other@x.org"
check "incomplete dependency excluded" "$out" "v4	depends on incomplete v5"
check "paused excluded" "$out" "v6	status paused"
check "external blocker excluded" "$out" "v7	external blocker"
check "unowned excluded by default" "$out" "v8	unowned"
check "malformed row excluded, not fatal" "$out" "unreadable row"
out2=$(python3 "$SCRIPTS/spec-loop-queue.py" --specs-dir "$FIX/specs" --owner me@x.org --include-unowned 2>/dev/null)
check "unowned included when project opts in" "${out2%%Excluded*}" "v8"
json=$(python3 "$SCRIPTS/spec-loop-queue.py" --specs-dir "$FIX/specs" --owner me@x.org --json 2>/dev/null)
if echo "$json" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert [q["version"] for q in d["queue"]]==["v2","v5","v9"]'; then pass "--json output parses and ranks"; else fail "--json output"; fi
python3 "$SCRIPTS/spec-loop-queue.py" --specs-dir "$FIX/nonexistent" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then pass "missing README exits 2"; else fail "missing README exit code $rc"; fi
before=$(find "$FIX" -type f | xargs cat | shasum)
python3 "$SCRIPTS/spec-loop-queue.py" --specs-dir "$FIX/specs" --owner me@x.org >/dev/null 2>&1
after=$(find "$FIX" -type f | xargs cat | shasum)
if [ "$before" = "$after" ]; then pass "queue is read-only"; else fail "queue modified files"; fi

echo ""
echo "Test: spec-loop-queue.py priority strategies"
PF="$REPO_DIR/tests/fixtures/spec-loop-priority"
order() { # order <extra args...> -> space-separated versions
    python3 "$SCRIPTS/spec-loop-queue.py" --specs-dir "$PF/specs" --owner me@x.org --json --config "$PF/none.yaml" "$@" 2>/dev/null \
        | python3 -c 'import json,sys; print(" ".join(q["version"] for q in json.load(sys.stdin)["queue"]))'
}
check "default: in progress, then fewest left" "$(order)" "v10 v12 v11"
check "oldest: lowest version first" "$(order --priority oldest)" "v10 v11 v12"
check "newest: highest version first" "$(order --priority newest)" "v12 v11 v10"
check "fewest-gated: all-buildable spec first" "$(order --priority fewest-gated)" "v11 v10 v12"
check "roi: value per buildable task (v11 2.5 > v10 1.6 > all-gated v12 0)" "$(order --priority roi --categories-file "$PF/categories.md")" "v11 v10 v12"
check "roi score in json" "$(python3 "$SCRIPTS/spec-loop-queue.py" --specs-dir "$PF/specs" --owner me@x.org --json --config "$PF/none.yaml" --priority roi --categories-file "$PF/categories.md" 2>/dev/null)" '"roi": 2.5'
CAT="$PF/categories.md"
ordc() { order --priority roi --categories-file "$@"; }
check "roi: category value feeds spec with no value: (v11 5 > v10 1.6)" "$(ordc "$CAT")" "v11 v10 v12"
check "roi: spec value: beats its category (v10 stays 2)" "$(python3 "$SCRIPTS/spec-loop-queue.py" --specs-dir "$PF/specs" --owner me@x.org --json --config "$PF/none.yaml" --priority roi --categories-file "$CAT" 2>/dev/null | python3 -c 'import json,sys; d={q["version"]:q["value"] for q in json.load(sys.stdin)["queue"]}; print(d["v10"], d["v11"])')" "2.0 5.0"
check "roi: missing categories file falls back to 3 (v11 1.5 > v10 0.67)" "$(ordc "$PF/nope.md")" "v11 v10 v12"
check "work-order: listed specs first, rest default" "$(order --priority work-order --work-order-file "$PF/work-order.md")" "v12 v11 v10"
check "config sets the strategy" "$(order --config "$PF/config-newest.yaml")" "v12 v11 v10"
check "flag overrides config" "$(order --config "$PF/config-newest.yaml" --priority oldest)" "v10 v11 v12"
check "bad config priority falls back to default" "$(order --config "$PF/config-bogus.yaml")" "v10 v12 v11"
check "header names the strategy" "$(python3 "$SCRIPTS/spec-loop-queue.py" --specs-dir "$PF/specs" --owner me@x.org --config "$PF/none.yaml" --priority oldest 2>/dev/null | head -1)" "priority: oldest"
python3 "$SCRIPTS/spec-loop-queue.py" --specs-dir "$PF/specs" --owner me@x.org --priority nope >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then pass "unknown strategy exits 2"; else fail "unknown strategy exit code $rc"; fi
python3 "$SCRIPTS/spec-loop-queue.py" --specs-dir "$PF/specs" --owner me@x.org --priority work-order --work-order-file "$PF/missing.md" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then pass "missing work-order file exits 2"; else fail "missing work-order exit code $rc"; fi

echo ""
echo "Test: roi weighs gated tasks heavily (gated_cost)"
GF="$REPO_DIR/tests/fixtures/spec-loop-gated"
gorder() { # gorder <config> -> versions in roi order
    python3 "$SCRIPTS/spec-loop-queue.py" --specs-dir "$GF/specs" --owner me@x.org --json --priority roi --config "$1" 2>/dev/null \
        | python3 -c 'import json,sys; print(" ".join(q["version"] for q in json.load(sys.stdin)["queue"]))'
}
check "default gated_cost 2: all-buildable v21 (1.0) beats value-5 gate-heavy v20 (0.5)" "$(gorder "$GF/none.yaml")" "v21 v20"
check "gated_cost 0.25 from config reverses it (v20 1.67 > v21 1.0)" "$(gorder "$GF/config-cheap-gates.yaml")" "v20 v21"
check "negative gated_cost falls back to the default" "$(gorder "$GF/config-bad-gated-cost.yaml")" "v21 v20"
check "config exposes gated_cost default" "$(python3 "$SCRIPTS/spec-loop-gates.py" config --file "$GF/none.yaml" 2>/dev/null)" '"gated_cost": 2.0'
check "config reads gated_cost override" "$(python3 "$SCRIPTS/spec-loop-gates.py" config --file "$GF/config-cheap-gates.yaml" 2>/dev/null)" '"gated_cost": 0.25'

echo ""
echo "Test: spec-loop-budget.py (AC-5)"
B="$SCRIPTS/spec-loop-budget.py"
BF="$FIX/budget"
TMPD=$(mktemp -d)
r=$(python3 "$B" reading --transcript "$BF/transcript-a.jsonl" 2>/dev/null)
check "duplicate message ids counted once (input 30)" "$r" '"input": 30,'
check "cache reads counted separately" "$r" '"cache_read": 11000'
check "tokens_new excludes cache reads" "$r" '"tokens_new": 1330'
check "dollars estimated from price table" "$r" '"usd_estimated": 0.'
echo "$r" > "$TMPD/before.json"
d=$(python3 "$B" delta "$TMPD/before.json" --transcript "$BF/transcript-b.jsonl" 2>/dev/null)
check "delta isolates the later pass" "$d" '"tokens_new": 3030'
check "exact dollars from cost-state" "$d" '"usd_exact": 1.5'
python3 "$B" check --since "$TMPD/before.json" --transcript "$BF/transcript-b.jsonl" --budget-tokens 3000 >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 3 ]; then pass "token budget reached exits 3"; else fail "token budget exit code $rc"; fi
python3 "$B" check --since "$TMPD/before.json" --transcript "$BF/transcript-b.jsonl" --budget-tokens 99999 >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ]; then pass "under budget exits 0"; else fail "under budget exit code $rc"; fi
python3 "$B" check --since "$TMPD/before.json" --transcript "$BF/transcript-b.jsonl" --budget-usd 1.0 >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 3 ]; then pass "usd budget reached exits 3"; else fail "usd budget exit code $rc"; fi
err=$(python3 "$B" reading --transcript "$BF/transcript-malformed.jsonl" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ]; then pass "malformed line is an error, not zero (exit 2)"; else fail "malformed exit code $rc"; fi
check "error names file and line" "$err" "transcript-malformed.jsonl:5"
u=$(python3 "$B" reading --transcript "$BF/transcript-unknown-model.jsonl" 2>/dev/null)
check "unknown model gives null estimate, not 0" "$u" '"usd_estimated": null'
h=$(python3 "$B" reading --result "$BF/result.json" 2>/dev/null)
check "headless result total_cost_usd read" "$h" '"usd_exact": 0.057359'
check "headless result tokens counted" "$h" '"tokens_new": 22932'
python3 "$B" reading --transcript "$BF/does-not-exist.jsonl" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then pass "missing file exits 2"; else fail "missing file exit code $rc"; fi
echo ""
echo "Test: spec-loop-gates.py (AC-4, AC-11)"
G="$SCRIPTS/spec-loop-gates.py"
cls() { python3 "$G" classify --file "${CFG:-/nonexistent}" "$1" 2>/dev/null; }
check "no config: defaults to mine-only" "$(python3 "$G" config --file /nonexistent 2>/dev/null)" '"owner_rule": "mine"'
check "no config: commit not allowed" "$(python3 "$G" config --file /nonexistent 2>/dev/null)" '"allow_commit": false'
check "no config: max_passes 4" "$(python3 "$G" config --file /nonexistent 2>/dev/null)" '"max_passes": 4'
c=$(python3 "$G" config --file "$FIX/config-full.yaml" 2>/dev/null)
check "config section read: owner rule" "$c" '"owner_rule": "mine_or_unowned"'
check "config section read: allow_commit" "$c" '"allow_commit": true'
check "config section read: max_passes" "$c" '"max_passes": 6'
check "config section read: extra gates list" "$c" '"clinical threshold"'
c=$(python3 "$G" config --file "$FIX/config-bad.yaml" 2>/dev/null)
check "bad owner_rule falls back to mine" "$c" '"owner_rule": "mine"'
check "bad max_passes falls back to 4" "$c" '"max_passes": 4'
check "bad allow_commit falls back to false" "$c" '"allow_commit": false'
check "deploy task is gated" "$(cls 'Deploy the worker to production and verify')" "GATED"
check "dev check is a gate" "$(cls 'Dev check: run the migration on the dev environment')" "GATED"
check "outbound message is a gate" "$(cls 'Send the summary email to the team')" "GATED"
check "sign-off is a gate" "$(cls 'Confirm whether the draft reply was sent and record the response')" "GATED"
check "touching ~/.claude is a gate" "$(cls 'Copy the skill into ~/.claude/commands')" "GATED"
check "delete is a gate" "$(cls 'Delete the old fixtures')" "GATED"
check "unknown task is gated (conservative)" "$(cls 'Final pass: enforce newspaper style')" "unclassified"
check "repo-local build task is buildable" "$(cls 'Add `tests/test-x.sh` covering the parser')" "BUILDABLE"
check "docs task is buildable" "$(cls 'Document the behavior in `docs/aid-help.md`')" "BUILDABLE"
check "commit task gated by default" "$(cls 'Commit and push the change')" "commit-push"
check "commit task not gated when config allows" "$(CFG="$FIX/config-full.yaml" cls 'Commit the change')" "BUILDABLE"
check "project extra gate applies" "$(CFG="$FIX/config-full.yaml" cls 'Add a clinical threshold for glucose')" "project-gate"
check "extra gates cannot open others (deploy stays gated with allow_commit)" "$(CFG="$FIX/config-full.yaml" cls 'Deploy it')" "GATED"
RUN="$TMPD/run1"
python3 "$G" park --run-dir "$RUN" --spec v9 --task 'Deploy the worker to production' >/dev/null 2>&1
python3 "$G" park --run-dir "$RUN" --spec v2 --task 'Confirm the decision with Bob' >/dev/null 2>&1
check "parked.md has gate kind heading" "$(cat "$RUN/parked.md")" "## v9 — deploy"
check "parked.md has who decides" "$(cat "$RUN/parked.md")" "Who decides:"
check "parked.md has what each answer changes" "$(cat "$RUN/parked.md")" "What each answer changes:"
check "parked.md has recommended answer" "$(cat "$RUN/parked.md")" "Recommended:"
p=$(python3 "$G" parked --run-dir "$RUN" 2>/dev/null)
if [ "$(echo "$p" | head -1 | python3 -c 'import json,sys; print(json.load(sys.stdin)["spec"])')" = "v9" ]; then pass "parked questions read back in order"; else fail "parked order"; fi
python3 "$G" park --run-dir "$RUN" --spec v1 >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then pass "park without --task exits 2"; else fail "park missing task exit $rc"; fi

echo ""
echo "Test: arch-review fixes (stdin task text, read errors, unpriced usd budget, run id)"
Q="$SCRIPTS/spec-loop-queue.py"
# V-f2341867: task text with backticks / quotes / $() must reach the classifier verbatim, unexecuted
MARK="$TMPD/shell-expanded"
tasks=$(printf '%s\n' 'Create `touch '"$MARK"'` and $(touch '"$MARK"') in "docs/x.md"' 'Deploy it to production' | python3 "$G" classify --stdin --file /nonexistent 2>/dev/null)
check "stdin classify: first task buildable" "$(echo "$tasks" | sed -n 1p)" "BUILDABLE"
check "stdin classify: second task gated" "$(echo "$tasks" | sed -n 2p)" "GATED"
if [ ! -e "$MARK" ]; then pass "stdin task text is never shell-expanded"; else fail "task text was executed by the shell"; fi
printf '%s' 'Deploy `rm x` "now"' | python3 "$G" park --run-dir "$TMPD/run2" --spec v3 --stdin >/dev/null 2>&1
check "park --stdin keeps text verbatim" "$(cat "$TMPD/run2/parked.md")" 'Deploy `rm x` "now"'
# V-771ff80c: unreadable README is a clean error (exit 2), not a traceback
mkdir -p "$TMPD/unreadable"; echo "## v1: x" > "$TMPD/unreadable/README.md"; chmod 000 "$TMPD/unreadable/README.md"
if [ "$(id -u)" -ne 0 ]; then
    err=$(python3 "$Q" --specs-dir "$TMPD/unreadable" --owner x 2>&1 >/dev/null); rc=$?
    if [ "$rc" -eq 2 ]; then pass "unreadable README exits 2"; else fail "unreadable README exit $rc"; fi
    check_not "no traceback on unreadable README" "$err" "Traceback"
    check "unreadable README logs structured error" "$err" "step=queue outcome=error"
    chmod 644 "$TMPD/unreadable/README.md"
else
    echo "  - skipped (running as root: chmod cannot make a file unreadable)"
fi
# V-e06556b5: a dollar budget that cannot be enforced must not look like 'under budget'
python3 "$B" reading --transcript "$BF/transcript-a.jsonl" 2>/dev/null > "$TMPD/zero.json"
python3 - "$TMPD/zero.json" <<'PYEOF'
import json,sys
p=sys.argv[1]; d=json.load(open(p))
for k in d['tokens']: d['tokens'][k]=0
d['by_model']={}; d['usd_exact']=None
json.dump(d,open(p,'w'))
PYEOF
python3 "$B" check --since "$TMPD/zero.json" --transcript "$BF/transcript-unknown-model.jsonl" --budget-usd 0.01 >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then pass "unpriced model + --budget-usd exits 2"; else fail "unpriced usd budget exit $rc"; fi
python3 "$B" check --since "$TMPD/zero.json" --transcript "$BF/transcript-unknown-model.jsonl" --budget-tokens 1 >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 3 ]; then pass "token budget still enforced for unpriced model"; else fail "token budget unpriced exit $rc"; fi
# V-5b072e3f: run id on every log line
logline=$(SPEC_LOOP_RUN_ID=run-123 python3 "$B" reading --transcript "$BF/transcript-a.jsonl" 2>&1 >/dev/null)
check "budget log carries run id" "$logline" "run=run-123"
logline=$(SPEC_LOOP_RUN_ID=run-123 python3 "$Q" --specs-dir "$FIX/specs" --owner me@x.org 2>&1 >/dev/null)
check "queue log carries run id" "$logline" "run=run-123"
logline=$(SPEC_LOOP_RUN_ID=run-123 python3 "$G" park --run-dir "$TMPD/run3" --spec v1 --task 'Add x' 2>&1 >/dev/null)
check "gates log carries run id" "$logline" "run=run-123"
# V-ada9e952: owner fallback is logged
check "owner fallback is not silent" "$(grep -c "step='owner'\|'owner', 'fallback'" "$Q")" "1"
check "skill passes task text on stdin" "$(cat "$REPO_DIR/modules/sdd/skills/sdd-spec-loop.md")" "classify --stdin"

echo ""
echo "Test: /sdd-spec-loop skill wiring (Phase 4)"
SK="$REPO_DIR/modules/sdd/skills/sdd-spec-loop.md"
if [ -f "$SK" ]; then pass "skill file exists"; else fail "skill file missing"; fi
check "frontmatter name" "$(sed -n 2p "$SK")" "name: sdd-spec-loop"
check "skill documents --dry-run" "$(cat "$SK")" "--dry-run"
check "skill documents --max-passes" "$(cat "$SK")" "--max-passes"
check "skill documents budget flags" "$(cat "$SK")" "--budget-tokens"
check "skill never performs gated tasks" "$(cat "$SK")" "never performed"
check "skill stops on repeated failure" "$(cat "$SK")" "repeated-failure"
check "skill fetches and rebases before a pass" "$(cat "$SK")" "git pull --rebase"
check "skill asks parked questions one per call" "$(cat "$SK")" "one per \`AskUserQuestion\` call"
check "listed in installer SDD_SKILLS" "$(cat "$REPO_DIR/scripts/install.sh")" '"sdd-spec-loop.md"'
check "listed in uninstaller" "$(cat "$REPO_DIR/scripts/uninstall.sh")" "sdd-spec-loop.md"
check "help entry in docs/aid-help.md" "$(cat "$REPO_DIR/docs/aid-help.md")" 'is "sdd-spec-loop"'
check "every script the skill calls exists" "$(ls "$SCRIPTS")" "spec-loop-gates.py"
check "queue script exists" "$(ls "$SCRIPTS")" "spec-loop-queue.py"
check "budget script exists" "$(ls "$SCRIPTS")" "spec-loop-budget.py"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
