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
- Dedicated debug Chrome running on port 19512 (persistent profile at `~/.chrome-gmail-debug`):

  ```bash
  /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
    --remote-debugging-port=19512 \
    --user-data-dir="$HOME/.chrome-gmail-debug" \
    --no-first-run --no-default-browser-check \
    "https://mail.google.com" &
  ```

## CDP Connection

All commands must resolve the WebSocket URL from port 19512 and pass it via `BU_CDP_WS`.
Resolve it once before running any command:

```bash
WS=$(curl -s http://localhost:19512/json/version | python3 -c "import sys,json; print(json.load(sys.stdin)['webSocketDebuggerUrl'])")
```

Then prefix every `uv run` command with `BU_CDP_WS="$WS"`.

If port 19512 is not reachable, launch the debug Chrome first (see Requirements above).

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

### Resolve CDP WebSocket (always do this first)

```bash
WS=$(curl -s http://localhost:19512/json/version | python3 -c "import sys,json; print(json.load(sys.stdin)['webSocketDebuggerUrl'])")
```

If the curl fails, launch the debug Chrome first (see Requirements above), then retry.

If the scrape fails with "no close frame received or sent", the browser-harness daemon is stale. Restart it:

```bash
pkill -f "daemon.py" 2>/dev/null; rm -f /tmp/bu-default.sock
GMAIL_WS=$(curl -s http://localhost:19512/json/list | python3 -c "import sys,json; tabs=json.load(sys.stdin); gmail=[t for t in tabs if 'mail.google.com' in t.get('url','')]; print(gmail[0].get('webSocketDebuggerUrl','') if gmail else '')")
cd ~/Play/github_repos/browser-harness && BU_CDP_WS="$GMAIL_WS" .venv/bin/python3 daemon.py &>/tmp/bu-default.log &
sleep 3
```

### If `--check` is in the arguments

```bash
BU_CDP_WS="$WS" uv run ~/.claude/aidev-toolkit/scripts/gmail-digest.py --check
```

Display the result and exit.

### If `--account list` is in the arguments

```bash
BU_CDP_WS="$WS" uv run ~/.claude/aidev-toolkit/scripts/gmail-digest.py --account list
```

Display the account list and exit.

### Otherwise

1. Build the scrape command — always use `--dry-run` to scrape without an API call.
   Pass through `--days`, `--weeks`, `--date`, `--all`, and `--account` if provided:

```bash
BU_CDP_WS="$WS" uv run ~/.claude/aidev-toolkit/scripts/gmail-digest.py --dry-run [flags]
```

1. If exit code is non-zero, display the error and fix:

| Error | Fix |
|---|---|
| `Chrome CDP not reachable` | Launch debug Chrome on port 19512 (see Requirements), retry |
| `browser-harness` not found | `uv tool install -e ~/Developer/browser-harness` |

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

1. If `--output file=/path` was specified, write the final digest to that path and confirm.
   Otherwise print to terminal.
