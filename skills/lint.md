---
name: lint
tier: core
description: Lint and fix markdown files using markdownlint.
model: haiku
allowed-tools: Bash(~/.claude/aidev-toolkit/scripts/lint.sh:*)
argument-hint: "[file|directory|glob]"
---

# Lint

Run the lint shell script:

```bash
bash ~/.claude/aidev-toolkit/scripts/lint.sh {{args}}
```

Report the output to the user. If there are remaining issues, list them.
