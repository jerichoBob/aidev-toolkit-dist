---
name: sdd-spec-status
description: "Show phase-by-phase progress for a specific spec"
argument-hint: "<vN>"
allowed-tools: Read, Grep, Glob
---

# Spec Status

Show phase-by-phase progress for a spec.

## Step 1: Parse Version Argument

Extract the version number from `$ARGUMENTS`:

- Accept formats: `v21`, `21`, `v8.1`, `8.1`
- Strip leading `v` if present to get the bare version number
- If no argument provided, print:

  ```text
  Usage: /sdd-spec-status <version>
  Example: /sdd-spec-status v21
  ```

  Stop.

## Step 2: Locate the Spec Section in README

Read `specs/README.md`. Search for a section header matching `## v{N}:` (e.g., `## v21:`).

If not found in `specs/README.md`, also check `specs/completed/` for archived specs:

```
Glob: specs/completed/spec-v{N}-*.md  (to confirm it exists)
```

Then re-search `specs/README.md` — archived specs still have their section in README even after the file moves.

If no section found at all, print:

```text
Unknown spec: v{N}
Run /sdd-specs to see all available specs.
```

Stop.

## Step 3: Extract Spec Name and Overall Progress

From the Quick Status table row for v{N}, extract:

- **Name**: The spec display name
- **Progress**: `done/total` (e.g., `3/15`)

Also compute the overall status emoji:

- `done == total` → `✅ Complete`
- `done > 0` → `🔧 In Progress`
- `done == 0` → `⬜ Not Started`

## Step 4: Parse Phases from README Section

Within the `## v{N}:` section (stop at the next `## v` or `---`), find all phase headers matching `### Phase`:

For each phase:

1. Record the phase name (e.g., `Phase 1: Create Skill`)
2. Count `- [x]` items → `done`
3. Count `- [ ]` items → `remaining`
4. `total = done + remaining`
5. Determine phase status:
   - `done == total && total > 0` → `✅`
   - `done > 0` → `🔧`
   - `done == 0` → `⬜`

## Step 5: Render Output

```text
v{N}: {Name} — {done}/{total}

  {emoji} Phase 1: {Name} ({done}/{total})
  {emoji} Phase 2: {Name} ({done}/{total})
  ...
```

Example:

```text
v21: Feedback Ingestion & Spec Generation — 3/15

  ✅ Phase 1: Slack Integration (3/3)
  🔧 Phase 2: Feedback Analysis & Prioritization (0/4)
  ⬜ Phase 3: Spec Generation (0/3)
  ⬜ Phase 4: Documentation (0/3)
```

If no phases found in the section, print:

```text
v{N}: {Name} — {done}/{total}

  (No phases defined yet)
```
