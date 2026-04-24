#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""
Gmail Morning Digest — scrape today's unread emails via browser-harness.

Usage:
  uv run scripts/gmail-digest.py [options]

Options:
  --date YYYY-MM-DD   Scrape a specific date (default: today)
  --output file=PATH  Write email list to a file instead of stdout
  --dry-run           Alias for normal behavior (kept for compatibility)
  --check             Validate Chrome CDP is reachable, then exit

Scheduling (macOS launchd):
  1. Visit chrome://inspect/#remote-debugging and tick Allow (once per profile).

  2. Create ~/Library/LaunchAgents/com.user.gmail-digest.plist:
       <?xml version="1.0" encoding="UTF-8"?>
       <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
         "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
       <plist version="1.0"><dict>
         <key>Label</key><string>com.user.gmail-digest</string>
         <key>ProgramArguments</key><array>
           <string>/bin/bash</string>
           <string>-c</string>
           <string>cd /path/to/aidev-toolkit && uv run scripts/gmail-digest.py --output file=/tmp/gmail-digest.txt</string>
         </array>
         <key>StartCalendarInterval</key><dict>
           <key>Hour</key><integer>7</integer>
           <key>Minute</key><integer>30</integer>
         </dict>
         <key>StandardOutPath</key><string>/tmp/gmail-digest.log</string>
         <key>StandardErrorPath</key><string>/tmp/gmail-digest.err</string>
       </dict></plist>

  3. Load it: launchctl load ~/Library/LaunchAgents/com.user.gmail-digest.plist
"""

import argparse
import json
import subprocess
import sys
from datetime import date
from pathlib import Path

BROWSER_HARNESS_CMD = "browser-harness"


# ── browser-harness bridge ─────────────────────────────────────────────────

def _run_browser(code: str, timeout: int = 60) -> str:
    if not _browser_harness_available():
        sys.exit(
            "Error: browser-harness CLI not found.\n"
            "Install: uv tool install -e ~/Developer/browser-harness"
        )
    result = subprocess.run(
        [BROWSER_HARNESS_CMD],
        input=code,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "browser-harness exited non-zero")
    return result.stdout


def _browser_harness_available() -> bool:
    return subprocess.run(
        ["command", "-v", BROWSER_HARNESS_CMD],
        shell=False,
        capture_output=True,
    ).returncode == 0 or Path(
        subprocess.run(
            ["which", BROWSER_HARNESS_CMD], capture_output=True, text=True
        ).stdout.strip()
    ).exists()


# ── scraping ───────────────────────────────────────────────────────────────

def check_chrome() -> bool:
    try:
        _run_browser("import json; print(json.dumps(page_info()))", timeout=10)
        return True
    except Exception as e:
        print(f"Chrome CDP not reachable: {e}", file=sys.stderr)
        return False


def scrape_todays_unread(target_date: str | None = None) -> list[dict]:
    """
    Scrape Gmail inbox via browser-harness.
    Returns list of {sender, subject, snippet, time}.
    """
    if target_date is None:
        target_date = date.today().isoformat()

    print("Navigating to Gmail inbox...", file=sys.stderr)

    # Gmail unread rows: zA + zE. Time cell shows "H:MM AM/PM" for today, "Mon DD" for older.
    scraping_code = """\
import json

goto("https://mail.google.com/mail/u/0/#inbox")
wait(2.0)
wait_for_load(timeout=20)
wait(2.0)

raw = js('''(function() {
    var rows = document.querySelectorAll("tr.zA.zE");
    var emails = [];
    rows.forEach(function(row) {
        var timeEl   = row.querySelector(".xW span, .xW");
        var timeText = timeEl ? (timeEl.getAttribute("title") || timeEl.textContent || "").trim() : "";
        var sender   = (row.querySelector(".yX, .zF")                   || {textContent:""}).textContent.trim();
        var subject  = (row.querySelector(".y6 span:first-child, .bog") || {textContent:""}).textContent.trim();
        var snippet  = (row.querySelector(".y2")                        || {textContent:""}).textContent.trim();
        if (sender || subject) emails.push({sender:sender, subject:subject, snippet:snippet, time:timeText});
    });
    return JSON.stringify(emails);
})()''')

print(raw or "[]")
"""

    try:
        output = _run_browser(scraping_code, timeout=60)
    except RuntimeError as e:
        print(f"Scraping failed: {e}", file=sys.stderr)
        return []

    try:
        emails = json.loads(output.strip())
    except json.JSONDecodeError:
        print(f"Warning: could not parse email JSON: {output[:200]}", file=sys.stderr)
        return []

    today = date.today().isoformat()
    if target_date == today:
        emails = [e for e in emails if ":" in e.get("time", "")]

    print(f"Found {len(emails)} unread email(s) from {target_date}", file=sys.stderr)
    return emails


# ── output ─────────────────────────────────────────────────────────────────

def print_emails(emails: list[dict], target_date: str, output: str) -> None:
    lines = [f"--- {len(emails)} unread emails for {target_date} ---\n"]
    for i, e in enumerate(emails, 1):
        lines.append(f"{i:>3}. [{e.get('time', '?')}] {e['sender']} — {e['subject']}")
        if e.get("snippet"):
            lines.append(f"       {e['snippet'][:120]}")
    text = "\n".join(lines)

    if output and output.startswith("file="):
        path = output[5:]
        Path(path).write_text(text)
        print(f"Email list written to {path}", file=sys.stderr)
    else:
        print(text)


# ── main ───────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Gmail Morning Digest — scrape today's unread emails."
    )
    parser.add_argument("--date", default=None, help="Date to scrape (YYYY-MM-DD, default: today)")
    parser.add_argument("--output", default="terminal", help="Output: terminal (default) or file=/path")
    parser.add_argument("--dry-run", action="store_true", help="Alias for normal behavior (kept for compatibility)")
    parser.add_argument("--check", action="store_true", help="Validate Chrome CDP is reachable, then exit")
    args = parser.parse_args()

    target_date = args.date or date.today().isoformat()

    if args.check:
        if check_chrome():
            print("✓ Chrome CDP is reachable (daemon alive)")
            sys.exit(0)
        else:
            print("✗ Chrome CDP is not reachable.")
            print('  Visit chrome://inspect/#remote-debugging and tick Allow, then retry.')
            sys.exit(1)

    emails = scrape_todays_unread(target_date)

    if not emails:
        print(f"No unread emails found for {target_date}. Inbox clear!")
        sys.exit(0)

    print_emails(emails, target_date, args.output)


if __name__ == "__main__":
    main()
