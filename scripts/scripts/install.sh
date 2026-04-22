#!/bin/bash
#
# aidev toolkit Installer
#
# Install with:
#   gh repo clone jerichoBob/aidev-toolkit-dist ~/.claude/aidev-toolkit
#   ~/.claude/aidev-toolkit/scripts/install.sh
#

set -e

# Parse command line arguments
QUIET=false
if [[ "${1:-}" == "--quiet" || "${1:-}" == "-q" ]]; then
    QUIET=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="git@github.com:jerichoBob/aidev-toolkit-dist.git"
REPO_URL_HTTPS="https://github.com/jerichoBob/aidev-toolkit-dist.git"
CLAUDE_DIR="$HOME/.claude"
TOOLKIT_DIR="$CLAUDE_DIR/aidev-toolkit"
COMMANDS_DIR="$CLAUDE_DIR/commands"
SKILLS_DIR="$CLAUDE_DIR/skills"

# Skills to symlink (user-facing commands)
SKILLS=(
    "aid.md"
    "aid-update.md"
    "aid-feedback.md"
    "docs-update.md"
    "inspect.md"
    "sdlc-plan.md"
    "arch-review.md"
    "deal-desk.md"
    "commit.md"
    "commit-push.md"
    "analyze-changes.md"
    "version-bump.md"
    "code-stats.md"
    "lint.md"
    "screenshots.md"
    "should-i-trust-it.md"
    "remember.md"
    "aws-costs.md"
    "browser-harness.md"
)

# SDD module skills (sourced from modules/sdd/skills/)
SDD_SKILLS=(
    "sdd-code.md"
    "sdd-code-phase.md"
    "sdd-code-spec.md"
    "sdd-next.md"
    "sdd-next-phase.md"
    "sdd-spec-prioritize.md"
    "sdd-spec.md"
    "sdd-spec-owner.md"
    "sdd-specs.md"
    "sdd-specs-update.md"
    "sdd-spec-tagging.md"
    "sdd-specs-doctor.md"
    "sdd-specs-archive.md"
    "sdd-init.md"
    "sdd-spec-status.md"
)

echo ""
echo -e "${BLUE}aidev toolkit Installer${NC}"
echo "======================"
echo ""

# Check for git
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git is required but not installed.${NC}"
    exit 1
fi

# Create commands and skills directories
mkdir -p "$COMMANDS_DIR"
mkdir -p "$SKILLS_DIR"

