#!/usr/bin/env bash
# Sender-side no-ack timer. After publishing a direct message, watch for the receiver to
# acknowledge it (claim it, or write a seen marker). If nothing arrives within the timeout,
# ping the receiver's human through the notifier configured on this machine (backbone-notify.sh).
#
# What happens on timeout depends on notify_confirm (per-project override, machine default, then ask):
#   ask   print a PING line. The sender's session shows the exact target and text, and runs
#         backbone-notify.sh only after the developer approves.
#   auto  call backbone-notify.sh here.
# With no notify_command configured, nothing is attempted and NONOTIFIER is printed (both modes).
#
# The ping names the sender and the title only — never the message body.
# Limit: this runs in the sender's session. If that session closes first, no ping is sent.
#
# Usage: backbone-ack-check.sh [--dir DIR] --id <type-id> --to AGENT --from AGENT --title TEXT
#                              [--timeout 300] [--interval 15]
# Output (stdout), only on timeout:
#   PING <human>|<notify> :: <from> sent you "<title>" on the backbone (<type-id>)     (ask)
#   SENT <human>|<notify> :: <type-id>                                                 (auto, delivered)
#   NOTIFYFAILED <human>|<notify> :: <type-id>                                         (auto, notifier failed)
#   NONOTIFIER no notify_command configured
#   NOPING no roster entry for <to>
# Exit: 0 acknowledged in time (silent) · 10 PING printed (ask) · 11 no roster entry · 12 sent (auto)
#       · 13 notifier failed (auto) · 14 no notifier configured · 4 usage
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backbone-lib.sh
source "$SELF_DIR/backbone-lib.sh"

DIR=""; ID=""; TO=""; FROM=""; TITLE=""; TIMEOUT=300; INTERVAL=15
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    --to) TO="$2"; shift 2 ;;
    --from) FROM="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    *) echo "backbone-ack-check: unknown argument $1" >&2; exit 4 ;;
  esac
done
[[ -n "$ID" && -n "$TO" && -n "$FROM" ]] || { echo "usage: backbone-ack-check.sh --id <type-id> --to AGENT --from AGENT --title TEXT" >&2; exit 4; }
[[ -n "$DIR" ]] || DIR="$(bb_default_dir "$SELF_DIR")"
DIR="$(cd "$DIR" && pwd)"
MODE="$(bb_transport "$DIR")" || exit 4

REF=""
if [[ "$MODE" == "git" ]]; then
  REF="origin/$(git -C "$DIR" rev-parse --abbrev-ref HEAD)"
fi

# acked — true when the message was claimed/completed, or any seen marker exists for it
acked() {
  local names
  if [[ -n "$REF" ]]; then
    git -C "$DIR" fetch -q origin 2>/dev/null || true
    names="$(git -C "$DIR" ls-tree -r --name-only "$REF" messages/ 2>/dev/null)"
  else
    names="$(cd "$DIR" && find messages -type f 2>/dev/null)"
  fi
  grep -qE "(^|/)($ID-(claimed|complete|archived)\.md|seen/$ID\.[^/]+)$" <<<"$names"
}

deadline=$((SECONDS + TIMEOUT))
while :; do
  acked && exit 0
  [[ $SECONDS -ge $deadline ]] && break
  sleep "$INTERVAL"
done

# Nothing is attempted without a notifier, so say so before looking anyone up.
if [[ -z "$(bb_config_get "$DIR" notify_command)" ]]; then
  echo "NONOTIFIER no notify_command configured (set it in $DIR/backbone.config; see docs/notify.md)"
  exit 14
fi

entry="$(bash "$SELF_DIR/backbone-roster-lookup.sh" --dir "$DIR" "$TO")" || {
  echo "NOPING no roster entry for $TO"
  exit 11
}
target="${entry#*|}"
CONFIRM="$(bb_notify_confirm "$DIR" "$FROM")" || exit 4

if [[ "$CONFIRM" == "ask" ]]; then
  echo "PING $entry :: $FROM sent you \"$TITLE\" on the backbone ($ID)"
  exit 10
fi

if bash "$SELF_DIR/backbone-notify.sh" --dir "$DIR" --target "$target" --from "$FROM" --title "$TITLE" --id "$ID" >/dev/null 2>&1; then
  echo "SENT $entry :: $ID"
  exit 12
fi
echo "NOTIFYFAILED $entry :: $ID"
exit 13
