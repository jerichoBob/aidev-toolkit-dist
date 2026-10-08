#!/usr/bin/env bash
# Show or set the agent address used by the SessionStart hook (agent= in <dir>/backbone.config).
# The address is the stable name others send to; each session adds its own ~suffix. With no agent=
# the hook infers <project>:<git user>. agent= applies to every project on this machine, so set it
# only for a name that makes sense everywhere (e.g. "bob"); BACKBONE_AGENT overrides it per project.
#
# Usage: backbone-name.sh [--dir DIR] show
#        backbone-name.sh [--dir DIR] set <address>
#        backbone-name.sh [--dir DIR] unset
# Exit: 0 ok · 4 usage or invalid address
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backbone-lib.sh
source "$SELF_DIR/backbone-lib.sh"

DIR=""
if [[ "${1:-}" == "--dir" ]]; then DIR="${2:-}"; shift 2; fi
[[ -n "$DIR" ]] || DIR="$(bb_default_dir "$SELF_DIR")"
[[ -d "$DIR" ]] || { echo "backbone-name: $DIR not found" >&2; exit 4; }
DIR="$(cd "$DIR" && pwd)"
CFG="$DIR/backbone.config"
SUB="${1:-show}"

# drop_agent — write the config without any agent= line (comments and other keys untouched)
drop_agent() {
  [[ -f "$CFG" ]] || return 0
  local tmp; tmp="$(mktemp "$CFG.XXXXXX")" || return 1
  awk 'BEGIN{FS="="} { k=$1; gsub(/^[ \t]+|[ \t\r]+$/, "", k); if (k != "agent") print }' "$CFG" > "$tmp" && mv "$tmp" "$CFG" || { rm -f "$tmp"; return 1; }
}

case "$SUB" in
  show)
    cur="$(bb_config_get "$DIR" agent)"
    if [[ -n "${BACKBONE_AGENT:-}" ]]; then echo "address: $BACKBONE_AGENT (from BACKBONE_AGENT)"
    elif [[ -n "$cur" ]]; then echo "address: $cur (from agent= in $CFG)"
    else echo "address: not set (the hook infers <project>:<git user.name>)"; fi ;;
  set)
    addr="${2:-}"
    [[ -n "$addr" ]] || { echo "usage: backbone-name.sh [--dir DIR] set <address>" >&2; exit 4; }
    # An address is one line with no "~" (the hook adds that) and nothing the shell or a filename would mangle.
    if [[ ! "$addr" =~ ^[A-Za-z0-9._:-]+$ ]]; then
      echo "backbone-name: address may use letters, digits, . _ : - only" >&2; exit 4
    fi
    drop_agent || { echo "backbone-name: could not update $CFG" >&2; exit 4; }
    printf 'agent=%s\n' "$addr" >> "$CFG" || { echo "backbone-name: could not write $CFG" >&2; exit 4; }
    echo "address set to $addr (new sessions will register as $addr~xxxx)" ;;
  unset)
    drop_agent || { echo "backbone-name: could not update $CFG" >&2; exit 4; }
    echo "address unset (the hook infers <project>:<git user.name>)" ;;
  *) echo "usage: backbone-name.sh [--dir DIR] show|set <address>|unset" >&2; exit 4 ;;
esac
