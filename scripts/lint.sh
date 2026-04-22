#!/usr/bin/env bash
set -euo pipefail

# Ensure markdownlint is available
if ! command -v markdownlint &>/dev/null; then
  echo "ERROR: markdownlint-cli not installed. Run: npm install -g markdownlint-cli"
  exit 1
fi

# Config source and destination
CONFIG_SRC="$HOME/.claude/aidev-toolkit/templates/markdownlint.json"
CONFIG_DST=".markdownlint.json"

# Copy config if missing
if [[ ! -f "$CONFIG_DST" ]] && [[ -f "$CONFIG_SRC" ]]; then
  cp "$CONFIG_SRC" "$CONFIG_DST"
  echo "Created $CONFIG_DST from aidev toolkit template"
fi

# Target: argument or default; expand directories to recursive glob
ARG="${1:-}"
if [[ -z "$ARG" ]]; then
  TARGET="**/*.md"
elif [[ -d "$ARG" ]]; then
  TARGET="${ARG%/}/**/*.md"
else
  TARGET="$ARG"
fi

# Run auto-fix
echo "Fixing: $TARGET"
markdownlint --fix "$TARGET" 2>&1 || true

# Final check
echo ""
echo "Remaining issues:"
if markdownlint "$TARGET" 2>&1; then
  echo "All clean!"
else
  echo ""
  echo "Some issues require manual fixes."
fi
