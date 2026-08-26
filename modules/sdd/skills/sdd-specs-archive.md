---
name: sdd-specs-archive
tier: extended
description: Move completed specs to specs/completed/ to keep the active spec list clean.
argument-hint: "[--dry-run]"
allowed-tools: Read, Edit, Bash(mkdir:*), Bash(git:*), Bash(ls:*), AskUserQuestion
---

# SDD Specs Archive

Move all `✅ Complete` spec files from `specs/` to `specs/completed/`. Status in `specs/README.md` remains `✅ Complete` — the file move is the archive indicator, not a status change.

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

```text
No completed specs to archive.
```

Stop.

### Step 2: Collect Spec Files

Run a single glob pass over all spec files, instead of one `ls` per spec:

```bash
ls specs/spec-v*.md 2>/dev/null
```

Match the resulting filenames in-memory against the list of complete version numbers from Step 1 (parse each filename's `v{N}` prefix and compare against the complete-version set). Build a list of: version, name, file path — one `ls` call total, regardless of how many specs are being archived.

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
README: status retained as ✅ Complete (file location is the archive indicator)
```

If `--dry-run`: print preview and stop. Do NOT make any changes.

### Step 4: Confirm

Use AskUserQuestion:

```text
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

Move all matched files in a single `git mv` invocation instead of one call per spec:

```bash
git mv specs/spec-v1-foo.md specs/spec-v2-bar.md ... specs/completed/
```

Build the file list from the paths collected in Step 2 and pass them all to one `git mv` call (git mv accepts multiple source paths when the destination is a directory). If any file from the archive list is missing on disk, drop it from the batch, print a warning for it, and continue with the rest in the same call.

### Step 7: Confirm

```text
Archive Complete
===============
Archived: N specs
  v1  — Core Foundation
  v2  — Dev Workflow
  ...

Files moved to: specs/completed/
README: status retained as ✅ Complete for all archived specs

Run /sdd-specs to see your active specs.
Run /sdd-specs --archived to browse completed/archived specs.
```
