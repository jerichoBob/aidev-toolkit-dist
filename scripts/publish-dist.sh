#!/usr/bin/env bash
# publish-dist.sh — copy clean artifacts to aidev-toolkit-dist repo
# Usage: ./scripts/publish-dist.sh [--dry-run]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$REPO_ROOT/scripts/dist-manifest.txt"
DIST_REPO="jerichoBob/aidev-toolkit-dist"
DIST_CLONE_DIR="$(mktemp -d)"
DRY_RUN=false

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

cleanup() { rm -rf "$DIST_CLONE_DIR"; }
trap cleanup EXIT

echo "aidev-toolkit dist publisher"
echo "============================"
echo "Source: $REPO_ROOT"
echo "Dest:   $DIST_REPO"
$DRY_RUN && echo "(dry run — no changes will be pushed)"
echo ""

# Clone dist repo
if ! $DRY_RUN; then
    echo "Cloning $DIST_REPO..."
    gh repo clone "$DIST_REPO" "$DIST_CLONE_DIR" -- --depth=1
else
    mkdir -p "$DIST_CLONE_DIR"
fi

# Copy allowlisted paths
echo "Copying allowlisted paths..."
while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    # Strip trailing slash — cp -r src/ into an existing dst/ creates dst/src/
    src="$REPO_ROOT/${line%/}"
    dst_parent="$DIST_CLONE_DIR/$(dirname "$line")"
    if [[ -e "$src" ]]; then
        mkdir -p "$dst_parent"
        cp -r "$src" "$dst_parent/"
        echo "  ✓ $line"
    else
        echo "  ⚠ missing: $line (skipped)"
    fi
done < "$MANIFEST"

# Generate dist-specific README.md (update repo URLs)
echo "Generating dist README.md..."
sed 's|jerichoBob/aidev-toolkit\b|jerichoBob/aidev-toolkit-dist|g' \
    "$REPO_ROOT/README.md" > "$DIST_CLONE_DIR/README.md"
echo "  ✓ README.md"

# Generate dist-specific CLAUDE.md (strip internal-only lines)
echo "Generating dist CLAUDE.md..."
grep -v "| \`PRD.md\`" "$REPO_ROOT/CLAUDE.md" \
    | grep -v "update the specs/README\.md checklist" \
    > "$DIST_CLONE_DIR/CLAUDE.md"
echo "  ✓ CLAUDE.md"

# Remove .DS_Store files
find "$DIST_CLONE_DIR" -name ".DS_Store" -delete

VERSION=$(cat "$REPO_ROOT/VERSION" | tr -d '\n')
echo ""

if $DRY_RUN; then
    echo "Dry run complete. Files that would be published:"
    find "$DIST_CLONE_DIR" -type f | sed "s|$DIST_CLONE_DIR/||" | sort
    exit 0
fi

# Commit and force-push
echo "Publishing v$VERSION to $DIST_REPO..."
cd "$DIST_CLONE_DIR"
git config user.email "actions@github.com"
git config user.name "aidev-toolkit publisher"
git add -A
git diff --cached --quiet && { echo "No changes to publish."; exit 0; }
git commit -m "chore: publish v$VERSION"
git push --force origin main

echo ""
echo "✓ Published v$VERSION to $DIST_REPO"
