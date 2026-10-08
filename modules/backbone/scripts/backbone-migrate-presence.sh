#!/usr/bin/env bash
# Rename presence files whose names Windows cannot create (e.g. presence-stak-app:main.md) to their
# safe form (presence-stak-app__main.md). Only the filename changes; agent_name inside the file is
# untouched, and every reader scans that field.
#
# History is preserved: inside a git repo, tracked files move with `git mv` (so `git log --follow`
# keeps working) and the renames are left staged for you to commit. Nothing is committed or pushed.
# Safe to run twice: files already in safe form are skipped, and a rename that would overwrite an
# existing file is reported and skipped, never forced.
#
# Usage: backbone-migrate-presence.sh [--dir DIR] [--dry-run]
# Exit: 0 ok (including nothing to do) · 1 one or more renames skipped because the target exists · 4 usage
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backbone-lib.sh
source "$SELF_DIR/backbone-lib.sh"

DIR=""; DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DIR="${2:-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) echo "usage: backbone-migrate-presence.sh [--dir DIR] [--dry-run]" >&2; exit 4 ;;
  esac
done
[[ -n "$DIR" ]] || DIR="$(bb_default_dir "$SELF_DIR")"
[[ -d "$DIR/presence" ]] || { echo "backbone-migrate-presence: $DIR/presence not found" >&2; exit 4; }
DIR="$(cd "$DIR" && pwd)"

in_git=0; git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 && in_git=1

moved=0; skipped=0
for f in "$DIR"/presence/presence-*.md; do
  [[ -f "$f" ]] || continue
  base="$(basename "$f")"
  safe="$(bb_safe_name "$base")"
  [[ "$safe" == "$base" ]] && continue
  if [[ -e "$DIR/presence/$safe" ]]; then
    echo "SKIP    $base -> $safe (target exists; resolve by hand)"
    skipped=$((skipped + 1))
    continue
  fi
  if [[ $DRY -eq 1 ]]; then
    echo "WOULD   $base -> $safe"
  else
    if [[ $in_git -eq 1 ]] && git -C "$DIR" ls-files --error-unmatch "presence/$base" >/dev/null 2>&1; then
      git -C "$DIR" mv "presence/$base" "presence/$safe" || { echo "FAIL    $base" >&2; skipped=$((skipped + 1)); continue; }
    else
      mv "$f" "$DIR/presence/$safe" || { echo "FAIL    $base" >&2; skipped=$((skipped + 1)); continue; }
    fi
    echo "RENAMED $base -> $safe"
  fi
  moved=$((moved + 1))
done

if [[ $moved -eq 0 && $skipped -eq 0 ]]; then echo "nothing to migrate"
elif [[ $DRY -eq 1 ]]; then echo "dry run: $moved file(s) would be renamed, $skipped skipped"
else echo "renamed $moved file(s), $skipped skipped. Review with git status, then commit."; fi
[[ $skipped -eq 0 ]]
