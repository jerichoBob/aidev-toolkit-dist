#!/usr/bin/env bash
# Print the backbone state directory this machine uses (see bb_default_dir in backbone-lib.sh).
# Skills call this once instead of hardcoding a path.
#
# Usage: backbone-dir.sh [--check]
#   --check   exit 1 with a hint on stderr when the directory has not been set up yet
# Exit: 0 ok · 1 --check and the directory is missing or has no messages/ and presence/
set -uo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backbone-lib.sh
source "$SELF_DIR/backbone-lib.sh"
DIR="$(bb_default_dir "$SELF_DIR")"
if [[ "${1:-}" == "--check" && ! ( -d "$DIR/messages" && -d "$DIR/presence" ) ]]; then
  echo "backbone: not set up at $DIR — run /backbone-setup" >&2
  echo "$DIR"; exit 1
fi
echo "$DIR"
