# Auth Setup — Maintainer Guide

This document covers the one-time setup steps to deploy the GitHub OAuth authentication
system for aidev-toolkit. End users just run `scripts/auth.sh login` — this guide is
for whoever operates the auth infrastructure.

## Architecture Overview

```
User machine                    Cloudflare Worker              GitHub
─────────────────               ──────────────────             ──────
auth.sh login
  → open browser ─────────────→ GET /login
                                  generate state token
                                  store in KV (5-min TTL)
                                ← redirect to GitHub ─────────→ OAuth consent page
                                                               ← code + state
                                ← GET /callback
                                  validate state (single-use)
                                  exchange code for token ────→ access_token
                                  fetch user profile ─────────→ user + email
                                  check allowlist
                                  sign JWT (HMAC-SHA256)
  ← redirect to localhost:PORT ←
  write JWT to ~/.claude/aidev-toolkit/.auth (chmod 600)
  ✓ Authenticated as @login
```

## Step 1: Create GitHub OAuth App

1. Go to `github.com/settings/applications/new` (or org settings for an org app)
2. Fill in:
   - **Application name**: `aidev-toolkit`
   - **Homepage URL**: `https://github.com/jerichoBob/aidev-toolkit-dist`
   - **Authorization callback URL**: `https://aidev-auth.aidev-toolkit.workers.dev/callback`
3. Click **Register application**
4. On the app page, click **Generate a new client secret**
5. Copy the **Client ID** (public — goes in `scripts/auth.sh` as `AIDEV_CLIENT_ID`)
6. Copy the **Client Secret** (secret — goes in Cloudflare Worker secrets only)

## Step 2: Deploy the Cloudflare Worker

See `infra/auth-worker/README.md` for full deployment instructions. Summary:

```bash
cd infra/auth-worker
npm install
wrangler kv namespace create AUTH_STATE
wrangler kv namespace create AUTH_STATE --preview
# Update wrangler.toml with the KV namespace IDs

wrangler secret put GITHUB_CLIENT_ID
wrangler secret put GITHUB_CLIENT_SECRET
wrangler secret put JWT_SIGNING_KEY       # openssl rand -hex 32
wrangler secret put ALLOWED_GITHUB_USERS  # "jerichoBob,otherusers"

npm run deploy
```

## Step 3: Configure Custom Domain (Optional)

To use `auth.aidev.tools` instead of the default `workers.dev` URL:

1. Add the domain to Cloudflare (must be on Cloudflare DNS)
2. Uncomment the `[routes]` block in `infra/auth-worker/wrangler.toml`
3. Redeploy: `npm run deploy`

## Step 4: Update `scripts/auth.sh`

Set `AIDEV_CLIENT_ID` and `WORKER_URL` in `scripts/auth.sh` to the values from Steps 1–3.

## Step 5: Verify

```bash
# Check Worker is reachable
curl https://auth.aidev.tools/health

# Test login flow end-to-end
scripts/auth.sh login
scripts/auth.sh status
```

## Managing Access

**Add a user:**

```bash
wrangler secret put ALLOWED_GITHUB_USERS  # enter "jerichoBob,newuser"
```

**Remove a user:**

```bash
wrangler secret put ALLOWED_GITHUB_USERS  # enter list without their login
```

Their existing JWT remains valid until expiry (up to 30 days). To revoke immediately,
rotate `JWT_SIGNING_KEY` — this invalidates all tokens and forces all users to re-login.

## Security Notes

- `GITHUB_CLIENT_SECRET` and `JWT_SIGNING_KEY` exist only in Cloudflare Worker environment — never in the repo or on user machines
- State tokens are single-use with 5-minute TTL (CSRF protection)
- Local callback server binds to `127.0.0.1` only, random port
- JWT files are stored `chmod 600` on user machines
- `read:user` and `user:email` are the only GitHub scopes requested
