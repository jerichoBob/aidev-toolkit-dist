#!/bin/bash
# Test: /sdd-code archives a spec automatically once it is complete (static assertions on the skill text), and the script it
# calls is the real archive script. No mocks.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SK="$REPO_DIR/modules/sdd/skills/sdd-code.md"
PASS=0
FAIL=0
pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
has() { case "$1" in *"$2"*) return 0;; *) return 1;; esac; }
check() { if has "$2" "$3"; then pass "$1"; else fail "$1 (missing: $3)"; fi; }

ALL="$(cat "$SK")"
echo ""
echo "Test: /sdd-code archives a completed spec (auto-archive)"
check "argument-hint lists --no-archive" "$ALL" "[--no-archive]"
check "step runs the archive script with --apply" "$ALL" "archive-complete-specs.sh --apply"
check "only when complete and tests passed" "$ALL" "only when the spec is now complete **and** its tests passed"
check "no confirmation prompt" "$ALL" "Do not ask for confirmation"
check "does not re-derive the script's logic" "$ALL" "do not re-derive its logic inline"
check "non-zero exit lists unresolved links and does not claim success" "$ALL" "do not claim the archive succeeded"
check "--no-archive opts out" "$ALL" 'unless `$ARGUMENTS` contains `--no-archive`'
check "summary reports the archive result" "$ALL" "Archived: {N} specs to specs/completed/"
LINE_TESTS=$(grep -n "Run any relevant tests if they exist" "$SK" | head -1 | cut -d: -f1)
LINE_ARCH=$(grep -n "Archive (automatic)" "$SK" | head -1 | cut -d: -f1)
LINE_BUMP=$(grep -n "Bump the version (patch for fixes" "$SK" | head -1 | cut -d: -f1)
if [ -n "$LINE_TESTS" ] && [ -n "$LINE_ARCH" ] && [ -n "$LINE_BUMP" ] && [ "$LINE_TESTS" -lt "$LINE_ARCH" ] && [ "$LINE_ARCH" -lt "$LINE_BUMP" ]; then
    pass "archive comes after the tests and before the version bump"
else
    fail "archive step is not between tests and version bump (tests=$LINE_TESTS archive=$LINE_ARCH bump=$LINE_BUMP)"
fi
[ -x "$REPO_DIR/modules/sdd/scripts/archive-complete-specs.sh" ] && pass "the archive script exists and is executable" || fail "archive script missing or not executable"
check "installer allows the script (no prompt on a run)" "$(cat "$REPO_DIR/scripts/install.sh")" "archive-complete-specs.sh *"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
