---
name: sdd-specs-archive
tier: extended
description: Move completed specs to specs/completed/ to keep the active spec list clean.
argument-hint: "[--dry-run]"
allowed-tools: Read, Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/archive-complete-specs.sh:*), Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/fix-spec-links.sh:*), AskUserQuestion
---

# SDD Specs Archive

Move all `✅ Complete` spec files from `specs/` to `specs/completed/`. Status in `specs/README.md` remains `✅ Complete` — the file move is the archive indicator, not a status change.

## When to Use

- Your `specs/` listing is cluttered with completed work
- You want `/sdd-specs` to show only active (Draft/In Progress) specs

## Arguments

- **(empty)**: Interactive — shows what will be archived, asks for confirmation
- **--dry-run**: Preview what would be archived without making any changes

## Script

The listing, the move and the link repair live in one script. **Do not re-derive any of that logic inline** (no `ls` loops, no README parsing, no hand-built `git mv`): call the script, so the run costs no tokens for logic that never changes.

```bash
A=~/.claude/aidev-toolkit/modules/sdd/scripts/archive-complete-specs.sh
```

- `$A` (list mode, default): read-only. Prints `version<TAB>name<TAB>path` for each spec to archive, then `count=N`. Exit 0 even when N is 0.
- `$A --apply`: creates `specs/completed/`, moves all files with one `git mv`, rewrites links to the moved specs, verifies them, and exits non-zero if any spec link is still unresolved.

The script acts on the git root of the current directory and reads status through `specs-parse.sh status`.

## Instructions

### Step 1: List

Run `$A`. If it prints `count=0`:

```text
No completed specs to archive.
```

Stop.

### Step 2: Show Preview

Display what will happen, from the script's rows:

```text
Specs to Archive (✅ Complete)
================================
  v1   — Core Foundation            specs/spec-v1-core-foundation.md
  v2   — Dev Workflow               specs/spec-v2-dev-workflow.md
  ...
  N specs total

Destination: specs/completed/
README: status retained as ✅ Complete (file location is the archive indicator)
Links: R would be rewritten, U would stay unresolved
```

Get R and U from the link fixer in dry-run mode (it reads the current tree, so links to files that have not moved yet are not counted; the real counts come after the move):

```bash
~/.claude/aidev-toolkit/modules/sdd/scripts/fix-spec-links.sh --dry-run fix
```

Read `rewritten=` and `unresolved=` from its `step=summary` line.

If `--dry-run`: print the preview and stop. Do NOT make any changes.

### Step 3: Confirm

Use AskUserQuestion:

```text
Archive N completed specs to specs/completed/?
```

Options:

- "Yes — archive all"
- "No — cancel"

If cancelled, stop.

### Step 4: Archive

Run `$A --apply`. Print each `step=rewrite` line it emits (file, line, old target, new target). Read `moved=` and the `rewritten=` and `unresolved=` values from its output. If it exits non-zero, list the unresolved links with file and line and do NOT claim success in Step 5.

### Step 5: Confirm

```text
Archive Complete
===============
Archived: N specs
  v1  — Core Foundation
  v2  — Dev Workflow
  ...

Files moved to: specs/completed/
Links rewritten: R
Unresolved spec links: U   (must be 0 to claim success; otherwise list them with file and line)
README: status retained as ✅ Complete for all archived specs

Run /sdd-specs to see your active specs.
Run /sdd-specs --archived to browse completed/archived specs.
```
