# Message Type Registry

This directory defines the schemas for all message types on the backbone. Each file is a loose guide that Claude reads at publish time to know what fields and sections to prompt for. No code parser — just markdown.

---

## Registered Types

| Type | File | Purpose |
|------|------|---------|
| `cr` | [cr.md](cr.md) | Change request — ask another agent to make a code/schema change |
| `task` | [task.md](task.md) | Task assignment — delegate a discrete unit of work to another agent |

---

## How to Add a New Type

1. Create `messages/types/{type-name}.md` using the template below
2. That's it — `/backbone-send` discovers types by scanning this directory

### Type Schema Template

```markdown
# {Type Name} Message Type

## Purpose

One sentence: what is this message for?

## Frontmatter Fields

In addition to the base fields (id, type, status, routing, from, to/topic, created, updated),
this type adds:

| Field | Required | Description |
|-------|----------|-------------|
| field_name | yes/no | what it means |

## Prose Sections

| Section | Filled by | When | Purpose |
|---------|-----------|------|---------|
| Section Name | sender/receiver | on publish/on complete | what goes here |

## Routing Modes Supported

- `direct` — addressed to a specific named agent
- `topic` — broadcast to all agents subscribed to a topic
- (or: `direct only` / `topic only` if restricted)

## Completion Notes

What the receiver should write in the completion section before calling /backbone-done.
```

---

## Base Frontmatter (all types)

Every message regardless of type carries these fields:

```yaml
---
id: YYYYMMDD-HHMMSS
type: cr | task | {registered-type}
status: pending | claimed | complete
routing: direct | topic
from: agent-name
to: agent-name        # routing: direct only
topic: topic-name     # routing: topic only
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

## Filename Convention

```text
{type}-{id}-{status}.md
```

Examples:

```text
cr-20260603-143022-pending.md
cr-20260603-143022-claimed.md
task-20260603-150000-pending.md
task-20260603-150000-complete.md   ← moved to messages/archive/ by /backbone-done
```

## State Machine

All types share the same lifecycle:

```text
pending
  └─► claimed      (/backbone-inbox — receiver claims)
        └─► complete  (/backbone-done — receiver closes, file moves to archive/)
```

Completed messages are moved to `messages/archive/` and never appear in `/backbone-inbox` scans.