# Clean up stale aidev-toolkit symlinks (skills that were renamed/removed)
for dir in "$COMMANDS_DIR" "$SKILLS_DIR"; do
    for file in "$dir"/*.md; do
        if [ -L "$file" ]; then
            target=$(readlink "$file")
            if [[ "$target" == *"aidev-toolkit/skills/"* ]]; then
                filename=$(basename "$file")
                if [[ ! " ${SKILLS[*]} " =~ " ${filename} " ]]; then
                    rm "$file"
                    echo -e "  - Removed stale symlink: $filename"
                fi
            elif [[ "$target" == *"aidev-toolkit/modules/"* ]]; then
                filename=$(basename "$file")
                if [[ ! " ${SDD_SKILLS[*]} " =~ " ${filename} " ]]; then
                    rm "$file"
                    echo -e "  - Removed stale symlink: $filename"
                fi
            fi
        fi
    done
done

# Check if already installed
if [ -d "$TOOLKIT_DIR/.git" ]; then
    echo -e "aidev toolkit already installed. Updating..."
    cd "$TOOLKIT_DIR"

    # Fetch and show what's new
    if [ "$QUIET" = true ]; then
        git fetch origin main --quiet
    else
        git fetch origin main
    fi

    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/main)

    if [ "$LOCAL" = "$REMOTE" ]; then
        echo -e "${GREEN}Already up to date.${NC}"
    else
        echo -e "Pulling latest changes..."
        if [ "$QUIET" = true ]; then
            git pull --quiet
        else
            git pull
        fi
        echo -e "${GREEN}Updated to latest version.${NC}"

        # Show what changed
        echo ""
        echo "Recent changes:"
        git log --oneline "$LOCAL"..HEAD | head -5
    fi
else
    echo -e "Installing aidev toolkit..."

    # Try gh CLI first, then SSH, then HTTPS
    echo -n "Cloning repository... "

    # Try gh CLI first if available and authenticated
    if command -v gh &> /dev/null && gh auth status &> /dev/null 2>&1; then
        GH_ERR=$(gh repo clone jerichoBob/aidev-toolkit-dist "$TOOLKIT_DIR" -- --quiet 2>&1) && {
            echo -e "${GREEN}✓${NC} (gh)"
        } || {
            # gh failed, try SSH (BatchMode=yes prevents passphrase prompts)
            SSH_ERR=$(GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes' git clone "$REPO_URL" "$TOOLKIT_DIR" 2>&1) && {
                echo -e "${GREEN}✓${NC} (SSH)"
            } || {
                # SSH failed, try HTTPS (GIT_TERMINAL_PROMPT=0 prevents credential prompts)
                HTTPS_ERR=$(GIT_TERMINAL_PROMPT=0 git clone "$REPO_URL_HTTPS" "$TOOLKIT_DIR" 2>&1) && {
                    echo -e "${GREEN}✓${NC} (HTTPS)"
                } || {
                    echo -e "${RED}✗${NC}"
                    echo -e "${RED}Failed to clone repository.${NC}"
                    echo ""
                    echo "gh error: $GH_ERR"
                    echo "SSH error: $SSH_ERR"
                    echo "HTTPS error: $HTTPS_ERR"
                    exit 1
                }
            }
        }
    else
        # gh not available, try SSH first (BatchMode=yes prevents passphrase prompts)
        SSH_ERR=$(GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes' git clone "$REPO_URL" "$TOOLKIT_DIR" 2>&1) && {
            echo -e "${GREEN}✓${NC} (SSH)"
        } || {
            # SSH failed, try HTTPS (GIT_TERMINAL_PROMPT=0 prevents credential prompts)
            HTTPS_ERR=$(GIT_TERMINAL_PROMPT=0 git clone "$REPO_URL_HTTPS" "$TOOLKIT_DIR" 2>&1) && {
                echo -e "${GREEN}✓${NC} (HTTPS)"
            } || {
                echo -e "${RED}✗${NC}"
                echo -e "${RED}Failed to clone repository.${NC}"
                echo ""
                echo "SSH error: $SSH_ERR"
                echo "HTTPS error: $HTTPS_ERR"
                echo ""
                echo "For private repos, install GitHub CLI:"
                echo "  brew install gh && gh auth login"
                exit 1
            }
        }
    fi
fi

# Configure Claude Code permissions for /aid-update
configure_permissions() {
    local SETTINGS_FILE="$CLAUDE_DIR/settings.json"

    # Permissions needed for /aid-update to run without prompts
    local PERMS_JSON='["Bash(git -C ~/.claude/aidev-toolkit *)","Bash(~/.claude/aidev-toolkit/scripts/install.sh *)","Bash(~/.claude/aidev-toolkit/scripts/screenshots.sh *)","Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/specs-parse.sh *)"]'

    # Try jq first (cleanest JSON manipulation)
    if command -v jq &> /dev/null; then
        if [ -f "$SETTINGS_FILE" ]; then
            # Merge with existing settings
            local TEMP_FILE
            TEMP_FILE=$(mktemp)
            jq --argjson perms "$PERMS_JSON" \
               '.permissions.allow = ((.permissions.allow // []) + $perms | unique)' \
               "$SETTINGS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$SETTINGS_FILE"
        else
            # Create new settings file
            echo "$PERMS_JSON" | jq '{permissions: {allow: .}}' > "$SETTINGS_FILE"
        fi
        return 0
    fi

    # Fall back to Python if jq not available
    if command -v python3 &> /dev/null; then
        python3 << 'PYTHON_SCRIPT'
import json
import os

settings_file = os.path.expanduser("~/.claude/settings.json")
permissions_to_add = [
    "Bash(git -C ~/.claude/aidev-toolkit *)",
    "Bash(~/.claude/aidev-toolkit/scripts/install.sh *)",
    "Bash(~/.claude/aidev-toolkit/scripts/screenshots.sh *)",
    "Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/specs-parse.sh *)"
]

# Load existing settings or create new
if os.path.exists(settings_file):
    with open(settings_file) as f:
        settings = json.load(f)
else:
    settings = {}

# Ensure structure exists
if "permissions" not in settings:
    settings["permissions"] = {}
if "allow" not in settings["permissions"]:
    settings["permissions"]["allow"] = []

# Add new permissions (avoiding duplicates)
for perm in permissions_to_add:
    if perm not in settings["permissions"]["allow"]:
        settings["permissions"]["allow"].append(perm)

# Write back
with open(settings_file, "w") as f:
    json.dump(settings, f, indent=2)
PYTHON_SCRIPT
        return 0
    fi

    # Neither jq nor python3 available
    return 1
}

echo -n "Configuring Claude Code permissions... "
if configure_permissions; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}skipped${NC}"
    echo -e "  ${YELLOW}Note:${NC} Install jq or python3 to auto-configure permissions"
    echo "  You may be prompted to approve /aid-update on first use."
fi

# Create/update symlinks for skills (in both commands/ and skills/ directories)
echo -e "Linking skills to ${YELLOW}$COMMANDS_DIR${NC} and ${YELLOW}$SKILLS_DIR${NC}..."
for skill in "${SKILLS[@]}"; do
    SOURCE="$TOOLKIT_DIR/skills/$skill"

    # Create symlinks in both directories
    for TARGET_DIR in "$COMMANDS_DIR" "$SKILLS_DIR"; do
        TARGET="$TARGET_DIR/$skill"

        # Remove existing symlink or file
        if [ -L "$TARGET" ] || [ -f "$TARGET" ]; then
            rm "$TARGET"
        fi

        # Create symlink
        if [ -f "$SOURCE" ]; then
            ln -s "$SOURCE" "$TARGET"
        fi
    done

    # Report status once per skill
    if [ -f "$SOURCE" ]; then
        echo -e "  - $skill ${GREEN}✓${NC}"
    else
        echo -e "  - $skill ${RED}✗ (not found)${NC}"
    fi
done

# Create/update symlinks for SDD module skills
echo -e "Linking SDD module skills..."
for skill in "${SDD_SKILLS[@]}"; do
    SOURCE="$TOOLKIT_DIR/modules/sdd/skills/$skill"

    # Create symlinks in both directories
    for TARGET_DIR in "$COMMANDS_DIR" "$SKILLS_DIR"; do
        TARGET="$TARGET_DIR/$skill"

        # Remove existing symlink or file
        if [ -L "$TARGET" ] || [ -f "$TARGET" ]; then
            rm "$TARGET"
        fi

        # Create symlink
        if [ -f "$SOURCE" ]; then
            ln -s "$SOURCE" "$TARGET"
        fi
    done

    # Report status once per skill
    if [ -f "$SOURCE" ]; then
        echo -e "  - $skill ${GREEN}✓${NC}"
    else
        echo -e "  - $skill ${RED}✗ (not found)${NC}"
    fi
done

# Ensure SDD scripts are executable
chmod +x "$TOOLKIT_DIR/modules/sdd/scripts/specs-parse.sh" 2>/dev/null || true
chmod +x "$TOOLKIT_DIR/modules/sdd/scripts/user-email.sh" 2>/dev/null || true
chmod +x "$TOOLKIT_DIR/modules/sdd/scripts/token-tracker.sh" 2>/dev/null || true
chmod +x "$TOOLKIT_DIR/modules/sdd/scripts/stats-parse.sh" 2>/dev/null || true

# /aid-feedback uses GitHub Issues via gh CLI — no webhook or secrets needed

# Configure user email for SDD ownership (skip in quiet mode)
if [ "$QUIET" = false ]; then
    echo ""
    echo -e "Configuring user email for spec ownership..."

    EXISTING_EMAIL=$("$TOOLKIT_DIR/modules/sdd/scripts/user-email.sh" get 2>/dev/null || echo "")
    if [[ -n "$EXISTING_EMAIL" ]]; then
        echo -e "  User email: ${YELLOW}$EXISTING_EMAIL${NC} ${GREEN}✓${NC} (already configured)"
    elif [ -t 0 ]; then
        # Interactive TTY — prompt the user explicitly
        DETECTED_EMAIL=$(git config user.email 2>/dev/null || echo "")
        echo -e "  ${BLUE}Used for spec ownership tracking (/sdd-spec, /sdd-spec-owner)${NC}"
        if [[ -n "$DETECTED_EMAIL" ]]; then
            echo -e "  Detected: ${YELLOW}$DETECTED_EMAIL${NC}"
            echo -n "  Accept this email? [Y/n/custom]: "
            read -r REPLY
            case "${REPLY:-Y}" in
                [Yy]|"")
                    "$TOOLKIT_DIR/modules/sdd/scripts/user-email.sh" set "$DETECTED_EMAIL"
                    echo -e "  ${GREEN}✓${NC} Spec ownership email set to: $DETECTED_EMAIL"
                    ;;
                [Nn])
                    echo -e "  ${YELLOW}Skipped.${NC} Set later: ~/.claude/aidev-toolkit/modules/sdd/scripts/user-email.sh set <email>"
                    ;;
                *)
                    "$TOOLKIT_DIR/modules/sdd/scripts/user-email.sh" set "$REPLY"
                    echo -e "  ${GREEN}✓${NC} Spec ownership email set to: $REPLY"
                    ;;
            esac
        else
            echo -n "  Enter your email (or press Enter to skip): "
            read -r USER_INPUT
            if [[ -n "$USER_INPUT" ]]; then
                "$TOOLKIT_DIR/modules/sdd/scripts/user-email.sh" set "$USER_INPUT"
                echo -e "  ${GREEN}✓${NC} Spec ownership email set to: $USER_INPUT"
            else
                echo -e "  ${YELLOW}Skipped.${NC} Set later: ~/.claude/aidev-toolkit/modules/sdd/scripts/user-email.sh set <email>"
            fi
        fi
    else
        # Non-interactive (piped/CI) — detect and set silently
        if "$TOOLKIT_DIR/modules/sdd/scripts/user-email.sh" ensure > /dev/null 2>&1; then
            USER_EMAIL=$("$TOOLKIT_DIR/modules/sdd/scripts/user-email.sh" get)
            echo -e "  User email: ${YELLOW}$USER_EMAIL${NC} ${GREEN}✓${NC}"
        fi
    fi
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "Installed:"
echo "  Toolkit:  $TOOLKIT_DIR"
echo "  Skills:   $COMMANDS_DIR/ (symlinked)"
echo "            $SKILLS_DIR/ (symlinked)"
echo ""
echo "Available commands:"
echo -e "  ${YELLOW}/aid${NC}            Show all aidev toolkit commands"
echo -e "  ${YELLOW}/aid-update${NC}     Pull latest updates from GitHub"
echo -e "  ${YELLOW}/aid-feedback${NC}   Submit feedback or feature requests"
echo -e "  ${YELLOW}/docs-update${NC}    Update README.md and CLAUDE.md"
echo -e "  ${YELLOW}/inspect${NC}        Analyze the current codebase"
echo -e "  ${YELLOW}/arch-review${NC}    Validate architecture compliance"
echo -e "  ${YELLOW}/deal-desk${NC}      Deal qualification and risk assessment"
echo -e "  ${YELLOW}/sdlc-plan${NC}      Analyze business documents for planning"
echo -e "  ${YELLOW}/commit${NC}         Smart commit with versioning"
echo -e "  ${YELLOW}/commit-push${NC}    Commit and push"
echo -e "  ${YELLOW}/code-stats${NC}     Count lines of code"
echo -e "  ${YELLOW}/lint${NC}           Lint and fix markdown files"
echo -e "  ${YELLOW}/screenshots${NC}    Load recent screenshots into context"
echo -e "  ${YELLOW}/should-i-trust-it${NC}  Verify skill safety before installation"
echo ""
echo "Spec-Driven Development (SDD):"
echo -e "  ${YELLOW}/sdd-specs${NC}          Show specs status, staleness, progress"
echo -e "  ${YELLOW}/sdd-specs-update${NC}   Sync project with SDD infrastructure"
echo -e "  ${YELLOW}/sdd-spec${NC}           Create a new specification document"
echo -e "  ${YELLOW}/sdd-next${NC}           Show the next task to implement"
echo -e "  ${YELLOW}/sdd-next-phase${NC}     Show all tasks in the current phase"
echo -e "  ${YELLOW}/sdd-code${NC}           Implement the next single task"
echo -e "  ${YELLOW}/sdd-code-phase${NC}     Implement all tasks in current phase"
echo -e "  ${YELLOW}/sdd-code-spec${NC}      Implement all remaining tasks in a spec"
echo -e "  ${YELLOW}/sdd-spec-tagging${NC}   Commit tagging convention reference"
echo ""
echo "Get started:"
echo "  1. Open a project: cd your-project"
echo "  2. Start Claude:   claude"
echo "  3. Run:            /aid"
echo ""
echo "Optional — authenticate for verified identity:"
echo "  $TOOLKIT_DIR/scripts/auth.sh login"
echo "  (opens browser → GitHub OAuth → stores JWT)"
echo ""
