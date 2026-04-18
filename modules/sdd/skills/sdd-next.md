---
name: sdd-next
description: "Show the next task that would be implemented if /sdd-code is run"
disable-model-invocation: false
allowed-tools: Read, Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/*:*)
---

# Show Next Task

Show the next task that would be implemented if `/sdd-code` is run.

## Step 1: Gather Data

Run this command first:

```bash
~/.claude/aidev-toolkit/modules/sdd/scripts/specs-parse.sh next-task
```

## Step 2: Display

1. If the output shows `NO_TASKS_REMAINING`, report that all specs are complete and suggest creating a new spec with `/sdd-spec`.

2. Otherwise, display the next task using the output. Also read the spec file (shown in `spec_file`) for brief context on what implementing this task would involve.

3. Display:
   - The spec version and name
   - The phase
   - The specific task
   - A brief preview of what implementing this task would involve

## Output Format

```text
Next Task

Spec: v{N} - {Name}
Phase: {Phase Name}
Task: {Task description}

This task involves: {brief explanation of what would be done}
```
