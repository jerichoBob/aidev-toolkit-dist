#!/usr/bin/env bash
# aid-config.sh — read simple key: value pairs from .aid/config.yaml
# No YAML library dependency — this file is intentionally a flat key: value list.
# Usage: aid-config.sh get <key>
#        aid-config.sh spec-guard-enabled

set -euo pipefail

CONFIG_FILE=".aid/config.yaml"

# Return the raw value for a top-level "key: value" line, or empty string
# if the file/key is missing or unreadable. Never errors — callers rely on
# the empty-string default to mean "off"/"unset".
get_value() {
  local key="$1"
  [[ -f "$CONFIG_FILE" ]] || { echo ""; return 0; }

  local line
  line=$(grep -E "^${key}:" "$CONFIG_FILE" 2>/dev/null | head -1) || true
  [[ -z "$line" ]] && { echo ""; return 0; }

  local value="${line#*:}"
  value="${value%%#*}"
  value="$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e "s/^\"\\(.*\\)\"\$/\\1/" -e "s/^'\\(.*\\)'\$/\\1/")"
  echo "$value"
}

case "${1:-}" in
  get)
    [[ -z "${2:-}" ]] && { echo "Usage: $0 get <key>" >&2; exit 1; }
    get_value "$2"
    ;;
  spec-guard-enabled)
    val="$(get_value "spec-guard")"
    if [[ "$val" == "true" ]]; then echo "true"; else echo "false"; fi
    ;;
  *)
    echo "Usage: $0 {get <key>|spec-guard-enabled}" >&2
    echo "" >&2
    echo "Commands:" >&2
    echo "  get <key>            - Raw value of a top-level key from .aid/config.yaml (empty if unset)" >&2
    echo "  spec-guard-enabled   - 'true' if spec-guard: true is set, else 'false' (default)" >&2
    exit 1
    ;;
esac
