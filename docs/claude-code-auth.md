# Claude Code Authentication Guide

## Two Ways to Authenticate

### 1. Subscription Login (Claude Pro/Max/Teams/Enterprise)

**Fixed monthly fee — recommended for most users**

```bash
claude
/login
```

Authenticates via browser OAuth. No API key needed. Run `/status` inside Claude Code to confirm — it will show your subscription plan.

Per the [official Anthropic docs](https://code.claude.com/docs/en/costs):

> _"Claude Max and Pro subscribers have usage included in their subscription, so `/cost` data isn't relevant for billing purposes."_

This means **no per-token charges** on top of your subscription — all Claude Code usage is included. The `/cost` command (which tracks token spend) is explicitly not relevant for billing if you're a subscriber.

### 2. API Key (Pay-per-token)

**Billed per token via [Anthropic Console](https://console.anthropic.com/) — good for CI/CD, automation, or teams without subscriptions**

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
claude
```

To persist across sessions, add to your shell profile:

```bash
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.zshrc
source ~/.zshrc
```

Or set it in `~/.claude/settings.json`:

```json
{
  "env": {
    "ANTHROPIC_API_KEY": "sk-ant-..."
  }
}
```

## Summary: All Three Ways + Billing

| Method                   | Auth                                     | Billed                               | Billing Location                   |
| ------------------------ | ---------------------------------------- | ------------------------------------ | ---------------------------------- |
| **Personal Pro/Max**     | `/login` with personal claude.ai account | Fixed monthly fee                    | `claude.ai/settings/billing`       |
| **Team/Enterprise seat** | `/login` with team-issued account        | Per seat/month to org admin          | `claude.ai/admin-settings/billing` |
| **API Key**              | `ANTHROPIC_API_KEY` env var              | Per token (auto-replenished credits) | `platform.claude.ai`               |

These are **two completely independent billing systems** — subscription billing on `claude.ai` and API credit billing on `platform.claude.ai` do not talk to each other.

**Adding a new user without API key charges:** Invite them via the Members page on `platform.claude.ai` → they accept → they run `/login` → their usage is covered by your team plan, no API credits consumed.

## Comparison

|          | Subscription (`/login`)    | API Key                            |
| -------- | -------------------------- | ---------------------------------- |
| Billing  | Fixed monthly fee          | Pay-per-token                      |
| Setup    | Browser login              | Set env var                        |
| Best for | Individual devs, daily use | CI/CD, automation, no subscription |

## Check Your Current Auth

Inside Claude Code, run `/status` — it shows your active auth method, current model, and plan details.

## Notes

- If both are configured, API key takes precedence
- Subscription credentials are stored in macOS Keychain (Linux/Windows: `~/.claude/.credentials.json`)
- To switch from API key back to subscription: `unset ANTHROPIC_API_KEY`, then restart Claude Code
