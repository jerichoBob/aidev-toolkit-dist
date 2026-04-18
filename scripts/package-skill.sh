#!/bin/bash
# Package an aidev toolkit skill for Claude Desktop
#
# Usage: ./scripts/package-skill.sh <skill-name>
# Output: dist/<skill-name>-<version>.skill
#         dist/<skill-name>-<version>-templates.md (if templates exist)
#
# Creates:
# - .skill package with SKILL.md (instructions + version/build metadata)
# - Single templates.md file for upload to Claude Desktop project files

set -e

SKILL_NAME="${1:-}"
if [[ -z "$SKILL_NAME" ]]; then
    echo "Usage: $0 <skill-name>"
    echo "Example: $0 deal-desk"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$REPO_DIR/skills"
TEMPLATES_DIR="$REPO_DIR/templates"
DIST_DIR="$REPO_DIR/dist"

# Extract version from README.md (skip blank line after header)
VERSION=$(grep -A2 "^## Version" "$REPO_DIR/README.md" | grep -v "^##" | grep -v "^$" | tr -d '[:space:]')
BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

SOURCE_FILE="$SKILLS_DIR/${SKILL_NAME}.md"
if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Error: Skill not found: $SOURCE_FILE"
    exit 1
fi

# Create dist directory
mkdir -p "$DIST_DIR"

# Create temp directory with skill structure
TEMP_DIR=$(mktemp -d)
SKILL_DIR="$TEMP_DIR/$SKILL_NAME"
mkdir -p "$SKILL_DIR"

# Copy skill file as SKILL.md, filtering unsupported frontmatter keys,
# injecting version/build metadata, and updating template path references
# Claude Desktop only allows: name, description, license, allowed-tools, compatibility, metadata
awk -v skill_name="$SKILL_NAME" -v version="$VERSION" -v build="$BUILD_TIMESTAMP" '
BEGIN { in_frontmatter = 0; frontmatter_done = 0 }
/^---$/ && !in_frontmatter && !frontmatter_done { in_frontmatter = 1; print; next }
/^---$/ && in_frontmatter {
    # Inject version and build as metadata (allowed by Claude Desktop)
    print "metadata:"
    print "  version: " version
    print "  build: " build
    in_frontmatter = 0
    frontmatter_done = 1
    print
    next
}
in_frontmatter {
    if (/^(name|description|license|allowed-tools|compatibility|metadata):/) {
        print
    }
    next
}
{
    # Update template path references to point to project files
    # Templates should be uploaded to Claude Desktop project separately
    gsub(/`~\/\.claude\/aidev-toolkit\/templates\/[^\/]+\//, "`templates/")
    gsub(/\$HOME\/\.claude\/aidev-toolkit\/templates\/[^`"]+/, "templates")
    gsub(/aidev-toolkit\/templates\/[^\/]+\//, "templates/")
    gsub(/`\$TEMPLATE_DIR\//, "`templates/pdf/")
    gsub(/"\$TEMPLATE_DIR\//, "\"templates/pdf/")
    print
}
' "$SOURCE_FILE" > "$SKILL_DIR/SKILL.md"

echo "Version: $VERSION"
echo "Build: $BUILD_TIMESTAMP"

# Create .skill zip (must contain folder at root)
# Filename includes version for tracking: deal-desk-0.16.1.skill
OUTPUT_FILE="$DIST_DIR/${SKILL_NAME}-${VERSION}.skill"
(cd "$TEMP_DIR" && zip -r "$OUTPUT_FILE" "$SKILL_NAME")

# Create single templates.md file if templates exist for this skill
SKILL_TEMPLATES="$TEMPLATES_DIR/$SKILL_NAME"
TEMPLATES_OUTPUT=""
if [[ -d "$SKILL_TEMPLATES" ]]; then
    TEMPLATES_OUTPUT="$DIST_DIR/${SKILL_NAME}-${VERSION}-templates.md"

    # Start with header
    cat > "$TEMPLATES_OUTPUT" << 'HEADER'
# Deal-Desk Templates

This file contains all templates for the deal-desk skill. Reference sections by their header path.

---

HEADER

    # Add skill-specific templates
    find "$SKILL_TEMPLATES" -type f \( -name "*.md" -o -name "*.typ" \) | sort | while read -r file; do
        # Get relative path from templates dir
        rel_path="${file#$TEMPLATES_DIR/}"
        # Remove skill name prefix to get template path (e.g., simple/00-deal-summary.md)
        template_path="${rel_path#$SKILL_NAME/}"

        echo "## Template: $template_path" >> "$TEMPLATES_OUTPUT"
        echo "" >> "$TEMPLATES_OUTPUT"

        if [[ "$file" == *.typ ]]; then
            echo '```typst' >> "$TEMPLATES_OUTPUT"
            cat "$file" >> "$TEMPLATES_OUTPUT"
            echo '```' >> "$TEMPLATES_OUTPUT"
        else
            cat "$file" >> "$TEMPLATES_OUTPUT"
        fi

        echo "" >> "$TEMPLATES_OUTPUT"
        echo "---" >> "$TEMPLATES_OUTPUT"
        echo "" >> "$TEMPLATES_OUTPUT"
    done

    # Add shared PDF templates if they exist
    PDF_TEMPLATES="$TEMPLATES_DIR/pdf"
    if [[ -d "$PDF_TEMPLATES" ]]; then
        find "$PDF_TEMPLATES" -type f \( -name "*.md" -o -name "*.typ" \) | sort | while read -r file; do
            rel_path="${file#$TEMPLATES_DIR/}"

            echo "## Template: $rel_path" >> "$TEMPLATES_OUTPUT"
            echo "" >> "$TEMPLATES_OUTPUT"

            if [[ "$file" == *.typ ]]; then
                echo '```typst' >> "$TEMPLATES_OUTPUT"
                cat "$file" >> "$TEMPLATES_OUTPUT"
                echo '```' >> "$TEMPLATES_OUTPUT"
            else
                cat "$file" >> "$TEMPLATES_OUTPUT"
            fi

            echo "" >> "$TEMPLATES_OUTPUT"
            echo "---" >> "$TEMPLATES_OUTPUT"
            echo "" >> "$TEMPLATES_OUTPUT"
        done
    fi
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "Created: $OUTPUT_FILE"
echo "Size: $(du -h "$OUTPUT_FILE" | cut -f1)"
if [[ -n "$TEMPLATES_OUTPUT" ]]; then
    echo ""
    echo "Created: $TEMPLATES_OUTPUT"
    echo "Size: $(du -h "$TEMPLATES_OUTPUT" | cut -f1)"
    echo ""
    echo "Setup in Claude Desktop:"
    echo "  1. Upload the .skill file"
    echo "  2. Upload the templates.md to project files"
fi
