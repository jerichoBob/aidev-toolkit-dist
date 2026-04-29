---
name: sdd-code-spec
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

4. **Create a todo list**: Use TodoWrite to create tasks for ALL unchecked items across ALL phases, organized by phase.

5. **Implement phase by phase, task by task**:
   - Work through phases in order (Phase 1, then Phase 2, etc.)
   - Within each phase, implement each task sequentially
   - For each task:
     - If token tracking is enabled (no `--no-stats` flag):
       - Capture token snapshot before: `~/.claude/aidev-toolkit/modules/sdd/scripts/token-tracker.sh snapshot /tmp/task-before-$RANDOM.json`
     - Mark each task as `in_progress` when starting
     - Implement the task fully
     - If token tracking is enabled:
       - Capture token snapshot after: `~/.claude/aidev-toolkit/modules/sdd/scripts/token-tracker.sh snapshot /tmp/task-after-$RANDOM.json`
       - Calculate delta: `delta_output=$(~/.claude/aidev-toolkit/modules/sdd/scripts/token-tracker.sh delta /tmp/task-before-*.json /tmp/task-after-*.json)`
       - Parse delta into: in_tokens, out_tokens, cache_tokens
       - Get current timestamp: `start_time=2026-02-21T$(date +%H:%M:%SZ)` and `end_time=2026-02-21T$(date +%H:%M:%SZ)`
       - Get git commit SHA: `commit_sha=$(git rev-parse --short HEAD)`
       - Insert HTML comment after task checkbox in `specs/README.md`: `<!-- task-meta: v={version},t={task_num},in={in_tokens},out={out_tokens},cache={cache_tokens},start={start_time},end={end_time},commit={commit_sha} -->`
       - Clean up temp snapshot files
     - Update `specs/README.md` to mark the task as complete (`- [x]`)
     - Mark the todo as `completed`
     - Move immediately to the next task
   - When a phase is complete, move immediately to the next phase

6. **Do NOT stop between tasks or phases**: Continue implementing until ALL phases in the spec are complete.

7. **After completing the entire spec**:
   - Update the Quick Status table row in `specs/README.md` to show completion
   - Update the spec file's YAML frontmatter `status` field to `complete`
   - Run any relevant tests if they exist
   - Bump the version (patch for fixes, minor for features)
   - Report a summary of what was implemented

## Important

- **Do not ask for confirmation between tasks or phases** — implement the entire spec end-to-end
- **Update specs/README.md after each task** — keep the checklist in sync
- **Update spec file YAML frontmatter** when completing a spec (`status: complete`)
- **Read the full spec file** for additional context on implementation details
- **Follow existing code patterns** in the codebase
- **Test as you go** when practical
- **If a task is blocked** (missing dependency, requires external config), mark it as blocked, skip it, and continue. Report blocked tasks in the summary.
- **Token tracking**: If token capture fails (snapshot command errors), skip the metadata insertion and continue normally. Do NOT block the workflow on token tracking issues.

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
