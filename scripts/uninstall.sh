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
SKILLS_DIR="$CLAUDE_DIR/skills"

if [ "$QUIET" = false ]; then
    echo ""
    echo -e "${YELLOW}aidev toolkit Uninstaller${NC}"
    echo "========================"
    echo ""
fi

# Remove aidev-toolkit skill files from commands/ and skills/ by known name
[ "$QUIET" = false ] && echo "Removing aidev-toolkit skill files..."

SKILLS=(
    "aid.md" "aid-update.md" "aid-feedback.md" "docs-update.md" "inspect.md"
    "sdlc-plan.md" "arch-review.md" "deal-desk.md" "commit.md" "commit-push.md"
    "analyze-changes.md" "version-bump.md" "code-stats.md" "lint.md" "screenshots.md"
    "should-i-trust-it.md" "remember.md" "aws-costs.md" "browser-harness.md"
    "aid-login.md" "gmail-digest.md" "test-run.md" "test-status.md" "status-footer.md"
    "backbone-setup.md" "handoff.md"
    "sdd-code.md" "sdd-code-spec.md" "sdd-spec-prioritize.md" "sdd-spec.md"
    "sdd-spec-owner.md" "sdd-specs.md" "sdd-specs-update.md" "sdd-spec-tagging.md"
    "sdd-specs-doctor.md" "sdd-specs-archive.md" "sdd-init.md" "sdd-spec-status.md"
)

for skill in "${SKILLS[@]}"; do
    for dir in "$COMMANDS_DIR" "$SKILLS_DIR"; do
        target="$dir/$skill"
        if [ -e "$target" ] || [ -L "$target" ]; then
            rm -f "$target"
            [ "$QUIET" = false ] && echo -e "  - $skill ${GREEN}✓${NC}"
        fi
    done
done

# Remove telemetry hook from settings.json
if command -v python3 &> /dev/null; then
    [ "$QUIET" = false ] && echo -n "Removing telemetry hook... "
    python3 << 'PYTHON_SCRIPT'
import json, os

settings_file = os.path.expanduser("~/.claude/settings.json")
if not os.path.exists(settings_file):
    import sys; sys.exit(0)

with open(settings_file) as f:
    settings = json.load(f)

hooks = settings.get("hooks", {})
upss = hooks.get("UserPromptSubmit", [])
cleaned = [e for e in upss if not any("log-usage.sh" in h.get("command", "") for h in e.get("hooks", []))]

if len(cleaned) != len(upss):
    if cleaned:
        hooks["UserPromptSubmit"] = cleaned
    else:
        hooks.pop("UserPromptSubmit", None)
    settings["hooks"] = hooks
    with open(settings_file, "w") as f:
        json.dump(settings, f, indent=2)
PYTHON_SCRIPT
    [ "$QUIET" = false ] && echo -e "${GREEN}✓${NC}"
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
