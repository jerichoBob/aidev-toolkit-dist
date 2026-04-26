---
name: sdd-specs
description: "Quick specs status from README, or deep scan with --deep/--verify/--stats flags"
disable-model-invocation: false
argument-hint: "[--deep] [--verify] [--stats] [--all] [--archived]"
allowed-tools: Read, Grep, Glob, Edit, Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/*:*)
---

# Specs Status

## Step 1: Route by Arguments

Check `$ARGUMENTS` to determine which path to take:

- If `$ARGUMENTS` contains `--stats`: go to **Stats Path** below
- If `$ARGUMENTS` contains `--deep`: go to **Deep Scan Path** below
- If `$ARGUMENTS` contains `--verify`: go to **Deep Scan Path** below (--verify implies --deep)
- If `$ARGUMENTS` contains `--archived`: go to **Fast Path** with archived-only filter
- If `$ARGUMENTS` contains `--all`: go to **Fast Path** with no filter (show everything)
- Otherwise (empty or unrecognized): go to **Fast Path** with active-only filter (default)

---

## Fast Path (default — no args)

This is the default. It is FAST — reads only `specs/README.md`, nothing else.

### Step F1: Read README

Read `specs/README.md`. Extract the Quick Status table (the markdown table under `## Quick Status`).

### Step F2: Filter Rows

Apply filter based on the active flag:

- **Default (no flag)**: Exclude rows where Status contains `✅ Complete`, `🗄 Archived`, or `⏸ Deferred`, and rows where Progress matches `→ v\d+` (consolidated). Show only actionable work (Draft, In Progress, Blocked).
- **`--all`**: Split into three groups — active rows first, deferred rows second, archived/complete rows third (see Step F4)
- **`--archived`**: Include ONLY rows where Status contains `🗄 Archived` or `✅ Complete`

### Step F3: Compute Summary

**CRITICAL: Compute totals from the post-filter row set only. Do NOT carry forward any previously computed totals, and do NOT sum rows before filtering is complete.**

**Default (active-only) view:**

1. Take the row set produced by Step F2
2. Count rows by status: `in_progress` (🔧) and `draft` (✏️)
3. For each row, parse Progress (`done/total`); skip non-numeric (`∞`, `→ vN`)
4. Sum all `total` values → total_tasks; sum all `done` values → total_done
5. remaining = total_tasks − total_done
6. Summary = `{total_specs} active specs ({in_progress} in progress · {draft} draft) | {remaining} tasks remaining`

**`--all` view:**

1. Include rows from active, deferred, and completed tables
2. Compute per-section counts separately for the summary line

### Step F4: Display

Before displaying, strip markdown links from the Name column. For any cell with format `[Display Text](url)`, extract only the Display Text using the pattern `\[([^\]]+)\]\([^)]+\)`. Leave plain text cells unchanged.

Output the cleaned table and summary. Include ALL columns present in the README table (e.g. Owner, Blocker). For blocked rows, the Blocker cell is the most important column for actionability — always show it. If a Blocker cell is long, truncate to ~80 chars with `…`.

**Default format:**

```text
{Project Name} — Specs Overview

| Spec | Name                    | Progress | Status         | Owner |
|------|-------------------------|----------|----------------|-------|
| v18  | Adaptive Cost Mgmt      | 0/25     | ✏️ Draft       | —     |
| v19  | Skill Tuning            | 5/17     | 🔧 In Progress | —     |

---
Summary: N active specs (X in progress · Y draft) | Z tasks remaining
(Showing active specs only. Use --all to include deferred and archived, --archived to browse archive.)
```

**`--all` format — three tables: active, deferred, completed:**

For the completed table, display `🗄 Archived` rows as `✅ Complete` in the Status column (replace the archive icon with the green check — these are done, show them as done).

Deferred rows are those with Status `⏸ Deferred` or Progress matching `→ v\d+` (consolidated). For deferred task totals: skip `∞` and `→ vN` values; treat them as 0/0.

```text
{Project Name} — Specs Overview

| Spec | Name                    | Progress | Status         | Owner |
|------|-------------------------|----------|----------------|-------|
| v18  | Adaptive Cost Mgmt      | 0/25     | ✏️ Draft       | —     |
| v22  | Simplify /aid-feedback  | 14/15    | 🔧 In Progress | Bob   |

### Deferred

| Spec | Name                    | Progress | Status       | Owner |
|------|-------------------------|----------|--------------|-------|
| v30  | Fathom Meeting Explorer | 0/12     | ⏸ Deferred  | —     |

### Completed

| Spec | Name                    | Progress | Status      | Owner |
|------|-------------------------|----------|-------------|-------|
| v1   | Core Foundation         | 7/7      | ✅ Complete | —     |
| v2   | Dev Workflow            | 8/8      | ✅ Complete | —     |

---
Summary: Active: A/B tasks (X%) | Completed: C/D | Deferred: N specs
```

**`--archived` format:**

```text
(Showing archived specs only. Use --all to include active specs.)
```

**STOP here.** Do not run any bash commands or do any scanning.

---

## Stats Path (--stats)

Display token usage metrics and cost estimates for specs with metadata.

### Step S1: Extract Token Metadata

Run the stats aggregation command:

```bash
~/.claude/aidev-toolkit/modules/sdd/scripts/stats-parse.sh aggregate-all
```

This outputs: `version in_tokens out_tokens cache_tokens duration_seconds task_count` (TSV)

### Step S2: Format and Display Enhanced Table

Read `specs/README.md` and extract the Quick Status table. For each spec:

1. Look up aggregated stats from Step S1 output
2. Format token counts with thousands separators: `12345` → `12,345`
3. Format duration: `3661` seconds → `1:01:01` (HH:MM:SS)
4. If no metadata exists for a spec, show "—" in token columns
5. Before displaying, strip markdown links from Name column (same as Fast Path)

Output the enhanced table with these columns:

- Spec
- Name
- Progress
- Status
- Owner (if present in README)
- **In Tokens** (new column)
- **Out Tokens** (new column)
- **Cache** (new column, optional)
- **Duration** (new column)

Example format:

```text
{Project Name} — Token Usage Overview

| Spec | Name                      | Progress | Status     | Owner | In Tokens | Out Tokens | Cache    | Duration |
|------|---------------------------|----------|------------|-------|-----------|------------|----------|----------|
| v14  | SDD Plain Text Output     | 6/6      | ✅ Complete | —     | 10,755    | 6,231      | 23,199   | 0:45:20  |
| v15  | Spec Owner & Checkout     | 0/19     | ✏️ Draft   | —     | —         | —          | —        | —        |

---
Summary: 6/25 tasks complete (24%)
```

### Step S3: Display Cost Summary

After the table, calculate and display a cost summary:

```text
---
Token Usage Summary (specs with metadata):

Tokens Used:
  Input:   {formatted_total_in} tokens
  Output:  {formatted_total_out} tokens
  Cache:   {formatted_total_cache} tokens
  Total:   {formatted_total_all} tokens

Estimated Cost: ${cost_usd} (based on Anthropic pricing)
  Input:  ${cost_in}  @ $3.00/MTok
  Output: ${cost_out} @ $15.00/MTok
  Cache:  ${cost_cache} @ $0.30/MTok

Time Tracked: {formatted_total_duration} hours (all specs)
Tasks Tracked: {task_count} of {total_tasks} (with metadata)
Average per Task: {avg_tokens_per_task} tokens
Average per Spec: {avg_tokens_per_spec} tokens
```

To calculate costs:

- Input cost = (total_input_tokens / 1,000,000) × $3.00
- Output cost = (total_output_tokens / 1,000,000) × $15.00
- Cache cost = (total_cache_tokens / 1,000,000) × $0.30
- Total cost = input_cost + output_cost + cache_cost

Format durations as HH:MM.

---

## Deep Scan Path (--deep or --verify)

Full scan with staleness detection, README validation, and optional code verification.

### Step D1: Gather Data

Run these commands to get current project state:

```bash
~/.claude/aidev-toolkit/modules/sdd/scripts/specs-parse.sh status
```

```bash
~/.claude/aidev-toolkit/modules/sdd/scripts/specs-parse.sh staleness
```

Also read the Quick Status section from `specs/README.md`.

### Step D2: Display Status Table

Before displaying, strip markdown links from the Name column. For any cell with format `[Display Text](url)`, extract only the Display Text using the pattern `\[([^\]]+)\]\([^)]+\)`. Leave plain text cells unchanged.

Display the cleaned Quick Status table from `specs/README.md` — it already contains emoji status indicators and progress counts.

Use the `specs-parse.sh status` TSV output to compute a summary line: total tasks completed vs total tasks.

### Step D3: Staleness Report

Using the staleness output, report:

- If STALE_FILES shows `(none)`: README is current
- Otherwise: list which spec files are newer than README — potential drift

### Step D4: Auto-Update README (if needed)

If the Quick Status table in `specs/README.md` has incorrect progress numbers or wrong status:

1. Show what's wrong (expected vs actual)
2. Update the table with correct counts and emoji status:
   - `✅ Complete` — all tasks done (done == total)
   - `🔧 In Progress` — some tasks done (0 < done < total)
   - `✏️ Draft` — no tasks done but tasks exist (done == 0, total > 0)
   - `⬜ Empty` — no tasks defined (total == 0)
3. Report that README was updated

### Step D5: Code Verification (only if --verify)

When `$ARGUMENTS` contains `--verify` or `verify`:

**CRITICAL: Verify BOTH directions** - README ahead of code (false positives) AND code ahead of README (false negatives).

For EVERY `[x]` (completed) and `[ ]` (pending) task in the README:

1. Parse the task description to identify verifiable artifacts (files, functions, flags, scripts)
2. Search codebase for evidence using Grep, Glob, Read, or Bash
3. Categorize findings:
   - `[x]` marked done AND found in code → ✅ correct
   - `[x]` marked done but NOT found → ❌ **FALSE POSITIVE** (README ahead of code)
   - `[ ]` marked pending but FOUND in code → ⚠️ **FALSE NEGATIVE** (README behind code - UPDATE CHECKBOX)
   - `[ ]` marked pending and not found → ✅ correct (truly pending)

**Verification Strategy:**

- **Complete specs (done == total)**: Spot-check 2-3 key artifacts per spec to ensure they exist
- **In Progress specs (0 < done < total)**: Verify ALL completed tasks exist, sample 2-3 pending tasks
- **Draft specs (done == 0)**: **IMPORTANT** - Check if major artifacts exist despite all tasks being unchecked. Draft specs often have implementation that wasn't marked complete. Look for:
  - Scripts mentioned in spec file names
  - Flags mentioned in task descriptions
  - Files matching spec patterns

**Report Format:**

After verification, report findings by spec:

```text
v15: 2 false positives found (tasks marked done, code missing)
  - Task 3: "Create .user-email mechanism" - no code found
  - Task 8: "Add checkout logic" - no implementation

v17: 24 false negatives found (code exists, tasks not checked)
  - Phase 1-6: ALL tasks implemented but unchecked
  - Found: token-tracker.sh, stats-parse.sh, --stats flag

v14: ✅ Verified (spot-checked 3 artifacts, all present)
```

If false negatives found, offer to update checkboxes automatically.
