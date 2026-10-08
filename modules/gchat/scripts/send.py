"""
Send a Google Chat message for the /gchat skill.

Unlike an email draft, there is no draft concept in Google
Chat — this posts the message immediately, visible to everyone in the
space, as the authenticated human user. Always confirm the exact target
space and message text with the user before running this.

Usage:
    gchat.sh send \\
        --space spaces/AAAAAAAAAAA --text "Message text here"
"""

import argparse
import sys

from auth import get_credentials
from googleapiclient.discovery import build


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--space", required=True, help="Space resource name, e.g. spaces/AAAAAAAAAAA (from list_spaces.py)")
    parser.add_argument("--text", required=True, help="Message text to post")
    args = parser.parse_args()

    if not args.space.startswith("spaces/"):
        print("BLOCKED: --space must be a resource name like 'spaces/AAAAAAAAAAA' "
              "(run list_spaces.py to find it), not a display name.", file=sys.stderr)
        sys.exit(1)

    creds = get_credentials()
    service = build("chat", "v1", credentials=creds)

    message = service.spaces().messages().create(
        parent=args.space,
        body={"text": args.text},
    ).execute()

    print(f"Message sent: {message.get('name')}", file=sys.stderr)
    print(message.get("name"))


if __name__ == "__main__":
    main()
