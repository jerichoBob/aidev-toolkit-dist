#!/usr/bin/env bash
# Git transport wrapper for the backbone. Honors transport=local|git in <dir>/backbone.config.
#
# Usage: backbone-sync.sh [--dir DIR] <mode|pull|push> [args]
#   mode                  print the effective transport (local|git)
#   pull                  fetch and rebase from origin (no-op when transport=local)
#   push <action> <id>    commit messages/ and presence/ as "backbone: <action> <id>", then push
#                         (no-op when transport=local). On a lost race the local commit is dropped.
#
# DIR defaults to $BACKBONE_DIR, else ../agent-backbone from the cwd. Scripts live in the toolkit module and
# never find state through their own location.
# Exit codes: 0 ok · 2 remote unreachable or git failure · 3 lost a race (someone else changed it first)
#             · 4 usage or config error
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backbone-lib.sh
source "$SELF_DIR/backbone-lib.sh"

DIR="$(bb_default_dir "$SELF_DIR")"
if [[ "${1:-}" == "--dir" ]]; then DIR="${2:-}"; shift 2; fi
[[ -d "$DIR" ]] || { echo "backbone: directory not found: $DIR" >&2; exit 4; }
DIR="$(cd "$DIR" && pwd)"
CMD="${1:-}"; shift || true

die() { local code="$1"; shift; echo "backbone: $*" >&2; exit "$code"; }

MODE="$(bb_transport "$DIR")" || exit 4

git_ready() {
  git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1 || die 4 "transport=git but $DIR is not a git repository"
  git -C "$DIR" remote get-url origin >/dev/null 2>&1 || die 4 "transport=git but $DIR has no 'origin' remote"
  BRANCH="$(git -C "$DIR" rev-parse --abbrev-ref HEAD)"
}

cmd_pull() {
  [[ "$MODE" == "local" ]] && return 0
  git_ready
  local out
  out="$(git -C "$DIR" fetch origin 2>&1)" || die 2 "remote unreachable, nothing pulled: $out"
  git -C "$DIR" rev-parse --verify -q "origin/$BRANCH" >/dev/null || return 0
  out="$(git -C "$DIR" rebase --autostash "origin/$BRANCH" 2>&1)" || {
    git -C "$DIR" rebase --abort >/dev/null 2>&1
    die 2 "could not rebase onto origin/$BRANCH: $out"
  }
}

cmd_push() {
  local action="${1:-}" id="${2:-}"
  [[ -n "$action" && -n "$id" ]] || die 4 "usage: push <action> <id>"
  [[ "$MODE" == "local" ]] && return 0
  git_ready

  local paths=() p
  for p in messages presence; do [[ -d "$DIR/$p" ]] && paths+=("$p"); done
  local pre; pre="$(git -C "$DIR" rev-parse HEAD)"
  if ((${#paths[@]})); then git -C "$DIR" add -A -f -- "${paths[@]}"; fi
  if ! git -C "$DIR" diff --cached --quiet; then
    git -C "$DIR" commit -q -m "backbone: $action $id" || die 2 "commit failed"
  fi

  local attempt out
  for attempt in 1 2 3; do
    if out="$(git -C "$DIR" push -q origin HEAD 2>&1)"; then return 0; fi
    if grep -qiE 'rejected|non-fast-forward|fetch first|failed to update ref' <<<"$out"; then
      git -C "$DIR" fetch -q origin 2>/dev/null || die 2 "remote unreachable during retry: $out"
      if git -C "$DIR" rebase --autostash "origin/$BRANCH" >/dev/null 2>&1; then continue; fi
      # Conflict: another agent changed the same message first. Drop our commit and re-sync.
      git -C "$DIR" rebase --abort >/dev/null 2>&1
      git -C "$DIR" reset -q --mixed "$pre"
      if ((${#paths[@]})); then
        git -C "$DIR" checkout -q -- "${paths[@]}" 2>/dev/null
        git -C "$DIR" clean -fdq -- "${paths[@]}"
      fi
      git -C "$DIR" rebase --autostash "origin/$BRANCH" >/dev/null 2>&1 || git -C "$DIR" rebase --abort >/dev/null 2>&1
      die 3 "lost the race for $id: another agent changed it first. Local state re-synced; re-read it before acting."
    fi
    die 2 "push failed (commit kept locally, re-run to retry): $out"
  done
  die 2 "push still rejected after 3 attempts"
}

case "$CMD" in
  mode) echo "$MODE" ;;
  pull) cmd_pull ;;
  push) cmd_push "$@" ;;
  *) die 4 "usage: backbone-sync.sh [--dir DIR] <mode|pull|push> [args]" ;;
esac
