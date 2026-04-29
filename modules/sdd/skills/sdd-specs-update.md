---
name: sdd-specs-update
tier: extended
description: "Sync local project with latest SDD methodology infrastructure — specs dir, template, README scaffold, CLAUDE.md methodology"
disable-model-invocation: true
argument-hint: "[--force]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/*:*)
---

# Update Specs & Methodology Infrastructure

Sync local project with latest SDD methodology.

## Step 1: Gather Data

Run these two commands first to check current state:

```bash
~/.claude/aidev-toolkit/modules/sdd/scripts/specs-parse.sh structure
```

```bash
~/.claude/aidev-toolkit/modules/sdd/scripts/specs-parse.sh status
```

Note: the status command will fail if specs/README.md doesn't exist yet — that's expected. Proceed with the structure output.

## Instructions

### Part A: Specs Directory

#### 1. Check specs directory

If the structure output shows `specs_dir: missing`:

- Create `specs/` directory
- Report: "Created specs/ directory"

#### 2. Sync TEMPLATE.md

If the structure output shows `template: missing`:

- Copy the canonical template from `~/.claude/aidev-toolkit/modules/sdd/templates/TEMPLATE.md` to `specs/TEMPLATE.md`
- Report: "Created specs/TEMPLATE.md"

If `specs/TEMPLATE.md` exists, check if it uses the current format (YAML frontmatter). If it still uses the old inline metadata format (`**Version**: vX`), update it from the canonical template.

#### 3. Sync specs/README.md

If the structure output shows `readme: missing`, create this scaffold:

```markdown
# {Project Name} - Specifications

This is the **single source of truth** for project progress. Individual spec files contain the What/Why/How; this README tracks what's done and what's next.

---

## Quick Status

| Spec | Name | Progress | Status | Owner |
| ---- | ---- | -------- | ------ | ----- |

---

## Creating New Specs

Use `/sdd-spec <description>` to create a new spec. Files are named `spec-v{N}-{short-name}.md`.

When adding tasks, add them to this README (the checklist lives here, not in the spec files).
```

If `specs/README.md` exists but is missing the Quick Status table:

- Add the table header after the intro section
- Report: "Added Quick Status table to README"

#### 4. Validate existing specs

Check the UNLINKED_SPECS section from the structure output. For each unlinked spec file, report:
"spec-v{N}-{name}.md not linked in README Quick Status table"

#### 5. Validate YAML frontmatter

For each `specs/spec-v*.md` file, check that it has valid YAML frontmatter with these required fields:

- `version` (number)
- `name` (string, kebab-case)
- `display_name` (string)
- `status` (one of: draft, in-progress, complete)
- `created` (date string)

Report any spec files missing frontmatter or required fields. If a spec file uses the old inline metadata format (`**Version**: vN` / `**Status**: X`), report it as needing migration.

### Part B: Methodology in CLAUDE.md

#### 6. Check project CLAUDE.md

Read the project's `.claude/CLAUDE.md` file (if it exists). Look for a "Development Methodology" section.

#### 7. Sync methodology

**If no CLAUDE.md exists:**

- Report: "No CLAUDE.md found. Create one with project overview and methodology."
- Do NOT auto-create

**If CLAUDE.md exists but no methodology section:**

- Append the Development Methodology section (Definition of Done, Planning Requirements, Task States)
- Report: "Added Development Methodology section to CLAUDE.md"

**If methodology section exists but differs:**

- Show differences
- If `$ARGUMENTS` contains `--force`: Update to match canonical
- Otherwise: Report differences only

### Part C: Report Summary

Display:

```text
Specs & Methodology Updated

Specs Infrastructure:
  - specs/ directory {exists | created}
  - specs/TEMPLATE.md {exists | created | updated}
  - specs/README.md {exists | created | updated}
  - N spec files validated (M linked in README)
  - YAML frontmatter: {all valid | N files need migration}

Methodology:
  - CLAUDE.md has Development Methodology section
  - or -
  - {issue description}

Run `/sdd-specs` to see current status.
```

## Idempotent

This command is safe to run multiple times. It only adds missing structure, never overwrites existing content unless `--force` is used.
