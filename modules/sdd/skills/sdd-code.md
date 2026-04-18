---
name: sdd-code
description: "Implement the single next task from the specs checklist"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/*:*), Bash(git:*), Bash(date:*), AskUserQuestion
---

# Implement Next Task

Implement the single next task from the specs checklist.

## Step 1: Gather Data

1. Run this command first to find the next task:

```bash
~/.claude/aidev-toolkit/modules/sdd/scripts/specs-parse.sh next-task
```

1. **Load coding rules** (if present): Check for `coding-rules.md` in project root, then `.claude/`. If found, read it.

## Step 2: Implement

1. If the output shows `NO_TASKS_REMAINING`, report that all specs are complete and suggest creating a new spec with `/sdd-spec`.

2. **Read the spec file** shown in `spec_file` for full implementation context.

2.5. **Check task against coding rules** (only if rules were loaded):

- If the task would violate a loaded rule (e.g., "write mock-based tests" violates a no-mocks rule), surface the violation
- Use `AskUserQuestion` to ask: "This task may violate a coding rule: [rule]. Rewrite the task or proceed anyway?"
- Never silently implement a task that violates a rule

1. **Report what you're implementing**:

   ```text
   Implementing Task

   Spec: v{N} - {Name}
   Phase: {Phase Name}
   Task: {Task description}
   ```

2. **Implement the task**:
   - Follow existing code patterns in the codebase
   - Make the minimal changes needed to complete the task
   - Test the implementation when practical

3. **Update the checklist**: Mark the task as complete in `specs/README.md` (`- [x]`)

4. **Bump version if needed**: If code was changed (not just docs), bump the patch version in `app.py`

5. **Report completion**:

   ```text
   Task Complete

   {Brief summary of what was done}

   Next task: {Preview of the next unchecked task, or "Phase complete!" if phase is done}
   ```

## Important

- **Implement only ONE task** — stop after completing it
- **Update specs/README.md** — keep the checklist in sync
- **Read the full spec file** for additional context
- **Follow existing code patterns** in the codebase
