# Feedback Message Type

## Purpose

Send a bug report, feature idea, question, or general observation about the backbone itself to whoever is maintaining it. Routes to `topic: backbone-meta` by default — the `agent-backbone:maintainer` session subscribes to this topic automatically on join.

## Frontmatter Fields

In addition to the base fields, feedback messages add:

| Field | Required | Description |
|-------|----------|-------------|
| `category` | yes | `bug` \| `idea` \| `question` \| `observation` |
| `urgency` | no | `blocking` \| `normal` \| `low` (default: `normal`) |

## Prose Sections

| Section | Filled by | When | Purpose |
|---------|-----------|------|---------|
| **Problem / Context** | sender | on publish | What happened or what's missing — include repo, command, and steps to reproduce for bugs |
| **Desired Outcome** | sender | on publish | What you'd like to happen instead, or what question you need answered |
| **Resolution** | maintainer | on complete | What was done or decided in response |

## Routing

Feedback always routes to `topic: backbone-meta`. Do not use `routing: direct` for feedback — the maintainer session may not be running under a predictable direct name.

```yaml
routing: topic
topic: backbone-meta
```

## Completion Notes

When calling `/backbone-done` on a claimed feedback message, write **Resolution** covering:

- What action was taken (fix committed, issue filed, question answered, deferred with reason)
- Whether the issue is fully resolved or follow-on work remains

## Example

```markdown
---
id: "20260606-151700"
type: feedback
status: pending
routing: topic
topic: backbone-meta
from: grostak-api:patient-schema
category: idea
urgency: normal
created: 2026-06-06
updated: 2026-06-06
---

# Problem / Context

When /backbone-inbox shows topic messages, there's no indication of which
topic matched — if you're subscribed to multiple topics it's hard to know
why a message showed up.

# Desired Outcome

Show the matched topic next to each inbox item, e.g.:
  task-20260606-091500  [via topic: schema-changes]

# Resolution

<!-- filled in by maintainer via /backbone-done -->
```
