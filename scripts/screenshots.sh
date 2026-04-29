#!/bin/bash
#
# screenshots.sh - Find the N most recent macOS screenshots on ~/Desktop
#
# Usage: screenshots.sh [N]
#   N: Number of screenshots to return (default: 1, must be positive integer)
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

N="${1:-1}"

# Validate N is a positive integer
if ! [[ "$N" =~ ^[1-9][0-9]*$ ]]; then
    echo -e "${RED}Error: argument must be a positive integer, got '$N'${NC}" >&2
    exit 1
fi

DESKTOP="$HOME/Desktop"

if [ ! -d "$DESKTOP" ]; then
    echo -e "${RED}Error: ~/Desktop directory not found${NC}" >&2
    exit 1
fi

# Find Screenshot*.png files sorted by modification time (newest first)
# Use ls -t for time sorting, while read to handle spaces in filenames
COUNT=0
ls -t "$DESKTOP"/Screenshot*.png 2>/dev/null | while IFS= read -r file; do
    if [ "$COUNT" -ge "$N" ]; then
        break
    fi
    echo "$file"
    COUNT=$((COUNT + 1))
done

# Check if any screenshots were found
if ! ls "$DESKTOP"/Screenshot*.png &>/dev/null; then
    echo -e "${RED}Error: no screenshots found on ~/Desktop${NC}" >&2
    exit 1
fi
