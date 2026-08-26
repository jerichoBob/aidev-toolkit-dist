#!/bin/bash
#
# publish-dist.sh README rewrite Test Suite
#
# Regression test for the README URL rewrite in scripts/publish-dist.sh.
# Bug (recurred after spec-v92): the sed pattern matched "jerichoBob/aidev-toolkit"
# with a trailing \b, which also matches right before "-dist" — so any
# already-correct "jerichoBob/aidev-toolkit-dist" reference in the source
# README got rewritten to "jerichoBob/aidev-toolkit-dist-dist".
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLISH_SCRIPT="$REPO_DIR/scripts/publish-dist.sh"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

# Extract the exact sed command used to rewrite README.md, so this test
# fails if the command is edited without re-verifying idempotency.
SED_CMD=$(grep '^sed -E ' "$PUBLISH_SCRIPT" | sed 's/ \\$//')

echo "=== publish-dist.sh README rewrite Test Suite ==="
echo ""

if [[ -z "$SED_CMD" ]]; then
    fail "could not locate README rewrite sed command in publish-dist.sh"
else
    pass "located README rewrite sed command"
fi

FIXTURE=$(mktemp)
cat > "$FIXTURE" <<'EOF'
gh repo clone jerichoBob/aidev-toolkit-dist ~/.claude/aidev-toolkit
git clone git@github.com:jerichoBob/aidev-toolkit-dist.git ~/.claude/aidev-toolkit
See jerichoBob/aidev-toolkit for the source repo.
EOF
cleanup() { rm -f "$FIXTURE"; }
trap cleanup EXIT

OUT=$(eval "$SED_CMD \"$FIXTURE\"")

if echo "$OUT" | grep -q "dist-dist"; then
    fail "rewrite doubled an already-correct -dist suffix (dist-dist found)"
else
    pass "rewrite does not double an already-correct -dist suffix"
fi

if echo "$OUT" | grep -q "^git clone git@github.com:jerichoBob/aidev-toolkit-dist.git"; then
    pass "already-correct SSH clone URL is left as aidev-toolkit-dist"
else
    fail "SSH clone URL was mangled"
fi

if echo "$OUT" | grep -q "See jerichoBob/aidev-toolkit-dist for the source repo."; then
    pass "bare jerichoBob/aidev-toolkit reference is rewritten to aidev-toolkit-dist"
else
    fail "bare jerichoBob/aidev-toolkit reference was not rewritten"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
