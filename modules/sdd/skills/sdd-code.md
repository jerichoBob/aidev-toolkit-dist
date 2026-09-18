---
name: sdd-code
display-name: "/sdd-code"
tier: core
description: "Implement ALL remaining phases and tasks in a spec without stopping"
argument-hint: "[spec-version] [--no-stats]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/*:*), Bash(git:*), Bash(date:*), AskUserQuestion
---

# Implement Complete Spec

Implement all remaining phases and tasks in the current spec without stopping between phases or tasks.

## Step 1: Gather Data

1. Check if token tracking is disabled:
   - If `$ARGUMENTS` contains `--no-stats`, skip all token capture steps (graceful degradation)
   - Otherwise, enable token tracking for each task

2. Run this command to see all specs and their status:

```bash
~/.claude/aidev-toolkit/modules/sdd/scripts/specs-parse.sh status
```

1. **Load coding rules** (if present): Check for `coding-rules.md` in project root, then `.claude/`. If found, read it. These rules govern what code is acceptable to write.

2. **Load architecture principles**: Implementation must follow the aidev-toolkit architecture principles — this is not optional. Resolve the principles directory in this order:
   - **Local project**: `architecture-principles/*.md` — if present, use it.
   - **Global fallback**: `~/.claude/aidev-toolkit/architecture-principles/*.md` — used if the local directory doesn't exist (the normal case; the toolkit ships its principles here).

   Read each file's frontmatter (`id`, `title`, `severity`, `category`) and body. Also load custom project-level principles from `.aid/principles/` if present (additive). If neither directory exists, proceed without principles and note it in the final summary.

## Step 2: Implement

1. **Find the target spec**:
   - If `$ARGUMENTS` contains a spec version (e.g., `v3`), find that spec in the status output
   - Otherwise, use the first spec with status `In Progress` or `Draft`
   - Read the full spec file for context (find it at `specs/spec-v{N}-*.md`)

2. **Identify all remaining work**: Read `specs/README.md` and collect ALL unchecked items across ALL phases of the target spec.

3. **Check pending tasks against coding rules** (only if rules were loaded):
   - Scan each pending task for potential violations of any loaded rule
   - For each violation found, surface it: task text, rule violated, suggested rewrite
   - Use `AskUserQuestion` to present all violations at once and ask how to proceed:
     - "Rewrite all violating tasks to comply" (recommended)
     - "Skip violating tasks"
     - "Proceed anyway (ignore rules)"
   - **Never silently proceed if a violation is detected**
   - If user selects rewrite: update the task descriptions in README before coding begins

4. **Check the spec against architecture principles** (only if principles were loaded in Step 1):
   - Scan the target spec file's `## Security` section for AP-005 compliance (explicit, non-placeholder Authentication/Authorization/Audit Logging decisions). If it's still boilerplate, patch it now using the same logic `/sdd-spec` Step 4.5 uses — don't start implementation with an unresolved security decision.
   - For the remaining required principles (AP-001 security, AP-002/AP-007 observability, AP-003 error handling, AP-004 testing, AP-006 supply chain), keep them in mind for every task in Step 5 below — see the per-task guidance there. No need to front-load a full audit; that's what `/arch-review` is for.

5. **Create a todo list**: Use TodoWrite to create tasks for ALL unchecked items across ALL phases, organized by phase.

