#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "anthropic>=0.40.0",
# ]
# ///
"""
Gmail Morning Digest — categorize today's unread emails via Claude.

Usage:
  uv run scripts/gmail-digest.py [options]

Options:
  --date YYYY-MM-DD   Scrape a specific date (default: today)
  --output terminal   Output destination: terminal (default), file=/path
  --output file=PATH  Write digest to a file instead of stdout
  --output slack      (stub) Post digest to Slack
  --output imessage   (stub) Send digest via iMessage
  --dry-run           Print raw emails without calling the Claude API
  --check             Validate Chrome CDP is reachable, then exit
  --verbose           Show token usage and timing info

Scheduling (macOS launchd):
  1. Start Chrome with remote debugging (do this once, or add to login items):
       open -a "Google Chrome" --args --remote-debugging-port=9222

  2. Create ~/Library/LaunchAgents/com.user.gmail-digest.plist:
       <?xml version="1.0" encoding="UTF-8"?>
       <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
         "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
       <plist version="1.0"><dict>
         <key>Label</key><string>com.user.gmail-digest</string>
         <key>ProgramArguments</key><array>
           <string>/bin/bash</string>
           <string>-c</string>
           <string>cd /path/to/aidev-toolkit && uv run scripts/gmail-digest.py --output file=/tmp/gmail-digest.md</string>
         </array>
         <key>StartCalendarInterval</key><dict>
           <key>Hour</key><integer>7</integer>
           <key>Minute</key><integer>30</integer>
         </dict>
         <key>EnvironmentVariables</key><dict>
           <key>ANTHROPIC_API_KEY</key><string>YOUR_KEY_HERE</string>
         </dict>
         <key>StandardOutPath</key><string>/tmp/gmail-digest.log</string>
         <key>StandardErrorPath</key><string>/tmp/gmail-digest.err</string>
       </dict></plist>

  3. Load it: launchctl load ~/Library/LaunchAgents/com.user.gmail-digest.plist
"""

import argparse
import json
import os
import sys
import time
from datetime import date
from pathlib import Path

# ── browser-harness setup ──────────────────────────────────────────────────
BH_PATH = Path.home() / "Play" / "github_repos" / "browser-harness"
if not BH_PATH.exists():
    sys.exit(
        f"Error: browser-harness not found at {BH_PATH}\n"
        "Clone it: git clone <repo> ~/Play/github_repos/browser-harness"
    )
sys.path.insert(0, str(BH_PATH))

try:
    from admin import ensure_daemon, daemon_alive
    from helpers import goto, js, wait, wait_for_load
except ImportError as e:
    sys.exit(f"Error importing browser-harness helpers: {e}")

# ── constants ──────────────────────────────────────────────────────────────
GMAIL_INBOX_URL = "https://mail.google.com/mail/u/0/#inbox"
ANTHROPIC_MODEL = "claude-sonnet-4-6"

SYSTEM_PROMPT = """\
You are an email triage assistant. Given a list of today's unread emails (sender, \
subject, snippet), categorize them into meaningful groups that emerge from the content.

Rules:
- Always place "Action Required" or "Real People" categories FIRST
- Security alerts, expiring offers, account notices go near the top
- Newsletters, promotions, and marketing go LAST
- Create category names from what's actually there — don't force content into generic buckets
- Keep each entry concise: one line per email showing sender and subject
- Lead each section with a header: ## Category Name (N emails)
- If an email is clearly urgent (security breach, expiring in <24h), prefix it with ⚠️

Output only the formatted digest, no preamble.
"""

# ── scraping ───────────────────────────────────────────────────────────────

def check_chrome() -> bool:
    """Return True if the browser-harness daemon is reachable."""
    try:
        ensure_daemon()
        result = js("document.readyState")
        return result is not None
    except Exception as e:
        print(f"Chrome CDP not reachable: {e}", file=sys.stderr)
        return False


def scrape_todays_unread(target_date: str | None = None) -> list[dict]:
    """
    Attach to Chrome, navigate to Gmail inbox, and extract unread emails
    from the target date (default: today).

    Returns list of {sender, subject, snippet, time}.
    """
    ensure_daemon()

    if target_date is None:
        target_date = date.today().isoformat()

    print(f"Navigating to Gmail inbox...", file=sys.stderr)
    goto(GMAIL_INBOX_URL)
    wait(2.0)
    wait_for_load(timeout=20)

    # Give Gmail's JS time to render the email list
    wait(2.0)

    # Extract unread email rows.
    # Gmail marks unread rows with classes zA + zE.
    # Time cells show "H:MM AM/PM" for today, "Mon DD" for older.
    # We filter by checking if the time text contains ":" (today's format).
    extract_js = """
(function() {
    var rows = document.querySelectorAll('tr.zA.zE');
    var emails = [];
    rows.forEach(function(row) {
        // Time cell — today shows "2:30 PM", older shows "Apr 18"
        var timeEl = row.querySelector('.xW span, .xW');
        var timeText = timeEl ? (timeEl.getAttribute('title') || timeEl.textContent || '').trim() : '';

        // Sender name
        var senderEl = row.querySelector('.yX, .zF');
        var sender = senderEl ? senderEl.textContent.trim() : '';

        // Subject + snippet are in the same cell, separated by " - "
        var subjectEl = row.querySelector('.y6 span:first-child, .bog');
        var subject = subjectEl ? subjectEl.textContent.trim() : '';

        var snippetEl = row.querySelector('.y2');
        var snippet = snippetEl ? snippetEl.textContent.trim() : '';

        if (sender || subject) {
            emails.push({
                sender: sender,
                subject: subject,
                snippet: snippet,
                time: timeText
            });
        }
    });
    return JSON.stringify(emails);
})()
"""

    raw = js(extract_js)
    if not raw:
        return []

    try:
        emails = json.loads(raw)
    except json.JSONDecodeError:
        print(f"Warning: could not parse email JSON: {raw[:200]}", file=sys.stderr)
        return []

    # Filter to today's date if target_date is today
    today = date.today().isoformat()
    if target_date == today:
        # Today's emails have time in H:MM format (contains ":")
        # The title attribute on the time element shows the full datetime
        emails = [e for e in emails if ":" in e.get("time", "")]

    print(f"Found {len(emails)} unread email(s) from {target_date}", file=sys.stderr)
    return emails


