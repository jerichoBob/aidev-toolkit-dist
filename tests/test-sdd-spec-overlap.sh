#!/bin/bash
#
# Integration tests for `specs-parse.sh requirements` (spec v128, AC-1, AC-7, AC-8) and the /sdd-spec overlap step.
# Runs the real script against fixture project trees — no mocks, no stubs, no temp files.
#

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PARSE="$REPO_DIR/modules/sdd/scripts/specs-parse.sh"
SKILL="$REPO_DIR/modules/sdd/skills/sdd-spec.md"
FIX="$SCRIPT_DIR/fixtures/spec-overlap"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
has() { case "$1" in *"$2"*) return 0;; *) return 1;; esac; }
check() { if has "$2" "$3"; then pass "$1"; else fail "$1 (missing: $3)"; fi; }
check_not() { if has "$2" "$3"; then fail "$1 (unexpected: $3)"; else pass "$1"; fi; }
run() { # run <fixture>: sets out (stdout), ERR (stderr), RC (exit code of the stdout run)
    out=$(cd "$FIX/$1" && "$PARSE" requirements 2>/dev/null); RC=$?
    ERR=$(cd "$FIX/$1" && "$PARSE" requirements 2>&1 >/dev/null)
}

echo ""
echo "Test: requirements index with specs/completed/"
run with-completed
if [ "$RC" -eq 0 ]; then pass "exits 0"; else fail "exit code $RC"; fi
check "header present" "$out" "REQUIREMENTS:"
check "open spec indexed with name and status" "$out" $'SPEC\tv1\tcsv-export\tin-progress\topen\tspecs/spec-v1-export.md'
check "completed spec indexed and marked completed" "$out" $'SPEC\tv2\toauth-login\tcomplete\tcompleted\tspecs/completed/spec-v2-auth.md'
check "decimal version indexed, quotes stripped from name" "$out" $'SPEC\tv3.1\texport-fix\tdraft\topen'
check "acceptance criterion emitted" "$out" $'AC\tv1\t- AC-1: Given a result set'
check "user story emitted" "$out" $'US\tv1\t- **US-1**: As an analyst'
check "numbered criteria from a completed spec emitted" "$out" $'AC\tv2\t1. Users sign in with GitHub OAuth only.'
check_not "inline frontmatter comment stripped from status" "$out" "settled"
check_not "lines outside criteria sections are not indexed (AC-8)" "$out" "AC-99"
order=$(echo "$out" | grep '^SPEC' | cut -f2 | tr '\n' ' ')
if [ "$order" = "v1 v2 v3.1 " ]; then pass "specs listed in version order across both directories"; else fail "order was: $order"; fi
if [ -z "$ERR" ]; then pass "no stderr output"; else fail "stderr: $ERR"; fi

echo ""
echo "Test: missing specs/completed/ (AC-7)"
run no-completed
if [ "$RC" -eq 0 ]; then pass "exits 0 without completed/"; else fail "exit code $RC"; fi
check "open spec still indexed" "$out" $'SPEC\tv1\tsolo\tdraft\topen'
check "criterion still emitted" "$out" "AC-1: Only spec in the project."
if [ -z "$ERR" ]; then pass "no stderr output"; else fail "stderr: $ERR"; fi

echo ""
echo "Test: specs with no criteria section"
run no-criteria
if [ "$RC" -eq 0 ]; then pass "exits 0"; else fail "exit code $RC"; fi
check "spec without criteria yields its SPEC line" "$out" $'SPEC\tv1\tbare\tdraft\topen'
if [ "$(echo "$out" | grep -c $'^\\(AC\\|US\\)\tv1\t')" -eq 0 ]; then pass "no AC/US lines invented for it"; else fail "AC/US lines emitted for criteria-free spec"; fi
check "spec with no frontmatter still indexed with placeholders" "$out" $'SPEC\tv2\t-\t-\topen'
check "its criteria still emitted" "$out" "AC-1: A spec file with no frontmatter still indexes."
if [ -z "$ERR" ]; then pass "no stderr output"; else fail "stderr: $ERR"; fi

echo ""
echo "Test: project with no specs/ directory"
run empty
if [ "$RC" -eq 0 ]; then pass "exits 0"; else fail "exit code $RC"; fi
check "prints the header" "$out" "REQUIREMENTS:"
if [ "$(echo "$out" | grep -c '^SPEC')" -eq 0 ]; then pass "no specs emitted"; else fail "unexpected specs emitted"; fi

echo ""
echo "Test: /sdd-spec skill wiring (Phase 2)"
skill=$(cat "$SKILL")
check "skill has the overlap step" "$skill" "Check the draft for overlap and contradiction"
check "skill calls the requirements subcommand" "$skill" "specs-parse.sh requirements"
check "skill covers completed specs" "$skill" "specs/completed/"
check "one-line no-overlap result" "$skill" "no overlap or contradiction found"
step_line=$(grep -n 'Check the draft for overlap' "$SKILL" | head -1 | cut -d: -f1)
write_line=$(grep -n '^1\. \*\*Write the file\*\*' "$SKILL" | head -1 | cut -d: -f1)
if [ -n "$step_line" ] && [ -n "$write_line" ] && [ "$step_line" -lt "$write_line" ]; then pass "step comes before the file is written"; else fail "step ($step_line) is not before 'Write the file' ($write_line)"; fi
usage=$("$PARSE" bogus 2>&1 || true)
check "usage lists the new subcommand" "$usage" "requirements"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
