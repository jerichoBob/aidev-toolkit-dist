"""
Download Google Chat message attachments for the /gchat skill.

Read-only — only fetches files. Takes the JSON written by
read_messages.py --json and downloads every attachment listed in it.

Uploaded-in-Chat files (source UPLOADED_CONTENT) are downloaded directly.
Files shared from Google Drive (source DRIVE_FILE) are NOT downloadable
with the Chat scopes — they are reported with their Drive file ID so the
user can fetch them (or the skill can be extended with a Drive scope).

Usage:
    gchat.sh read_messages \
        --scan --days 3 --grep "csv" --json .claude/data/gchat/messages-X.json
    gchat.sh download_attachments \
        --from-json .claude/data/gchat/messages-X.json
Files land in .claude/data/gchat/attachments/ (override with --out-dir, which
must stay under .claude/data/).
"""

import argparse
import io
import json
import re
import sys
from pathlib import Path

from auth import get_credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload

DEFAULT_OUT = ".claude/data/gchat/attachments"


def safe_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]", "_", name or "attachment")


def download(service, resource_name: str, dest: Path) -> None:
    request = service.media().download_media(resourceName=resource_name)
    buf = io.BytesIO()
    downloader = MediaIoBaseDownload(buf, request)
    done = False
    while not done:
        _, done = downloader.next_chunk()
    dest.write_bytes(buf.getvalue())


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--from-json", required=True, help="JSON file written by read_messages.py --json")
    parser.add_argument("--out-dir", default=DEFAULT_OUT, help=f"Output dir under .claude/data/ (default {DEFAULT_OUT})")
    args = parser.parse_args()

    if ".claude/data/" not in (args.out_dir.replace("\\", "/") + "/"):
        print("Refusing to write outside .claude/data/", file=sys.stderr)
        sys.exit(1)

    rows = json.loads(Path(args.from_json).read_text())
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    creds = get_credentials()
    service = build("chat", "v1", credentials=creds)

    n = 0
    for r in rows:
        for a in r.get("attachments", []):
            label = f"{a['contentName']} (from {r['sender']} at {r['time']})"
            if not a.get("resourceName"):
                print(f"SKIP {label}: not Chat-hosted (source={a['source']}, driveFileId={a['driveFileId']})")
                continue
            stamp = (r["time"] or "")[:19].replace(":", "")
            dest = out_dir / f"{stamp}-{safe_name(a['contentName'])}"
            if dest.exists():
                print(f"EXISTS {dest} — not overwriting")
                continue
            try:
                download(service, a["resourceName"], dest)
            except Exception as e:
                print(f"FAIL {label}: {e}", file=sys.stderr)
                continue
            print(f"OK {dest}")
            n += 1
    print(f"Downloaded {n} attachment(s) to {out_dir}")


if __name__ == "__main__":
    main()
