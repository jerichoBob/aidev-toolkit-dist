"""
Read Google Chat message history for the /gchat skill.

Read-only — never posts, edits, or deletes. Two modes:

  --space spaces/AAAA   read recent messages from one space/DM
  --scan                scan every space/group chat/DM the account belongs to
                        for recent messages (optionally filtered by --grep)

Usage:
    gchat.sh read_messages \
        --space spaces/AAAAAAAAAAA --days 3
    gchat.sh read_messages \
        --scan --days 2 --grep "csv|stratus"
    ... --json .claude/data/gchat/messages-YYYYMMDD.json
"""

import argparse
import json
import re
import sys
from datetime import datetime, timedelta, timezone

from auth import get_credentials
from googleapiclient.discovery import build
from list_spaces import list_spaces


def list_messages(service, space: str, since: datetime) -> list[dict]:
    messages = []
    page_token = None
    while True:
        resp = (
            service.spaces()
            .messages()
            .list(
                parent=space,
                pageSize=100,
                filter=f'createTime > "{since.strftime("%Y-%m-%dT%H:%M:%SZ")}"',
                orderBy="createTime asc",
                pageToken=page_token,
            )
            .execute()
        )
        messages.extend(resp.get("messages", []))
        page_token = resp.get("nextPageToken")
        if not page_token:
            break
    return messages


def to_row(space: dict, m: dict) -> dict:
    sender = m.get("sender", {})
    return {
        "space": space["name"],
        "spaceDisplayName": space["displayName"],
        "time": m.get("createTime"),
        "sender": sender.get("displayName") or sender.get("name"),
        "text": m.get("text", ""),
        "thread": (m.get("thread") or {}).get("name"),
        "attachments": [
            {
                "contentName": a.get("contentName"),
                "contentType": a.get("contentType"),
                "source": a.get("source"),
                "resourceName": (a.get("attachmentDataRef") or {}).get("resourceName"),
                "driveFileId": (a.get("driveDataRef") or {}).get("driveFileId"),
            }
            for a in m.get("attachment", [])
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--space", help="Space resource name, e.g. spaces/AAAAAAAAAAA")
    mode.add_argument("--scan", action="store_true", help="Scan all spaces/DMs the account belongs to")
    parser.add_argument("--days", type=float, default=2, help="How far back to look (default 2 days)")
    parser.add_argument("--grep", help="Case-insensitive regex; only show messages whose text matches")
    parser.add_argument("--json", help="Also write results to this path (must be under .claude/data/)")
    args = parser.parse_args()

    if args.json and ".claude/data/" not in args.json.replace("\\", "/"):
        print("Refusing to write --json output outside .claude/data/", file=sys.stderr)
        sys.exit(1)

    creds = get_credentials()
    service = build("chat", "v1", credentials=creds)
    since = datetime.now(timezone.utc) - timedelta(days=args.days)
    pattern = re.compile(args.grep, re.IGNORECASE) if args.grep else None

    if args.scan:
        spaces = list_spaces(service)
    else:
        spaces = [{"name": args.space, "displayName": args.space, "type": None}]

    rows = []
    for space in spaces:
        try:
            msgs = list_messages(service, space["name"], since)
        except Exception as e:  # one unreadable space shouldn't abort a scan
            print(f"skip {space['name']} ({space['displayName']}): {e}", file=sys.stderr)
            continue
        for m in msgs:
            row = to_row(space, m)
            if pattern and not pattern.search(row["text"]):
                continue
            rows.append(row)

    rows.sort(key=lambda r: r["time"] or "")
    if not rows:
        print("No matching messages.")
    for r in rows:
        print(f"[{r['time']}] {r['spaceDisplayName']} ({r['space']}) — {r['sender']}:\n  {r['text']}")
        for a in r["attachments"]:
            print(f"  [attachment] {a['contentName']} ({a['contentType']}, {a['source']})")
        print()

    if args.json:
        with open(args.json, "w") as f:
            json.dump(rows, f, indent=2)
        print(f"Wrote {len(rows)} messages to {args.json}", file=sys.stderr)


if __name__ == "__main__":
    main()
