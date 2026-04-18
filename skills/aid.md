---
name: aid
description: aidev toolkit help. Shows available commands or details for a specific command.
argument-hint: [command]
allowed-tools:
  - "Read(~/.claude/aidev-toolkit/**)"
  - "Bash(git -C ~/.claude/aidev-toolkit rev-list HEAD..origin/main --count:*)"
model: haiku
---

# aidev toolkit Help

You are a simple manpage display skill. Output help text based on arguments. No reasoning, no planning, just output.

**Arguments received:** `$ARGUMENTS`

## Instructions

1. Read the version from `~/.claude/aidev-toolkit/VERSION` (just the first line, trimmed)
2. Read the help reference from `~/.claude/aidev-toolkit/docs/aid-help.md`
3. Find the section matching `$ARGUMENTS` and output the corresponding help text
4. Replace `{VERSION}` in the output with the version you read
5. After the output, run: `git -C ~/.claude/aidev-toolkit rev-list HEAD..origin/main --count 2>/dev/null`
   - If the result is a number greater than 0, append this line: `new version of /aidev-toolkit available. use /aid-update to feel the love ❤️`
   - If the result is 0 or empty, output nothing extra

Do not add any introduction or explanation. Find the matching section in the reference file between the <!-- OUTPUT --> and <!-- /OUTPUT --> markers and output ONLY that content as raw markdown (do not wrap it in a code block).
