---
name: docs-update
description: Update README.md and CLAUDE.md to reflect current codebase state.
argument-hint: [--deep]
allowed-tools: Read, Write, Edit, Glob, Grep
model: sonnet
---

# Documentation Update

Update documentation files to accurately reflect the current state of the codebase.

## When to Use

- User asks to "update documentation", "sync docs", or "update README"
- User wants to ensure docs match the current code
- After significant changes to the codebase structure
- When onboarding documentation is stale

## Arguments

- **(empty)**: Update top-level README.md and CLAUDE.md only
- **--deep**: Scan and update ALL README.md and CLAUDE.md files in the repo, plus run the deep audit (spec cross-reference, tech stack verification, path verification)

## Instructions

### Step 1: Determine Scope

Check `$ARGUMENTS`:

- If empty or blank: Only process `./README.md` and `./CLAUDE.md`
- If `--deep`: Use Glob to find all `**/README.md` and `**/CLAUDE.md` files; also run Steps 6–8 (deep audit) after the standard pass

### Step 2: Analyze Current State

For each documentation file:

1. **Read the existing content**
2. **Scan related code** to understand what the documentation should cover:
   - For top-level README.md: Project structure, installation, usage, commands
   - For CLAUDE.md: Development workflow, key concepts, file purposes
   - For subdirectory README.md: Purpose of that directory, key files, usage

### Step 3: Cross-check "What's Included" inventory

The README.md has a **"What's Included"** section with three tables that must stay in sync with the codebase:

1. **Skills (User-Invocable Commands)** — Glob `skills/*.md`, read each file's YAML frontmatter. Every skill that does NOT have `user-invocable: false` should appear here. Match the `name` and `description` from frontmatter. Exclude `SKILL-TEMPLATE.md`.
2. **Support Skills** — Every skill with `user-invocable: false` in its frontmatter should appear here with its "Used By" parent skill.
3. **Scripts** — Glob `scripts/*`. Every script file should have a row.

Also cross-check CLAUDE.md's **File Purposes** table to ensure scripts and key files are listed there too.

Also cross-check the **"After installation"** symlink tree diagram in README.md. Every user-invocable skill should have a `commands/` entry in the tree.

Flag and fix any:

- Skills or scripts present on disk but missing from tables or tree
- Table/tree rows referencing skills or scripts that no longer exist
- Descriptions that don't match current frontmatter

### Step 4: Identify Gaps

Compare documentation against actual codebase:

- **Missing sections**: New features, commands, or files not documented
- **Outdated information**: Changed paths, renamed files, deprecated features
- **Incorrect instructions**: Commands that no longer work, wrong file references
- **Missing examples**: New usage patterns not shown
- **Undocumented scripts**: Scripts in `scripts/` not listed in file purposes or referenced in docs

### Step 5: Update Documentation

For each file that needs updates:

1. **Preserve existing structure** where possible
2. **Add new sections** for undocumented features
3. **Update outdated sections** with current information
4. **Remove references** to deleted/renamed items
5. **Keep the same tone and style** as existing content

### Step 6: Deep Audit — Spec Cross-Reference (`--deep` only)

Skip this step if `$ARGUMENTS` does not contain `--deep`.

1. Check if `specs/README.md` exists. If not, skip (non-SDD project).
2. Read `specs/README.md` and extract the Quick Status table rows (version, name, progress, status).
3. For each spec row found in the project README:
   - Compare progress and status against the Quick Status table
   - If stale (wrong count or wrong status emoji): update the project README row and note it as updated
4. Scan `specs/` with Glob for `spec-v*.md` files. For each spec file not already in the project README's spec table, add it.
5. Track: spec_updated count, spec_added count.

### Step 7: Deep Audit — Tech Stack Verification (`--deep` only)

Skip this step if `$ARGUMENTS` does not contain `--deep`.

1. Detect manifest: check for `package.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `Podfile` (in that order, use first found).
2. If no manifest found, skip.
3. Extract key dependency versions from the manifest.
4. Scan the project README for version claims (e.g., "React 18", "Go 1.21", "Node 20").
5. For each claim where the manifest has a different version, report a flag:

   ```text
   [FLAG] README says React 18.2, package.json has 19.0
   ```

6. Do NOT auto-fix version claims — flag only.
7. Track: tech_flagged count.

### Step 8: Deep Audit — Path Verification (`--deep` only)

Skip this step if `$ARGUMENTS` does not contain `--deep`.

1. From the project README, extract:
   - Markdown link targets: `[text](path)` — keep only paths that look like local file paths (start with `./`, `../`, or a letter and contain `/`; exclude URLs starting with `http`)
   - Inline code paths that look like file references (contain `/` and a file extension)
2. For each extracted path, check if it exists on disk using Read (or Glob with exact path).
3. For each path that does not exist, report a flag:

   ```text
   [FLAG] README references scripts/foo.sh — file not found
   ```

4. Do NOT auto-fix broken paths — flag only.
5. Track: path_flagged count.

### Step 9: Report Changes

Output a summary:

```text
Documentation Update Complete
=============================

Files analyzed: X
Files updated: Y

Changes:
  README.md
    - Added: /new-command to Available Commands
    - Updated: Installation instructions
    - Removed: Reference to deleted script

  CLAUDE.md
    - Added: New skill development workflow
    - Updated: File purposes table

  (--deep only)
  skills/README.md
    - Created: New file documenting skills directory

Deep Audit Summary (--deep only):
  Specs:  N rows updated, M specs added
  Tech:   K version mismatches flagged
  Paths:  P broken paths flagged
```

## Important Notes

- **Do not create new documentation files** unless `--deep` is specified and a directory lacks a README
- **Preserve changelog entries** - never modify version history
- **Keep formatting consistent** with existing style
- **For CLAUDE.md**: Focus on what Claude Code needs to know to work effectively
- **For README.md**: Focus on what humans need to get started and use the project
- **Deep audit flags are informational** — report them, do not auto-fix (exception: spec progress rows which are unambiguous data)
