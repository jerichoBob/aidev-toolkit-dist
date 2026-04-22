#!/bin/bash
#
# aidev toolkit Uninstaller
#

set -e

# Parse command line arguments
QUIET=false
if [[ "${1:-}" == "--quiet" || "${1:-}" == "-q" ]]; then
    QUIET=true
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CLAUDE_DIR="$HOME/.claude"
TOOLKIT_DIR="$CLAUDE_DIR/aidev-toolkit"
COMMANDS_DIR="$CLAUDE_DIR/commands"

if [ "$QUIET" = false ]; then
    echo ""
    echo -e "${YELLOW}aidev toolkit Uninstaller${NC}"
    echo "========================"
    echo ""
fi

# Remove ONLY symlinks in commands/ that point to aidev-toolkit
# This is surgical - we check each symlink's target before removing
[ "$QUIET" = false ] && echo "Removing aidev-toolkit symlinks..."
if [ -d "$COMMANDS_DIR" ]; then
    for file in "$COMMANDS_DIR"/*.md; do
        [ -e "$file" ] || continue  # Handle empty glob
        if [ -L "$file" ]; then
            target=$(readlink "$file")
            # Only remove if it points to aidev-toolkit
            if [[ "$target" == *"aidev-toolkit/skills/"* ]] || [[ "$target" == "../aidev-toolkit/skills/"* ]]; then
                filename=$(basename "$file")
                rm "$file"
                [ "$QUIET" = false ] && echo -e "  - $filename ${GREEN}✓${NC}"
            fi
        fi
    done
fi

# Remove toolkit directory
if [ -d "$TOOLKIT_DIR" ]; then
    [ "$QUIET" = false ] && echo -n "Removing toolkit directory... "
    rm -rf "$TOOLKIT_DIR"
    [ "$QUIET" = false ] && echo -e "${GREEN}✓${NC}"
fi

if [ "$QUIET" = false ]; then
    echo ""
    echo -e "${GREEN}aidev toolkit uninstalled.${NC}"
    echo ""
fi
