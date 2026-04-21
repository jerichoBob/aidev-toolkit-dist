---
id: AP-005
title: Security-First Spec Design
severity: required
category: security
applies_to: [specs, sdd-workflow]
---

## Principle

Every specification must explicitly address authentication, authorization, and audit logging before implementation begins — even for POCs, internal tools, and prototypes.

## Rationale

Security is consistently omitted from early specs because there's no forcing function at design time. By the time a POC becomes production, retrofitting auth and audit logging is costly, disruptive, and often skipped. Making the Security section mandatory in every spec shifts this decision to the cheapest possible moment: before any code is written.

"Not applicable" is an acceptable answer — but silence is not. The decision must be documented.

## Requirements

### Spec Security Section

- Every spec file must contain a `## Security` section with three subsections: **Authentication**, **Authorization**, and **Audit Logging**
- Each subsection must contain an explicit decision — not template placeholder text (e.g., not `{e.g., JWT}` left unfilled)
- "Not applicable — [rationale]" is valid. A blank field or unmodified placeholder is not.

### Authentication

- State who can access the feature: authenticated users, service accounts, or public
- Name the auth mechanism: JWT, session cookie, API key, OAuth2, or "none" with explicit rationale
- "None" requires a documented reason (e.g., "internal CLI tool with no network surface")

### Authorization

- State the minimum required roles/permissions
- State what is explicitly denied
- If no roles apply (e.g., all authenticated users have equal access), say so explicitly

### Audit Logging

- Name the events that must be logged (create, update, delete, auth failure, permission denied)
- Specify required fields per event: actor identity, action, resource identifier, timestamp, outcome
- State retention requirements or "not required" with rationale

## Validation Checklist

- [ ] Spec contains a `## Security` section
- [ ] Authentication subsection has an explicit decision (not placeholder text)
- [ ] Authorization subsection has an explicit decision (not placeholder text)
- [ ] Audit Logging subsection has an explicit decision (not placeholder text)
- [ ] If any subsection says "Not applicable", a rationale is provided

## Examples

### Good — User-Facing API Feature

```markdown
## Security

### Authentication
JWT bearer token required. Tokens issued by our auth service, validated on every request.
Unauthenticated requests return 401.

### Authorization
Role `editor` or `admin` required to create/update. Role `viewer` may only read.
Explicit deny: `viewer` role receives 403 on any mutation attempt.

### Audit Logging
Log: resource created, resource updated, resource deleted, unauthorized access attempt.
Fields: actor_id, action, resource_id, timestamp, outcome.
Retention: 90 days.
```

### Good — Internal CLI Tool

```markdown
## Security

### Authentication
Not applicable — CLI tool runs locally under the developer's own credentials.
No network surface, no shared accounts.

### Authorization
Not applicable — single-user local tool. No role separation needed.

### Audit Logging
Not applicable — tool produces no persistent state changes in shared systems.
```

### Bad — Placeholder Left Unfilled

```markdown
## Security

### Authentication
- **Mechanism**: (e.g., JWT bearer token, session cookie, API key)
```

This is a violation — placeholder text was not replaced with an actual decision.
