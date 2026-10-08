#!/usr/bin/env bash
# Locate presence records without building a filename from an agent name. The name lives in the
# file's agent_name field; the filename is only a filesystem-safe label (no ":" etc., so Windows
# can create it). Commands call this instead of constructing presence-<name>.md themselves.
#
# Usage: backbone-presence.sh [--dir DIR] path  <agent>   record to read or write for this exact name
#        backbone-presence.sh [--dir DIR] files <agent>   every record belonging to the name; an address
#                                                          (no "~") includes all of its sessions
#        backbone-presence.sh [--dir DIR] safe  <name>    the filesystem-safe form of a name
#        backbone-presence.sh [--dir DIR] me [PROJECT]    the latest session name registered from PROJECT
#                                                          (default $CLAUDE_PROJECT_DIR, else cwd); exit 1 if none
# Exit: 0 ok · 1 files/me: nothing found · 4 usage
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backbone-lib.sh
source "$SELF_DIR/backbone-lib.sh"

DIR=""
if [[ "${1:-}" == "--dir" ]]; then DIR="${2:-}"; shift 2; fi
SUB="${1:-}"; NAME="${2:-}"
[[ -n "$SUB" && ( -n "$NAME" || "$SUB" == "me" ) ]] || { echo "usage: backbone-presence.sh [--dir DIR] path|files|safe <agent> | me [PROJECT]" >&2; exit 4; }
[[ -n "$DIR" ]] || DIR="$(bb_default_dir "$SELF_DIR")"
[[ -d "$DIR" ]] || { echo "backbone-presence: $DIR not found" >&2; exit 4; }
DIR="$(cd "$DIR" && pwd)"

case "$SUB" in
  path) bb_presence_path "$DIR" "$NAME" ;;
  files) out="$(bb_presence_files "$DIR" "$NAME")"; [[ -n "$out" ]] || exit 1; echo "$out" ;;
  safe) bb_safe_name "$NAME"; echo ;;
  me)
    proj="${NAME:-${CLAUDE_PROJECT_DIR:-$PWD}}"
    f="$(bb_session_file "$DIR" "proj-$(bb_slug "$proj")")"
    [[ -f "$f" ]] || exit 1
    head -1 "$f" ;;
  *) echo "backbone-presence: unknown subcommand $SUB" >&2; exit 4 ;;
esac
