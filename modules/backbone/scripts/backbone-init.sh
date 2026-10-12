#!/usr/bin/env bash
# Create (or join, or import into) the backbone state directory. Safe to run twice.
#
# Usage: backbone-init.sh [--dir DIR] [--remote URL] [--import OLD_DIR]
#   --dir DIR      where to create it (default: backbone-dir.sh, i.e. $BACKBONE_DIR / pointer / default)
#   --remote URL   clone a shared backbone from URL into DIR and set transport=git. DIR must not hold one yet.
#   --import OLD   copy messages, archive, presence and roster.md from an existing backbone checkout (for
#                  example the retired agent-backbone repo), then rename colon-named presence files.
#                  backbone.config is copied only if DIR has none. Message-type schemas are not copied: they
#                  ship with the module (an optional DIR/messages/types overrides them).
# Without --remote the directory is local (transport=local) and shared by every project on this machine.
# Exit: 0 ok · 4 usage · 5 DIR already holds something else / clone failed
set -uo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backbone-lib.sh
source "$SELF_DIR/backbone-lib.sh"
TEMPLATES="$SELF_DIR/../templates"

DIR=""; REMOTE=""; OLD=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DIR="${2:-}"; shift 2 ;;
    --remote) REMOTE="${2:-}"; shift 2 ;;
    --import) OLD="${2:-}"; shift 2 ;;
    *) echo "usage: backbone-init.sh [--dir DIR] [--remote URL] [--import OLD_DIR]" >&2; exit 4 ;;
  esac
done
[[ -n "$DIR" ]] || DIR="$(bb_default_dir "$SELF_DIR")"
DIR="${DIR/#\~/$HOME}"
if [[ -n "$OLD" && ! -d "$OLD" ]]; then echo "backbone-init: --import directory not found: $OLD" >&2; exit 4; fi

if [[ -n "$REMOTE" ]]; then
  if [[ -d "$DIR/.git" ]]; then
    echo "backbone-init: $DIR is already a git checkout; not cloning again" >&2; exit 5
  elif [[ -e "$DIR" && -n "$(ls -A "$DIR" 2>/dev/null)" ]]; then
    echo "backbone-init: $DIR exists and is not empty; choose another --dir or clear it" >&2; exit 5
  fi
  mkdir -p "$(dirname "$DIR")"
  git clone -q "$REMOTE" "$DIR" || { echo "backbone-init: clone of $REMOTE failed" >&2; exit 5; }
  echo "cloned $REMOTE -> $DIR"
fi

mkdir -p "$DIR/messages/archive" "$DIR/presence"
DIR="$(cd "$DIR" && pwd)"
# keep empty directories in git
for d in messages/archive presence; do [[ -e "$DIR/$d/.gitkeep" || -n "$(ls -A "$DIR/$d")" ]] || : > "$DIR/$d/.gitkeep"; done

# machine-local files stay out of a shared repo
GI="$DIR/.gitignore"
for pat in backbone.config .claude/data/; do grep -qxF "$pat" "$GI" 2>/dev/null || echo "$pat" >> "$GI"; done

if [[ ! -f "$DIR/roster.md" ]]; then cp "$TEMPLATES/roster.md" "$DIR/roster.md"; echo "created roster.md (edit it: who is behind each agent, and the notify target)"; fi

if [[ ! -f "$DIR/backbone.config" ]]; then
  if [[ -n "$OLD" && -f "$OLD/backbone.config" ]]; then cp "$OLD/backbone.config" "$DIR/backbone.config"; echo "copied backbone.config"
  elif [[ -n "$REMOTE" ]]; then printf 'transport=git\n' > "$DIR/backbone.config"
  else printf 'transport=local\n' > "$DIR/backbone.config"; fi
fi

if [[ -n "$OLD" ]]; then
  n=0
  for f in "$OLD"/messages/*.md; do
    [[ -f "$f" && "$(basename "$f")" != README.md ]] || continue
    [[ -e "$DIR/messages/$(basename "$f")" ]] || { cp "$f" "$DIR/messages/"; n=$((n+1)); }
  done
  for f in "$OLD"/messages/archive/*; do [[ -f "$f" && ! -e "$DIR/messages/archive/$(basename "$f")" ]] && { cp "$f" "$DIR/messages/archive/"; n=$((n+1)); }; done
  [[ -d "$OLD/messages/seen" ]] && { mkdir -p "$DIR/messages/seen"; cp -n "$OLD"/messages/seen/* "$DIR/messages/seen/" 2>/dev/null; }
  for f in "$OLD"/presence/presence-*.md; do
    base="$(basename "$f")"; [[ -f "$f" && "$base" != presence-example.md ]] || continue
    nm="${base#presence-}"; safe="presence-$(bb_safe_name "${nm%.md}").md"      # compare by the Windows-safe name
    [[ -e "$DIR/presence/$safe" ]] || { cp "$f" "$DIR/presence/$safe"; n=$((n+1)); }
  done
  [[ -f "$OLD/roster.md" && "$(grep -c . "$DIR/roster.md")" -le "$(grep -c . "$TEMPLATES/roster.md")" ]] && cp "$OLD/roster.md" "$DIR/roster.md" && echo "imported roster.md"
  bash "$SELF_DIR/backbone-migrate-presence.sh" --dir "$DIR" >/dev/null 2>&1
  echo "imported $n file(s) from $OLD"
fi

echo "backbone ready at $DIR (transport=$(bb_transport "$DIR"))"
