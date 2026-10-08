#!/usr/bin/env bash
# Look up the human behind an agent name in <dir>/roster.md.
#
# roster.md is the agent-to-human map. It lives at the backbone root, is edited by hand, and is
# committed like any other file on the shared branch (the sync wrapper does not stage it).
# One table row per human; the agent column may use shell globs so one row covers a whole repo:
#
#   | agent        | human | notify             |
#   | ------------ | ----- | ------------------ |
#   | stak-app:*   | Bob   | bob@example.com    |
#   | radeas-*:*   | Nate  | nate@example.com   |
#
# Usage: backbone-roster-lookup.sh [--dir DIR] <agent-name>
# The notify column is an opaque target handed to the configured notifier (for Radeas, a Chat space ID).
# Prints "<human>|<notify>" for the first matching row. Exit 0 found · 1 no match · 4 usage.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backbone-lib.sh
source "$SELF_DIR/backbone-lib.sh"

DIR=""
if [[ "${1:-}" == "--dir" ]]; then DIR="$2"; shift 2; fi
AGENT="${1:-}"
[[ -n "$AGENT" ]] || { echo "usage: backbone-roster-lookup.sh [--dir DIR] <agent-name>" >&2; exit 4; }
[[ -n "$DIR" ]] || DIR="$(bb_default_dir "$SELF_DIR")"
ROSTER="$DIR/roster.md"
[[ -f "$ROSTER" ]] || exit 1

while IFS='|' read -r _ pattern human notify _; do
  pattern="$(echo "$pattern" | sed -E 's/^[[:space:]`]+|[[:space:]`]+$//g')"
  human="$(echo "$human" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
  notify="$(echo "$notify" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
  [[ -n "$pattern" && "$pattern" != "agent" && "$pattern" != -* ]] || continue
  # shellcheck disable=SC2254
  case "$AGENT" in $pattern) echo "$human|$notify"; exit 0 ;; esac
done < "$ROSTER"
exit 1
