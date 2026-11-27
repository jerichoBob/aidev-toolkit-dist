#!/bin/bash
#
# specs-parse.sh layer-suffix tests (spec-v118): real fixture trees, no mocks.
# Fixtures live in a mktemp dir under the system temp dir (left for the OS to reap).
#
set -e
PASS=0; FAIL=0
pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
P="$(cd "$(dirname "$0")/.." && pwd)/modules/sdd/scripts/specs-parse.sh"
has() { grep -qF -- "$2" <<<"$1"; }

W=$(mktemp -d)
mk() { mkdir -p "$1/specs"; }
fm() { printf -- '---\nversion: 68\ncreator: c@x\nowner: %s\ndeveloper: d@x\n---\n# s\n' "$2" > "$1"; }

# ---- main fixture ----
M="$W/main"; mk "$M"
fm "$M/specs/spec-v68-user-provisioning-api.md" api-owner@x
fm "$M/specs/spec-v68-user-provisioning-ui.md" ui-owner@x
fm "$M/specs/spec-v1-plain.md" p@x
fm "$M/specs/spec-v69-foo.md" p@x
fm "$M/specs/spec-v70-unlinked-api.md" p@x
fm "$M/specs/spec-v70-unlinked-ui.md" p@x
cat > "$M/specs/README.md" <<'R'
# Specs

## v1: Plain Spec

### Phase 1: One

- [x] done

## v2.1 - Decimal Spec

### Phase 1: One

- [x] done

## v68-api: User Provisioning (API)

### Phase 1: Api work

- [x] api done

## v68-ui: User Provisioning (UI)

### Phase 1: Ui work

- [ ] ui todo

## v69-experimental: Foo

### Phase 1: Foo

- [ ] foo todo

## v70-api: Linked API only

### Phase 1: X

- [x] x
R

echo ""; echo "specs-parse layer-suffix Tests"; echo "=============================="
S=$(cd "$M" && "$P" status)
has "$S" $'v68-api\tUser Provisioning (API)\t1\t1\tComplete' && pass "AC-1 status: v68-api version and exact name" || { fail "AC-1 v68-api"; echo "$S"; }
has "$S" $'v68-ui\tUser Provisioning (UI)\t0\t1\tDraft' && pass "AC-1 status: v68-ui tracked separately" || fail "AC-1 v68-ui"
has "$S" $'v1\tPlain Spec\t1\t1\tComplete' && pass "AC-2 unsuffixed v1 unchanged" || fail "AC-2 v1"
has "$S" $'v2.1\tDecimal Spec\t1\t1\tComplete' && pass "AC-2 decimal v2.1 unchanged" || fail "AC-2 v2.1"
has "$S" $'v69\texperimental: Foo\t0\t1\tDraft' && pass "AC-7 unrecognized suffix keeps legacy behavior" || { fail "AC-7"; echo "$S"; }

N=$(cd "$M" && "$P" next-task)
has "$N" "spec_version: v68-ui" && has "$N" "spec_file: specs/spec-v68-user-provisioning-ui.md" && pass "AC-3 next-task resolves the -ui sibling" || { fail "AC-3 next-task"; echo "$N"; }
NP=$(cd "$M" && "$P" next-phase)
has "$NP" "spec_version: v68-ui" && has "$NP" "spec_file: specs/spec-v68-user-provisioning-ui.md" && pass "AC-3 next-phase resolves the -ui sibling" || { fail "AC-3 next-phase"; echo "$NP"; }

# api sibling when its task is unchecked
A="$W/api"; mk "$A"; cp "$M"/specs/spec-v68-*.md "$A/specs/"
printf '## v68-api: User Provisioning (API)\n\n### Phase 1: Api work\n\n- [ ] api todo\n\n## v68-ui: User Provisioning (UI)\n\n### Phase 1: Ui work\n\n- [ ] ui todo\n' > "$A/specs/README.md"
N=$(cd "$A" && "$P" next-task)
has "$N" "spec_file: specs/spec-v68-user-provisioning-api.md" && pass "AC-3 next-task resolves the -api sibling" || { fail "AC-3 api"; echo "$N"; }

R1=$(cd "$M" && "$P" spec-roles v68-api); R2=$(cd "$M" && "$P" spec-roles v68-ui)
has "$R1" "api-owner@x" && ! has "$R1" "ui-owner@x" && pass "AC-4 spec-roles v68-api reads the api sibling" || { fail "AC-4 api"; echo "$R1"; }
has "$R2" "ui-owner@x" && ! has "$R2" "api-owner@x" && pass "AC-4 spec-roles v68-ui reads the ui sibling" || { fail "AC-4 ui"; echo "$R2"; }
mkdir -p "$M/specs/completed"; fm "$M/specs/completed/spec-v72-done-ui.md" done-owner@x
R3=$(cd "$M" && "$P" spec-roles v72-ui)
has "$R3" "done-owner@x" && pass "AC-4 spec-roles finds a suffixed spec in specs/completed" || fail "AC-4 completed"

U=$(cd "$M" && "$P" structure)
has "$U" "specs/spec-v70-unlinked-ui.md" && ! has "$U" "specs/spec-v70-unlinked-api.md" && pass "AC-5 UNLINKED_SPECS is per-suffix (ui unlinked, api linked)" || { fail "AC-5"; echo "$U"; }
! has "$U" "specs/spec-v68-user-provisioning-ui.md" && ! has "$U" "specs/spec-v68-user-provisioning-api.md" && pass "AC-5 both linked v68 siblings are not reported" || fail "AC-5 v68"

# AC-6: unaffected subcommands run and give sane output
(cd "$M" && "$P" next-version >/dev/null && "$P" spec-list >/dev/null && "$P" staleness >/dev/null) && pass "AC-6 next-version/spec-list/staleness still run" || fail "AC-6"

# ---- ambiguity ----
D="$W/dup"; mk "$D"
fm "$D/specs/spec-v71-first-api.md" a@x; fm "$D/specs/spec-v71-second-api.md" b@x
printf '## v71-api: Dup\n\n### Phase 1: X\n\n- [ ] t\n' > "$D/specs/README.md"
RC=0; OUT=$(cd "$D" && "$P" next-task 2>&1) || RC=$?
[[ $RC -ne 0 ]] && has "$OUT" "ambiguous" && has "$OUT" "spec-v71-first-api.md" && has "$OUT" "spec-v71-second-api.md" && pass "ambiguous-match error names every match" || { fail "ambiguous (rc=$RC)"; echo "$OUT"; }
RC=0; OUT=$(cd "$D" && "$P" spec-roles v71-api 2>&1) || RC=$?
[[ $RC -ne 0 ]] && has "$OUT" "ambiguous" && pass "spec-roles also errors on ambiguity" || fail "ambiguous spec-roles"

echo ""; echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
