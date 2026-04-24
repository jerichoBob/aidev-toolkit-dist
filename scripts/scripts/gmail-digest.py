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
  --days N                    Scrape the last N days (default: 1 = today)
  --weeks N                   Scrape the last N weeks (shorthand for --days N*7)
  --date YYYY-MM-DD           Scrape a specific date instead of today
  --all                       Include read emails (default: unread only)
  --account N                 Gmail /u/N/ index within active Chrome profile (default: 0)
  --account email@domain.com  Target a specific account across any Chrome profile
  --account list              List all logged-in Gmail accounts and exit
  --output file=PATH          Write email list to a file instead of stdout
  --dry-run                   Alias for normal behavior (kept for compatibility)
  --check                     Validate Chrome CDP is reachable, then exit

Scheduling (macOS launchd):
  1. Visit chrome://inspect/#remote-debugging and tick Allow (once per profile).

  2. Create ~/Library/LaunchAgents/com.user.gmail-digest.plist and load it:
       launchctl load ~/Library/LaunchAgents/com.user.gmail-digest.plist
"""

import argparse
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import threading
import time
from datetime import date, timedelta
from pathlib import Path

BROWSER_HARNESS_CMD = "browser-harness"
CHROME_BIN = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Large cache directories to skip when copying a Chrome profile
_SKIP_CACHE_DIRS = {
    "Cache", "Code Cache", "GPUCache", "DawnCache", "ShaderCache",
    "VideoDecodeStats", "blob_storage", "databases", "IndexedDB",
    "Service Worker", "Session Storage", "Extension State",
}


# ── browser-harness bridge ─────────────────────────────────────────────────

def _run_browser(code: str, timeout: int = 60, cdp_ws: str | None = None) -> str:
    """
    Run Python code via browser-harness CLI.
    cdp_ws: override CDP WebSocket URL via BU_CDP_WS env var (for non-default profiles).
    """
    if not _browser_harness_available():
        sys.exit(
            "Error: browser-harness CLI not found.\n"
            "Install: uv tool install -e ~/Developer/browser-harness"
        )
    env = None
    if cdp_ws:
        env = os.environ.copy()
        env["BU_CDP_WS"] = cdp_ws

    result = subprocess.run(
        [BROWSER_HARNESS_CMD],
        input=code,
        capture_output=True,
        text=True,
        timeout=timeout,
        env=env,
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


def _find_profile_for_email(email: str) -> str | None:
    """Return the Chrome profile directory name that contains this email, or None."""
    for a in list_accounts():
        if a["email"].lower() == email.lower():
            return a["profile"]
    return None


# ── profile-targeted Chrome launch ────────────────────────────────────────

def _find_free_port(start: int = 9223) -> int:
    for port in range(start, start + 100):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(("", port))
                return port
        except OSError:
            continue
    raise RuntimeError("No free port found in range 9223-9323")


def _copy_profile_minimal(src: Path, dst: Path) -> None:
    """Copy Chrome profile directory, skipping large cache dirs."""
    dst.mkdir(parents=True, exist_ok=True)
    for item in src.iterdir():
        if item.name in _SKIP_CACHE_DIRS:
            continue
        dest = dst / item.name
        try:
            if item.is_file():
                shutil.copy2(item, dest)
            elif item.is_dir():
                shutil.copytree(
                    str(item), str(dest),
                    ignore=shutil.ignore_patterns(*_SKIP_CACHE_DIRS),
                )
        except Exception:
            pass  # skip locked or unreadable files


def _launch_chrome_profile(profile_dir: str, port: int) -> tuple[subprocess.Popen, str, str]:
    """
    Launch a new Chrome instance for the given profile on the given port.
    Copies the profile (sans caches) to a temp dir so it doesn't conflict
    with the running Chrome instance.
    Returns (process, temp_dir, cdp_ws_url). Caller must call _cleanup_chrome().
    """
    chrome_src = Path.home() / "Library/Application Support/Google/Chrome"
    temp_dir = Path(
        subprocess.run(["mktemp", "-d"], capture_output=True, text=True).stdout.strip()
    )

    print(f"  Copying {profile_dir} (no caches)...", file=sys.stderr)
    _copy_profile_minimal(chrome_src / profile_dir, temp_dir / profile_dir)

    local_state = chrome_src / "Local State"
    if local_state.exists():
        shutil.copy2(str(local_state), str(temp_dir))

    print(f"  Starting Chrome on port {port}...", file=sys.stderr)
    proc = subprocess.Popen(
        [
            CHROME_BIN,
            f"--user-data-dir={temp_dir}",
            f"--profile-directory={profile_dir}",
            f"--remote-debugging-port={port}",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-sync",
            "--window-size=1280,800",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )

    # Chrome prints "DevTools listening on ws://..." to stderr when CDP is ready.
    # DevToolsActivePort is not reliably written on macOS; parse stderr instead.
    cdp_ws_found: list[str] = []

    def _read_stderr():
        assert proc.stderr is not None
        for line in proc.stderr:
            m = re.search(r"DevTools listening on (ws://\S+)", line)
            if m:
                cdp_ws_found.append(m.group(1))
                break
        # drain remaining stderr so the pipe doesn't block Chrome
        for _ in proc.stderr:
            pass

    t = threading.Thread(target=_read_stderr, daemon=True)
    t.start()

    deadline = time.time() + 30
    while time.time() < deadline:
        if cdp_ws_found:
            t.join(timeout=1)
            return proc, str(temp_dir), cdp_ws_found[0]
        time.sleep(0.25)

    proc.terminate()
    shutil.rmtree(str(temp_dir), ignore_errors=True)
    raise RuntimeError(f"Chrome on port {port} did not become ready within 30s")


def _cleanup_chrome(proc: subprocess.Popen, temp_dir: str) -> None:
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
    shutil.rmtree(temp_dir, ignore_errors=True)


# ── date parsing ──────────────────────────────────────────────────────────

def _parse_email_date(time_text: str, today: date) -> date | None:
    """
    Parse Gmail's compact time display into a date.
    Today's emails: "1:09 AM" / "12:41 PM"  → today
    This-year dates: "Apr 22"               → parsed with current year
    Cross-year: if parsed date is in the future, use previous year.
    """
    text = time_text.strip()
    if not text:
        return None
    if "AM" in text or "PM" in text:
        return today
    try:
        from datetime import datetime as _dt
        d = _dt.strptime(f"{text} {today.year}", "%b %d %Y").date()
        if d > today:
            d = _dt.strptime(f"{text} {today.year - 1}", "%b %d %Y").date()
        return d
    except ValueError:
        return None


# ── scraping ───────────────────────────────────────────────────────────────

def check_chrome(cdp_ws: str | None = None) -> bool:
    try:
        _run_browser("import json; print(json.dumps(page_info()))", timeout=10, cdp_ws=cdp_ws)
        return True
    except Exception as e:
        print(f"Chrome CDP not reachable: {e}", file=sys.stderr)
        return False


def scrape_emails(
    days: int = 1,
    target_date: str | None = None,
    include_read: bool = False,
    account: int = 0,
    cdp_ws: str | None = None,
) -> tuple[list[dict], str]:
    """
    Scrape Gmail via browser-harness.
    Returns (emails, label).
    """
    base = f"https://mail.google.com/mail/u/{account}"
    row_selector = "tr.zA" if include_read else "tr.zA.zE"

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

    filter_expr = '":" in (timeText || "")' if filter_today else "true"

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
        output = _run_browser(scraping_code, timeout=60, cdp_ws=cdp_ws)
    except RuntimeError as e:
        print(f"Scraping failed: {e}", file=sys.stderr)
        return [], label

    try:
        emails = json.loads(output.strip())
    except json.JSONDecodeError:
        print(f"Warning: could not parse email JSON: {output[:200]}", file=sys.stderr)
        return [], label

    # Gmail's newer_than:Nd search is unreliable — filter by date in Python.
    # target_date uses explicit after:/before: bounds so no extra filter needed.
    if not target_date and days > 1:
        today = date.today()
        cutoff = today - timedelta(days=days - 1)
        before = len(emails)
        emails = [
            e for e in emails
            if (d := _parse_email_date(e.get("time", ""), today)) is not None and d >= cutoff
        ]
        dropped = before - len(emails)
        if dropped:
            print(f"  (filtered out {dropped} emails outside date range)", file=sys.stderr)

    # Deduplicate: Gmail sometimes returns the same email twice at page boundaries.
    seen: set[tuple[str, str, str]] = set()
    deduped = []
    for e in emails:
        key = (e.get("sender", ""), e.get("subject", ""), e.get("time", ""))
        if key not in seen:
            seen.add(key)
            deduped.append(e)
    emails = deduped

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
    parser.add_argument("--account", default="0", help="Account: index, email@domain, or 'list'")
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

    # ── account resolution ─────────────────────────────────────────────────

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

    launched: tuple[subprocess.Popen, str] | None = None
    cdp_ws: str | None = None
    account_index = 0

    if "@" in args.account:
        # Email-based: find the Chrome profile, launch a dedicated Chrome instance
        email = args.account
        profile_dir = _find_profile_for_email(email)
        if not profile_dir:
            sys.exit(f"No Chrome profile found for {email}\nRun --account list to see available accounts.")
        print(f"Targeting {email} ({profile_dir})", file=sys.stderr)
        port = _find_free_port()
        proc, temp_dir, cdp_ws = _launch_chrome_profile(profile_dir, port)
        launched = (proc, temp_dir)
        time.sleep(2)  # let the browser fully settle before navigating
    else:
        try:
            account_index = int(args.account)
        except ValueError:
            sys.exit(f"--account must be an integer, email, or 'list', got: {args.account}")

    # ── scrape ─────────────────────────────────────────────────────────────

    try:
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
            cdp_ws=cdp_ws,
        )
    finally:
        if launched:
            _cleanup_chrome(*launched)

    if not emails:
        kind = "emails" if getattr(args, "all") else "unread emails"
        print(f"No {kind} found ({label}). Inbox clear!")
        sys.exit(0)

    print_emails(emails, label, getattr(args, "all"), args.output)


if __name__ == "__main__":
    main()
