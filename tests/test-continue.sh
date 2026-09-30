#!/bin/bash
#
# aidev toolkit test-continue.sh Test Suite
#
# /continue is a Claude-driven skill (skills/continue.md), not a standalone
# script, so there is no binary to invoke directly. These tests exercise the
# deterministic file-resolution logic the skill instructs Claude to use:
# most-recent-file selection, project->global fallback, the no-handoffs case,
# explicit filename/partial-match resolution, and path-traversal rejection.
#

set -e

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

TEST_HOME=$(mktemp -d)
cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

# Mirrors skills/continue.md Step 1: most recent in project dir, else global fallback.
resolve_most_recent() {
    local project_dir="$1" global_dir="$2" result
    result=$(ls -t "$project_dir"/*.md 2>/dev/null | head -1)
    if [ -n "$result" ]; then
        echo "$result"
        return 0
    fi
    ls -t "$global_dir"/*.md 2>/dev/null | head -1
}

# Mirrors skills/continue.md path validation: match the argument only against
# filenames actually present in the two allowed directories — never
# interpolate it directly into a path.
resolve_explicit_arg() {
    local project_dir="$1" global_dir="$2" arg="$3"
    local candidates match
    candidates=$( { ls "$project_dir" 2>/dev/null; ls "$global_dir" 2>/dev/null; } )
    match=$(echo "$candidates" | grep -F "$arg" | head -1)
    if [ -z "$match" ]; then
        return 1
    fi
    if [ -f "$project_dir/$match" ]; then
        echo "$project_dir/$match"
    else
        echo "$global_dir/$match"
    fi
}

echo ""
echo "aidev toolkit test-continue.sh Tests"
echo "====================================="

# ─── Test 1: Most-recent resolution in project directory ──────────────────

echo ""
echo "Test: resolves most recently modified file in .claude/handoffs/..."

PROJECT_DIR="$TEST_HOME/proj/.claude/handoffs"
GLOBAL_DIR="$TEST_HOME/home/.claude/handoffs"
mkdir -p "$PROJECT_DIR" "$GLOBAL_DIR"

echo "older" > "$PROJECT_DIR/handoff-2026-01-01-000000.md"
sleep 1
echo "newer" > "$PROJECT_DIR/handoff-2026-01-02-000000.md"

result=$(resolve_most_recent "$PROJECT_DIR" "$GLOBAL_DIR")
if [ "$result" = "$PROJECT_DIR/handoff-2026-01-02-000000.md" ]; then
    pass "picks the most recently modified project handoff file"
else
    fail "expected newest project file, got: $result"
fi

# ─── Test 2: Fallback to global directory when project dir is empty ───────

echo ""
echo "Test: falls back to ~/.claude/handoffs/ when project dir has no files..."

EMPTY_PROJECT_DIR="$TEST_HOME/proj2/.claude/handoffs"
mkdir -p "$EMPTY_PROJECT_DIR"
echo "global handoff" > "$GLOBAL_DIR/handoff-2026-02-01-000000.md"

result=$(resolve_most_recent "$EMPTY_PROJECT_DIR" "$GLOBAL_DIR")
if [ "$result" = "$GLOBAL_DIR/handoff-2026-02-01-000000.md" ]; then
    pass "falls back to global handoffs dir when project dir is empty"
else
    fail "expected global fallback file, got: $result"
fi

# ─── Test 3: Nothing to continue from ──────────────────────────────────────

echo ""
echo "Test: reports nothing to continue from when neither location has files..."

EMPTY_PROJECT2="$TEST_HOME/proj3/.claude/handoffs"
EMPTY_GLOBAL="$TEST_HOME/home3/.claude/handoffs"
mkdir -p "$EMPTY_PROJECT2" "$EMPTY_GLOBAL"

set +e
result=$(resolve_most_recent "$EMPTY_PROJECT2" "$EMPTY_GLOBAL")
set -e
if [ -z "$result" ]; then
    pass "resolution yields nothing when both directories are empty"
else
    fail "expected empty result, got: $result"
fi

# ─── Test 4: Explicit filename / partial-match argument ────────────────────

echo ""
echo "Test: resolves an explicit filename/partial-match argument..."

result=$(resolve_explicit_arg "$PROJECT_DIR" "$GLOBAL_DIR" "2026-01-01")
if [ "$result" = "$PROJECT_DIR/handoff-2026-01-01-000000.md" ]; then
    pass "resolves partial-match argument to the correct file"
else
    fail "expected partial-match resolution, got: $result"
fi

# ─── Test 5: Path-traversal argument is rejected ───────────────────────────

echo ""
echo "Test: rejects a path-traversal argument..."

set +e
result=$(resolve_explicit_arg "$PROJECT_DIR" "$GLOBAL_DIR" "../../etc/passwd")
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ] && [ -z "$result" ]; then
    pass "path-traversal argument resolves to nothing (no match, no escape)"
else
    fail "path-traversal argument should be rejected, got: $result"
fi

echo ""
echo "====================================="
printf "Results: %d passed, %d failed\n" "$PASS" "$FAIL"
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-continue PASSED"
    exit 0
else
    echo "✗ test-continue FAILED"
    exit 1
fi
