#!/bin/bash
#
# aidev toolkit Clean Install
#
# Removes ONLY aidev-toolkit components and reinstalls fresh.
# Does NOT touch any other ~/.claude files (CLAUDE.md, settings.json, etc.)
#
# Usage:
#   ~/.claude/aidev-toolkit/scripts/clean-install.sh
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLAUDE_DIR="$HOME/.claude"
TOOLKIT_DIR="$CLAUDE_DIR/aidev-toolkit"
COMMANDS_DIR="$CLAUDE_DIR/commands"

echo ""
echo -e "${BLUE}aidev toolkit Clean Install${NC}"
echo "=========================="
echo ""

# Check for git
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git is required but not installed.${NC}"
    exit 1
fi

# Check for gh CLI (required)
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is required but not installed.${NC}"
    echo ""
    echo "Install it and authenticate:"
    echo "  brew install gh && gh auth login"
    exit 1
fi

# Authenticate if needed (skip if already logged in)
if ! gh auth status &> /dev/null 2>&1; then
    echo -e "GitHub CLI is not authenticated. Running gh auth login..."
    gh auth login
fi

# Step 1: Clone to temp location first (so we have scripts even if old install is broken)
echo -n "Fetching fresh copy... "
TEMP_DIR=$(mktemp -d)
trap "rm -rf '$TEMP_DIR'" EXIT

if gh repo clone jerichoBob/aidev-toolkit "$TEMP_DIR/aidev-toolkit" -- --quiet 2>/dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo -e "${RED}Failed to clone repository.${NC}"
    exit 1
fi

# Step 2: Remove ONLY symlinks in commands/ that point to aidev-toolkit
# This is surgical - we check each symlink's target before removing
echo "Removing aidev-toolkit symlinks..."
if [ -d "$COMMANDS_DIR" ]; then
    shopt -s nullglob
    for file in "$COMMANDS_DIR"/*.md; do
        if [ -L "$file" ]; then
            target=$(readlink "$file")
            # Only remove if it points to aidev-toolkit
            if [[ "$target" == *"aidev-toolkit/skills/"* ]] || [[ "$target" == "../aidev-toolkit/skills/"* ]]; then
                filename=$(basename "$file")
                rm "$file"
                echo -e "  - $filename ${GREEN}✓${NC}"
            fi
        fi
    done
    shopt -u nullglob
fi

# Step 3: Remove old toolkit directory (ONLY this directory)
if [ -d "$TOOLKIT_DIR" ]; then
    echo -n "Removing old toolkit... "
    rm -rf "$TOOLKIT_DIR"
    echo -e "${GREEN}✓${NC}"
fi

# Step 4: Move fresh copy to final location
echo -n "Installing fresh copy... "
mkdir -p "$CLAUDE_DIR"
mv "$TEMP_DIR/aidev-toolkit" "$TOOLKIT_DIR"
echo -e "${GREEN}✓${NC}"

# Step 5: Run the install script to create symlinks
echo ""
"$TOOLKIT_DIR/scripts/install.sh"
