---
name: sdd-code-phase
description: "Implement all remaining tasks in the current phase without stopping"
tier: extended
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/*:*), Bash(git:*), Bash(date:*)
---

# Implement Next Phase

Implement all remaining tasks in the current phase without stopping between tasks.

## Step 1: Gather Data

Run this command first to get the current phase and its tasks:

```bash
~/.claude/aidev-toolkit/modules/sdd/scripts/specs-parse.sh next-phase
```

## Step 2: Implement

1. If the output shows `NO_TASKS_REMAINING`, report that all specs are complete and suggest creating a new spec with `/sdd-spec`.

2. **Read the spec file** shown in `spec_file` for full implementation context.

3. **Create a todo list**: Use TodoWrite to create tasks for ALL unchecked items (`[ ]` lines) from the output.

4. **Implement each task sequentially**:
   - Mark each task as `in_progress` when starting
   - Implement the task fully
   - Update `specs/README.md` to mark the task as complete (`- [x]`)
   - Mark the todo as `completed`
   - Move immediately to the next task

5. **Do NOT stop between tasks**: Continue implementing until ALL tasks in the phase are complete.

6. **After completing the phase**:
   - Run any relevant tests if they exist
   - Bump the version in `app.py` if code was changed (patch for fixes, minor for features)
   - Report a summary of what was implemented

## Important

- **Do not ask for confirmation between tasks** — implement the entire phase
- **Update specs/README.md after each task** — keep the checklist in sync
- **Read the full spec file** for additional context
- **Follow existing code patterns** in the codebase
- **Test as you go** when practical

## Output Format

When starting:

```text
Implementing Phase: {Phase Name}
Spec: v{N} - {Name}
Tasks to complete: {count}

Starting implementation...
```

When complete:

```text
Phase Complete: {Phase Name}

Implemented:
- {Task 1}
- {Task 2}
- {Task 3}

Version bumped: {old} -> {new}
```
