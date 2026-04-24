#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""
Gmail Morning Digest — scrape Gmail emails via browser-harness.

Usage:
  uv run scripts/gmail-digest.py [options]

Options:
  --days N            Scrape the last N days (default: 1 = today)
  --weeks N           Scrape the last N weeks (shorthand for --days N*7)
  --date YYYY-MM-DD   Scrape a specific date instead of today
  --all               Include read emails (default: unread only)
  --account N         Gmail account index, 0-based (default: 0)
  --account list      List all logged-in Gmail accounts and exit
  --output file=PATH  Write email list to a file instead of stdout
  --dry-run           Alias for normal behavior (kept for compatibility)
  --check             Validate Chrome CDP is reachable, then exit

Scheduling (macOS launchd):
  1. Visit chrome://inspect/#remote-debugging and tick Allow (once per profile).

  2. Create ~/Library/LaunchAgents/com.user.gmail-digest.plist and load it:
       launchctl load ~/Library/LaunchAgents/com.user.gmail-digest.plist
"""

import argparse
import json
import subprocess
import sys
from datetime import date, timedelta
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


# ── account listing ────────────────────────────────────────────────────────

def list_accounts() -> list[dict]:
    """
    Read logged-in Gmail accounts from Chrome's local Preferences files.
    Returns list of {profile, email, name} for every account found across all profiles.
    No browser navigation needed — instant and accurate.
    """
    chrome_dir = Path.home() / "Library/Application Support/Google/Chrome"
    if not chrome_dir.exists():
        return []

    accounts = []
    for prefs_path in sorted(chrome_dir.glob("*/Preferences")):
        try:
            prefs = json.loads(prefs_path.read_text(encoding="utf-8", errors="ignore"))
            for info in prefs.get("account_info", []):
                email = info.get("email", "")
                if "@" in email:
                    accounts.append({
                        "profile": prefs_path.parent.name,
                        "email": email,
                        "name": info.get("full_name", ""),
                    })
        except Exception:
            continue

    return accounts


# ── scraping ───────────────────────────────────────────────────────────────

def check_chrome() -> bool:
    try:
        _run_browser("import json; print(json.dumps(page_info()))", timeout=10)
        return True
    except Exception as e:
        print(f"Chrome CDP not reachable: {e}", file=sys.stderr)
        return False


def scrape_emails(
    days: int = 1,
    target_date: str | None = None,
    include_read: bool = False,
    account: int = 0,
) -> tuple[list[dict], str]:
    """
    Scrape Gmail via browser-harness.
    Returns (emails, label) where label describes the time range scraped.
    emails is a list of {sender, subject, snippet, time}.
    """
    base = f"https://mail.google.com/mail/u/{account}"
    row_selector = "tr.zA" if include_read else "tr.zA.zE"

    # Build URL and label based on mode
    if target_date:
        d = date.fromisoformat(target_date)
        next_d = d + timedelta(days=1)
        search = f"after:{d.strftime('%Y/%m/%d')}+before:{next_d.strftime('%Y/%m/%d')}"
        url = f"{base}/#search/{search}"
        filter_today = False
        label = target_date
    elif days > 1:
        url = f"{base}/#search/newer_than:{days}d"
        filter_today = False
        label = f"last {days} days"
    else:
        url = f"{base}/#inbox"
        filter_today = True
        label = date.today().isoformat()

    email_type = "emails" if include_read else "unread emails"
    print(f"Scraping {email_type} ({label})...", file=sys.stderr)

    # filter_today_js: JS expression — true means keep the row, false means skip
    filter_expr = (
        '":" in (timeText || "")' if filter_today else "true"
    )

    scraping_code = f"""
import json

goto("{url}")
wait(2.0)
wait_for_load(timeout=20)
wait(2.0)

raw = js('''(function() {{
    var rows = document.querySelectorAll("{row_selector}");
    var emails = [];
    rows.forEach(function(row) {{
        var timeEl   = row.querySelector(".xW span, .xW");
        var timeText = timeEl ? (timeEl.getAttribute("title") || timeEl.textContent || "").trim() : "";
        if (!({filter_expr})) return;
        var sender   = (row.querySelector(".yX, .zF")                   || {{textContent:""}}).textContent.trim();
        var subject  = (row.querySelector(".y6 span:first-child, .bog") || {{textContent:""}}).textContent.trim();
        var snippet  = (row.querySelector(".y2")                        || {{textContent:""}}).textContent.trim();
        if (sender || subject) emails.push({{sender:sender, subject:subject, snippet:snippet, time:timeText}});
    }});
    return JSON.stringify(emails);
}})()''')

print(raw or "[]")
"""

    try:
        output = _run_browser(scraping_code, timeout=60)
    except RuntimeError as e:
        print(f"Scraping failed: {e}", file=sys.stderr)
        return [], label

    try:
        emails = json.loads(output.strip())
    except json.JSONDecodeError:
        print(f"Warning: could not parse email JSON: {output[:200]}", file=sys.stderr)
        return [], label

    print(f"Found {len(emails)} {email_type} ({label})", file=sys.stderr)
    return emails, label


# ── output ─────────────────────────────────────────────────────────────────

def print_emails(emails: list[dict], label: str, include_read: bool, output: str) -> None:
    kind = "emails" if include_read else "unread emails"
    lines = [f"--- {len(emails)} {kind} ({label}) ---\n"]
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
        description="Gmail Morning Digest — scrape Gmail emails via browser-harness."
    )
    parser.add_argument("--days", type=int, default=None, help="Scrape the last N days (default: 1)")
    parser.add_argument("--weeks", type=int, default=None, help="Scrape the last N weeks")
    parser.add_argument("--date", default=None, help="Specific date to scrape (YYYY-MM-DD)")
    parser.add_argument("--all", action="store_true", help="Include read emails (default: unread only)")
    parser.add_argument("--account", default="0", help="Account index (0=default) or 'list'")
    parser.add_argument("--output", default="terminal", help="Output: terminal (default) or file=/path")
    parser.add_argument("--dry-run", action="store_true", help="Alias for normal behavior (kept for compatibility)")
    parser.add_argument("--check", action="store_true", help="Validate Chrome CDP is reachable, then exit")
    args = parser.parse_args()

    if args.check:
        if check_chrome():
            print("✓ Chrome CDP is reachable (daemon alive)")
            sys.exit(0)
        else:
            print("✗ Chrome CDP is not reachable.")
            print("  Visit chrome://inspect/#remote-debugging and tick Allow, then retry.")
            sys.exit(1)

    # Resolve account
    if args.account == "list":
        accounts = list_accounts()
        if not accounts:
            print("No Gmail accounts found in Chrome profiles.")
            sys.exit(1)
        print(f"\nLogged-in Gmail accounts ({len(accounts)} total):\n")
        for a in accounts:
            name = f"  {a['name']}" if a.get("name") else ""
            print(f"  [{a['profile']}]  {a['email']}{name}")
        sys.exit(0)

    try:
        account_index = int(args.account)
    except ValueError:
        sys.exit(f"--account must be an integer or 'list', got: {args.account}")

    # Resolve day count
    if args.weeks is not None:
        days = args.weeks * 7
    elif args.days is not None:
        days = args.days
    else:
        days = 1

    emails, label = scrape_emails(
        days=days,
        target_date=args.date,
        include_read=getattr(args, "all"),
        account=account_index,
    )

    if not emails:
        kind = "emails" if getattr(args, "all") else "unread emails"
        print(f"No {kind} found ({label}). Inbox clear!")
        sys.exit(0)

    print_emails(emails, label, getattr(args, "all"), args.output)


if __name__ == "__main__":
    main()
