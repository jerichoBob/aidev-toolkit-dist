---
name: gmail-digest
tier: core
description: Run the Gmail Morning Digest — fetch unread emails via the Gmail API and categorize them by urgency via Claude.
argument-hint: "[--days N | --weeks N | --date YYYY-MM-DD | --all | --account email/list | --check | --output file=/path | --dry-run]"
allowed-tools: Bash(uv:*), Write(*)
---

# Gmail Morning Digest

Fetch Gmail via the official Gmail API (OAuth), then categorize and summarize inline.
No browser, no Chrome CDP, no scraping — works the same on macOS, Linux, and Windows.

## Requirements

- A Google Cloud Console project with the Gmail API (and Drive API) enabled.
- An OAuth 2.0 "Desktop app" client ID downloaded as `config/credentials.json` (relative to the aidev-toolkit install root, i.e. `~/.claude/aidev-toolkit/config/credentials.json`).
- First run opens a browser for a one-time consent flow and caches a token under `config/` (`config/token.json`, or `config/token-{account}.json` for `--account email@domain`). Subsequent runs reuse/refresh the cached token — no browser needed.

## Arguments

- **(empty)**: Unread emails from today, default account
- **--days N**: Last N days instead of just today
- **--weeks N**: Last N weeks (shorthand for --days N×7)
- **--date YYYY-MM-DD**: A specific date instead of today
- **--all**: Include read emails (default: unread only)
- **--account email@domain**: Target a specific Google account (uses/creates `config/token-{account}.json`)
- **--account list**: Show all accounts with a cached token and exit
- **--check**: Validate OAuth credentials/token are usable, then exit
- **--output file=/path**: Write the final digest to a file
- **--dry-run**: Print raw fetched emails only, skip categorization

## Instructions

### If `--check` is in the arguments

```bash
uv run ~/.claude/aidev-toolkit/scripts/gmail-digest.py --check
```

Display the result and exit.

### If `--account list` is in the arguments

```bash
uv run ~/.claude/aidev-toolkit/scripts/gmail-digest.py --account list
```

Display the account list and exit.

### Otherwise

1. Build the fetch command — always use `--dry-run` to fetch without an API call.
   Pass through `--days`, `--weeks`, `--date`, `--all`, and `--account` if provided:

```bash
uv run ~/.claude/aidev-toolkit/scripts/gmail-digest.py --dry-run [flags]
```

1. If exit code is non-zero, display the error and fix:

| Error | Fix |
|---|---|
| `credentials.json not found` | Download OAuth client credentials from Google Cloud Console (Desktop app type) to `~/.claude/aidev-toolkit/config/credentials.json` |
| Browser opens for consent and doesn't return | Complete the consent screen in the browser; the script blocks until `run_local_server` receives the redirect |

1. If the output contains `Inbox clear` — print that and exit.

2. If `--dry-run` was explicitly passed — print the raw list and exit.

3. Otherwise, categorize the emails. Rules:
   - Real people and action-required items **FIRST**
   - Security alerts, expiring offers, account notices near the top
   - Newsletters, digests, and marketing **LAST**
   - Name categories from what's actually there — no generic buckets
   - Skip snippet text that is clearly whitespace padding (long runs of `͏` or `·`)
   - For multi-day ranges, group by day within each category if helpful

4. Format the digest:

```text
# Gmail Digest — {label}
N emails (unread / all)

## Category Name (N emails)
- **Sender** (time) — Subject
  > Snippet if it adds context beyond the subject (truncated ~100 chars)

## Next Category (N emails)
...
```

- Bold the sender name
- Show time or date in parens after the sender
- Include snippet on the next line with `>`, only when it adds context
- Prefix clearly urgent items with ⚠️ (security breach, payment failed, expires <24h)

1. If `--output file=/path` was specified, write the final digest to that path and confirm.
   Otherwise print to terminal.
