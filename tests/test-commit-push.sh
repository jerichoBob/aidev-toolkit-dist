#!/bin/bash
#
# aidev toolkit commit-push divergence-check skip test (spec-v108, Phase 2)
#
# Verifies the logic described in skills/commit-push.md: when the pre-pull
# check finds a clean tree and `git pull` succeeds, the subsequent
# `git fetch` + `git status -sb` divergence check is skipped. Uses a real
# local git repo with a real remote (a second local bare-ish clone) — no
# mocks, no network.
#

set -e

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

echo ""
echo "aidev toolkit commit-push divergence-skip Tests"
echo "==================================================="

# Set up a real "remote" as a plain git repo (not bare, but fine for local push/pull).
REMOTE="$WORK/remote"
mkdir -p "$REMOTE"
(cd "$REMOTE" && git init -q && git config user.email t@t.com && git config user.name T \
  && echo "hello" > file.txt && git add -A && git commit -q -m init)

CLONE="$WORK/clone"
git clone -q "$REMOTE" "$CLONE"
(cd "$CLONE" && git config user.email t@t.com && git config user.name T)

run_commit_push_pull_and_divergence_check() {
    # Mirrors skills/commit-push.md step 1: pre-pull check, then conditional
    # divergence check.
    local pull_ran=0 pull_ok=0 divergence_ran=0

    if git diff --quiet && git diff --cached --quiet; then
        if git pull -q; then
            pull_ran=1
            pull_ok=1
        else
            pull_ran=1
            pull_ok=0
        fi
    else
        pull_ran=0
    fi

    if [ "$pull_ran" -eq 1 ] && [ "$pull_ok" -eq 1 ]; then
        divergence_ran=0
    else
        git fetch origin -q 2>/dev/null || true
        git status -sb >/dev/null 2>&1 || true
        divergence_ran=1
    fi

    echo "$pull_ran $pull_ok $divergence_ran"
}

echo ""
echo "Test: clean tree + successful pull → divergence check is skipped..."
result=$(cd "$CLONE" && run_commit_push_pull_and_divergence_check)
read -r pull_ran pull_ok divergence_ran <<< "$result"

if [ "$pull_ran" -eq 1 ] && [ "$pull_ok" -eq 1 ]; then
    pass "pull ran and succeeded on clean tree"
else
    fail "expected pull to run and succeed: $result"
fi

if [ "$divergence_ran" -eq 0 ]; then
    pass "divergence check correctly skipped after successful pull"
else
    fail "divergence check should have been skipped: $result"
fi

echo ""
echo "Test: dirty tree → pull skipped, divergence check still runs..."
echo "local edit" >> "$CLONE/file.txt"
result=$(cd "$CLONE" && run_commit_push_pull_and_divergence_check)
read -r pull_ran pull_ok divergence_ran <<< "$result"

if [ "$pull_ran" -eq 0 ]; then
    pass "pull correctly skipped on dirty tree"
else
    fail "pull should have been skipped on dirty tree: $result"
fi

if [ "$divergence_ran" -eq 1 ]; then
    pass "divergence check correctly still runs when pull was skipped"
else
    fail "divergence check should run when pull was skipped: $result"
fi

echo ""
echo "==================================================="
printf "Results: %d passed, %d failed\n" "$PASS" "$FAIL"
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-commit-push PASSED"
    exit 0
else
    echo "✗ test-commit-push FAILED"
    exit 1
fi
