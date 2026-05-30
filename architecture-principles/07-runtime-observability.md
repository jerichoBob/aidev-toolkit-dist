---
id: AP-007
title: Runtime-Adjustable Observability
severity: required
category: observability
applies_to: [all]
---

## Principle

Every application must support runtime-adjustable verbosity: the ability to increase
or decrease what the system emits — logs, traces, debug payloads — without a code
change or redeploy. Each application surface (API, web, mobile) owns its own
verbosity state. When verbosity is elevated above normal, the system must make
that fact visible and auditable.

## Rationale

Static observability (AP-002) tells you what a healthy system emits. Runtime-adjustable
observability tells you what a system *can* emit when something goes wrong. The gap
between the two is where debugging pain lives.

In AI-assisted development this matters more, not less. Claude cannot diagnose what
it cannot see. When an agent is debugging a distributed system — tracing a multi-hop
request, correlating a race condition, understanding why a background job silently
failed — it needs the application to be able to surface intermediate state, query
plans, branch decisions, and raw payloads on demand. "Redeploy with more logging"
is not a viable debugging loop when working with an AI pair that needs signal *now*.

The two-tier model — plumbing first, UI optional — ensures the capability exists
everywhere, even in headless or early-stage services, while giving full-stack
applications a consistent, safe pattern for operator-controlled verbosity.

---

## Verbosity Levels

| Level | Value | Intended Use | What the system emits |
|-------|-------|-------------|----------------------|
| `silent` | 0 | Incident suppression | Errors only. No request detail, no internals |
| `normal` | 1 | Default (all environments) | Standard structured logs: request in/out, errors, significant events |
| `verbose` | 2 | QA / pre-prod investigation | Step-by-step progress, timing, key variable values |
| `debug` | 3 | Active debugging | Full request/response bodies, intermediate state, decision branches |
| `trace` | 4 | Deep diagnosis | Everything: raw payloads, query plans, all branch conditions, env context (secrets redacted) |

`normal` is the required default in every environment, including production. `silent`
is not a "safer" production default — it hides errors that need attention.

---

## Requirements

### Plumbing (required for all applications)

#### Config & Bootstrap

- Each application surface must maintain a verbosity config, either:
  - A server-side config entry (database row, config file, environment variable override)
  - An in-memory default that can be overridden at runtime via authenticated API call
- The config must persist across restarts (not just in-process memory)
- Bootstrap default: `normal`. Never bootstrap to `silent` or `debug`

#### Level Control API

- Expose an authenticated internal endpoint to read and set the current verbosity level:
  - `GET /internal/obs` — returns `{ level, value, lockedBy, changedAt, changedBy }`
  - `POST /internal/obs` — accepts `{ level }`, updates config, writes audit entry
- This endpoint must be protected by the application's highest privilege gate
  (superadmin, internal service token, or equivalent)
- Reject unknown level names with a `400` and a list of valid values
- The endpoint must be available in every environment, including production

#### Structured Level Propagation

- The current verbosity level must be included in every structured log entry:
  `{ ..., "obs_level": "debug" }`
- For cross-service requests, propagate the requesting surface's level in a
  request header: `X-Obs-Level: debug`
- Receiving services must log the received level but are not required to adopt it —
  each surface controls its own state

#### Secret Redaction at Trace

- At `trace` level, all log values must pass through a redaction filter before
  emission
- Redact any value whose key matches: `password`, `token`, `secret`, `key`,
  `authorization`, `credential`, `ssn`, `card` (case-insensitive, substring match)
- Replace redacted values with `[REDACTED]`
- Log a single warning when trace is activated: `"trace level active — secrets
  will be redacted but treat logs as sensitive"`

#### Audit Trail

- Every verbosity level change must be written to the application's audit log:
  - Actor (user ID or service identity)
  - Previous level
  - New level
  - Timestamp
  - Source (API call, config file, environment override)
- Audit entries must be written even when the change is rejected (log the attempt
  and the rejection reason)

### UI Treatment (required when an admin UI exists)

#### Verbosity Control Surface

- The admin UI must expose verbosity controls accessible only to the highest
  privilege role (superadmin or equivalent)
- Controls must show: current level per surface, who last changed it, when
- Setting verbosity above `normal` must require an explicit confirmation step —
  not a single click

#### Elevated Verbosity Banner

- When any surface is operating above `normal`, display a persistent, visually
  distinct banner to all authenticated users of that surface
- The banner must identify:
  - Which surface(s) are elevated
  - The current level
  - Who activated it and when
  - A link to the verbosity control panel (superadmin only)
