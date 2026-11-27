#!/bin/bash
#
# fix-spec-links.sh tests (spec-v122): real git fixture repo, real archive move, no mocks.
# The fixture lives in a mktemp dir under the system temp dir (left for the OS to reap).
#
set -e
PASS=0; FAIL=0
pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
S="$(cd "$(dirname "$0")/.." && pwd)/modules/sdd/scripts/fix-spec-links.sh"
WORK=$(mktemp -d)
cd "$WORK"
git init -q . && git config user.email t@t && git config user.name t
mkdir -p specs docs
echo "# a" > specs/spec-v1-alpha.md
printf '# b\nSee [alpha](spec-v1-alpha.md#why) and [self](spec-v2-beta.md).\n' > specs/spec-v2-beta.md
printf '# c\nCross [alpha](spec-v1-alpha.md) and [web](https://x.io/spec-v9-z.md)\n' > specs/spec-v3-gamma.md
cat > specs/README.md <<'R'
- **Spec**: [spec-v1-alpha.md](spec-v1-alpha.md#top)
- **Spec**: [spec-v2-beta.md](./spec-v2-beta.md "title")
- **Spec**: [spec-v3-gamma.md](spec-v3-gamma.md)
```
[fenced](spec-v1-alpha.md)
```
R
printf '[a](../specs/spec-v1-alpha.md)\n[esc](../../../etc/spec-v1-alpha.md)\n' > docs/guide.md
git add -A && git commit -qm init

echo ""; echo "fix-spec-links Tests"; echo "===================="
$S verify | grep -q "outcome=unresolved" && fail "no unresolved links before move" || pass "no unresolved links before move"

mkdir specs/completed
git mv specs/spec-v1-alpha.md specs/spec-v2-beta.md specs/completed/

$S verify >/dev/null && fail "verify detects dead links after move" || pass "verify detects dead links after move"
OUT=$($S --dry-run fix spec-v1-alpha.md spec-v2-beta.md)
echo "$OUT" | grep -q "rewritten=4.*dry_run=1" && pass "dry-run counts rewrites" || { fail "dry-run counts rewrites"; echo "$OUT"; }
grep -q '(spec-v1-alpha.md#top)' specs/README.md && pass "dry-run changes nothing" || fail "dry-run changes nothing"

$S fix specs/completed/spec-v1-alpha.md specs/completed/spec-v2-beta.md >/dev/null || true
grep -q '(completed/spec-v1-alpha.md#top)' specs/README.md && pass "README link rewritten, anchor kept" || fail "README anchor"
grep -q '(completed/spec-v2-beta.md "title")' specs/README.md && pass "./ prefix and title handled" || fail "./ prefix and title"
grep -q '\[spec-v1-alpha.md\]' specs/README.md && pass "link text preserved" || fail "link text"
grep -q '(spec-v1-alpha.md)' specs/README.md && pass "fenced block untouched" || fail "fenced block"
grep -q '(completed/spec-v1-alpha.md)' specs/spec-v3-gamma.md && pass "active spec -> archived spec rewritten" || fail "active->archived"
grep -q '(spec-v1-alpha.md#why)' specs/completed/spec-v2-beta.md && pass "archived->archived link already resolves" || fail "archived->archived"
grep -q '(../specs/completed/spec-v1-alpha.md)' docs/guide.md && pass "docs link rewritten" || fail "docs link"
grep -q 'https://x.io/spec-v9-z.md' specs/spec-v3-gamma.md && pass "external URL untouched" || fail "external URL"
grep -q '(../../../etc/spec-v1-alpha.md)' docs/guide.md && pass "root-escaping link not changed" || fail "escape guard"

RC=0; $S verify >/dev/null || RC=$?
[ "$RC" -eq 1 ] && pass "verify flags the root-escaping link (nonzero)" || fail "verify rc=$RC"
$S verify | grep -q "escapes-root" && pass "escape reported with file:line" || fail "escape report"

grep -v 'esc' docs/guide.md > docs/guide.new && mv docs/guide.new docs/guide.md
$S verify >/dev/null && pass "verify exits 0 when all resolve" || fail "verify exits 0"

BEFORE=$(cat specs/README.md specs/*.md docs/guide.md | shasum)
$S fix specs/completed/spec-v1-alpha.md specs/completed/spec-v2-beta.md | grep -q "rewritten=0" && pass "second run rewrites nothing" || fail "idempotent count"
[ "$BEFORE" = "$(cat specs/README.md specs/*.md docs/guide.md | shasum)" ] && pass "second run changes no file" || fail "idempotent bytes"

echo ""; echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
