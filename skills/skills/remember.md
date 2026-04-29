---
name: remember
tier: core
description: Save a piece of knowledge to persistent memory (global or project scope).
argument-hint: "[--user | --project] <content>"
allowed-tools: Read, Edit, Write, AskUserQuestion
model: haiku
---

# Remember

Save a piece of knowledge to persistent memory.

## Arguments

- **`--user`**: Save directly to `~/.claude/CLAUDE.md` (global scope) — skips scope prompt
- **`--project`**: Save directly to the project's `memory/MEMORY.md` — skips scope prompt
- **`<content>`**: The knowledge, preference, or instruction to remember

## Instructions

### Step 1: Parse Arguments

Check `$ARGUMENTS`:

- If it starts with `--user`: set scope = `global`, strip `--user` from content
- If it starts with `--project`: set scope = `project`, strip `--project` from content
- If neither flag: set scope = `ask` (interactive)

Extract the content to remember (everything after the flag, or all of `$ARGUMENTS` if no flag).

### Step 2: Determine Scope

**If scope = `ask`**: Use `AskUserQuestion` to ask:

> Where should I save this?

| Option         | Description                                                              |
| -------------- | ------------------------------------------------------------------------ |
| Global         | Saved to `~/.claude/CLAUDE.md` — applies to ALL projects                 |
| Project memory | Saved to the project's `memory/MEMORY.md` — applies only to this project |

**If scope = `global`** or user chose Global: proceed to Step 3a.

**If scope = `project`** or user chose Project memory: proceed to Step 3b.

### Step 3a: Save to Global CLAUDE.md

- Read `~/.claude/CLAUDE.md`
- Append the new instruction in an appropriate existing section, or create a new section if none fits
- Use `Edit` to add it

### Step 3b: Save to Project memory/MEMORY.md

- Read the project's `memory/MEMORY.md`
- Append the new instruction organized by topic
- Use `Edit` or `Write` to add it

### Step 4: Confirm

Report in one line:

```text
Saved to [global CLAUDE.md | project memory]: "<summary>"
```
