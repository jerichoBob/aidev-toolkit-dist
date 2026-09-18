#!/usr/bin/env bash
# spec-guard.sh — remote-arbitrated spec numbering (spec-v114)
#
# Uses git refs on the remote (default: origin) as an atomic-create primitive:
# a ref under refs/spec-guard/v{N} is claimed with `git push --force-with-lease=<ref>:`
# (empty expected-old-value = "this ref must not exist yet"). The remote rejects
# the push atomically if another reserve already created that ref, so two
# concurrent callers can never both succeed for the same N.
#
# Commands:
#   next-number [--remote <name>]         Highest reserved vN on the remote, +1 (1 if none)
#   reserve <N> [--remote <name>]          Claim vN. Exit 0 = reserved, 2 = collision (retry N+1), 1 = hard failure (stop)
#   release <N> [--remote <name>]          Delete a reservation (manual escape hatch)
#   claim [--remote <name>]                next-number + reserve, retrying on collision (bounded). Prints reserved N on success.
#
# On any hard failure (network/auth/remote unreachable), this script exits
# nonzero and prints an error — callers must NOT fall back to local numbering.

set -uo pipefail

REF_PREFIX="refs/spec-guard/v"
DEFAULT_REMOTE="origin"
MAX_CLAIM_ATTEMPTS=10
AUDIT_LOG="${HOME}/.claude/aidev-toolkit/spec-guard-audit.log"

die() { echo "ERROR: $*" >&2; exit 1; }

parse_remote_flag() {
  # Prints the remote name found after --remote, or DEFAULT_REMOTE
  local remote="$DEFAULT_REMOTE"
  local args=("$@")
  local i
  for ((i = 0; i < ${#args[@]}; i++)); do
    if [[ "${args[$i]}" == "--remote" ]]; then
      remote="${args[$((i + 1))]:-$DEFAULT_REMOTE}"
    fi
  done
  echo "$remote"
}

audit() {
  # audit <action> <resource> <outcome>
  local action="$1" resource="$2" outcome="$3"
  local actor timestamp
  actor="$(~/.claude/aidev-toolkit/modules/sdd/scripts/user-email.sh get 2>/dev/null || true)"
  [[ -z "$actor" ]] && actor="$(git config user.email 2>/dev/null || echo "unknown")"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null || true
  echo "actor=${actor} action=${action} resource=${resource} timestamp=${timestamp} outcome=${outcome}" >> "$AUDIT_LOG" 2>/dev/null || true
}

# Highest N currently reserved on the remote, or empty if none / on failure
highest_reserved() {
  local remote="$1"
  local refs
  refs=$(git ls-remote "$remote" "${REF_PREFIX}*" 2>/dev/null) || return 1
  [[ -z "$refs" ]] && { echo ""; return 0; }
  echo "$refs" \
    | sed -E "s#.*${REF_PREFIX}##" \
    | sort -t. -k1,1n -k2,2n \
    | tail -1
}

cmd_next_number() {
  local remote
  remote="$(parse_remote_flag "$@")"
  local refs
  refs=$(git ls-remote "$remote" "${REF_PREFIX}*" 2>&1)
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    echo "ERROR: could not reach remote '$remote' to determine next spec number: $refs" >&2
    exit 1
  fi
  if [[ -z "$refs" ]]; then
    echo 1
    return 0
  fi
  local highest
  highest=$(echo "$refs" | sed -E "s#.*${REF_PREFIX}##" | sort -t. -k1,1n -k2,2n | tail -1)
  # Integer-only bump for the plain next-number case (decimal claims go through `reserve` directly)
  local major="${highest%%.*}"
  echo $((major + 1))
}

cmd_reserve() {
  local n="${1:-}"
  [[ -z "$n" ]] && die "Usage: $0 reserve <N> [--remote <name>]"
  shift
  local remote
  remote="$(parse_remote_flag "$@")"

  local ref="${REF_PREFIX}${n}"
  local sha
  sha="$(git rev-parse HEAD 2>/dev/null)" || die "not a git repository (or no commits yet) — cannot reserve a spec number"

  local output
  output=$(git push "$remote" "--force-with-lease=${ref}:" "${sha}:${ref}" 2>&1)
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    audit "reserve" "v${n}" "success"
    echo "RESERVED $n"
    return 0
  fi

  if echo "$output" | grep -qi "stale info\|\[rejected\]"; then
    audit "reserve" "v${n}" "collision"
    echo "COLLISION $n" >&2
    echo "$output" >&2
    return 2
  fi

  audit "reserve" "v${n}" "failed"
  echo "ERROR: could not reserve v${n} on remote '$remote': $output" >&2
  return 1
}

cmd_release() {
  local n="${1:-}"
  [[ -z "$n" ]] && die "Usage: $0 release <N> [--remote <name>]"
  shift
  local remote
  remote="$(parse_remote_flag "$@")"
  local ref="${REF_PREFIX}${n}"

  local output
  output=$(git push "$remote" "--delete" "$ref" 2>&1)
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    audit "release" "v${n}" "success"
    echo "RELEASED $n"
    return 0
  fi

  audit "release" "v${n}" "failed"
  echo "ERROR: could not release v${n} on remote '$remote': $output" >&2
  return 1
}

cmd_claim() {
  local remote
  remote="$(parse_remote_flag "$@")"

  local attempt=0
  local n
  n=$(cmd_next_number --remote "$remote") || exit 1

  while (( attempt < MAX_CLAIM_ATTEMPTS )); do
    attempt=$((attempt + 1))
    local reserve_output reserve_exit
    reserve_output=$(cmd_reserve "$n" --remote "$remote")
    reserve_exit=$?
    if [[ $reserve_exit -eq 0 ]]; then
      echo "$n"
      return 0
    elif [[ $reserve_exit -eq 2 ]]; then
      n=$((n + 1))
      continue
    else
      echo "ERROR: spec-guard claim failed on remote '$remote' — not falling back to local numbering" >&2
      return 1
    fi
  done

  echo "ERROR: exhausted $MAX_CLAIM_ATTEMPTS attempts trying to reserve a spec number on remote '$remote'" >&2
  return 1
}

case "${1:-}" in
  next-number)
    shift
    cmd_next_number "$@"
    ;;
  reserve)
    shift
    cmd_reserve "$@"
    ;;
  release)
    shift
    cmd_release "$@"
    ;;
  claim)
    shift
    cmd_claim "$@"
    ;;
  *)
    echo "Usage: $0 {next-number|reserve <N>|release <N>|claim} [--remote <name>]" >&2
    exit 1
    ;;
esac
