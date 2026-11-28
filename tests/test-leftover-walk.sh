#!/bin/bash
# Test: spec v121 — /sdd-code walks leftover open items one at a time (static assertions on the skill text).
# Reads the real skill file; no mocks.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SK="$REPO_DIR/modules/sdd/skills/sdd-code.md"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
has() { case "$1" in *"$2"*) return 0;; *) return 1;; esac; }
check() { # check <label> <haystack> <needle>
    if has "$2" "$3"; then pass "$1"; else fail "$1 (missing: $3)"; fi
}

[ -f "$SK" ] || { echo "skill not found: $SK"; exit 1; }
ALL="$(cat "$SK")"
# The walk section: from its heading to the end of the file
WALK="$(awk '/^## Step 3: Walk the Leftover Items/{f=1} f' "$SK")"

echo ""
echo "Test: the leftover walk exists after the summary (AC-1)"
check "Step 3 heading exists" "$ALL" "## Step 3: Walk the Leftover Items One at a Time"
check "Output Format points to the walk" "$ALL" "run Step 3 (the leftover walk)"

echo ""
echo "Test: what counts as a leftover item (AC-1, AC-5)"
check "collects skipped questions" "$WALK" "Open Questions skipped"
check "collects blocked tasks" "$WALK" "marked \`(blocked: ...)\`"
check "collects loose ends" "$WALK" "Loose ends noted while coding"

echo ""
echo "Test: one item per turn, one single-question call (AC-1)"
check "one item per turn" "$WALK" "one item per turn and one single-question \`AskUserQuestion\` call"
check "never batched" "$WALK" "Never batch items"
check "waits for the answer" "$WALK" "wait for the answer before moving on"

echo ""
echo "Test: explanation before each call (AC-2)"
check "message before the call" "$WALK" "**Before the call**"
check "says what the item is" "$WALK" "what the item is"
check "says why it came up" "$WALK" "Why it came up:"
check "says what each answer changes" "$WALK" "What each answer changes:"
check "says what happens if undecided" "$WALK" "If left undecided:"
check "labels alone are not enough" "$WALK" "Option labels and descriptions alone do not satisfy this"

echo ""
echo "Test: recommended option first (AC-3)"
check "2-4 options" "$WALK" "2-4 options"
check "recommended first and labelled" "$WALK" 'the recommended one first and labelled "(Recommended)"'
check "reason is in the message text" "$WALK" "The reason for the recommendation is in the message text"

echo ""
echo "Test: no leftovers, no prompts; opt-out flag (AC-4, AC-6)"
check "no leftover items means no extra prompt" "$WALK" "no extra prompt appears"
check "--skip-questions skips the walk" "$WALK" 'contains `--skip-questions`'

echo ""
echo "Test: answers are recorded durably, skipping never blocks (AC-5)"
check "question answers go to the spec" "$WALK" 'Resolved ({date}): {answer}'
check "blocked tasks noted in the README" "$WALK" "remove its \`(blocked: ...)\` marker in \`specs/README.md\`"
check "unanswered items stay open" "$WALK" "leave the item open"
check "never blocks on an unanswered item" "$WALK" "Never block on an unanswered item"

echo ""
echo "Test: failure paths (AP-003)"
check "AskUserQuestion unavailable falls back to the summary lists" "$WALK" "\`AskUserQuestion\` is unavailable"
check "fallback says the walk could not run" "$WALK" "the walk could not run"

echo ""
echo "Test: the pre-coding walk is unchanged (out of scope)"
check "Step 2 item 5 still walks Open Questions" "$ALL" "Walk through the spec's Open Questions, one at a time"
check "Important lists both exceptions" "$ALL" "the leftover walk (Step 3)"

echo ""
echo "Test: reusable snippet for project-local commands (docs/leftover-walk-snippet.md)"
SNIP="$(cat "$(dirname "$0")/../docs/leftover-walk-snippet.md" 2>/dev/null)"
check "snippet doc exists and names the one-item-per-turn rule" "$SNIP" "one item per turn and one single-question"
check "snippet keeps the --skip-questions switch" "$SNIP" "--skip-questions"
check "snippet keeps the recommended-first option rule" "$SNIP" "labelled \"(Recommended)\""
check "snippet has the failure paths" "$SNIP" "AskUserQuestion\` unavailable"
check "snippet records the audit of toolkit commands" "$SNIP" "Audit result for toolkit commands"
check "snippet names the project-local commands" "$SNIP" "/commit-push-x"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
