---
name: sdd-specs-archive
tier: extended
description: Move completed specs to specs/completed/ to keep the active spec list clean.
argument-hint: [--dry-run]
allowed-tools: Read, Edit, Bash(mkdir:*), Bash(git:*), Bash(ls:*), AskUserQuestion
model: sonnet
---

# SDD Specs Archive

Move all `✅ Complete` spec files from `specs/` to `specs/completed/` and mark them as `🗄 Archived` in `specs/README.md`.

## When to Use

- Your `specs/` listing is cluttered with completed work
- You want `/sdd-specs` to show only active (Draft/In Progress) specs

## Arguments

- **(empty)**: Interactive — shows what will be archived, asks for confirmation
- **--dry-run**: Preview what would be archived without making any changes

## Instructions

### Step 1: Read Quick Status Table

Read `specs/README.md`. Extract all rows from the Quick Status table where Status column contains `✅ Complete`.

If no complete specs found:

```
No completed specs to archive.
```

Stop.

### Step 2: Collect Spec Files

For each complete spec row (version = vN), find its file:

```bash
ls specs/spec-v{N}-*.md 2>/dev/null
```

Build a list of: version, name, file path.

### Step 3: Show Preview

Display what will happen:

```text
Specs to Archive (✅ Complete)
================================
  v1   — Core Foundation            specs/spec-v1-core-foundation.md
  v2   — Dev Workflow               specs/spec-v2-dev-workflow.md
  ...
  N specs total

Destination: specs/completed/
README: N rows will be marked 🗄 Archived
```

If `--dry-run`: print preview and stop. Do NOT make any changes.

### Step 4: Confirm

Use AskUserQuestion:

```
Archive N completed specs to specs/completed/?
```

Options:

- "Yes — archive all"
- "No — cancel"

If cancelled, stop.

### Step 5: Create specs/completed/

```bash
mkdir -p specs/completed
```

### Step 6: Move Spec Files

For each spec in the archive list:

```bash
git mv specs/spec-v{N}-*.md specs/completed/
```

If a file is not found, print a warning and continue.

### Step 7: Update Quick Status Table

For each archived spec row in `specs/README.md`, change the Status column value from `✅ Complete` to `🗄 Archived`.

Use Edit tool to make these changes.

### Step 8: Confirm

```text
Archive Complete
===============
Archived: N specs
  v1  — Core Foundation
  v2  — Dev Workflow
  ...

Files moved to: specs/completed/
README updated: N rows marked 🗄 Archived

Run /sdd-specs to see your active specs.
Run /sdd-specs --archived to browse archived specs.
```
