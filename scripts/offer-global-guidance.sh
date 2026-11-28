#!/bin/bash
# offer-global-guidance.sh — offer the toolkit's blockers-to-paths rule (v129) to an existing ~/.claude/CLAUDE.md.
#
# Never overwrites the file. The rule is only appended, and only when the user says yes (interactive prompt, once)
# or passes --append. Asking is recorded so repeated installs stay quiet. Idempotent: if the rule is already in
# the file nothing happens.
#
# Usage: offer-global-guidance.sh [--append]
#   (no flag)  offer once on a terminal; print a one-line hint when there is no terminal (not recorded as asked)
#   --append   append without asking (the user's explicit request)
#   --pending  exit 0 if an offer is waiting (file exists, rule missing, not yet asked), else exit 1; prints nothing
#   --decline  record that the user was asked and said no (never asks again)
#
# State and audit log live in ~/.config/aidev/, never under ~/.claude.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${GUIDANCE_TEMPLATE:-$SCRIPT_DIR/../templates/global-claude.md}"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
STATE_DIR="$HOME/.config/aidev"
ASKED_FILE="$STATE_DIR/guidance-offered"
AUDIT_FILE="$STATE_DIR/guidance-audit.log"
MARKER="follow every list of blockers"

audit() { # action outcome
    mkdir -p "$STATE_DIR"
    printf '%s actor=%s action=%s resource=%s outcome=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${USER:-unknown}" "$1" "$CLAUDE_MD" "$2" >> "$AUDIT_FILE"
}

# Fresh installs get the whole template from install.sh; nothing to offer without a file or a rule to offer.
[ -f "$CLAUDE_MD" ] || exit 0
RULE="$(grep -F "$MARKER" "$TEMPLATE" 2>/dev/null | head -1)"
[ -n "$RULE" ] || exit 0
grep -qF "$MARKER" "$CLAUDE_MD" && exit 0

append_rule() {
    {
        printf '\n## Blockers and Paths (from aidev-toolkit)\n\n%s\n' "$RULE"
    } >> "$CLAUDE_MD" && audit append ok || { audit append failed; return 1; }
    echo "  Appended the blockers-to-paths rule to $CLAUDE_MD"
}

if [ "${1:-}" = "--pending" ]; then
    [ ! -f "$ASKED_FILE" ]
    exit $?
fi

if [ "${1:-}" = "--decline" ]; then
    mkdir -p "$STATE_DIR"
    date -u +%Y-%m-%dT%H:%M:%SZ > "$ASKED_FILE"
    audit offer declined
    exit 0
fi

if [ "${1:-}" = "--append" ]; then
    append_rule
    exit $?
fi

[ -f "$ASKED_FILE" ] && exit 0

if [ ! -t 0 ]; then
    echo "  New aidev guidance available for $CLAUDE_MD (blockers-to-paths rule)."
    echo "  Add it with: $SCRIPT_DIR/offer-global-guidance.sh --append"
    exit 0
fi

echo ""
echo "aidev toolkit has a new guidance rule for $CLAUDE_MD:"
echo "  $RULE"
printf "Append it to your file? Your existing content is kept. [y/N] "
read -r ANSWER
mkdir -p "$STATE_DIR"
date -u +%Y-%m-%dT%H:%M:%SZ > "$ASKED_FILE"
case "$ANSWER" in
    y|Y|yes|YES) append_rule ;;
    *) audit offer declined; echo "  Skipped. Add later with: $SCRIPT_DIR/offer-global-guidance.sh --append" ;;
esac
