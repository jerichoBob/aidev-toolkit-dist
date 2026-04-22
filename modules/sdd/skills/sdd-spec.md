---
name: sdd-spec
description: "Create a new specification document from a user prompt"
argument-hint: "[-p|--prioritize] <description>"
allowed-tools: Read, Write, Edit, Glob, Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/*:*), AskUserQuestion
---

# Create a New Spec

Create a new specification document based on the user's prompt: $ARGUMENTS

## Step 0: Routing

First check if `$ARGUMENTS` is empty or only contains flags (no description):

- **If empty or no description**: Follow **Checkout Flow** (resume or claim a spec)
- **If description provided**: Check for prioritize flag:
  - **If `-p` or `--prioritize` present**: Follow **Prioritization Flow**
  - **Otherwise**: Follow **Normal Append Flow**

## Step 0.5: Verify User Email

Before proceeding, ensure user email is configured:

```bash
~/.claude/aidev-toolkit/modules/sdd/scripts/user-email.sh ensure
```

This will prompt for email if not already set. The email is stored in `~/.claude/aidev-toolkit/.user-email` and used for spec ownership tracking.

## Step 0.6: Load Coding Rules (if present)

Check for a `coding-rules.md` file. Resolution order: project root first, then `.claude/`, then none.

```bash
if [ -f coding-rules.md ]; then cat coding-rules.md
elif [ -f .claude/coding-rules.md ]; then cat .claude/coding-rules.md
fi
```

- If found: read it and store the rules. Report: "Loaded coding rules from {path}"
- If not found: proceed with no rules (no change in behavior)

The format is plain markdown — each rule is a bullet or numbered item. No special syntax required.

---

## Checkout Flow

Use this flow when user runs `/sdd-spec` with no description.

### Step C1: Get User Email

```bash
USER_EMAIL=$(~/.claude/aidev-toolkit/modules/sdd/scripts/user-email.sh get)
```

### Step C2: Check for Owned Unfinished Specs

Read `specs/README.md` Quick Status table. Find all specs where:

- Status is `🔧 In Progress` or `✏️ Draft`
- Owner column matches `$USER_EMAIL`

If multiple owned unfinished specs exist, prioritize the first `In Progress` one, then first `Draft` one.

### Step C3: Prompt to Resume (if owned spec found)

If an owned unfinished spec exists, use AskUserQuestion to ask:

```text
You have an unfinished spec:
  v{N}: {Name} — {done}/{total} tasks complete

Continue working on this spec?
```

Options:

- "Yes — Resume v{N}" (recommended)
- "No — Find a different spec"

If user selects "Yes":

- Report: "Resuming v{N}: {Name}"
- Suggest: "Run `/sdd-next` to see the next task"
- Exit the skill (no need to claim - already owned)

If user selects "No", continue to Step C4.

### Step C4: Find Unblocked Unowned Spec

Read `specs/README.md` Quick Status table. Find the first spec where:

- Status is `🔧 In Progress` or `✏️ Draft` (has uncompleted work)
- Owner is `—` (unowned)

**Sort order**: Prioritize `In Progress` specs before `Draft` specs, then by version number (v1 before v2, etc.)

### Step C5: Prompt to Claim

If an unblocked unowned spec exists, use AskUserQuestion to ask:

```text
Available spec to work on:
  v{N}: {Name} — {done}/{total} tasks complete

Claim this spec?
```

Options:

- "Yes — Claim v{N}" (recommended)
- "No — Don't claim"

If user selects "Yes", go to Step C6.

If user selects "No":

- Report: "No spec claimed. To create a new spec, run: `/sdd-spec <description>`"
- Exit the skill

### Step C6: Update Owner in README

Update the Quick Status table in `specs/README.md`:

- Find the row for v{N}
- Replace the Owner column value from `—` to `$USER_EMAIL`

Report:

- "Claimed v{N}: {Name}"
- "Owner set to: {USER_EMAIL}"
- Suggest: "Run `/sdd-next` to see the next task"

### Step C7: Handle No Available Specs

If no unfinished specs exist (all complete or empty):

- Report: "All specs are complete! 🎉"
- Suggest: "To create a new spec, run: `/sdd-spec <description>`"
- Exit the skill

---

## Normal Append Flow

## Step 1: Gather Data

Run this command first to see existing specs:

```bash
~/.claude/aidev-toolkit/modules/sdd/scripts/specs-parse.sh spec-list
```

## Step 2: Create the Spec

1. **Determine the version number**: Using the spec-list output, find the highest version number and increment by 1. If no specs exist, start at v1.

2. **Find the template**: Read `specs/TEMPLATE.md` if it exists. If not, use the canonical template at `~/.claude/aidev-toolkit/modules/sdd/templates/TEMPLATE.md`.

3. **Create a short name**: Based on the user's prompt (`$ARGUMENTS`), create a kebab-case name (e.g., "user-authentication", "dark-mode"). The filename should be: `spec-v{N}-{short-name}.md`

4. **Draft the spec**:
   - Parse `$ARGUMENTS` to identify the WHY (problem/goal), WHAT (requirements), and HOW (approach)
   - Fill in the template with reasonable defaults
   - **Use YAML frontmatter** for metadata (version, name, display_name, status, created, depends_on, tags)
   - Set `status: draft` in frontmatter
   - Set `created:` to today's date
   - **Do NOT use checkboxes** (`- [ ]` / `- [x]`) anywhere in the spec file — use plain bullets instead
   - The spec file is a **design document**, not a progress tracker

4.5. **Populate the Security section** (always required):

After drafting the spec content, fill in the `## Security` section based on the description context. Do not leave it as template boilerplate. Apply this logic:

- **User-facing feature** (involves users, UI, API endpoints, data access): Set AuthN to "Required". Choose an appropriate default mechanism based on project context (JWT bearer token if API-based, session cookie if web app). Note roles/permissions based on what the feature does. Set audit logging for all state-mutating operations.
- **Internal/background process** (cron job, data pipeline, worker): Note service identity requirements (e.g., "service account with read access to X"). Set AuthZ to the minimum privilege needed. Audit log job start, end, and any failures.
- **Infrastructure/tooling** (CLI tool, script, dev tool with no user-facing surface): State "Not applicable — internal tool only" with rationale for each subsection. At minimum one subsection must be non-"Not applicable" unless all three genuinely don't apply (which is rare).

After filling in the Security section, confirm it was populated in the report (Step 3 / Step 8).

**Boilerplate detection**: If the Security section still contains placeholder text like `{e.g.,` or `(e.g.,` or subsection headers with no content below them, emit a warning:

```text
⚠️  Security section may still contain template placeholders. Review before committing.
```

4.6. **Check tasks against coding rules** (only if rules were loaded in Step 0.6):

- For each task in the draft spec, check whether it would violate any loaded rule
- Example: if a rule says "never use mocks, vi.mock, jest.mock, sinon stubs", any task like "write mock-based tests for X" or "stub out Y with vi.mock" violates it
- For any violating task: rewrite the task to comply with the rule (e.g., rewrite mock test → integration test or real-implementation test)
- Show the user: original task, rule triggered, rewritten task
- Add a note in the spec's Technical Notes section: "Coding rules applied: [list of rules that triggered rewrites]"
- If no violations found: continue silently

1. **Write the file**: Save to `specs/spec-v{N}-{short-name}.md`

2. **Update README**: Add the new spec to `specs/README.md`:
   - Add a new `## v{N}: {Name}` section with Phase/Task **checklists** (`- [ ]` items)
   - Count the total number of checklist items (`- [ ]`) you added to the section
   - Get user email: `USER_EMAIL=$(~/.claude/aidev-toolkit/modules/sdd/scripts/user-email.sh get)`
   - Add a Quick Status table row with format: `| v{N} | {Name} | 0/{TASK_COUNT} | ✏️ Draft | {USER_EMAIL} |`
   - **CRITICAL**: The progress count must match the actual number of tasks in the README section
   - **Only `specs/README.md` gets checkboxes** — it is the sole progress tracker

3. **Report back**: Tell the user:
   - Spec was created with version v{N}
   - Filename: `spec-v{N}-{short-name}.md`
   - Confirm: Quick Status table updated with correct progress (0/{TASK_COUNT})
   - **Security section**: Confirm it was populated (not boilerplate). Summarize in one line what was set for AuthN, AuthZ, and Audit Logging.
   - Next steps: Edit the spec file to flesh out details, then run `/sdd-code-spec v{N}`

## Two-File Model

- **Spec file** (`specs/spec-v{N}-*.md`): Design document with YAML frontmatter. Contains Why/What/How as prose and plain bullets. No checkboxes.
- **README** (`specs/README.md`): Progress tracker. Contains `- [ ]` / `- [x]` checklists. This is the single source of truth for what's done.

## Example

If the user runs `/sdd-spec add ability to export classifications to CSV`, create:

- File: `specs/spec-v5-csv-export.md`
- Frontmatter: `version: 5`, `name: csv-export`, `display_name: "CSV Export"`, `status: draft`
- Why: "As a user, I want to export classifications to CSV so that I can analyze data in spreadsheets"
- What: Requirements for CSV export feature (plain bullets)
- How: Phased approach plan (plain bullets, no checkboxes)

---

## Prioritization Flow

Use this flow when user includes `-p` or `--prioritize` flag.

## Step 1: Query Incomplete Specs

Run specs-parse.sh to get all specs:

```bash
~/.claude/aidev-toolkit/modules/sdd/scripts/specs-parse.sh status
```

Filter output to only specs with `status = "Draft"` or `status = "In Progress"`. Store these as an array of incomplete specs.

## Step 2: Present Insertion Menu

Display a numbered menu showing incomplete specs plus an "At the end" option:

```text
Where should this spec be inserted?
1) Before v9: Testing & CI
2) Before v10: Spec Prioritize Flag
3) At the end (after v10)

Enter number:
```

Use **AskUserQuestion** to present this menu and get the user's selection.

## Step 3: Calculate Decimal Version

Based on user selection:

**If "At the end" selected:**

- Find highest version number from all specs
- New version = max_version + 1 (e.g., if max is v10, use v11)

**If "Before vN" selected:**

- Find the version immediately before the target (vN-1)
- Calculate decimal version between them
- **Algorithm:**
  - If inserting before v9 and previous is v8: use v8.9
  - If inserting before v10 and previous is v9: use v9.9
  - If gap already has decimals (e.g., v8.1, v8.2 exist between v8 and v9):
    - Find highest decimal in that gap (e.g., v8.2)
    - Use next increment (e.g., v8.3)
  - If all .1-.9 slots are full in a gap, use deeper decimal (e.g., v8.15)

**Special case - inserting before v1:**

- Use v0.9

**Edge case warning:**

- If 9 decimals already exist in a gap (v8.1 through v8.9), warn user and suggest using deeper decimal (v8.15, v8.25, etc.)

## Step 4: Extract Description

- Remove `-p` or `--prioritize` flag from `$ARGUMENTS`
- Remaining text is the spec description
- Create kebab-case short name (lowercase, hyphens, max 30 chars)

## Step 5: Insert README Section

Find all `## v{N}:` section headers in README.

**Algorithm:**

1. Parse all version section headers with their line numbers
2. Sort versions numerically to determine insertion point
3. Insert new section **before** the target version's section
4. Section template:

```markdown
## v{N.M}: {Display Name}

**Spec**: [spec-v{N.M}-{short-name}.md](spec-v{N.M}-{short-name}.md)

### Phase 1: Placeholder

- [ ] Task placeholder

---
```

1. Maintain spacing: blank line before section, `---` separator after

## Step 6: Insert Quick Status Table Row

Now that the README section with tasks exists, update the Quick Status table:

**Algorithm:**

1. Count the total number of checklist items (`- [ ]`) in the section you just created
2. Read `specs/README.md` and locate the Quick Status table (typically lines 9-25)
3. Parse all existing version rows from table
4. Get user email: `USER_EMAIL=$(~/.claude/aidev-toolkit/modules/sdd/scripts/user-email.sh get)`
5. Add new version to list: `| v{N.M} | {Name} | 0/{TASK_COUNT} | ✏️ Draft | {USER_EMAIL} |`
   - **CRITICAL**: Use the actual task count from Step 5, not "0/0"
6. Sort all versions **numerically**: 8 < 8.1 < 8.2 < 8.9 < 9 < 10 < 10.1
   - Use numeric comparison, not string sort
   - Split on dot: compare major, then minor
7. Insert new row at correct sorted position in table
8. Write updated README

## Step 6.5: Check Tasks Against Coding Rules (only if rules loaded in Step 0.6)

Before creating the spec file, check the tasks defined in Step 5 against any loaded coding rules:

- For each task, identify if it would violate any rule
- For any violating task: rewrite it to comply, show user the original + rewrite + rule triggered
- Add a note in the spec's Technical Notes section: "Coding rules applied: [list of rules that triggered rewrites]"
- If no violations: continue silently

## Step 7: Create Spec File

Use template from `~/.claude/aidev-toolkit/modules/sdd/templates/TEMPLATE.md`.

Fill in:

- **Frontmatter:**
  - `version: {N.M}` (decimal version, e.g., 8.9 or 10.1)
  - `name: {short-name}` (kebab-case)
  - `display_name: "{Display Name}"`
  - `status: draft`
  - `created: {today's date in YYYY-MM-DD format}`

- **Why section:** Use user's description as the primary content
- **What/How sections:** Leave as boilerplate placeholders from template

Save to: `specs/spec-v{N.M}-{short-name}.md`

## Step 8: Report Back

Tell user:

- Spec created with version v{N.M}
- Inserted before v{target} (or "at the end" if appended)
- Filename: `spec-v{N.M}-{short-name}.md`
- Confirm: Quick Status table updated with correct progress (0/{TASK_COUNT})
- **Security section**: Confirm it was populated (not boilerplate). Summarize in one line what was set for AuthN, AuthZ, and Audit Logging.
- Next steps: Edit the spec file to flesh out What/How sections, then run `/sdd-code-spec v{N.M}`
