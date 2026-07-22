#!/bin/bash
#
# screenshots.sh - Find the N most recent screenshots on the configured source directory
#
# Usage: screenshots.sh [N]
#   N: Number of screenshots to return (default: 1, must be positive integer)
#
# Configuration (env vars, falling back to ~/.claude/aidev-toolkit/.env if set there):
#   AIDEV_SCREENSHOTS_DIR      Source directory (default: ~/Desktop)
#   AIDEV_SCREENSHOTS_PATTERN  Filename glob pattern (default: Screenshot*.png)
#
# Output: Absolute paths, one per line, most recent first
#

set -e

# Colors for error output
RED='\033[0;31m'
NC='\033[0m'

# macOS-only guard
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${RED}Error: /screenshots is macOS only.${NC}" >&2
    echo "  This skill uses the macOS Screenshot naming convention (Screenshot*.png on ~/Desktop)." >&2
    echo "  It is not supported on Linux or Windows." >&2
    exit 0
fi

# shellcheck disable=SC1091
[ -f "$HOME/.claude/aidev-toolkit/.env" ] && source "$HOME/.claude/aidev-toolkit/.env"

SCREENSHOTS_DIR="${AIDEV_SCREENSHOTS_DIR:-$HOME/Desktop}"
SCREENSHOTS_PATTERN="${AIDEV_SCREENSHOTS_PATTERN:-Screenshot*.png}"

N="${1:-1}"

# Validate N is a positive integer
if ! [[ "$N" =~ ^[1-9][0-9]*$ ]]; then
    echo -e "${RED}Error: argument must be a positive integer, got '$N'${NC}" >&2
    exit 1
fi

if [ ! -d "$SCREENSHOTS_DIR" ]; then
    echo -e "${RED}Error: screenshots directory not found: $SCREENSHOTS_DIR${NC}" >&2
    exit 1
fi

# Find matching files sorted by modification time (newest first)
# Use ls -t for time sorting, while read to handle spaces in filenames
COUNT=0
# shellcheck disable=SC2086
ls -t "$SCREENSHOTS_DIR"/$SCREENSHOTS_PATTERN 2>/dev/null | while IFS= read -r file; do
    if [ "$COUNT" -ge "$N" ]; then
        break
    fi
    echo "$file"
    COUNT=$((COUNT + 1))
done

# Check if any screenshots were found
# shellcheck disable=SC2086
if ! ls "$SCREENSHOTS_DIR"/$SCREENSHOTS_PATTERN &>/dev/null; then
    echo -e "${RED}Error: no screenshots found in $SCREENSHOTS_DIR${NC}" >&2
    exit 1
fi
