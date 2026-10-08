"""
List Google Chat spaces for the /gchat skill.

Read-only — lists the named spaces and group chats the authenticated user
is a member of, so a target space's resource name can be picked for
send.py. Never posts anything.

Usage:
    gchat.sh list_spaces
    gchat.sh list_spaces --json out.json
"""

import argparse
import json
import sys

from auth import get_credentials
from googleapiclient.discovery import build


def list_spaces(service) -> list[dict]:
    spaces = []
    page_token = None
    while True:
        resp = (
            service.spaces()
            .list(
                pageSize=100,
                filter='spaceType = "SPACE" OR spaceType = "GROUP_CHAT" OR spaceType = "DIRECT_MESSAGE"',
                pageToken=page_token,
            )
            .execute()
        )
        for s in resp.get("spaces", []):
            spaces.append(
                {
                    "name": s.get("name"),
                    "displayName": s.get("displayName") or "(unnamed group chat/DM)",
                    "type": s.get("spaceType"),
                }
            )
        page_token = resp.get("nextPageToken")
        if not page_token:
            break
    return spaces


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--json", help="Also write results to this path (must be under .claude/data/)")
    args = parser.parse_args()

    if args.json and ".claude/data/" not in args.json.replace("\\", "/"):
        print("Refusing to write --json output outside .claude/data/", file=sys.stderr)
        sys.exit(1)

    creds = get_credentials()
    service = build("chat", "v1", credentials=creds)
    spaces = list_spaces(service)

    if not spaces:
        print("No spaces or group chats found for this account.")
        return

    for s in spaces:
        print(f"{s['name']}\t{s['type']}\t{s['displayName']}")

    if args.json:
        with open(args.json, "w") as f:
            json.dump(spaces, f, indent=2)
        print(f"\nWrote {len(spaces)} spaces to {args.json}", file=sys.stderr)


if __name__ == "__main__":
    main()
