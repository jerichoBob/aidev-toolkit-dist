---
name: screenshots
tier: extended
description: Load recent macOS screenshots into context, auto-tiled to fit model resolution limits.
argument-hint: [N]
allowed-tools: Bash(~/.claude/aidev-toolkit/scripts/screenshots.sh *), Bash(~/.claude/aidev-toolkit/scripts/tile-image.sh *), Read(~/Desktop/**), Read(/tmp/claude-tiles/**)
---

# Screenshots

Load the N most recent macOS screenshots from ~/Desktop into context. Images larger than
the model's vision resolution limit are automatically tiled so full detail is preserved.

## Arguments

- **No argument**: Load the most recent screenshot (default: 1)
- **N**: Load the N most recent screenshots (e.g., `/screenshots 3`)

## Instructions

1. **Determine your resolution limit** based on your model family:
   - Claude Opus 4.x → `2576`
   - Claude Sonnet / Haiku (any version) → `1568`

2. **Get screenshot paths:**

   ```bash
   ~/.claude/aidev-toolkit/scripts/screenshots.sh $ARGUMENTS
   ```

3. **Tile each image** to fit within your resolution limit:

   ```bash
   ~/.claude/aidev-toolkit/scripts/tile-image.sh "<path>" --limit <LIMIT>
   ```

   This outputs one path per line:
   - If the image fits: returns the original path (single line)
   - If the image is too large: returns tile paths in row-major order (top-left → bottom-right)

4. **Read every path** output by the tiling step using the Read tool.

5. **Confirm** what was loaded. If tiles were produced, note the grid (e.g., "Loaded 1 screenshot as 2×1 tiles").

## Notes

- Screenshots must match the macOS naming pattern `Screenshot*.png` on `~/Desktop`
- Files are returned most recent first
- Tiles are cached in `/tmp/claude-tiles/` and reused within a session
- If no screenshots are found, the script reports an error