# ── categorization ─────────────────────────────────────────────────────────

def categorize_with_claude(emails: list[dict], verbose: bool = False) -> str:
    """
    Send the email list to Claude for categorization.
    Uses prompt caching on the system prompt to reduce cost on repeated runs.
    Returns the formatted digest string.
    """
    import anthropic

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        sys.exit("Error: ANTHROPIC_API_KEY environment variable not set")

    client = anthropic.Anthropic(api_key=api_key)

    # Format emails as a numbered list for the prompt
    email_lines = []
    for i, e in enumerate(emails, 1):
        line = f"{i}. From: {e['sender']} | Subject: {e['subject']}"
        if e.get("snippet"):
            line += f" | Snippet: {e['snippet'][:120]}"
        if e.get("time"):
            line += f" | Time: {e['time']}"
        email_lines.append(line)

    user_content = "Today's unread emails:\n\n" + "\n".join(email_lines)

    t0 = time.time()
    response = client.messages.create(
        model=ANTHROPIC_MODEL,
        max_tokens=2048,
        system=[
            {
                "type": "text",
                "text": SYSTEM_PROMPT,
                "cache_control": {"type": "ephemeral"},  # prompt caching
            }
        ],
        messages=[{"role": "user", "content": user_content}],
    )
    elapsed = time.time() - t0

    if verbose:
        usage = response.usage
        cache_hit = getattr(usage, "cache_read_input_tokens", 0)
        cache_write = getattr(usage, "cache_creation_input_tokens", 0)
        print(
            f"\n[API] model={ANTHROPIC_MODEL} "
            f"in={usage.input_tokens} out={usage.output_tokens} "
            f"cache_hit={cache_hit} cache_write={cache_write} "
            f"elapsed={elapsed:.1f}s",
            file=sys.stderr,
        )

    return response.content[0].text


# ── output ─────────────────────────────────────────────────────────────────

def render_digest(digest: str, output: str, target_date: str) -> None:
    """Write digest to the configured output destination."""
    header = f"# Gmail Digest — {target_date}\n\n"
    full = header + digest

    if output == "terminal" or output is None:
        print(full)
    elif output.startswith("file="):
        path = output[5:]
        Path(path).write_text(full)
        print(f"Digest written to {path}", file=sys.stderr)
    elif output == "slack":
        print("[stub] Slack output not yet implemented.", file=sys.stderr)
        print(full)
    elif output == "imessage":
        print("[stub] iMessage output not yet implemented.", file=sys.stderr)
        print(full)
    else:
        print(f"Unknown output mode '{output}', falling back to terminal.", file=sys.stderr)
        print(full)


# ── main ───────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Gmail Morning Digest — categorize today's unread emails via Claude."
    )
    parser.add_argument("--date", default=None, help="Date to scrape (YYYY-MM-DD, default: today)")
    parser.add_argument(
        "--output",
        default="terminal",
        help="Output destination: terminal (default), file=/path, slack, imessage",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print raw emails without calling the Claude API",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate Chrome CDP is reachable, then exit",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Show token usage and timing info",
    )
    args = parser.parse_args()

    target_date = args.date or date.today().isoformat()

    if args.check:
        if check_chrome():
            print(f"✓ Chrome CDP is reachable (daemon alive)")
            sys.exit(0)
        else:
            print("✗ Chrome CDP is not reachable. Start Chrome with remote debugging:")
            print('  open -a "Google Chrome" --args --remote-debugging-port=9222')
            sys.exit(1)

    emails = scrape_todays_unread(target_date)

    if not emails:
        print(f"No unread emails found for {target_date}. Inbox clear!")
        sys.exit(0)

    if args.dry_run:
        print(f"\n--- {len(emails)} unread emails for {target_date} (dry run) ---\n")
        for i, e in enumerate(emails, 1):
            print(f"{i:>3}. [{e.get('time', '?')}] {e['sender']} — {e['subject']}")
            if e.get("snippet"):
                print(f"       {e['snippet'][:100]}")
        sys.exit(0)

    if args.verbose:
        print(f"Categorizing {len(emails)} emails with Claude...", file=sys.stderr)

    digest = categorize_with_claude(emails, verbose=args.verbose)
    render_digest(digest, args.output, target_date)


if __name__ == "__main__":
    main()
