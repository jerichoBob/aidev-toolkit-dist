#!/bin/bash
#
# close-spec-issues.sh tests (spec v140): real temporary git repos and a real bare remote, no mocks.
# The live `gh issue close` needs a sandbox repository and credentials, so it is reported BLOCKED
# unless CLOSE_SPEC_ISSUES_SANDBOX is set; it is never faked.
#
set -e
PASS=0; FAIL=0; BLOCKED=0
pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
blocked() { echo "  ⊘ BLOCKED: $1"; ((BLOCKED++)) || true; }
REPO="$(cd "$(dirname "$0")/.." && pwd)"
S="$REPO/modules/sdd/scripts/close-spec-issues.sh"
has() { grep -qF -- "$2" <<<"$1"; }

T=$(mktemp -d)
git init -q --bare "$T/origin.git"
git clone -q "$T/origin.git" "$T/work" 2>/dev/null
cd "$T/work"
git config user.email t@t && git config user.name t
git checkout -q -b main 2>/dev/null || true
mkdir specs
echo "0.1.0" > VERSION

mkspec() { # mkspec <n> <issue> <repo> [status]
  { echo "---"; echo "version: $1"; echo "status: ${4:-complete}"; [[ -n "$2" ]] && echo "github_issue: $2"; [[ -n "$3" ]] && echo "github_issue_repo: $3"; echo "---"; echo "# v$1"; } > "specs/spec-v$1-fixture.md"
}
mkspec 1 11 "o/r"; mkspec 2 12 "o/r"; mkspec 3 13 "o/r" draft; mkspec 4 "" ""; mkspec 5 "12x" "o/r"; mkspec 6 15 "not a repo"; mkspec 7 17 "o/r"
cat > specs/README.md <<'R'
# Specs

## Quick Status

| Spec | Name | Progress | Status | Owner |
| ---- | ---- | -------- | ------ | ----- |
| v1 | Eligible | 2/3 | ✅ Complete | — |
| v2 | Unchecked | 1/3 | ✅ Complete | — |
| v3 | Draft | 0/1 | ✏️ Draft | — |
| v4 | No link | 1/1 | ✅ Complete | — |
| v5 | Bad issue | 1/2 | ✅ Complete | — |
| v6 | Bad repo | 1/2 | ✅ Complete | — |
| v7 | Done | 2/2 | ✅ Complete | — |

## v1: Eligible

### Phase 1: One

- [x] build it
- [x] verify it
- [ ] Close GitHub issue #11 (gh issue close 11 --repo o/r)

## v2: Unchecked

### Phase 1: One

- [x] build it
- [ ] Manual verification of the thing
- [ ] Close GitHub issue #12 (gh issue close 12 --repo o/r)

## v3: Draft

### Phase 1: One

- [ ] Close GitHub issue #13 (gh issue close 13 --repo o/r)

## v4: No link

### Phase 1: One

- [x] build it

## v5: Bad issue

### Phase 1: One

- [x] build it
- [ ] Close GitHub issue #12x (gh issue close)

## v6: Bad repo

### Phase 1: One

- [x] build it
- [ ] Close GitHub issue #15 (gh issue close)

## v7: Done

### Phase 1: One

- [x] build it
- [x] Close GitHub issue #17 (gh issue close 17 --repo o/r)
R
git add -A && git commit -q -m fixture

echo ""; echo "close-spec-issues Tests"; echo "======================="
run() { ROOT="$T/work" AUDIT_FILE="$T/audit.log" bash "$S" "$@" 2>/dev/null || true; }

echo "Guards (committed but not pushed)"
OUT=$(run)
has "$OUT" "$(printf 'v1\to/r\t#11\tskipped:not-pushed')" && pass "committed, not pushed: stays open (not-pushed)" || { fail "not-pushed"; echo "$OUT"; }
has "$OUT" "v2	o/r	#12	skipped:unchecked-tasks" && pass "unchecked manual-verification task blocks the close" || fail "unchecked-tasks"
has "$OUT" "v3	o/r	#13	skipped:not-complete" && pass "draft spec is not closed" || fail "not-complete"
has "$OUT" "v5	o/r	#12x	skipped:bad-issue" && pass "non-numeric issue number refused" || fail "bad-issue"
has "$OUT" "v6	not a repo	#15	skipped:bad-repo" && pass "repo not of the form owner/name refused" || fail "bad-repo"
has "$OUT" "v7	o/r	#17	skipped:already-done" && pass "task already checked: nothing to do" || fail "already-done"
has "$OUT" "v4" && fail "spec without a linked issue must not be listed" || pass "spec without a linked issue is silent"

