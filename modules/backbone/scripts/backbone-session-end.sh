#!/usr/bin/env bash
# SessionEnd hook. Marks this Claude session's presence record inactive and, in git mode, pushes it.
# It finds the record through the session name the SessionStart hook remembered (same session key).
# It does NOT write the "Learned" section: that needs the model, so it stays with an explicit
# /backbone leave. Always exits 0 — a hook must never block the session from ending.
#
# Usage: backbone-session-end.sh [--dir DIR] [--key KEY]
#   --key  session key override (tests); default from stdin session_id, else the project directory
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backbone-lib.sh
source "$SELF_DIR/backbone-lib.sh"

DIR=""; KEY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DIR="${2:-}"; shift 2 ;;
    --key) KEY="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "$DIR" ]] || DIR="$(bb_default_dir "$SELF_DIR")"
[[ -d "$DIR" ]] || { echo "backbone: $DIR not found — nothing to deregister"; exit 0; }
DIR="$(cd "$DIR" && pwd)"

if [[ -z "$KEY" && ! -t 0 ]]; then
  payload=""; IFS= read -r -t 1 -d '' payload || true
  KEY="$(sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<<"$payload" | head -1)"
fi
[[ -n "$KEY" ]] || KEY="proj-$(bb_slug "${CLAUDE_PROJECT_DIR:-$PWD}")"

SF="$(bb_session_file "$DIR" "$KEY")"
if [[ ! -f "$SF" ]]; then
  echo "backbone: no registered session found for this Claude session — nothing to deregister"
  exit 0
fi
NAME="$(head -1 "$SF")"
PF="$(bb_presence_path "$DIR" "$NAME")"
if [[ ! -f "$PF" ]]; then
  echo "backbone: no presence record for $NAME — nothing to deregister"
  rm -f "$SF"
  exit 0
fi

if bb_fm_set "$PF" status inactive && bb_fm_set "$PF" updated "$(bb_now)"; then
  rm -f "$SF"
  PSF="$(bb_session_file "$DIR" "proj-$(bb_slug "${CLAUDE_PROJECT_DIR:-$PWD}")")"
  [[ -f "$PSF" && "$(head -1 "$PSF")" == "$NAME" ]] && rm -f "$PSF"
  echo "backbone: $NAME marked inactive"
else
  echo "backbone: could not update $PF — $NAME stays active until its ttl expires"
  exit 0
fi
bash "$SELF_DIR/backbone-sync.sh" --dir "$DIR" push session-end "$NAME" >/dev/null 2>&1 \
  || echo "backbone: could not push the inactive record (remote unreachable?) — it will go out on the next push"
exit 0
