# aidev-toolkit Security Architecture

**Status:** Proposed (v52 implementation pending)
**Last updated:** 2026-04-18
**Owner:** @jerichoBob

---

## Overview

aidev-toolkit is a developer CLI distributed as shell scripts and markdown. This document describes the security model, trust boundaries, auth flow, and threat model for the toolkit and its supporting infrastructure.

---

## Trust Boundaries

```
┌─────────────────────────────────────────────────────────────────┐
│  USER MACHINE (untrusted)                                       │
│                                                                 │
│  ~/.claude/aidev-toolkit/         ← git clone, scripts         │
│  ~/.claude/aidev-toolkit/.auth    ← signed JWT only (chmod 600) │
│  ~/.claude/aidev-toolkit/.env     ← local config (no secrets)  │
│                                                                 │
│  scripts/auth.sh     ← opens browser, captures JWT             │
│  skills/*.md         ← readable by anyone (by design)          │
└───────────────────────┬─────────────────────────────────────────┘
                        │  HTTPS only
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│  CLOUDFLARE WORKER (trusted server)                             │
│                                                                 │
│  GITHUB_CLIENT_SECRET  ← env var, never leaves this boundary   │
│  JWT_SIGNING_KEY       ← env var, never leaves this boundary   │
│  ALLOWED_USERS / ORG   ← env var, access control list          │
│  KV store              ← state tokens (5 min TTL)              │
└───────────────────────┬─────────────────────────────────────────┘
                        │  OAuth
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│  GITHUB (external IdP)                                          │
│                                                                 │
│  OAuth authorization endpoint                                   │
│  User identity: login, email, name                             │
└─────────────────────────────────────────────────────────────────┘
```

**Key principle:** Secrets never cross the server boundary downward. The CLI only ever holds a signed JWT — which is worthless without the server's signing key to validate it.

---

## Auth Flow

```
User runs: scripts/auth.sh login
           │
           ├─ 1. Generate: random state (32-byte hex), random callback port
           ├─ 2. Start: local HTTP server on 127.0.0.1:{port}
           └─ 3. Open browser to:
                 https://auth.aidev.tools/login?state={state}&port={port}

                        CLOUDFLARE WORKER
                        │
                        ├─ 4. Store state in KV (TTL: 5 min)
                        └─ 5. Redirect to GitHub OAuth:
                              github.com/login/oauth/authorize
                              ?client_id={CLIENT_ID}
                              &scope=read:user,user:email
                              &state={state}

                                    GITHUB
                                    │
                                    └─ 6. User approves → redirect to:
                                          auth.aidev.tools/callback
                                          ?code={code}&state={state}

                        CLOUDFLARE WORKER
                        │
                        ├─ 7. Validate state token (KV lookup + delete)
                        ├─ 8. Exchange code for GitHub access token
                        ├─ 9. Fetch user profile (login, email, name)
                        ├─ 10. Check allowlist / org membership
                        ├─ 11. Issue signed JWT (HMAC-SHA256, 30d expiry)
                        └─ 12. Redirect to:
                               http://127.0.0.1:{port}?token={JWT}

           LOCAL SERVER
           │
           ├─ 13. Capture JWT from query param
           ├─ 14. Write to ~/.claude/aidev-toolkit/.auth (chmod 600)
           ├─ 15. Kill local server
           └─ 16. Print: ✓ Authenticated as @{login}
```

---

## JWT Structure

```json
{
  "header": {
    "alg": "HS256",
    "typ": "JWT"
  },
  "payload": {
    "sub": "github:bseaton",
    "github_login": "bseaton",
    "github_email": "bob@example.com",
    "name": "Bob Seaton",
    "iat": 1713456789,
    "exp": 1716048789
  }
}
```

**Signed with:** HMAC-SHA256 using `JWT_SIGNING_KEY` — exists only in Cloudflare Worker env vars.

**Stored at:** `~/.claude/aidev-toolkit/.auth` — permissions `600`.

**Expiry:** 30 days. Silent refresh if called within 7 days of expiry.

---

## Threat Model

### T1 — Email Bombing / Spam via Verification Endpoint

**Not applicable.** Email-based verification was considered and rejected in favor of GitHub OAuth. There is no "send code to email" endpoint. See decision rationale below.

---

### T2 — OAuth State Token Forgery (CSRF)

**Attack:** Attacker crafts a URL with a known state token, tricks user into completing a forged OAuth flow.

**Mitigation:**
- State tokens are 32-byte random hex (256-bit entropy)
- Stored in Cloudflare KV with 5-minute TTL
- Deleted on first use (single-use)
- Mismatch returns 400

**Residual risk:** Negligible.

---

### T3 — JWT Theft from Local Filesystem

**Attack:** Malware or another process reads `~/.claude/aidev-toolkit/.auth`.

**Mitigation:**
- File permissions `chmod 600` — owner-readable only
- 30-day expiry limits the window
- No long-lived refresh tokens stored locally
- Revocation: remove user from allowlist → next API call fails

**Residual risk:** Low. Equivalent risk to any stored credential (SSH keys, `~/.netrc`, etc). User's machine security is the user's responsibility.

