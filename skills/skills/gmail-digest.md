---
name: gmail-digest
description: Run the Gmail Morning Digest — scrape unread emails and categorize them by urgency via Claude.
argument-hint: [--days N | --weeks N | --date YYYY-MM-DD | --all | --account N/email/list | --check | --output file=/path | --dry-run]
allowed-tools: Bash(uv:*), Write(*)
---

# Gmail Morning Digest

Scrape Gmail via browser-harness, then categorize and summarize inline.
No API key required — Claude Code handles the analysis.

## Requirements

- `browser-harness` installed: `uv tool install -e ~/Developer/browser-harness`
- Chrome running with remote debugging enabled: visit `chrome://inspect/#remote-debugging` and tick Allow

## Arguments

- **(empty)**: Unread emails from today, default account
- **--days N**: Last N days instead of just today
- **--weeks N**: Last N weeks (shorthand for --days N×7)
- **--date YYYY-MM-DD**: A specific date instead of today
- **--all**: Include read emails (default: unread only)
- **--account N**: Use Gmail /u/N/ index within the active Chrome profile (0=default)
- **--account email@domain**: Target any account across any Chrome profile (launches dedicated Chrome)
- **--account list**: Show all logged-in Gmail accounts and exit
- **--check**: Verify Chrome CDP is reachable, then exit
- **--output file=/path**: Write the final digest to a file
- **--dry-run**: Print raw scraped emails only, skip categorization

## Instructions

### If `--check` is in the arguments:

```bash
uv run ~/.claude/aidev-toolkit/scripts/gmail-digest.py --check
```

Display the result and exit.

### If `--account list` is in the arguments:

```bash
uv run ~/.claude/aidev-toolkit/scripts/gmail-digest.py --account list
```

Display the account list and exit.

### Otherwise:

1. Build the scrape command — always use `--dry-run` to scrape without an API call.
   Pass through `--days`, `--weeks`, `--date`, `--all`, and `--account` if provided:

```bash
uv run ~/.claude/aidev-toolkit/scripts/gmail-digest.py --dry-run [flags]
```

2. If exit code is non-zero, display the error and fix:

| Error | Fix |
|---|---|
| `Chrome CDP not reachable` | Visit `chrome://inspect/#remote-debugging`, tick Allow, retry |
| `browser-harness` not found | `uv tool install -e ~/Developer/browser-harness` |

3. If the output contains `Inbox clear` — print that and exit.

4. If `--dry-run` was explicitly passed — print the raw list and exit.

5. Otherwise, categorize the emails. Rules:
   - Real people and action-required items **FIRST**
   - Security alerts, expiring offers, account notices near the top
   - Newsletters, digests, and marketing **LAST**
   - Name categories from what's actually there — no generic buckets
   - Skip snippet text that is clearly whitespace padding (long runs of `͏` or `·`)
   - For multi-day ranges, group by day within each category if helpful

6. Format the digest:

```
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

7. If `--output file=/path` was specified, write the final digest to that path and confirm.
   Otherwise print to terminal.
