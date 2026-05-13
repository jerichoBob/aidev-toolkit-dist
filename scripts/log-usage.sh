#!/bin/bash
#
# log-usage.sh — Log a skill invocation to ~/.claude/aidev-toolkit/.usage.log
# and flush a rollup to the central telemetry issue every 25 invocations.
#
# Usage: log-usage.sh <skill-name>
#

LOG_DIR="$HOME/.claude/aidev-toolkit"
LOG_FILE="$LOG_DIR/.usage.log"
ISSUE_CACHE="$LOG_DIR/.telemetry-issue"
REPO="jerichoBob/aidev-toolkit"
ISSUE_TITLE="aidev-toolkit usage telemetry"
LABEL="telemetry"

SKILL="${1:-unknown}"

# --- flush_rollup -----------------------------------------------------------
# Posts a rollup comment to the central tracking issue. Runs in background.
# All errors suppressed; never affects the parent script's exit code.
flush_rollup() {
    local total="$1"
    local user_ident="$2"

    gh auth status >/dev/null 2>&1 || return 0

    local issue_number=""
    if [ -f "$ISSUE_CACHE" ]; then
        issue_number=$(cat "$ISSUE_CACHE" 2>/dev/null)
    fi

    if [ -z "$issue_number" ]; then
        issue_number=$(gh issue list \
            --repo "$REPO" \
            --label "$LABEL" \
            --state open \
            --json number,title 2>/dev/null \
            | jq -r --arg t "$ISSUE_TITLE" '.[] | select(.title == $t) | .number' 2>/dev/null \
            | head -1)
    fi

    if [ -z "$issue_number" ]; then
        gh label create "$LABEL" --repo "$REPO" --color "0075ca" --force >/dev/null 2>&1 || true
        issue_number=$(gh issue create \
            --repo "$REPO" \
            --title "$ISSUE_TITLE" \
            --label "$LABEL" \
            --body "Central rollup for passive usage telemetry. Each comment is one user's periodic flush." \
            2>/dev/null | grep -oE '[0-9]+$')
    fi

    [ -z "$issue_number" ] && return 0
    printf '%s\n' "$issue_number" > "$ISSUE_CACHE" 2>/dev/null || true

    local last_seen
    last_seen=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")

    gh issue comment "$issue_number" \
        --repo "$REPO" \
        --body "$(printf 'user: %s\ntotal: %d\nlast_seen: %s' "$user_ident" "$total" "$last_seen")" \
        >/dev/null 2>&1 || true
}

# --- main -------------------------------------------------------------------

USER_IDENT=$(git config user.email 2>/dev/null || echo "${USER:-unknown}")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")

# Append one log entry; create file and directory if needed; exit 0 on failure
{
    mkdir -p "$LOG_DIR"
    printf '%s\t%s\t%s\n' "$TIMESTAMP" "$USER_IDENT" "$SKILL" >> "$LOG_FILE"
} 2>/dev/null || true

# Count lines and trigger flush at multiples of 25
LINE_COUNT=$(wc -l < "$LOG_FILE" 2>/dev/null | tr -d ' ') 2>/dev/null || true
LINE_COUNT="${LINE_COUNT:-0}"

if [[ "$LINE_COUNT" -gt 0 && $(( LINE_COUNT % 25 )) -eq 0 ]]; then
    flush_rollup "$LINE_COUNT" "$USER_IDENT" &
fi

exit 0
