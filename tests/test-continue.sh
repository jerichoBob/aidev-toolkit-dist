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
echo "Test: skill text — framing, plan gate before execution, AskUserQuestion allowed, path validation unchanged (spec v124)..."

CONT_SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/skills/continue.md"
CONT_TEXT="$(cat "$CONT_SKILL")"
has_text() { case "$CONT_TEXT" in *"$1"*) return 0;; *) return 1;; esac; }
line_of() { grep -n -- "$1" "$CONT_SKILL" | head -1 | cut -d: -f1; }

if awk '/^allowed-tools:/ && /AskUserQuestion/ {f=1} END{exit !f}' "$CONT_SKILL"; then pass "allowed-tools includes AskUserQuestion"; else fail "allowed-tools is missing AskUserQuestion"; fi
if has_text "sanctioned continuation" && has_text "authoritative record"; then pass "framing names the session a sanctioned continuation with the handoff as authoritative record"; else fail "framing statement missing"; fi
if has_text "names the file by its path" || has_text "Name the file by its path"; then pass "framing names the handoff file by path"; else fail "framing does not name the file"; fi
PLAN=$(line_of "### Step 3: Plan"); GATE=$(line_of "### Step 4: Confirm gate"); EXEC=$(line_of "### Step 5: Execute")
if [ -n "$PLAN" ] && [ -n "$GATE" ] && [ -n "$EXEC" ] && [ "$PLAN" -lt "$GATE" ] && [ "$GATE" -lt "$EXEC" ]; then pass "order is Plan, Confirm gate, Execute"; else fail "steps not ordered Plan < Confirm gate < Execute (plan=$PLAN gate=$GATE exec=$EXEC)"; fi
if has_text "Start no work until the answer arrives"; then pass "no work starts before the answer"; else fail "gate does not forbid work before the answer"; fi
if has_text "Never execute a revised plan that has not been confirmed"; then pass "revised plan is reconfirmed before execution"; else fail "revise-and-reconfirm rule missing"; fi
if has_text "Cancel, or no answer" && has_text "execute nothing"; then pass "cancel or no answer executes nothing"; else fail "cancel/no-answer path missing"; fi
if has_text "Settled decisions" && has_text "Do not re-litigate"; then pass "settled decisions still treated as given"; else fail "settled-decisions rule missing"; fi
if has_text "**Path validation (required before reading any user-supplied argument):**" && has_text "resolve the argument only against filenames actually present"; then pass "path validation text unchanged"; else fail "path validation text changed"; fi
if has_text "use \`AskUserQuestion\` to have the user pick"; then pass "multiple-candidates picker unchanged"; else fail "candidate picker text changed"; fi

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
