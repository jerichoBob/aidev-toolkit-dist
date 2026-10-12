# Task Message Type

## Purpose

Delegate a discrete, well-defined unit of work to another agent. Lighter than a CR — no schema change implied, just something that needs doing.

## Frontmatter Fields

In addition to the base fields, task messages add:

| Field | Required | Description |
|-------|----------|-------------|
| `priority` | no | `high` \| `normal` \| `low` (default: `normal`) |
| `due_date` | no | YYYY-MM-DD — informational, not enforced |

## Prose Sections

| Section | Filled by | When | Purpose |
|---------|-----------|------|---------|
| **Task Description** | sender | on publish | What needs to be done and why — enough context to start without asking |
| **Acceptance Criteria** | sender | on publish | How the receiver knows they're done |
| **Completion Notes** | receiver | on complete | What was done, any decisions made, anything the sender should know |

## Routing Modes Supported

- `direct` — assigned to a specific named agent
- `topic` — broadcast to a topic (e.g. `topic: available` for any free agent to pick up)

## Completion Notes

When calling `/backbone-done` on a claimed task, write **Completion Notes** covering:

- What was done (files changed, decisions made)
- Whether all acceptance criteria were met — if not, which ones weren't and why
- Any follow-on work the sender should be aware of

## Example

```markdown
---
id: "20260604-091500"
type: task
status: pending
routing: direct
from: agent-backbone:spec-work
to: grostak-api:core
priority: normal
due_date: 2026-06-05
created: 2026-06-04
updated: 2026-06-04
---

# Task Description

Add an index on refill_requests(tenant_id, status) — the patient dashboard
query is doing a full table scan on large tenants.

# Acceptance Criteria

- Migration file exists and runs cleanly
- EXPLAIN ANALYZE shows index scan on the dashboard query
- No other queries regressed

# Completion Notes

<!-- filled in by receiver via /backbone-done -->
```
