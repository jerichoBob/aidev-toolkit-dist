---
name: lint
tier: core
description: Lint and fix markdown files using markdownlint.
model: haiku
allowed-tools: Bash(~/.claude/aidev-toolkit/scripts/lint.sh:*), Bash(markdownlint:*), Read, Edit
argument-hint: "[file|directory|glob]"
---

# Lint

## Step 1: Run the lint script

```bash
bash ~/.claude/aidev-toolkit/scripts/lint.sh {{args}}
```

Report the output to the user. If there are no remaining issues, you are done — report success.

## Step 2: Manual fixes (if issues remain)

If the lint script reports "Some issues require manual fixes", fix them using the Edit tool.

### MD040 Fix Pattern — CRITICAL

When fixing fenced-code-language (MD040) errors, the language specifier **must** go inline on the same line as the opening fence. Never place it on a separate line below the opening fence.

**Correct:**

````text
```bash
some code
```
````

**Incorrect (do NOT do this):**

````text
```
bash
some code
```
````

This rule applies to all language specifiers: `bash`, `json`, `yaml`, `plaintext`, `python`, `typescript`, `javascript`, `text`, etc.

## Step 3: Verify fixes (self-verification loop)

After applying any Edit tool fixes, re-run the lint script to confirm the fixes are clean:

```bash
bash ~/.claude/aidev-toolkit/scripts/lint.sh {{args}}
```

- If clean: report success. You are done.
- If errors remain: apply further fixes and re-run. Repeat up to **3 total attempts**.
- After 3 attempts with errors still present: report the final error state clearly to the user. Do **not** claim success.