---

### T4 — Local Callback Server Hijacking

**Attack:** Another process on the machine binds to the same port before `auth.sh`, captures the JWT.

**Mitigation:**
- Bind to `127.0.0.1` only (not `0.0.0.0`)
- Random port (1024–65535) — hard to predict
- 60-second timeout; server exits immediately after capturing one request

**Residual risk:** Very low. Requires malware already running on the machine.

---

### T5 — GitHub OAuth Client Secret Exposure

**Attack:** Client secret leaked → attacker can impersonate the OAuth App and exchange codes for tokens.

**Mitigation:**
- Secret stored ONLY in Cloudflare Worker environment variables
- Never committed to the repo (even accidentally — repo does not contain a `.env` with secrets)
- If leaked: rotate immediately via GitHub OAuth App settings

**Residual risk:** Low with current controls. Cloudflare env vars are encrypted at rest.

---

### T6 — Unauthorized User Gains Access

**Attack:** A valid GitHub user who is not an authorized toolkit user authenticates successfully.

**Mitigation:**
- Worker checks `ALLOWED_GITHUB_USERS` (comma-separated) or `ALLOWED_GITHUB_ORG` before issuing JWT
- Non-allowlisted users receive a 403 with a clear message — no JWT issued

**Residual risk:** None if allowlist is maintained.

---

### T7 — Brute Force / DoS on Auth Worker

**Attack:** Flood `/login` or `/callback` to exhaust rate limits or degrade availability.

**Mitigation:**
- Cloudflare rate limiting: max 10 requests/IP/hour on auth routes
- Cloudflare DDoS protection is automatic (it's Cloudflare)
- State token KV TTL means stale requests fail fast

**Residual risk:** Low.

---

### T8 — Script Readability — "Security Through Obscurity" is Not the Model

The shell scripts are intentionally readable. This is NOT a vulnerability. The security model does not rely on obscurity:

- The JWT signing key never appears in scripts
- The OAuth client secret never appears in scripts
- An attacker reading `scripts/auth.sh` learns: "it calls `auth.aidev.tools` and gets a JWT." Without the signing key, that JWT is useless as a forgery target.

Compare: `gh` CLI is open source. Its auth scripts are fully readable. GitHub's security comes from server-side secrets, not client obscurity.

---

## Access Control Model

### Current (v52): Allowlist

```
ALLOWED_GITHUB_USERS=bseaton,collaborator2,collaborator3
```

Simple, maintainer-controlled. Suitable for small trusted user base.

### Future (v49 Monetization): Entitlement Check

```
Worker checks: does this GitHub login have an active subscription?
  └─ query entitlement DB (Stripe customer lookup or similar)
  └─ issue JWT with tier claims: { "tier": "pro", "features": ["sdd", "aws-costs"] }
```

Feature flags become JWT claims. No code changes needed in CLI — just new claims in the token.

---

## What Is NOT Stored on User Machines

| Item | Location |
|------|----------|
| GitHub OAuth client_secret | Cloudflare Worker env only |
| JWT signing key | Cloudflare Worker env only |
| User allowlist | Cloudflare Worker env only |
| Cloudflare API token | Maintainer's machine only (deploy-time) |

---

## Key Design Decisions

### Why GitHub OAuth, not email verification?

Email verification requires an exposed endpoint that accepts arbitrary email addresses and sends codes — creating an email bombing attack surface and requiring email credentials to exist somewhere accessible. GitHub OAuth delegates the "prove who you are" problem to GitHub, which already solved it.

### Why Cloudflare Workers, not AWS Lambda / Vercel?

- Zero cold starts — auth callbacks must be fast
- Free tier covers thousands of auth events/day
- Cloudflare rate limiting is a first-class primitive
- Deployment is a single `wrangler deploy` command

### Why HMAC-SHA256, not RSA?

The Worker is both issuer and validator in v52. Asymmetric keys would be needed if a second service needed to independently verify JWTs without calling back to the Worker. That's a future concern (v49+). HMAC is simpler and fast.

### Why local callback server, not "copy the code"?

UX. `gh auth login` and Claude Code both use local callback. Users expect it. The "copy a code" pattern creates support burden ("I pasted the code but it says invalid") and is slower.

---

## File Reference

| File | Purpose |
|------|---------|
| `scripts/auth.sh` | CLI auth: login, status, logout, token, refresh |
| `infra/auth-worker/` | Cloudflare Worker source |
| `infra/auth-worker/README.md` | Worker deployment guide |
| `docs/auth-setup.md` | GitHub OAuth App creation guide (maintainer) |
| `~/.claude/aidev-toolkit/.auth` | Stored JWT (user machine, chmod 600) |

---

## Future Considerations

- **Token refresh**: Silent background refresh when token is within 7 days of expiry
- **Org-based access**: Switch from per-user allowlist to GitHub org membership check
- **Entitlement tiers**: Add `tier` and `features` claims to JWT for v49 monetization
- **Audit log**: Worker logs each auth event (GitHub login, timestamp, IP) to Cloudflare Analytics
- **Token revocation endpoint**: `POST /revoke` — marks a `sub` as revoked in KV until token expiry
