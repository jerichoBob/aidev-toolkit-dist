#!/bin/bash
#
# Tests for scripts/aid-changelog.sh and its use in skills/aid-update.md
# Uses a real fixture README — no mocks.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_DIR/scripts/aid-changelog.sh"
SKILL="$REPO_DIR/skills/aid-update.md"
PASS=0
FAIL=0

check() {
  if eval "$1"; then echo "  ✓ $2"; ((PASS++)) || true; else echo "  ✗ $2"; ((FAIL++)) || true; fi
}

FIX=$(mktemp -d)
trap 'rm -rf "$FIX"' EXIT
cat > "$FIX/README.md" <<'MD'
# Fixture

## Version

0.3.0

### Release Notes

#### v0.3.0 (2026-03-03) — author: a@example.com

- feat: Add widget support [`aaa1111`]
- chore: bump version to 0.3.0 [`aaa2222`]

#### v0.2.1 (2026-02-02)

- fix: Handle empty input [`bbb1111`]
- chore: publish v0.2.1 [`bbb2222`]

#### v0.2.0 (2026-02-01)

- feat: Older feature [`ccc1111`]

#### v0.1.9 (2026-01-01)

- fix: Ancient fix [`ddd1111`]

---

## Other Section

- feat: not a release note
MD

echo "aid-changelog Tests"
echo "==================="

OUT=$("$SCRIPT" 0.2.0 "$FIX/README.md")
check 'echo "$OUT" | grep -q "^2026-03-03  v0.3.0"' "newest release header is '<date>  <version>'"
check 'echo "$OUT" | grep -q "^2026-02-02  v0.2.1"' "intermediate release included"
check 'echo "$OUT" | grep -q "feat: Add widget support"' "substantive change shown"
check '! echo "$OUT" | grep -q "v0.2.0"' "old version itself excluded"
check '! echo "$OUT" | grep -q "Ancient fix"' "older releases excluded"
check '! echo "$OUT" | grep -q "bump version"' "version-bump bookkeeping dropped"
check '! echo "$OUT" | grep -q "publish v"' "publish bookkeeping dropped"
check '! echo "$OUT" | grep -q "aaa1111"' "commit hashes stripped"
check '! echo "$OUT" | grep -q "not a release note"' "content after release notes ignored"

OUT=$("$SCRIPT" 0.3.0 "$FIX/README.md")
check '[ -z "$OUT" ]' "already up to date prints nothing"

OUT=$("$SCRIPT" 0.1.0 "$FIX/README.md" 2)
check 'echo "$OUT" | grep -q "2 older release\|1 older release"' "max_versions cap reports hidden releases"

OUT=$("$SCRIPT" 0.9.0 "$FIX/README.md")
check '[ -z "$OUT" ]' "numeric (not lexical) version compare: 0.3.0 < 0.9.0"

"$SCRIPT" >/dev/null 2>&1
check '[ $? -eq 2 ]' "missing argument exits 2"

echo "Skill wiring"
check 'grep -q "aid-changelog.sh" "$SKILL"' "aid-update skill calls aid-changelog.sh"
check 'grep -q "aid-changelog.sh\*" "$SKILL"' "script is in allowed-tools"
check '! grep -q "log --oneline --invert-grep" "$SKILL"' "old git-log recent-changes recipe removed"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
