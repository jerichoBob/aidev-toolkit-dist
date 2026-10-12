# CR (Change Request) Message Type

## Purpose

Ask another agent to make a code, schema, or API change on their side of the project boundary.

## Frontmatter Fields

In addition to the base fields, CR messages add:

| Field | Required | Description |
|-------|----------|-------------|
| `affected_endpoints` | no | List of API endpoints affected (e.g. `POST /api/refills`) |
| `affected_tables` | no | List of DB tables affected (e.g. `refill_requests`) |

## Prose Sections

| Section | Filled by | When | Purpose |
|---------|-----------|------|---------|
| **Problem Statement** | sender | on publish | What the sender's side needs and why the receiver's side doesn't support it yet |
| **Solution Recommendation** | sender | on publish | Specific enough for the receiver to act without follow-up: endpoint signatures, schema, auth requirements |
| **Implementation Notes** | receiver | on complete | What was built: endpoints added, schema changes, migration path, breaking changes, auth changes |
| **Follow-up Notes** | sender | after reading Implementation Notes | What the sender did on their side in response |

## Routing Modes Supported

- `direct` — addressed to a specific named agent (most common for CRs)
- `topic` — broadcast (e.g. `topic: schema-changes` to notify all interested agents)

## Completion Notes

When calling `/backbone-done` on a claimed CR, the receiver should write **Implementation Notes** covering:

- Endpoints added or modified (full signatures)
- Schema changes and migration file path
- Breaking changes (anything the sender must handle differently)
- Auth changes (new permissions, JWT claim requirements)
- Known gaps or deferred items

Be specific enough that the sender can act without asking follow-up questions.

## Example

```markdown
---
id: "20260603-143022"
type: cr
status: pending
routing: direct
from: stak-app:refill-flow
to: grostak-api:core
affected_endpoints:
  - POST /api/refills
  - GET /api/refills/:id
affected_tables:
  - refill_requests
created: 2026-06-03
updated: 2026-06-03
---

# Problem Statement

The mobile app needs to submit refill requests...

# Solution Recommendation

Add POST /api/refills accepting { medication_id, notes }...

# Implementation Notes

<!-- filled in by receiver via /backbone-done -->

# Follow-up Notes

<!-- filled in by sender after reading implementation notes -->
```
