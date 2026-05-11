#!/bin/bash
#
# tile-image.sh - Dynamically tile an image to fit model vision resolution limits
#
# Usage: tile-image.sh <image_path> [--limit N]
#   image_path : path to a PNG/JPG image
#   --limit N  : max pixels on the long edge (default: 1568 for Sonnet/Haiku;
#                pass 2576 for Opus 4.x)
#
# Output: one absolute file path per line
#   - Image fits within limit: outputs the original path unchanged
#   - Image exceeds limit: outputs tile paths from a temp dir
#
# Tiles are cached in /tmp/claude-tiles/<basename>-<WxH>-<COLS>x<ROWS>/
# and reused on repeat calls within a session.
#

set -e

RED='\033[0;31m'
NC='\033[0m'

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${RED}Error: tile-image.sh requires macOS (uses sips)${NC}" >&2
    exit 1
fi

# Parse args
IMAGE=""
LIMIT=1568

while [[ $# -gt 0 ]]; do
    case "$1" in
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        *)
            IMAGE="$1"
            shift
            ;;
    esac
done

if [[ -z "$IMAGE" || ! -f "$IMAGE" ]]; then
    echo -e "${RED}Error: image file not found: '$IMAGE'${NC}" >&2
    exit 1
fi

# Get image dimensions
WIDTH=$(sips -g pixelWidth "$IMAGE" 2>/dev/null | awk '/pixelWidth/ {print $2}')
HEIGHT=$(sips -g pixelHeight "$IMAGE" 2>/dev/null | awk '/pixelHeight/ {print $2}')

if [[ -z "$WIDTH" || -z "$HEIGHT" ]]; then
    echo -e "${RED}Error: could not read dimensions for '$IMAGE'${NC}" >&2
    exit 1
fi

# If image fits within limit on both axes, return original path unchanged
if [[ "$WIDTH" -le "$LIMIT" && "$HEIGHT" -le "$LIMIT" ]]; then
    echo "$IMAGE"
    exit 0
fi

# Calculate tile grid: ceil(dim / limit)
COLS=$(( (WIDTH  + LIMIT - 1) / LIMIT ))
ROWS=$(( (HEIGHT + LIMIT - 1) / LIMIT ))

# Divide evenly — last tile may be smaller (clamped during crop)
TILE_W=$(( (WIDTH  + COLS - 1) / COLS ))
TILE_H=$(( (HEIGHT + ROWS - 1) / ROWS ))

# Temp dir keyed to image identity + tile grid (cache across calls)
BASENAME=$(basename "$IMAGE" | sed 's/\.[^.]*$//')
TILE_DIR="/tmp/claude-tiles/${BASENAME}-${WIDTH}x${HEIGHT}-${COLS}x${ROWS}"

if [[ ! -d "$TILE_DIR" ]]; then
    mkdir -p "$TILE_DIR"

    for (( row=0; row<ROWS; row++ )); do
        for (( col=0; col<COLS; col++ )); do
            OFFSET_X=$(( col * TILE_W ))
            OFFSET_Y=$(( row * TILE_H ))

            # Clamp to actual image bounds for edge tiles
            ACTUAL_W=$(( WIDTH  - OFFSET_X ))
            ACTUAL_H=$(( HEIGHT - OFFSET_Y ))
            [[ "$ACTUAL_W" -gt "$TILE_W" ]] && ACTUAL_W=$TILE_W
            [[ "$ACTUAL_H" -gt "$TILE_H" ]] && ACTUAL_H=$TILE_H

            TILE_FILE="${TILE_DIR}/tile-r${row}c${col}.png"

            # sips crop syntax: -c <height> <width> --cropOffset <y> <x>
            sips -c "$ACTUAL_H" "$ACTUAL_W" --cropOffset "$OFFSET_Y" "$OFFSET_X" \
                "$IMAGE" --out "$TILE_FILE" > /dev/null 2>&1
        done
    done
fi

# Output tile paths in reading order: row-major, left→right, top→bottom
for (( row=0; row<ROWS; row++ )); do
    for (( col=0; col<COLS; col++ )); do
        echo "${TILE_DIR}/tile-r${row}c${col}.png"
    done
done
