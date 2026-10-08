#!/usr/bin/env bash
# Poll for NEW messages addressed to this agent. Meant to run under Claude Code's Monitor tool:
# it prints nothing while idle (no model tokens spent), and prints one line then exits when a
# message that was not pending at startup arrives — which wakes the agent.
#
# In git mode it fetches origin and reads the remote tree without touching the working copy.
# In local mode it re-reads messages/ on disk. Only the final seen-marker push (on a hit) syncs
# the working copy, as a side effect of rebasing before the push.
#
# Usage: backbone-poll.sh [--dir DIR] [--agent NAME] [--interval SECONDS] [--max-iterations N]
#   --interval        seconds between checks (default 30)
#   --max-iterations  stop after N checks with exit 1 (default 0 = run until a message arrives)
# Exit: 0 a new message arrived · 1 gave up after --max-iterations · 4 usage/config error
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backbone-lib.sh
source "$SELF_DIR/backbone-lib.sh"

DIR=""; AGENT_FLAG=""; INTERVAL=30; MAX=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    --agent) AGENT_FLAG="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --max-iterations) MAX="$2"; shift 2 ;;
    *) echo "backbone-poll: unknown argument $1" >&2; exit 4 ;;
  esac
done
[[ -n "$DIR" ]] || DIR="$(bb_default_dir "$SELF_DIR")"
[[ -d "$DIR" ]] || { echo "backbone-poll: $DIR not found" >&2; exit 4; }
DIR="$(cd "$DIR" && pwd)"
AGENT="$(bb_resolve_agent "$DIR" "$AGENT_FLAG")"
[[ -n "$AGENT" ]] || { echo "backbone-poll: no agent name (use --agent, BACKBONE_AGENT, or agent= in backbone.config)" >&2; exit 4; }
MODE="$(bb_transport "$DIR")" || exit 4

REF=""
if [[ "$MODE" == "git" ]]; then
  BRANCH="$(git -C "$DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)" || { echo "backbone-poll: $DIR is not a git repository" >&2; exit 4; }
  REF="origin/$BRANCH"
fi

refresh() {
  [[ "$MODE" == "git" ]] || return 0
  if git -C "$DIR" fetch -q origin 2>/dev/null; then OUTAGE=0; return 0; fi
  if [[ "${OUTAGE:-0}" -eq 0 ]]; then OUTAGE=1; echo "backbone-poll: remote unreachable — still watching"; fi
  return 1
}

OUTAGE=0
refresh >/dev/null
baseline="$(bb_pending_for "$DIR" "$AGENT" "$REF")"

i=0
while :; do
  i=$((i + 1))
  [[ "$MAX" -gt 0 && "$i" -gt "$MAX" ]] && exit 1
  sleep "$INTERVAL"
  refresh || continue
  now="$(bb_pending_for "$DIR" "$AGENT" "$REF")"
  new="$(comm -13 <(sort <<<"$baseline") <(sort <<<"$now") | grep -v '^$' | head -1)"
  if [[ -n "$new" ]]; then
    echo "backbone: new message — $(bb_msg_summary "$DIR" "$new" "$REF") (run /backbone-inbox)"
    if [[ -n "$(bb_mark_seen "$DIR" "$new" "$AGENT")" ]]; then
      bash "$SELF_DIR/backbone-sync.sh" --dir "$DIR" push seen "${new%-pending.md}" >/dev/null 2>&1 || true
    fi
    exit 0
  fi
done
