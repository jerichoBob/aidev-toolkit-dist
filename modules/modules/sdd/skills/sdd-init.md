---
name: sdd-init
description: "Scaffold specs/ directory for a new SDD project"
argument-hint: "[--force]"
allowed-tools: Read, Write, Bash(mkdir:*), Bash(ls:*), Bash(cp:*)
---

# SDD Init

Scaffold the `specs/` directory for this project so it's ready for Spec-Driven Development.

## Step 1: Check for --force

Parse `$ARGUMENTS`:

- If `--force` is present, set `FORCE=true`
- Otherwise, `FORCE=false`

## Step 2: Ensure specs/ exists

```bash
mkdir -p specs
```

## Step 3: Handle specs/TEMPLATE.md

Check whether `specs/TEMPLATE.md` exists:

```bash
ls specs/TEMPLATE.md 2>/dev/null
```

- **If it exists**: skip silently (safe to re-run)
- **If it does not exist**: copy from the toolkit:

```bash
cp ~/.claude/aidev-toolkit/modules/sdd/templates/TEMPLATE.md specs/TEMPLATE.md
```

Report: `✓ Created specs/TEMPLATE.md`

## Step 4: Handle specs/README.md

Check whether `specs/README.md` exists and has content:

```bash
ls specs/README.md 2>/dev/null
```

**Case A — File does not exist:**

Create `specs/README.md` with the standard Quick Status table header and an Architecture section placeholder:

```markdown
# Specs — {Project Name}

> Single source of truth for all specifications. Parsed by `specs-parse.sh`.

---

## Quick Status

| Spec | Name | Progress | Status | Owner |
| ---- | ---- | -------- | ------ | ----- |

---

## Architecture

> Document key architecture decisions and constraints here.
```

Use the current directory name as `{Project Name}` (run `basename $(pwd)` to get it).

Report: `✓ Created specs/README.md`

**Case B — File exists, FORCE=false:**

Print warning and skip:

```
⚠  specs/README.md already exists — skipping to avoid data loss.
   Run /sdd-init --force to overwrite.
```

**Case C — File exists, FORCE=true:**

Print what will be overwritten:

```
Overwriting specs/README.md (--force)
```

Then overwrite with the standard scaffold (same as Case A).

Report: `✓ Overwrote specs/README.md`

## Step 5: Report Summary

Print a summary of what happened:

```text
SDD initialized
===============
  specs/TEMPLATE.md  — {created | already existed}
  specs/README.md    — {created | skipped (already exists) | overwritten}

Next step: /sdd-spec <description>
  Example: /sdd-spec add user authentication with OAuth
```

If both files were skipped (project already initialized), end with:

```text
Project already initialized. Run /sdd-specs to check status.
```
