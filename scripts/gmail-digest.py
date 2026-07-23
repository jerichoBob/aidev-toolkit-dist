#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "google-api-python-client",
#   "google-auth-oauthlib",
#   "google-auth-httplib2",
# ]
# ///
"""
Gmail Morning Digest — fetch Gmail emails via the official Gmail API (OAuth).

Usage:
  uv run scripts/gmail-digest.py [options]

Options:
  --days N                    Fetch the last N days (default: 1 = today)
  --weeks N                   Fetch the last N weeks (shorthand for --days N*7)
  --date YYYY-MM-DD           Fetch a specific date instead of today
  --all                       Include read emails (default: unread only)
  --account email@domain.com  Target a specific Google account (default account otherwise)
  --account list              List all accounts with a cached token and exit
  --output file=PATH          Write email list to a file instead of stdout
  --dry-run                   Alias for normal behavior (kept for compatibility)
  --check                     Validate OAuth credentials/token are usable, then exit

Auth setup:
  1. Create an OAuth 2.0 "Desktop app" client in Google Cloud Console with the
     Gmail API (and Drive API) enabled, and download it as config/credentials.json.
  2. First run opens a browser for consent and caches a token under config/.
"""

import argparse
import json
import os
import sys
from datetime import date, timedelta
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

# ── config / auth ────────────────────────────────────────────────────────

CONFIG_DIR = Path(__file__).resolve().parent.parent / "config"
CREDENTIALS_FILE = CONFIG_DIR / "credentials.json"

SCOPES = [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/drive.readonly",
]
# Only usable on Google Workspace accounts with the Chat API enabled in the
# same GCP project; requested only when explicitly opted in.
CHAT_SCOPE = "https://www.googleapis.com/auth/chat.messages.readonly"


def _token_file(account: str | None) -> Path:
    if account and account not in ("0", "default"):
        safe = account.replace("/", "_")
        return CONFIG_DIR / f"token-{safe}.json"
    return CONFIG_DIR / "token.json"


def get_credentials(account: str | None = None, allow_interactive: bool = True) -> Credentials:
    """Get valid credentials for `account`, refreshing or re-authenticating as needed."""
    scopes = list(SCOPES)
    if os.environ.get("GMAIL_DIGEST_CHAT"):
        scopes.append(CHAT_SCOPE)

    token_file = _token_file(account)
    creds = None
    if token_file.exists():
        creds = Credentials.from_authorized_user_file(str(token_file), scopes)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        elif allow_interactive:
            if not CREDENTIALS_FILE.exists():
                raise FileNotFoundError(
                    f"Credentials file not found at {CREDENTIALS_FILE}.\n"
                    "Download OAuth client credentials from Google Cloud Console "
                    "(APIs & Services > Credentials > Create OAuth client ID > Desktop app) "
                    f"and save them to {CREDENTIALS_FILE}."
                )
            flow = InstalledAppFlow.from_client_secrets_file(str(CREDENTIALS_FILE), scopes)
            creds = flow.run_local_server(port=0)
        else:
            raise RuntimeError("No valid cached credentials and interactive auth is disabled")

        token_file.parent.mkdir(parents=True, exist_ok=True)
        token_file.write_text(creds.to_json())

    return creds


def check_auth() -> tuple[bool, str]:
    """Validate that credentials.json exists and a valid/refreshable token can be obtained."""
    if not CREDENTIALS_FILE.exists():
        return False, (
            f"credentials.json not found at {CREDENTIALS_FILE}. "
            "Set up OAuth credentials in Google Cloud Console (see auth setup in module docstring)."
        )
    try:
        get_credentials(allow_interactive=False)
        return True, "Gmail API credentials are valid"
    except RuntimeError:
        return False, "No cached token found — run the digest once interactively to authenticate"
    except Exception as e:
        return False, str(e)


# ── account listing ────────────────────────────────────────────────────────

def list_accounts() -> list[dict]:
    """List accounts with a cached OAuth token under CONFIG_DIR."""
    if not CONFIG_DIR.exists():
        return []

    accounts = []
    default_token = CONFIG_DIR / "token.json"
    if default_token.exists():
        accounts.append({"account": "default", "token_file": str(default_token)})
    for token_path in sorted(CONFIG_DIR.glob("token-*.json")):
        name = token_path.stem[len("token-"):]
        accounts.append({"account": name, "token_file": str(token_path)})
    return accounts


# ── query building ─────────────────────────────────────────────────────────

