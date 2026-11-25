#!/bin/bash
#
# Integration test for v133: scripts/statusline.sh must not write the git index
# (and so cannot leave a stale .git/index.lock behind). Uses a real temp git
# repo and the real script — no mocks, no stubs.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATUSLINE="${STATUSLINE_UNDER_TEST:-$REPO_DIR/scripts/statusline.sh}"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

if [ ! -f "$STATUSLINE" ]; then
    echo "BLOCKED: scripts/statusline.sh not found"
    exit 0
fi
for dep in jq git python3; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "BLOCKED: $dep not available — required for statusline no-lock tests"
        exit 0
    fi
done
if ! git --no-optional-locks version >/dev/null 2>&1; then
    echo "BLOCKED: git too old for --no-optional-locks (needs 2.15+)"
    exit 0
fi

echo ""
echo "Test: statusline.sh takes no git index lock (v133)"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FAKE_HOME="$TMP/home"
REPO="$TMP/repo"
mkdir -p "$FAKE_HOME" "$REPO"

git -C "$REPO" init -q
git -C "$REPO" config user.email test@example.com
git -C "$REPO" config user.name test
echo one > "$REPO/a.txt"
git -C "$REPO" add a.txt
git -C "$REPO" commit -q -m init

INDEX="$REPO/.git/index"
LOCK="$REPO/.git/index.lock"
INPUT_JSON=$(jq -n --arg d "$REPO" '{workspace:{current_dir:$d},context_window:{used_percentage:10}}')

index_mtime() { python3 -I -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$INDEX"; }

# Make the index stale: a content-identical rewrite changes the file's stat data,
# so a plain `git status` wants to refresh (rewrite) the index.
stale_index() {
    sleep 1.1
    touch "$REPO/a.txt"
}

run_statusline() {
    HOME="$FAKE_HOME" bash "$STATUSLINE" <<< "$INPUT_JSON" 2>&1
}

# Control: prove the fixture really is sensitive — plain `git status` rewrites the index.
stale_index
before=$(index_mtime)
git -C "$REPO" status --porcelain >/dev/null
after=$(index_mtime)
if [ "$before" != "$after" ]; then
    pass "Control: plain git status refreshes (writes) a stale index"
else
    echo "  - Control: git on this machine did not rewrite the index; mtime checks below are weaker"
fi

# AC-3/AC-4: with a stale index, repeated status-line runs leave the index untouched.
stale_index
before=$(index_mtime)
out=$(run_statusline)
for _ in 1 2 3; do run_statusline >/dev/null; done
after=$(index_mtime)
if [ "$before" = "$after" ]; then
    pass "Index mtime unchanged after repeated status-line runs on a stale index"
else
    fail "Status line wrote the git index (mtime $before -> $after)"
fi

if [ ! -e "$LOCK" ]; then
    pass "No .git/index.lock left behind"
else
    fail ".git/index.lock exists after status-line runs"
fi

if echo "$out" | grep -q "main\|master"; then
    pass "Output unchanged in kind: branch still shown"
else
    fail "Branch missing from status line output: $out"
fi

# AC-1 output parity: a modified file still shows the modified symbol.
echo two > "$REPO/a.txt"
out_mod=$(run_statusline)
if echo "$out_mod" | grep -q "✭"; then
    pass "Modified-file symbol still shown (status output parity)"
else
    fail "Modified symbol missing: $out_mod"
fi
git -C "$REPO" checkout -q -- a.txt

# AC-4: with the lock held by another writer, the status line neither fails,
# nor removes the lock, nor creates its own.
: > "$LOCK"
lock_before=$(python3 -I -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$LOCK")
if out_locked=$(run_statusline) && echo "$out_locked" | grep -q "main\|master"; then
    pass "Status line still renders while another process holds the index lock"
else
    fail "Status line failed while the index lock was held: $out_locked"
fi
if [ -e "$LOCK" ] && [ "$lock_before" = "$(python3 -I -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$LOCK")" ]; then
    pass "Held lock left exactly as it was"
else
    fail "Held lock was removed or modified"
fi
rm -f "$LOCK"

# AC-2: the update-check fetch is unchanged and carries no lock flag.
if grep -n 'fetch' "$STATUSLINE" | grep -q -- '--no-optional-locks'; then
    fail "Update-check fetch must not use --no-optional-locks"
else
    pass "Update-check fetch left unchanged"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
