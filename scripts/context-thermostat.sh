#!/bin/bash
#
# context-thermostat.sh — UserPromptSubmit hook that nudges Claude to /compact
# once context usage crosses a threshold, then stays quiet until usage drops
# back below it (re-arming for the next crossing).
#
# statusline.sh writes ~/.claude/ctx-state.json on every redraw with the
# current context_window.used_percentage — this hook is the only channel
# that can put that information back in front of Claude, since the
# UserPromptSubmit hook payload itself carries no context-window data.
#

STATE_FILE="$HOME/.claude/ctx-state.json"

[[ -f "$STATE_FILE" ]] || exit 0

armed=$(jq -r '.armed // false' "$STATE_FILE" 2>/dev/null)
notified=$(jq -r '.notified // false' "$STATE_FILE" 2>/dev/null)
last_pct=$(jq -r '.last_pct // empty' "$STATE_FILE" 2>/dev/null)

if [[ "$armed" == "true" && "$notified" != "true" ]]; then
    jq -n --argjson pct "${last_pct:-0}" \
        '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: ("Context usage just crossed the thermostat threshold (~" + ($pct | tostring) + "% of the context window). Consider running /compact soon.")}}'
    jq '.notified = true' "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null && mv "${STATE_FILE}.tmp" "$STATE_FILE"
fi

exit 0
