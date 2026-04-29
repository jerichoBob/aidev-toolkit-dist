---
name: aid-login
tier: extended
description: Authenticate with GitHub via browser-based OAuth. Stores a verified JWT so spec ownership and future paid features know who you are.
argument-hint: [status | logout | refresh]
allowed-tools: Bash(~/.claude/aidev-toolkit/scripts/auth.sh:*)
model: sonnet
---

# aidev-toolkit Login

Authenticate with GitHub so aidev-toolkit knows who you are.

## Arguments

- **(empty)**: Log in via browser (GitHub OAuth)
- **status**: Show who is logged in and when the token expires
- **logout**: Remove saved credentials
- **refresh**: Renew token if within 7 days of expiry

## Instructions

Map `$ARGUMENTS` to the correct `auth.sh` subcommand:

| Argument          | Command                                          |
| ----------------- | ------------------------------------------------ |
| empty             | `~/.claude/aidev-toolkit/scripts/auth.sh login`  |
| `status`          | `~/.claude/aidev-toolkit/scripts/auth.sh status` |
| `logout`          | `~/.claude/aidev-toolkit/scripts/auth.sh logout` |
| `refresh`         | `~/.claude/aidev-toolkit/scripts/auth.sh refresh`|

Run the mapped command and relay its output verbatim to the user.

If `auth.sh` is not found at `~/.claude/aidev-toolkit/scripts/auth.sh`, print:

```
aidev-toolkit is not installed. Run the installer first:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jerichoBob/aidev-toolkit/main/scripts/install.sh)"
```

After a successful login, remind the user:
> Your GitHub identity is now used automatically for spec ownership and future API access. Run `/aid-login status` to verify.
