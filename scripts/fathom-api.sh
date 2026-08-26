#!/bin/bash
# Fathom API helper for the /fathom skill.
# Reads FATHOM_API_KEY from ~/.config/fathom/config so the key never lives in the skill file or git history.
set -euo pipefail

API_BASE="https://api.fathom.ai/external/v1"
CONFIG_FILE="$HOME/.config/fathom/config"

if [[ "${1:-}" == "check" ]]; then
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    if [[ -n "${FATHOM_API_KEY:-}" ]]; then
      echo "ok"
      exit 0
    fi
  fi
  echo "missing"
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing config file: $CONFIG_FILE" >&2
  exit 1
fi
source "$CONFIG_FILE"

if [[ -z "${FATHOM_API_KEY:-}" ]]; then
  echo "FATHOM_API_KEY not set in $CONFIG_FILE" >&2
  exit 1
fi

ENDPOINT="${1:?Usage: fathom-api.sh <endpoint> [jq-filter] [jq-args...]}"
JQ_FILTER="${2:-.}"
shift 2 2>/dev/null || true

curl -s -H "X-Api-Key: $FATHOM_API_KEY" "${API_BASE}/${ENDPOINT}" | jq "$@" "$JQ_FILTER"
