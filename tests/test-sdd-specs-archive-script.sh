#!/bin/bash
#
# archive-complete-specs.sh tests (spec-v138): real temporary git repo, no mocks.
# The fixture lives in a mktemp dir under the system temp dir (left for the OS to reap).
#
set -e
PASS=0; FAIL=0
pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
S="$(cd "$(dirname "$0")/.." && pwd)/modules/sdd/scripts/archive-complete-specs.sh"
has() { grep -qF -- "$2" <<<"$1"; }

T=$(mktemp -d)
cd "$T"
git init -q . && git config user.email t@t && git config user.name t
mkdir specs docs
cat > specs/README.md <<'R'
# Specs

## Quick Status

| Version | Name | Progress | Status |
| ------- | ---- | -------- | ------ |
| v1 | Done Spec | 1/1 | ✅ Complete |
| v2 | Open Spec | 0/1 | ✏️ Draft |
| v3.5 | Done Dotted | 1/1 | ✅ Complete |
| v68-api | Provisioning API | 1/1 | ✅ Complete |
| v68-ui | Provisioning UI | 0/1 | ✏️ Draft |

## v1: Done Spec

### Phase 1: One

- [x] done

## v2: Open Spec

### Phase 1: One

- [ ] todo

## v3.5: Done Dotted

### Phase 1: One

- [x] done

## v68-api: Provisioning API

### Phase 1: Api

- [x] done

## v68-ui: Provisioning UI

### Phase 1: Ui

- [ ] todo

See [v1](spec-v1-done.md), [v2](spec-v2-open.md) and [dotted](spec-v3.5-dotted.md#top).
R
for f in spec-v1-done spec-v2-open spec-v3.5-dotted spec-v68-prov-api spec-v68-prov-ui spec-v4-no-row; do echo "# $f" > "specs/$f.md"; done
printf '# Root\n\nSee [done](specs/spec-v1-done.md).\n' > README.md
printf 'Doc [x](../specs/spec-v3.5-dotted.md)\n' > docs/guide.md
git add -A && git commit -q -m fixture

echo ""; echo "archive-complete-specs Tests"; echo "============================"
BEFORE=$(git status --porcelain)
OUT=$(ROOT="$T" bash "$S")
has "$OUT" "count=3" && pass "list: Complete specs counted (v1, v3.5, v68-api)" || { fail "list count"; echo "$OUT"; }
has "$OUT" "specs/spec-v1-done.md" && pass "list: v1 present" || fail "list v1"
has "$OUT" "specs/spec-v3.5-dotted.md" && pass "list: dotted version v3.5 matched (AC-3)" || fail "list dotted"
has "$OUT" "specs/spec-v68-prov-api.md" && ! has "$OUT" "spec-v68-prov-ui.md" && pass "list: suffixed sibling matched on its own suffix" || fail "list suffix"
! has "$OUT" "spec-v2-open.md" && pass "list: Draft spec not listed" || fail "list draft"
! has "$OUT" "spec-v4-no-row.md" && pass "list: spec with no README section never listed (AC-3)" || fail "list no-row"
[ "$BEFORE" = "$(git status --porcelain)" ] && [ -f specs/spec-v1-done.md ] && pass "list mode is read-only (AC-1)" || fail "list read-only"
[ ! -d specs/completed ] && pass "list mode creates no directory" || fail "list mkdir"

(cd specs && bash "$S" | grep -q "count=3") && pass "root = git root of the cwd, not the script dir (AC-5)" || fail "git-root resolution"

RC=0; bash "$S" --bogus >/dev/null 2>&1 || RC=$?
[ "$RC" -eq 2 ] && pass "unknown argument exits 2" || fail "bad arg rc=$RC"

ROOT="$T" bash "$S" --apply > apply.out 2>&1 && pass "--apply exits 0 when links all resolve (AC-2)" || { fail "--apply rc"; cat apply.out; }
[ -f specs/completed/spec-v1-done.md ] && [ -f specs/completed/spec-v3.5-dotted.md ] && [ -f specs/completed/spec-v68-prov-api.md ] && pass "--apply moved the 3 Complete specs" || fail "apply moved"
[ -f specs/spec-v2-open.md ] && [ -f specs/spec-v68-prov-ui.md ] && [ -f specs/spec-v4-no-row.md ] && pass "--apply left Draft and no-row specs" || fail "apply left"
grep -q "(specs/completed/spec-v1-done.md)" README.md && pass "root README link rewritten" || fail "root link"
grep -q "(completed/spec-v1-done.md)" specs/README.md && grep -q "(completed/spec-v3.5-dotted.md#top)" specs/README.md && pass "specs/README links rewritten, anchor kept" || fail "specs link"
grep -q "(../specs/completed/spec-v3.5-dotted.md)" docs/guide.md && pass "docs link rewritten" || fail "docs link"
grep -q "(spec-v2-open.md)" specs/README.md && pass "link to unmoved spec untouched" || fail "unmoved link"

OUT=$(ROOT="$T" bash "$S")
has "$OUT" "count=0" && pass "second run reports count=0" || { fail "second run"; echo "$OUT"; }

# non-zero exit when a spec link cannot be resolved even after the rewrite (AC-2)
U=$(mktemp -d); cd "$U"; git init -q . && git config user.email t@t && git config user.name t
mkdir specs
printf '## v1: Done\n\n### P\n\n- [x] a\n\nSee [gone](spec-v77-missing.md).\n' > specs/README.md
echo "# a" > specs/spec-v1-done.md
git add -A && git commit -q -m f
RC=0; ROOT="$U" bash "$S" --apply > "$U/out" 2>&1 || RC=$?
[ "$RC" -eq 1 ] && pass "--apply exits non-zero when a spec link stays unresolved" || { fail "unresolved rc=$RC"; cat "$U/out"; }
[ -f specs/completed/spec-v1-done.md ] && pass "files were still moved before verify failed" || fail "moved before verify"
grep -q "outcome=unresolved" "$U/out" && grep -q "spec-v77-missing.md" "$U/out" && pass "unresolved link reported with file:line" || fail "unresolved report"

echo ""; echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
