#!/usr/bin/env bash
# Backbone notifier: post the ping to a Google Chat space.
# Set in backbone.config:  notify_command=~/.claude/aidev-toolkit/modules/gchat/scripts/gchat-notify.sh
# Reads BACKBONE_NOTIFY_TARGET (a space resource name, spaces/AAAA...) and BACKBONE_NOTIFY_TEXT from the
# environment that backbone-notify.sh sets. Confirmation before sending is backbone's notify_confirm.
# Exit: 0 sent · 1 send failed · 4 bad/missing target or text
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${BACKBONE_NOTIFY_TARGET:-}"
TEXT="${BACKBONE_NOTIFY_TEXT:-}"

[[ -n "$TEXT" ]] || { echo "gchat-notify: BACKBONE_NOTIFY_TEXT is empty" >&2; exit 4; }
[[ "$TARGET" =~ ^spaces/[A-Za-z0-9_-]+$ ]] || {
  echo "gchat-notify: BACKBONE_NOTIFY_TARGET must be a space resource name like spaces/AAAAAAAAAAA (got '${TARGET}')" >&2
  exit 4
}

bash "$SELF_DIR/gchat.sh" send --space "$TARGET" --text "$TEXT" >/dev/null || exit 1
