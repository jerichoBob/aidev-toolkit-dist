# Story Status Update Message Type

## Purpose

Notify a peer agent that one or more user story statuses have changed on your side, so they
can update their local `feature-burndown.ts`. Used to keep the shared platform status page
in sync without either agent manually editing the other's data file.

Both sides publish these — gv2 when it ships gv2-side work, stak-app when mobile-side work
completes. The receiver applies the updates to their `feature-burndown.ts` and commits.

## Frontmatter Fields

In addition to the base fields, story-status-update messages add:

| Field | Required | Description |
|-------|----------|-------------|
| `stories` | yes | Inline YAML list of story updates (see schema below) |

### Story update schema

```yaml
stories:
  - id: STORY-042        # matches id field in feature-burndown.ts
    side: stak-app       # "gv2" or "stak-app" — whose status is changing
    status: FUNCTIONAL   # FUNCTIONAL | PARTIAL | STUBBED | ABSENT | COMPLETE | null
    notes: optional note # replaces the existing notes field if provided (omit to leave unchanged)
```

## Prose Sections

| Section | Filled by | When | Purpose |
|---------|-----------|------|---------|
| **What Changed** | sender | on publish | Human-readable summary of what shipped and why these statuses changed |
| **Context for Receiver** | sender | on publish | Anything the receiver needs to know before updating — deps, caveats, follow-up asks |
| **Applied Notes** | receiver | on complete | Confirm which rows were updated, commit hash |

## Routing Modes Supported

- `direct` — send to a specific named agent (preferred — both repos maintain a `main` agent)

## Completion

When the receiver applies the updates and commits, call `/backbone-done` and fill in
**Applied Notes** with the commit hash and any rows that were skipped (e.g. status was
already correct).

## Example

```markdown
---
id: "20260611-120000"
type: story-status-update
status: pending
routing: direct
from: grostak-v2:main
to: stak-app:main
stories:
  - id: STORY-042
    side: gv2
    status: FUNCTIONAL
  - id: STORY-043
    side: gv2
    status: FUNCTIONAL
created: 2026-06-11
updated: 2026-06-11
---

# What Changed

Shipped vial concentration/volume/lot fields on gv2 side (v12). STORY-042 and STORY-043
gv2Status can now be marked FUNCTIONAL.

# Context for Receiver

stak-app side still STUBBED — these are `→ SA needed` items. No action required on your
side yet, just updating the shared burndown so the platform status page reflects reality.

# Applied Notes

<!-- filled in by receiver via /backbone-done -->
```