6. **Implement phase by phase, task by task**:
   - Work through phases in order (Phase 1, then Phase 2, etc.)
   - Within each phase, implement each task sequentially
   - **Token-tracking file reuse (per-phase, not per-task)**: use two fixed, alternating snapshot files for the whole phase — `/tmp/sdd-code-phase-{version}-{phase_num}-a.json` and `/tmp/sdd-code-phase-{version}-{phase_num}-b.json`. A task's "after" snapshot IS the next task's "before" snapshot — no copy, no re-snapshot, just point the `delta` call at whichever file already holds that state. This drops the redundant "before" snapshot Bash call for every task after the first in a phase (only one `snapshot` call per task instead of two).
   - For each task:
     - **If architecture principles were loaded (Step 1)**: apply the relevant required principles while writing the code, not as an afterthought — AP-001 (validate external input, parameterize queries, no hardcoded secrets), AP-002/AP-007 (structured logging for new runtime paths), AP-003 (handle failure modes explicitly, no empty catch blocks), AP-004 (add/extend tests for the critical path this task introduces), AP-006 (vet any new dependency before adding it). Only apply the ones relevant to what the task actually touches — don't pad unrelated tasks with unrelated principle busywork.
     - If token tracking is enabled (no `--no-stats` flag):
       - **First task in the phase**: capture a real before-snapshot into file `a`: `~/.claude/aidev-toolkit/modules/sdd/scripts/token-tracker.sh snapshot /tmp/sdd-code-phase-{version}-{phase_num}-a.json`
       - **Subsequent tasks in the phase**: no snapshot call needed — the previous task's "after" file already holds this task's "before" state; just track which of `a`/`b` currently holds it.
     - Mark each task as `in_progress` when starting
     - Implement the task fully
     - If token tracking is enabled:
       - Capture token snapshot after into the *other* alternating file (e.g. task uses `a` as before → snapshot after into `b`; next task will then use `b` as before → snapshot after into `a`): `~/.claude/aidev-toolkit/modules/sdd/scripts/token-tracker.sh snapshot /tmp/sdd-code-phase-{version}-{phase_num}-{other_letter}.json`
       - Calculate delta: `delta_output=$(~/.claude/aidev-toolkit/modules/sdd/scripts/token-tracker.sh delta /tmp/sdd-code-phase-{version}-{phase_num}-{before_letter}.json /tmp/sdd-code-phase-{version}-{phase_num}-{after_letter}.json); delta_exit=$?`
       - **Check `delta_exit`**: if nonzero (or `delta_output` starts with `STALE`), the snapshot pair was stale/unmeasurable — skip the `task-meta` insertion entirely for this task and move on, per the graceful-degradation clause below. Only parse and insert `task-meta` when `delta_exit` is `0`.
       - Parse delta into: in_tokens, out_tokens, cache_tokens
       - Get current timestamp: `start_time=2026-02-21T$(date +%H:%M:%SZ)` and `end_time=2026-02-21T$(date +%H:%M:%SZ)`
       - Get git commit SHA: `commit_sha=$(git rev-parse --short HEAD)`
       - Insert HTML comment after task checkbox in `specs/README.md`: `<!-- task-meta: v={version},t={task_num},in={in_tokens},out={out_tokens},cache={cache_tokens},start={start_time},end={end_time},commit={commit_sha} -->` — per-task attribution is preserved even though the snapshot files are shared/alternated across the phase
     - Update `specs/README.md` to mark the task as complete (`- [x]`)
     - Mark the todo as `completed`
     - Move immediately to the next task
   - When a phase is complete, move immediately to the next phase. Delete that phase's snapshot files (`rm -f /tmp/sdd-code-phase-{version}-{phase_num}-a.json /tmp/sdd-code-phase-{version}-{phase_num}-b.json`) and start a fresh before-snapshot for the first task of the next phase.

7. **Do NOT stop between tasks or phases**: Continue implementing until ALL phases in the spec are complete.

8. **After completing the entire spec**:
   - Update the Quick Status table row in `specs/README.md` to show completion
   - Update the spec file's YAML frontmatter `status` field to `complete`
   - Run any relevant tests if they exist
   - Bump the version (patch for fixes, minor for features)
   - If architecture principles were loaded, suggest `/arch-review` in the summary as the formal compliance check — the inline principle-awareness in Step 6 is not a substitute for a full audit
   - Report a summary of what was implemented

## Important

- **Do not ask for confirmation between tasks or phases** — implement the entire spec end-to-end
- **Update specs/README.md after each task** — keep the checklist in sync
- **Update spec file YAML frontmatter** when completing a spec (`status: complete`)
- **Read the full spec file** for additional context on implementation details
- **Follow existing code patterns** in the codebase
- **Test as you go** when practical
- **If a task is blocked** (missing dependency, requires external config), mark it as blocked, skip it, and continue. Report blocked tasks in the summary.
- **Token tracking**: If token capture fails (snapshot command errors) or `token-tracker.sh delta` signals a stale/unmeasurable snapshot pair (nonzero exit / `STALE` prefix), skip the metadata insertion and continue normally. Do NOT block the workflow on token tracking issues, and never write a `task-meta` comment from a stale delta.

## Output Format

When starting:

```text
Implementing Spec: v{N} - {Name}
Phases to complete: {count}
Total tasks remaining: {count}

Starting Phase 1: {Phase Name}...
```

When complete:

```text
Spec Complete: v{N} - {Name}

Phase 1: {Phase Name}
- {Task 1}
- {Task 2}

{Blocked (if any):}
{- {Task} — {reason}}

Version bumped: {old} -> {new}
```
