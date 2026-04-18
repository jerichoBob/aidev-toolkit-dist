#!/usr/bin/env bash
set -euo pipefail

# stats-parse.sh — Parse and aggregate token usage metadata from specs/README.md
# Reads HTML comment metadata embedded in README and outputs statistics.
# Metadata format: <!-- task-meta: v={version},t={task_num},in={in},out={out},cache={cache},start={ISO8601},end={ISO8601},commit={sha} -->
# Usage: stats-parse.sh <subcommand>
# Subcommands: extract-spec, aggregate-spec, aggregate-all

README="specs/README.md"

die() { echo "ERROR: $*" >&2; exit 1; }

# Check if README exists
require_readme() {
  [[ -f "$README" ]] || die "specs/README.md not found"
}

# Extract all task metadata from a specific spec version
# Usage: extract_spec <version>
# Output: TSV with columns: task_num in_tokens out_tokens cache_tokens duration_seconds
cmd_extract_spec() {
  local version="${1:-}"
  [[ -n "$version" ]] || die "extract-spec: requires version argument (e.g., 17)"

  require_readme

  # Normalize version (remove 'v' prefix if present)
  version="${version#v}"

  # Find the spec section and extract metadata comments
  local in_spec=0
  local next_spec_started=0

  while IFS= read -r line; do
    # Check if we've started the target spec section
    if [[ "$line" =~ ^##\ v${version}[[:space:]]*[:—–-] ]]; then
      in_spec=1
      continue
    fi

    # Check if we've moved to the next spec section
    if (( in_spec )); then
      if [[ "$line" =~ ^##\ v[0-9] ]]; then
        next_spec_started=1
        break
      fi
    fi

    # Extract metadata from task lines in this spec
    if (( in_spec )); then
      # Look for task-meta HTML comments
      if [[ "$line" =~ task-meta:\ v=([0-9]+),t=([0-9]+),in=([0-9]+),out=([0-9]+),cache=([0-9]+),start=([^,]+),end=([^,]+),commit=([^\ ]*) ]]; then
        local task_num="${BASH_REMATCH[2]}"
        local in_tokens="${BASH_REMATCH[3]}"
        local out_tokens="${BASH_REMATCH[4]}"
        local cache_tokens="${BASH_REMATCH[5]}"
        local start_time="${BASH_REMATCH[6]}"
        local end_time="${BASH_REMATCH[7]}"

        # Calculate duration in seconds
        local start_unix end_unix duration_seconds
        start_unix=$(parse_iso8601 "$start_time" 2>/dev/null || echo 0)
        end_unix=$(parse_iso8601 "$end_time" 2>/dev/null || echo 0)
        duration_seconds=$((end_unix - start_unix))
        [[ $duration_seconds -lt 0 ]] && duration_seconds=0

        # Output: task_num in_tokens out_tokens cache_tokens duration_seconds
        printf "%s\t%s\t%s\t%s\t%d\n" "$task_num" "$in_tokens" "$out_tokens" "$cache_tokens" "$duration_seconds"
      fi
    fi
  done < "$README"
}

# Aggregate token stats for a single spec
# Usage: aggregate_spec <version>
# Output: total_in total_out total_cache total_duration task_count
cmd_aggregate_spec() {
  local version="${1:-}"
  [[ -n "$version" ]] || die "aggregate-spec: requires version argument"

  require_readme

  local data
  data=$(cmd_extract_spec "$version")

  if [[ -z "$data" ]]; then
    # No metadata found for this spec
    echo "0 0 0 0 0"
    return 0
  fi

  local total_in=0 total_out=0 total_cache=0 total_duration=0 task_count=0

  while IFS=$'\t' read -r task_num in_tokens out_tokens cache_tokens duration_seconds; do
    total_in=$((total_in + in_tokens))
    total_out=$((total_out + out_tokens))
    total_cache=$((total_cache + cache_tokens))
    total_duration=$((total_duration + duration_seconds))
    task_count=$((task_count + 1))
  done <<< "$data"

  echo "$total_in $total_out $total_cache $total_duration $task_count"
}

# Aggregate stats for all specs with metadata
# Output: TSV with columns: version name in_tokens out_tokens cache_tokens duration_seconds task_count
cmd_aggregate_all() {
  require_readme

  # Get all spec versions from README
  local version name done total

  # Parse Quick Status table (simplified parsing)
  local in_table=0
  while IFS= read -r line; do
    # Start reading table after "Quick Status" header
    if [[ "$line" =~ ^##\ Quick\ Status ]]; then
      in_table=1
      continue
    fi

    # Stop when we hit the next section or a separator
    if (( in_table )); then
      if [[ "$line" =~ ^---$ ]]; then
        break
      fi

      # Parse table rows: | v14 | Name | 6/6 | ✅ Complete | — |
      if [[ "$line" =~ ^\\|\ v([0-9]+)[\ \-]? ]]; then
        version="v${BASH_REMATCH[1]}"

        # Get aggregated stats for this spec
        local stats
        stats=$(cmd_aggregate_spec "${version#v}" 2>/dev/null || echo "0 0 0 0 0")
        read -r in_tokens out_tokens cache_tokens duration_seconds task_count <<< "$stats"

        # Only output specs that have metadata (task_count > 0)
        if (( task_count > 0 )); then
          printf "%s\t%d\t%d\t%d\t%d\t%d\n" "$version" "$in_tokens" "$out_tokens" "$cache_tokens" "$duration_seconds" "$task_count"
        fi
      fi
    fi
  done < "$README"
}

# Parse ISO8601 timestamp to Unix timestamp
# Input: ISO8601 string (e.g., 2026-02-15T10:30:00Z)
# Output: Unix timestamp in seconds
parse_iso8601() {
  local iso8601="${1:-}"
  [[ -n "$iso8601" ]] || return 1

  # Use date command to convert
  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS: use -j for UTC, -f for input format
    date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$iso8601" "+%s" 2>/dev/null || echo 0
  else
    # Linux: use -d for parsing
    date -d "$iso8601" "+%s" 2>/dev/null || echo 0
  fi
}

# Format tokens with thousands separators (e.g., 12345 → 12,345)
format_tokens() {
  local tokens="${1:-0}"

  # Validate input is numeric
  if ! [[ "$tokens" =~ ^[0-9]+$ ]]; then
    echo "$tokens"
    return 0
  fi

  # Use printf with thousands separator
  if printf "%'d" 0 &>/dev/null; then
    printf "%'d" "$tokens"
  else
    # Fallback: use sed to add commas
    echo "$tokens" | sed -E 's/([0-9])([0-9]{3})+$/&/;:a;s/^([0-9]+)([0-9]{3})/\1,\2/;ta'
  fi
}

# Format duration as HH:MM
# Input: seconds (integer)
# Output: formatted string (e.g., 3661 → 1:01:01)
format_duration() {
  local seconds="${1:-0}"

  # Validate input is numeric
  if ! [[ "$seconds" =~ ^[0-9]+$ ]]; then
    echo "0:00"
    return 0
  fi

  local hours=$((seconds / 3600))
  local minutes=$(((seconds % 3600) / 60))
  local secs=$((seconds % 60))

  if (( hours > 0 )); then
    printf "%d:%02d:%02d" "$hours" "$minutes" "$secs"
  else
    printf "%d:%02d" "$minutes" "$secs"
  fi
}

# Calculate estimated cost from token counts
# Input: input_tokens output_tokens cache_tokens
# Output: cost in USD
calculate_cost() {
  local in_tokens="${1:-0}"
  local out_tokens="${2:-0}"
  local cache_tokens="${3:-0}"

  # Pricing (as of 2026-02-16, Anthropic official rates)
  local cost_in=3.00      # $3.00 per 1M input tokens
  local cost_out=15.00    # $15.00 per 1M output tokens
  local cost_cache=0.30   # $0.30 per 1M cache read tokens

  # Convert to cost in USD (divide by 1M)
  local cost
  cost=$(bc -l <<< "scale=2; ($in_tokens * $cost_in + $out_tokens * $cost_out + $cache_tokens * $cost_cache) / 1000000" 2>/dev/null || echo 0)

  printf "%.2f" "$cost"
}

# --- Main dispatch ---
case "${1:-}" in
  extract-spec)    cmd_extract_spec "$2" ;;
  aggregate-spec)  cmd_aggregate_spec "$2" ;;
  aggregate-all)   cmd_aggregate_all ;;
  format-tokens)   format_tokens "$2" ;;
  format-duration) format_duration "$2" ;;
  calculate-cost)  calculate_cost "$2" "$3" "$4" ;;
  *)
    echo "Usage: stats-parse.sh <extract-spec|aggregate-spec|aggregate-all|format-tokens|format-duration|calculate-cost>"
    echo ""
    echo "Subcommands:"
    echo "  extract-spec <version>       - Extract task metadata for one spec"
    echo "  aggregate-spec <version>     - Aggregate stats for one spec"
    echo "  aggregate-all                - Aggregate stats for all specs with metadata"
    echo "  format-tokens <count>        - Format tokens with thousands separators"
    echo "  format-duration <seconds>    - Format duration as HH:MM or HH:MM:SS"
    echo "  calculate-cost <in> <out> <cache> - Calculate estimated cost in USD"
    exit 1
    ;;
esac