def build_query(days: int, target_date: str | None, include_read: bool) -> tuple[str, str]:
    """Build a Gmail search query string equivalent to the previous scraping behavior."""
    parts = []
    if not include_read:
        parts.append("is:unread")

    if target_date:
        d = date.fromisoformat(target_date)
        next_d = d + timedelta(days=1)
        parts.append(f"after:{d.strftime('%Y/%m/%d')}")
        parts.append(f"before:{next_d.strftime('%Y/%m/%d')}")
        label = target_date
    elif days > 1:
        parts.append(f"newer_than:{days}d")
        label = f"last {days} days"
    else:
        today = date.today()
        next_d = today + timedelta(days=1)
        parts.append(f"after:{today.strftime('%Y/%m/%d')}")
        parts.append(f"before:{next_d.strftime('%Y/%m/%d')}")
        label = today.isoformat()

    return " ".join(parts), label


# ── fetching ───────────────────────────────────────────────────────────────

def fetch_emails(service, query: str) -> list[dict]:
    """Fetch emails matching `query` via the Gmail API, returning the digest dict shape."""
    emails: list[dict] = []
    page_token = None
    while True:
        resp = service.users().messages().list(
            userId="me", q=query, pageToken=page_token
        ).execute()
        for m in resp.get("messages", []):
            msg = service.users().messages().get(
                userId="me", id=m["id"], format="metadata",
                metadataHeaders=["From", "Subject", "Date"],
            ).execute()
            headers = {h["name"]: h["value"] for h in msg.get("payload", {}).get("headers", [])}
            emails.append({
                "sender": headers.get("From", ""),
                "subject": headers.get("Subject", ""),
                "snippet": msg.get("snippet", ""),
                "time": headers.get("Date", ""),
            })
        page_token = resp.get("nextPageToken")
        if not page_token:
            break

    return emails


def fetch_digest(
    days: int = 1,
    target_date: str | None = None,
    include_read: bool = False,
    account: str | None = None,
) -> tuple[list[dict], str]:
    creds = get_credentials(account=account)
    service = build("gmail", "v1", credentials=creds)
    query, label = build_query(days, target_date, include_read)

    email_type = "emails" if include_read else "unread emails"
    print(f"Fetching {email_type} ({label})...", file=sys.stderr)

    emails = fetch_emails(service, query)

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
        description="Gmail Morning Digest — fetch Gmail emails via the official Gmail API."
    )
    parser.add_argument("--days", type=int, default=None, help="Fetch the last N days (default: 1)")
    parser.add_argument("--weeks", type=int, default=None, help="Fetch the last N weeks")
    parser.add_argument("--date", default=None, help="Specific date to fetch (YYYY-MM-DD)")
    parser.add_argument("--all", action="store_true", help="Include read emails (default: unread only)")
    parser.add_argument("--account", default="default", help="Account: 'default', email@domain, or 'list'")
    parser.add_argument("--output", default="terminal", help="Output: terminal (default) or file=/path")
    parser.add_argument("--dry-run", action="store_true", help="Alias for normal behavior (kept for compatibility)")
    parser.add_argument("--check", action="store_true", help="Validate OAuth credentials/token are usable, then exit")
    args = parser.parse_args()

    if args.check:
        ok, message = check_auth()
        if ok:
            print(f"✓ {message}")
            sys.exit(0)
        else:
            print(f"✗ {message}")
            sys.exit(1)

    # ── account resolution ─────────────────────────────────────────────────

    if args.account == "list":
        accounts = list_accounts()
        if not accounts:
            print("No cached Gmail accounts found. Run the digest once to authenticate.")
            sys.exit(1)
        print(f"\nAccounts with a cached token ({len(accounts)} total):\n")
        for a in accounts:
            print(f"  {a['account']}  ({a['token_file']})")
        sys.exit(0)

    # ── fetch ──────────────────────────────────────────────────────────────

    if args.weeks is not None:
        days = args.weeks * 7
    elif args.days is not None:
        days = args.days
    else:
        days = 1

    try:
        emails, label = fetch_digest(
            days=days,
            target_date=args.date,
            include_read=getattr(args, "all"),
            account=args.account,
        )
    except FileNotFoundError as e:
        sys.exit(str(e))

    if not emails:
        kind = "emails" if getattr(args, "all") else "unread emails"
        print(f"No {kind} found ({label}). Inbox clear!")
        sys.exit(0)

    print_emails(emails, label, getattr(args, "all"), args.output)


if __name__ == "__main__":
    main()
