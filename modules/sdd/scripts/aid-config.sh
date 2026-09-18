#!/usr/bin/env bash
# aid-config.sh — read simple key: value pairs from .aid/config.yaml
# No YAML library dependency — this file is intentionally a flat key: value list.
# Usage: aid-config.sh get <key>
#        aid-config.sh spec-guard-enabled

set -euo pipefail

CONFIG_FILE=".aid/config.yaml"
CONFIG_EXAMPLE=".aid/config.yaml.example"

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

# Write "key: value" into .aid/config.yaml, creating the file (from the
# .example template if available) if it doesn't exist yet, and replacing
# an existing "key:" line in place rather than appending a duplicate.
set_value() {
  local key="$1"
  local value="$2"

  mkdir -p .aid

  if [[ ! -f "$CONFIG_FILE" ]]; then
    if [[ -f "$CONFIG_EXAMPLE" ]]; then
      cp "$CONFIG_EXAMPLE" "$CONFIG_FILE"
    else
      : > "$CONFIG_FILE"
    fi
  fi

  if grep -qE "^${key}:" "$CONFIG_FILE" 2>/dev/null; then
    local tmp
    tmp="$(mktemp)"
    sed -E "s/^(${key}:).*/\\1 ${value}/" "$CONFIG_FILE" > "$tmp"
    mv "$tmp" "$CONFIG_FILE"
  else
    printf '%s: %s\n' "$key" "$value" >> "$CONFIG_FILE"
  fi
}

case "${1:-}" in
  get)
    [[ -z "${2:-}" ]] && { echo "Usage: $0 get <key>" >&2; exit 1; }
    get_value "$2"
    ;;
  set)
    [[ -z "${2:-}" || -z "${3:-}" ]] && { echo "Usage: $0 set <key> <value>" >&2; exit 1; }
    set_value "$2" "$3"
    echo "$2: $3"
    ;;
  spec-guard-enabled)
    val="$(get_value "spec-guard")"
    if [[ "$val" == "true" ]]; then echo "true"; else echo "false"; fi
    ;;
  *)
    echo "Usage: $0 {get <key>|set <key> <value>|spec-guard-enabled}" >&2
    echo "" >&2
    echo "Commands:" >&2
    echo "  get <key>            - Raw value of a top-level key from .aid/config.yaml (empty if unset)" >&2
    echo "  set <key> <value>    - Write key: value into .aid/config.yaml (creates the file if missing)" >&2
    echo "  spec-guard-enabled   - 'true' if spec-guard: true is set, else 'false' (default)" >&2
    exit 1
    ;;
esac
