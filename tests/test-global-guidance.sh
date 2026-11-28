#!/bin/bash
# Test: v129 global guidance delivery. Real script, temp HOME, no mocks.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OFFER="$REPO_DIR/scripts/offer-global-guidance.sh"
TEMPLATE="$REPO_DIR/templates/global-claude.md"
MARKER="follow every list of blockers"
PASS=0
FAIL=0
pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
count() { grep -cF "$MARKER" "$1" 2>/dev/null || true; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo ""
echo "Test: global guidance (v129)"

# Template carries the rule, short enough to stay a guideline (AC-1, AC-6)
if [ "$(count "$TEMPLATE")" = "1" ]; then pass "template contains the rule once"; else fail "template rule count"; fi
LEN=$(grep -F "$MARKER" "$TEMPLATE" | wc -l | tr -d ' ')
[ "$LEN" -le 5 ] && pass "rule is at most five lines" || fail "rule too long"
grep -F "$MARKER" "$TEMPLATE" | grep -q "do not invent one" && pass "rule says not to invent paths" || fail "invent clause missing"

# Existing file with user edits, no terminal: hint only, file untouched
export HOME="$TMP/h1"; mkdir -p "$HOME/.claude"
printf '# Mine\n\nuser edit line\n' > "$HOME/.claude/CLAUDE.md"
cp "$HOME/.claude/CLAUDE.md" "$TMP/before1"
OUT="$("$OFFER" < /dev/null)"
cmp -s "$TMP/before1" "$HOME/.claude/CLAUDE.md" && pass "no terminal: file unchanged" || fail "file changed without consent"
case "$OUT" in *"--append"*) pass "no terminal: prints how to add it" ;; *) fail "no hint printed" ;; esac
[ ! -f "$HOME/.config/aidev/guidance-offered" ] && pass "no terminal: not recorded as asked" || fail "recorded as asked"

# --append keeps user content, adds the rule once, logs an audit line
"$OFFER" --append > /dev/null
grep -q "user edit line" "$HOME/.claude/CLAUDE.md" && pass "--append preserves user content" || fail "user content lost"
[ "$(count "$HOME/.claude/CLAUDE.md")" = "1" ] && pass "--append adds the rule once" || fail "rule count after append"
grep -q "action=append.*outcome=ok" "$HOME/.config/aidev/guidance-audit.log" && pass "audit line written" || fail "no audit line"

# Repeat runs are idempotent
"$OFFER" --append > /dev/null; "$OFFER" < /dev/null > /dev/null
[ "$(count "$HOME/.claude/CLAUDE.md")" = "1" ] && pass "repeat runs keep one copy" || fail "rule duplicated"

# --pending / --decline drive the /aid-update question
export HOME="$TMP/h3"; mkdir -p "$HOME/.claude"; printf 'x\n' > "$HOME/.claude/CLAUDE.md"
"$OFFER" --pending && pass "--pending: offer waiting" || fail "--pending should exit 0"
"$OFFER" --decline > /dev/null
"$OFFER" --pending && fail "--pending after decline" || pass "--pending: quiet after decline"
[ "$(count "$HOME/.claude/CLAUDE.md")" = "0" ] && pass "--decline leaves the file alone" || fail "decline changed file"
grep -q "action=offer.*outcome=declined" "$HOME/.config/aidev/guidance-audit.log" && pass "decline audited" || fail "decline not audited"
"$OFFER" --pending && fail "--pending: already asked must not be pending" || pass "--pending: exit 1 once asked"
export HOME="$TMP/h4"; mkdir -p "$HOME/.claude"
"$OFFER" --pending && fail "--pending: no CLAUDE.md must not be pending" || pass "--pending: exit 1 with no CLAUDE.md"
export HOME="$TMP/h3"
SK="$REPO_DIR/skills/aid-update.md"
grep -q "offer-global-guidance.sh --pending" "$SK" && grep -q "AskUserQuestion" "$SK" && pass "aid-update skill asks via AskUserQuestion" || fail "skill missing the question"

# Missing file: nothing created (fresh installs use the template copy in install.sh)
export HOME="$TMP/h2"; mkdir -p "$HOME/.claude"
"$OFFER" --append > /dev/null
[ ! -f "$HOME/.claude/CLAUDE.md" ] && pass "no CLAUDE.md: nothing created" || fail "created a file"

# Fresh install path: install.sh copies the template, which holds the rule (AC-4)
grep -q 'cp "$TOOLKIT_DIR/templates/global-claude.md"' "$REPO_DIR/scripts/install.sh" && pass "install.sh copies the template on fresh install" || fail "template copy missing"
grep -q "offer-global-guidance.sh" "$REPO_DIR/scripts/install.sh" && pass "install.sh calls the offer for existing files" || fail "install.sh does not call the offer"

echo ""
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