echo "Tree guards"
git push -q origin HEAD:main 2>/dev/null; git branch -q --set-upstream-to=origin/main 2>/dev/null || git push -q -u origin HEAD:main 2>/dev/null
echo "# edit" >> specs/spec-v1-fixture.md
OUT=$(run)
has "$OUT" "v1	o/r	#11	skipped:uncommitted" && pass "uncommitted change blocks the close" || { fail "uncommitted"; echo "$OUT"; }
git checkout -q -- specs/spec-v1-fixture.md
OUT=$(run)
has "$OUT" "v1	o/r	#11	eligible" && pass "clean and pushed: eligible" || { fail "eligible"; echo "$OUT"; }
has "$OUT" "count=1" && pass "list mode counts exactly the eligible spec" || fail "count"

echo "List mode is read-only and repeatable"
BEFORE=$(git status --porcelain; cat specs/README.md)
run > /dev/null; run > /dev/null
AFTER=$(git status --porcelain; cat specs/README.md)
[[ "$BEFORE" == "$AFTER" ]] && pass "list mode changes nothing, run twice" || fail "list mode wrote something"
[[ ! -e "$T/audit.log" ]] && pass "list mode writes no audit line" || fail "audit line from list mode"

echo "Apply without a reachable issue stays open"
SNAP=$(cat specs/README.md)
OUT=$(run --apply)
has "$OUT" "v1	o/r	#11	skipped:gh-unavailable" && pass "unreachable issue: stays open, reported" || { fail "gh-unavailable"; echo "$OUT"; }
[[ "$SNAP" == "$(cat specs/README.md)" ]] && pass "README untouched when the close did not happen" || fail "README changed without a close"
[[ ! -e "$T/audit.log" ]] && pass "no audit line when nothing was closed" || fail "audit line without a close"

echo "Idempotent repeat on settled state (AC-7)"
OUT1=$(run --apply | grep "v7"); OUT2=$(run --apply | grep "v7")
[[ "$OUT1" == "$OUT2" ]] && has "$OUT1" "skipped:already-done" && pass "already-done spec: same result every run" || fail "repeat run differs"
[[ "$SNAP" == "$(cat specs/README.md)" && ! -e "$T/audit.log" ]] && pass "repeat runs: no README edit, no audit line, no comment" || fail "repeat run changed state"

echo "Usage"
bash "$S" --bogus >/dev/null 2>&1 && fail "unknown flag accepted" || pass "unknown flag exits non-zero"

echo "Live close"
if [[ -n "${CLOSE_SPEC_ISSUES_SANDBOX:-}" ]]; then
  blocked "sandbox repo configured but the live-close harness is not written yet"
else
  blocked "live 'gh issue close' (close, README check-off, audit line) needs a sandbox repo and credentials: set CLOSE_SPEC_ISSUES_SANDBOX"
fi

echo ""
echo "Skill, install and docs wiring"
SK="$(cat "$REPO/modules/sdd/skills/sdd-code.md")"
has "$SK" "[--no-close]" && pass "sdd-code argument-hint lists --no-close" || fail "argument-hint"
has "$SK" "close-spec-issues.sh --apply" && pass "sdd-code step 9 runs the script" || fail "step 9 call"
has "$SK" 'unless `$ARGUMENTS` contains `--no-close`' && pass "--no-close opts out" || fail "opt-out text"
has "$SK" "do not re-derive its logic inline" && pass "skill does not re-derive the script" || fail "re-derive text"
has "$SK" "Issues closed: {N}" && pass "summary reports the result" || fail "summary line"
CP="$(cat "$REPO/skills/commit-push.md")"
has "$CP" "close-spec-issues.sh --apply" && pass "commit-push runs the script after the push" || fail "commit-push call"
has "$CP" "archive-complete-specs.sh --apply" && pass "commit-push archives in the same pass as the close" || fail "commit-push archive step"
has "$CP" "archive-complete-specs.sh*)" && pass "commit-push allows the archive script" || fail "commit-push archive allowed-tools"
has "$CP" "Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/close-spec-issues.sh*)" && pass "commit-push allows the script" || fail "commit-push allowed-tools"
IN="$(cat "$REPO/scripts/install.sh")"
has "$IN" "close-spec-issues.sh *" && pass "installer allows the script" || fail "installer permission"
has "$IN" 'chmod +x "$TOOLKIT_DIR/modules/sdd/scripts/close-spec-issues.sh"' && pass "installer makes it executable" || fail "installer chmod"
has "$(cat "$REPO/docs/aid-help.md")" "--no-close" && pass "aid-help documents --no-close" || fail "aid-help"

echo ""
echo "Results: $PASS passed, $FAIL failed, $BLOCKED blocked"
[[ $FAIL -eq 0 ]]
