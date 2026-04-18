---
name: sdd-specs-doctor
description: "Migrate spec files from old format (inline metadata, checkboxes) to current YAML frontmatter format"
disable-model-invocation: true
argument-hint: "[--dry-run]"
allowed-tools: Read, Write, Edit, Glob, Grep
---

# Specs Doctor — Migrate Spec Files to Current Format

Scan `specs/spec-v*.md` files and migrate them from the old format to the current YAML frontmatter format.

## Arguments

- `--dry-run`: Report what would change without modifying any files
- (no argument): Detect and fix all issues

## Instructions

### Step 1: Scan Spec Files

Find all spec files:

```bash
ls specs/spec-v*.md 2>/dev/null
```

For each spec file, detect these old-format indicators:

#### Indicator 1: Inline Metadata (instead of YAML frontmatter)

Check if the file starts with `---` (YAML frontmatter). If NOT, look for lines matching:

- `**Version**: v{N}`
- `**Status**: {Draft | In Progress | Complete}`
- `**Created**: {date}`

These indicate old-format inline metadata that needs to be converted to YAML frontmatter.

#### Indicator 2: Checkboxes in Spec File

Search for `- [ ]` or `- [x]` in the file body (not in code blocks). Spec files should use plain bullets — checkboxes belong only in `specs/README.md`.

#### Indicator 3: Old Heading Name

Search for `## How (Implementation)` — should be `## How (Approach)`.

### Step 2: Report Findings

Display a summary of what was detected:

```text
Specs Doctor — Scan Results

File                              Frontmatter  Checkboxes  Old Heading
specs/spec-v1-core-foundation.md  ✅ YAML       ⚠️ 14 found  ✅ OK
specs/spec-v2-dev-workflow.md     ⚠️ inline     ⚠️ 12 found  ⚠️ found
specs/spec-v3-deal-desk.md        ✅ YAML       ✅ none       ✅ OK

Summary: 2 files need migration, 1 file already current
```

If `$ARGUMENTS` contains `--dry-run`, stop here. Show what would be changed but don't modify files.

### Step 3: Migrate Each File

For each file that needs migration, apply these transformations in order:

#### 3a: Convert Inline Metadata to YAML Frontmatter

If the file has inline metadata instead of YAML frontmatter:

1. Extract values from inline lines:
   - `**Version**: v{N}` → `version: {N}` (number, not string)
   - `**Status**: {value}` → `status: {value lowercase}` (draft, in-progress, or complete)
   - `**Created**: {date}` → `created: {date}`

2. Derive additional fields:
   - `name`: Extract from filename. `spec-v3-deal-desk-planning.md` → `deal-desk-planning`
   - `display_name`: Extract from the `# Heading` on the first content line. `# Deal Desk & Planning` → `"Deal Desk & Planning"`
   - `depends_on`: Default to `[]`
   - `tags`: Default to `[]`

3. Remove the inline metadata lines and the `---` separator that follows them.

4. Insert YAML frontmatter block at the top of the file:

```yaml
---
version: 3
name: deal-desk-planning
display_name: "Deal Desk & Planning"
status: complete
created: 2026-02-11
depends_on: []
tags: []
---
```

#### 3b: Strip Checkboxes

Replace all checkbox bullets with plain bullets:

- `- [x] Task description` → `- Task description`
- `- [ ] Task description` → `- Task description`

Only strip in the file body — do NOT modify code blocks (``` fenced sections).

#### 3c: Rename Heading

Replace `## How (Implementation)` with `## How (Approach)`.

### Step 4: Report Summary

After all migrations:

```text
Specs Doctor — Migration Complete

Migrated:
  specs/spec-v1-core-foundation.md — frontmatter added, 14 checkboxes stripped
  specs/spec-v2-dev-workflow.md — frontmatter added, 12 checkboxes stripped, heading renamed

Already current:
  specs/spec-v3-deal-desk.md

Summary: 2 files migrated, 1 already current, 0 errors

Run `/sdd-specs-update` to validate the results.
```

## Idempotent

This command is safe to run multiple times:

- If YAML frontmatter exists → skip frontmatter conversion
- If no checkboxes found → skip checkbox stripping
- If heading is already "How (Approach)" → skip rename
- Running on fully-migrated files produces "0 files migrated, N already current"

## Important

- **Never modify `specs/README.md`** — it's the progress tracker and should keep its checkboxes
- **Never modify `specs/TEMPLATE.md`** — that's handled by `/sdd-specs-update`
- **Preserve all content** — only format/metadata changes, never alter design content
- **Back up nothing** — git provides the safety net; users can `git diff` or `git checkout` if needed
