"""
Google Chat OAuth 2.0 authentication for the /gchat skill.

Not tied to any one account — whoever runs this script authenticates as
their own Google (Workspace) account. Credentials and token live per user
under ~/.config/aidev/gchat/ (override with GCHAT_CONFIG_DIR); nothing is
stored in a project or in the toolkit, and nobody shares a token.

Usage:
    gchat.sh auth

Opens a browser for OAuth consent, then caches the token at
<config dir>/token.json.

Requires <config dir>/credentials.json — a Desktop OAuth client from a
Google Cloud project that has the Google Chat API enabled. See the /gchat
skill for the one-time setup steps.
"""

import os
import sys
from pathlib import Path

from google.auth.exceptions import RefreshError
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow

# spaces.readonly covers listing spaces; messages.readonly covers reading
# message history; messages.create covers sending a message as the
# authenticated human user. No admin/delete/membership scopes.
SCOPES = [
    "https://www.googleapis.com/auth/chat.spaces.readonly",
    "https://www.googleapis.com/auth/chat.messages.readonly",
    "https://www.googleapis.com/auth/chat.messages.create",
]

CONFIG_DIR = Path(os.environ.get("GCHAT_CONFIG_DIR") or Path.home() / ".config" / "aidev" / "gchat")
CREDENTIALS_FILE = CONFIG_DIR / "credentials.json"
TOKEN_FILE = CONFIG_DIR / "token.json"


class WorkspaceAuthBlocked(RuntimeError):
    """Raised when a Google Workspace admin policy rejects the OAuth client."""


def get_credentials() -> Credentials:
    """Get valid credentials, refreshing or re-authenticating as needed."""
    creds = None

    if TOKEN_FILE.exists():
        creds = Credentials.from_authorized_user_file(str(TOKEN_FILE), SCOPES)
        if creds and not set(SCOPES).issubset(set(creds.scopes or [])):
            print(
                "Cached token is missing a required scope (SCOPES changed "
                "since it was created) — re-running consent to pick up the "
                "full scope set..."
            )
            creds = None

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            print("Refreshing expired token...")
            try:
                creds.refresh(Request())
            except RefreshError as e:
                # Typically invalid_scope: the cached token was granted
                # before SCOPES grew. Fall through to a fresh consent flow.
                print(f"Refresh failed ({e}) — re-running consent...")
                creds = None
        else:
            creds = None
        if not creds:
            if not CREDENTIALS_FILE.exists():
                raise FileNotFoundError(
                    f"Credentials file not found at {CREDENTIALS_FILE}. "
                    "Download a Desktop OAuth client credentials.json from a "
                    "Google Cloud project with the Google Chat API enabled "
                    "and save it there. See the /gchat skill."
                )
            print("Starting OAuth flow — a browser window will open for you "
                  "to sign in with your own Google account...")
            flow = InstalledAppFlow.from_client_secrets_file(
                str(CREDENTIALS_FILE), SCOPES
            )
            try:
                creds = flow.run_local_server(port=0)
            except Exception as e:
                msg = str(e).lower()
                if "admin" in msg or "disabled_client" in msg or "policy" in msg:
                    raise WorkspaceAuthBlocked(
                        "A Workspace admin policy is blocking this OAuth "
                        "client for Chat scopes. This is not a code bug — "
                        "your Workspace administrator must allowlist the "
                        "client/scopes, or confirm the Chat API is enabled on "
                        f"the Cloud project. Original error: {e}"
                    ) from e
                raise

        TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(TOKEN_FILE, "w") as token:
            token.write(creds.to_json())
        print(f"Token saved to {TOKEN_FILE}")

    return creds


def main():
    try:
        creds = get_credentials()
    except WorkspaceAuthBlocked as e:
        print(f"BLOCKED: {e}", file=sys.stderr)
        sys.exit(2)
    except FileNotFoundError as e:
        print(f"BLOCKED: {e}", file=sys.stderr)
        sys.exit(2)

    from googleapiclient.discovery import build

    service = build("chat", "v1", credentials=creds)
    # A cheap authenticated call to confirm the token actually works.
    resp = service.spaces().list(pageSize=1, filter='spaceType = "SPACE"').execute()
    print("Authentication successful — Chat API reachable.")
    print(f"Token expires: {creds.expiry}")
    if not resp.get("spaces"):
        print("(No spaces returned on this test call — that's fine, just confirming auth.)")


if __name__ == "__main__":
    main()
