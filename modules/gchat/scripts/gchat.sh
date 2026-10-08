#!/usr/bin/env bash
# Run a gchat Python script with its Google API dependencies available.
# Usage: gchat.sh <auth|list_spaces|read_messages|send|download_attachments> [args...]
#        gchat.sh confirm [ask|auto]   print (or set) whether /gchat send asks before posting; default ask
# Uses uv (no install needed) when present, else the system python3 (needs google-api-python-client,
# google-auth-oauthlib installed). Credentials and token live in ~/.config/aidev/gchat/ (GCHAT_CONFIG_DIR).
set -euo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
CMD="${1:-}"

if [[ "$CMD" == "confirm" ]]; then
  CFG_DIR="${GCHAT_CONFIG_DIR:-$HOME/.config/aidev/gchat}"; CFG="$CFG_DIR/config"
  if [[ $# -ge 2 ]]; then
    case "$2" in
      ask|auto) ;;
      *) echo "gchat: confirm must be 'ask' or 'auto' (got '$2')" >&2; exit 4 ;;
    esac
    mkdir -p "$CFG_DIR"
    { grep -v '^confirm=' "$CFG" 2>/dev/null || true; echo "confirm=$2"; } > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
    echo "$2"; exit 0
  fi
  v="$({ grep '^confirm=' "$CFG" 2>/dev/null || true; } | tail -1 | cut -d= -f2 | tr -d '[:space:]')"
  case "${v:-ask}" in
    ask|auto) echo "${v:-ask}" ;;
    *) echo "gchat: invalid confirm '$v' in $CFG (expected ask or auto)" >&2; exit 4 ;;
  esac
  exit 0
fi
case "$CMD" in
  auth|list_spaces|read_messages|send|download_attachments) shift ;;
  *) echo "usage: gchat.sh <confirm|auth|list_spaces|read_messages|send|download_attachments> [args...]" >&2; exit 4 ;;
esac

if command -v uv >/dev/null 2>&1; then
  exec uv run --quiet --no-project --with google-api-python-client --with google-auth-oauthlib \
    python3 "$SELF_DIR/$CMD.py" "$@"
fi
exec python3 "$SELF_DIR/$CMD.py" "$@"
