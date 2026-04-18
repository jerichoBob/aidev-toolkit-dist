#!/usr/bin/env bash
set -euo pipefail

# token-tracker.sh — Capture and analyze token usage from Claude Code stats
# Reads ~/.claude/stats-cache.json and outputs token metrics for task tracking.
# Usage: token-tracker.sh <subcommand>
# Subcommands: snapshot <file>, delta <before> <after>, format <tokens>

STATS_CACHE="${HOME}/.claude/stats-cache.json"

die() { echo "ERROR: $*" >&2; exit 1; }

# Check if stats-cache.json exists and is readable
has_stats() {
  [[ -f "$STATS_CACHE" && -r "$STATS_CACHE" ]]
}

# Capture current token state and save to a snapshot file
# Output: JSON object with modelUsage data
cmd_snapshot() {
  local snapshot_file="${1:-}"
  [[ -n "$snapshot_file" ]] || die "snapshot: requires output file argument"

  if ! has_stats; then
    # Create empty snapshot if stats-cache.json doesn't exist
    echo '{}' > "$snapshot_file"
    return 0
  fi

  # Extract modelUsage from stats-cache.json and save to snapshot
  if command -v jq &> /dev/null; then
    jq -r '.modelUsage // {}' "$STATS_CACHE" > "$snapshot_file"
  else
    # Fallback: simple grep for modelUsage section (basic parsing)
    echo '{}' > "$snapshot_file"
  fi
}

# Calculate token delta between two snapshots
# Returns: input_tokens output_tokens cache_tokens (space-separated)
cmd_delta() {
  local before_file="${1:-}"
  local after_file="${2:-}"
  [[ -n "$before_file" && -n "$after_file" ]] || die "delta: requires before and after file arguments"

  [[ -f "$before_file" ]] || die "delta: before snapshot not found: $before_file"
  [[ -f "$after_file" ]] || die "delta: after snapshot not found: $after_file"

  if ! command -v jq &> /dev/null; then
    # Fallback if jq not available
    echo "0 0 0"
    return 0
  fi

  # Calculate differences in token counts
  # Sum all models' usage if multiple models were used
  local before_input before_output before_cache
  local after_input after_output after_cache

  before_input=$(jq '[.[] | .inputTokens // 0] | add // 0' "$before_file" 2>/dev/null || echo 0)
  before_output=$(jq '[.[] | .outputTokens // 0] | add // 0' "$before_file" 2>/dev/null || echo 0)
  before_cache=$(jq '[.[] | .cacheReadInputTokens // 0] | add // 0' "$before_file" 2>/dev/null || echo 0)

  after_input=$(jq '[.[] | .inputTokens // 0] | add // 0' "$after_file" 2>/dev/null || echo 0)
  after_output=$(jq '[.[] | .outputTokens // 0] | add // 0' "$after_file" 2>/dev/null || echo 0)
  after_cache=$(jq '[.[] | .cacheReadInputTokens // 0] | add // 0' "$after_file" 2>/dev/null || echo 0)

  # Calculate deltas
  local delta_input=$((after_input - before_input))
  local delta_output=$((after_output - before_output))
  local delta_cache=$((after_cache - before_cache))

  # Ensure non-negative values (in case stats reset)
  [[ $delta_input -lt 0 ]] && delta_input=0
  [[ $delta_output -lt 0 ]] && delta_output=0
  [[ $delta_cache -lt 0 ]] && delta_cache=0

  # Output as space-separated values
  echo "$delta_input $delta_output $delta_cache"
}

# Format token count with thousands separators
# Input: numeric token count
# Output: formatted string (e.g., 12345 → 12,345)
cmd_format() {
  local tokens="${1:-0}"

  # Validate input is numeric
  if ! [[ "$tokens" =~ ^[0-9]+$ ]]; then
    echo "$tokens"
    return 0
  fi

  # Use printf with thousands separator (works on macOS and Linux)
  if printf "%'d" 0 &>/dev/null; then
    printf "%'d" "$tokens"
  else
    # Fallback: use sed to add commas
    echo "$tokens" | sed -E 's/([0-9])([0-9]{3})+$/&/;:a;s/^([0-9]+)([0-9]{3})/\1,\2/;ta'
  fi
}

# Format duration as HH:MM
# Input: seconds (integer)
# Output: formatted string (e.g., 3661 → 1:01:01 or 901 → 00:15:01)
cmd_format_duration() {
  local seconds="${1:-0}"

  # Validate input is numeric
  if ! [[ "$seconds" =~ ^[0-9]+$ ]]; then
    echo "0:00"
    return 0
  fi

  local hours=$((seconds / 3600))
  local minutes=$(((seconds % 3600) / 60))
  local secs=$((seconds % 60))

  printf "%d:%02d:%02d" "$hours" "$minutes" "$secs"
}

# Parse ISO8601 timestamp and return Unix timestamp
# Input: ISO8601 string (e.g., 2026-02-15T10:30:00Z)
# Output: Unix timestamp in seconds
cmd_parse_iso8601() {
  local iso8601="${1:-}"
  [[ -n "$iso8601" ]] || die "parse_iso8601: requires ISO8601 timestamp"

  # Use date command to convert
  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS: use -j for UTC, -f for input format
    date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$iso8601" "+%s" 2>/dev/null || echo 0
  else
    # Linux: use -d for parsing
    date -d "$iso8601" "+%s" 2>/dev/null || echo 0
  fi
}

# --- Main dispatch ---
case "${1:-}" in
  snapshot)         cmd_snapshot "$2" ;;
  delta)            cmd_delta "$2" "$3" ;;
  format)           cmd_format "$2" ;;
  format-duration)  cmd_format_duration "$2" ;;
  parse-iso8601)    cmd_parse_iso8601 "$2" ;;
  *)
    echo "Usage: token-tracker.sh <snapshot|delta|format|format-duration|parse-iso8601>"
    echo ""
    echo "Subcommands:"
    echo "  snapshot <file>           - Capture current token state from stats-cache.json"
    echo "  delta <before> <after>    - Calculate token delta between two snapshots"
    echo "  format <tokens>           - Format token count with thousands separators"
    echo "  format-duration <seconds> - Format duration as HH:MM:SS"
    echo "  parse-iso8601 <timestamp> - Parse ISO8601 timestamp to Unix timestamp"
    exit 1
    ;;
esac
