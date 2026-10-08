#!/usr/bin/env bash
# Deliver one ping through the notifier configured on this machine.
#
# The notifier is whatever command backbone.config names in notify_command=. It is read only from
# the machine-local <dir>/backbone.config — never from a message, a roster, or a file in a project
# repo — so a sender cannot cause a command to run on a receiver's machine.
#
# The ping text is built from sender and title only (never the message body) and reaches the command
# as environment variables, never interpolated into a shell string:
#   BACKBONE_NOTIFY_TARGET  roster notify target (e.g. a Chat space ID)
#   BACKBONE_NOTIFY_TEXT    "<from> sent you "<title>" on the backbone (<id>)"
#   BACKBONE_NOTIFY_FROM    sender agent name
#   BACKBONE_NOTIFY_TITLE   message title, unchanged
#   BACKBONE_NOTIFY_ID      message id
#
# Usage: backbone-notify.sh [--dir DIR] --target TARGET --from AGENT --title TEXT --id <type-id>
# Each attempt is logged to <dir>/.claude/data/backbone/pings.log (time, result, target, id; never the body).
# Exit: 0 sent · 1 notifier ran and failed · 3 no notifier configured (nothing attempted) · 4 usage
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backbone-lib.sh
source "$SELF_DIR/backbone-lib.sh"

DIR=""; TARGET=""; FROM=""; TITLE=""; ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --from) FROM="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    *) echo "backbone-notify: unknown argument $1" >&2; exit 4 ;;
  esac
done
[[ -n "$TARGET" && -n "$FROM" && -n "$ID" ]] || {
  echo "usage: backbone-notify.sh [--dir DIR] --target TARGET --from AGENT --title TEXT --id <type-id>" >&2
  exit 4
}
[[ -n "$DIR" ]] || DIR="$(bb_default_dir "$SELF_DIR")"
DIR="$(cd "$DIR" && pwd)"

CMD="$(bb_config_get "$DIR" notify_command)"
if [[ -z "$CMD" ]]; then
  echo "backbone-notify: no notifier configured (set notify_command= in $DIR/backbone.config)" >&2
  exit 3
fi

# log_attempt <result> — one tab-separated line per attempt: time, result, target, id.
# Never the title or text, so a log can be shared without leaking message content. A logging
# failure is reported but never changes the notifier's result.
log_attempt() {
  local logdir="$DIR/.claude/data/backbone" safe_target safe_id
  safe_target="$(printf '%s' "$TARGET" | tr -d '\r\n\t')"
  safe_id="$(printf '%s' "$ID" | tr -d '\r\n\t')"
  { mkdir -p "$logdir" && printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$safe_target" "$safe_id" >> "$logdir/pings.log"; } 2>/dev/null \
    || echo "backbone-notify: could not write $logdir/pings.log" >&2
}

TEXT="$FROM sent you \"$TITLE\" on the backbone ($ID)"
if BACKBONE_NOTIFY_TARGET="$TARGET" BACKBONE_NOTIFY_TEXT="$TEXT" BACKBONE_NOTIFY_FROM="$FROM" \
   BACKBONE_NOTIFY_TITLE="$TITLE" BACKBONE_NOTIFY_ID="$ID" bash -c "$CMD"; then
  log_attempt sent
  exit 0
fi
log_attempt failed
echo "backbone-notify: notifier failed for $ID" >&2
exit 1
