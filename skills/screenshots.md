---
name: screenshots
description: Load recent macOS screenshots into context.
argument-hint: [N]
allowed-tools: Bash(~/.claude/aidev-toolkit/scripts/screenshots.sh *), Read(~/Desktop/**)
model: haiku
---

# Screenshots

Load the N most recent macOS screenshots from ~/Desktop into context.

## Arguments

- **No argument**: Load the most recent screenshot (default: 1)
- **N**: Load the N most recent screenshots (e.g., `/screenshots 3`)

## Instructions

1. **Run the screenshots script** to get file paths:

   ```bash
   ~/.claude/aidev-toolkit/scripts/screenshots.sh $ARGUMENTS
   ```

2. **Read each file path** returned by the script using the Read tool. Claude natively views PNG images when read.

3. **Confirm** what was loaded — e.g., "Loaded 3 screenshots" with the filenames.

## Notes

- Screenshots must match the macOS naming pattern `Screenshot*.png` on `~/Desktop`
- Files are returned most recent first
- If no screenshots are found, the script reports an error
