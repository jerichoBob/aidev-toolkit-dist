---
name: sdd-next-phase
description: "Show all tasks in the next phase of work to be done"
tier: extended
disable-model-invocation: false
allowed-tools: Read, Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/*:*)
---

# Show Next Phase

Show all tasks in the next phase of work.

## Step 1: Gather Data

Run this command first:

```bash
~/.claude/aidev-toolkit/modules/sdd/scripts/specs-parse.sh next-phase
```

## Step 2: Display

1. If the output shows `NO_TASKS_REMAINING`, report that all specs are complete and suggest creating a new spec with `/sdd-spec`.

2. Otherwise, display all tasks in the current working phase. Count done vs total from the `[x]` and `[ ]` lines in the TASKS section.

3. Display:
   - The spec version and name
   - The phase name
   - All tasks with their status (done or pending)
   - A summary of progress (e.g., "2/5 complete")

## Output Format

```text
Next Phase

Spec: v{N} - {Name}
Phase: {Phase Name}
Progress: {done}/{total} complete

Tasks:
[done] {Completed task 1}
[pending] {Pending task 2}
[pending] {Pending task 3}
```