- The banner must not be dismissible by non-superadmin users
- The intent: anyone using the system knows that elevated logging is active.
  This applies in every environment — a developer running debug in staging
  should see the same signal as an operator in production

#### Banner Appearance

- `verbose`: yellow/amber background — informational, non-alarming
- `debug`: orange background — active investigation in progress
- `trace`: red background — maximum signal, treat logs as sensitive
- `silent`: grey background with warning icon — errors may be hidden

---

## Cross-Surface Visibility

When multiple surfaces are involved in a debugging session (e.g., web → API →
background worker), the aggregate verbosity picture must be inspectable:

- Each surface's `GET /internal/obs` (or equivalent) must be reachable by the
  debugging actor
- The admin UI verbosity panel (when present) should show the level of all known
  surfaces in a single view
- AI tooling (Claude, agents) should be directed to query each surface's obs
  endpoint at the start of a debugging session to understand what signal is
  available before issuing requests

---

## Examples

### Good — Level control endpoint (Hono/TypeScript)

```typescript
import { requireSuperadmin, writePlatformAudit } from "../middleware/superadmin.js";
import { obsConfig } from "../lib/obs-config.js";

obsRoutes.get("/internal/obs", requireSuperadmin, async (c) => {
  return c.json(await obsConfig.get());
});

obsRoutes.post("/internal/obs", requireSuperadmin, async (c) => {
  const actorId = c.get("clerkUserId");
  const { level } = await c.req.json();
  const previous = await obsConfig.getLevel();

  const result = await obsConfig.set(level);
  if (!result.ok) return c.json({ error: result.error }, 400);

  await writePlatformAudit({
    actorId,
    action: "obs.level.changed",
    metadata: { previous, next: level, source: "api" },
  });

  return c.json({ level, changedBy: actorId, changedAt: new Date().toISOString() });
});
```

### Good — Structured log entry with obs_level propagated

```typescript
logger.info({
  obs_level: currentLevel,
  correlationId: req.headers["x-correlation-id"],
  action: "patient.dose.recorded",
  patientId: patient.id,
  ...(obsLevel >= OBS.debug && { rawPayload: req.body }),
  ...(obsLevel >= OBS.verbose && { durationMs: Date.now() - start }),
});
```

### Good — Outbound request with level header

```typescript
const response = await fetch(upstreamUrl, {
  headers: {
    "Authorization": `Bearer ${token}`,
    "X-Obs-Level": currentObsLevel,
    "X-Correlation-Id": correlationId,
  },
});
```

### Good — Elevated verbosity banner (React)

```tsx
{obsLevel > OBS.normal && (
  <ObsBanner
    level={obsLevel}
    activatedBy={obs.changedBy}
    activatedAt={obs.changedAt}
    surfaces={obs.surfaces}
  />
)}
```

### Bad — Static logging with no runtime control

```typescript
// No way to get more signal without a code change and redeploy
app.use(logger()); // always on, always the same
console.error("[bloodwork] parse failed:", err); // unstructured, not level-gated
```

### Bad — Verbosity change with no audit

```typescript
// Sets level but leaves no trace of who changed it or when
await db.config.update({ key: "log_level", value: "debug" });
```

### Bad — UI control without confirmation or banner

```tsx
// Single-click level change, no confirmation, no visible signal to other users
<Select onChange={(v) => setLogLevel(v)} />
```

---

## Implementation Checklist for New Applications

When implementing AP-007 for a new application, follow this sequence:

1. **Plumbing first** — config storage, `GET`/`POST /internal/obs`, audit writes, structured log propagation
2. **Confirm with the team** whether the full UI treatment (banner + admin controls) is in scope for this iteration
3. **UI treatment** — verbosity panel in admin UI, elevated banner, confirmation dialog

AI agents implementing this principle should ask the developer at the start of
implementation: *"Should I implement the full UI treatment (banner + admin controls)
or just the plumbing (config + API + audit) for this iteration?"*

---

## Validation Checklist

- [ ] Verbosity config persists across restarts (not in-process memory only)
- [ ] Default level is `normal` in all environments
- [ ] `GET /internal/obs` returns current level, actor, and timestamp
- [ ] `POST /internal/obs` is protected by highest-privilege gate
- [ ] Every level change writes an audit entry (including rejected attempts)
- [ ] `obs_level` field present in all structured log entries
- [ ] `X-Obs-Level` header propagated on outbound cross-service requests
- [ ] Secret redaction filter active at `trace` level
- [ ] If admin UI exists: verbosity panel present, superadmin-gated
- [ ] If admin UI exists: elevated banner shown to all users when level > `normal`
- [ ] If admin UI exists: level change requires explicit confirmation step
- [ ] AI debugging sessions start with a query to each surface's obs endpoint
