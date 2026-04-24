---
version: X
name: short-name
display_name: "Human Readable Name"
status: draft  # draft | in-progress | validation-needed | complete
created: YYYY-MM-DD
depends_on: []
tags: []
---

# {Display Name}

## Why (Problem Statement)

> As a {role}, I want to {goal} so that I can {benefit}.

### Context

- Background information
- Current pain points
- Business value

---

## What (Requirements)

### User Stories

- **US-1**: As a {role}, I want {feature} so that {benefit}
- **US-2**: ...

### Acceptance Criteria

- AC-1: Given {context}, when {action}, then {expected result}
- AC-2: ...

### Out of Scope

- Items explicitly not included in this version

---

## How (Approach)

> **Two-file model — no checkboxes here.** Tasks below are plain bullets. Checkboxes (`- [ ]` / `- [x]`) belong only in `specs/README.md`, which is the single source of truth for progress tracking. `specs-parse.sh` counts from README only.

### Phase 1: {Phase Name}

- Task 1
- Task 2

### Phase 2: {Phase Name}

- Task 1
- Task 2

### Phase N: Tests

- Add `tests/test-{name}.sh` covering all new scripts and entry points introduced by this spec
- Verify tests pass via `tests/run-all.sh`

---

## Technical Notes

### Architecture Decisions

- Decision 1: Rationale

### Dependencies

- External services
- Libraries

### Risks & Mitigations

| Risk | Mitigation |
| ---- | ---------- |
| ...  | ...        |

---

## Open Questions

1. Question 1?
2. Question 2?

---

## Changelog

| Date       | Change        |
| ---------- | ------------- |
| YYYY-MM-DD | Initial draft |
