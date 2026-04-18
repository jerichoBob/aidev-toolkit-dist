#!/usr/bin/env bash
set -euo pipefail

# specs-parse.sh — Shared parsing infrastructure for SDD module
# Reads specs/README.md and outputs structured data for skill consumption.
# Usage: specs-parse.sh <subcommand>
# Subcommands: status, next-task, next-phase, staleness, structure, spec-list

README="specs/README.md"

die() { echo "ERROR: $*" >&2; exit 1; }

# macOS vs Linux stat for mtime
file_mtime() {
  if [[ "$(uname)" == "Darwin" ]]; then
    stat -f %m "$1" 2>/dev/null || echo 0
  else
    stat -c %Y "$1" 2>/dev/null || echo 0
  fi
}

require_readme() {
  [[ -f "$README" ]] || die "specs/README.md not found. Run /sdd-specs-update to create it."
}

# Parse README into spec sections with checkbox counts
# Outputs TSV: version\tname\tdone\ttotal\tstatus
cmd_status() {
  require_readme

  local version="" name="" done=0 total=0 first=1

  while IFS= read -r line; do
    # Match spec headers: ## v{N}: {Name} or ## v{N} — {Name} or ## v{N} - {Name}
    # Supports decimal versions like v2.1, v4.2
    if [[ "$line" =~ ^##[[:space:]]+v([0-9]+(\.[0-9]+)?)[[:space:]]*[:—–-][[:space:]]*(.*) ]]; then
      # Emit previous spec if any
      if [[ -n "$version" ]]; then
        local status
        if (( total == 0 )); then
          status="Empty"
        elif (( done == total )); then
          status="Complete"
        elif (( done == 0 )); then
          status="Draft"
        else
          status="In Progress"
        fi
        printf "%s\t%s\t%d\t%d\t%s\n" "$version" "$name" "$done" "$total" "$status"
      fi
      version="v${BASH_REMATCH[1]}"
      name="${BASH_REMATCH[3]}"
      # Trim trailing whitespace
      name="${name%"${name##*[![:space:]]}"}"
      done=0
      total=0
    fi
    # Count checkboxes
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]\[x\] ]]; then
      (( done++ )) || true
      (( total++ )) || true
    elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]\[[[:space:]]\] ]]; then
      (( total++ )) || true
    fi
  done < "$README"

  # Emit last spec
  if [[ -n "$version" ]]; then
    local status
    if (( total == 0 )); then
      status="Empty"
    elif (( done == total )); then
      status="Complete"
    elif (( done == 0 )); then
      status="Draft"
    else
      status="In Progress"
    fi
    printf "%s\t%s\t%d\t%d\t%s\n" "$version" "$name" "$done" "$total" "$status"
  fi
}

# Find the first unchecked task with full context
cmd_next_task() {
  require_readme

  local version="" name="" phase="" spec_file=""

  while IFS= read -r line; do
    # Spec header (supports decimal versions like v2.1, v4.2)
    if [[ "$line" =~ ^##[[:space:]]+v([0-9]+(\.[0-9]+)?)[[:space:]]*[:—–-][[:space:]]*(.*) ]]; then
      version="v${BASH_REMATCH[1]}"
      name="${BASH_REMATCH[3]}"
      name="${name%"${name##*[![:space:]]}"}"
      phase=""
      # Find the spec file
      spec_file=$(ls specs/spec-v"${BASH_REMATCH[1]}"-*.md 2>/dev/null | head -1 || true)
    fi
    # Phase header: ### Phase N: Name or ### Name
    if [[ "$line" =~ ^###[[:space:]]+(.*) ]]; then
      phase="${BASH_REMATCH[1]}"
      phase="${phase%"${phase##*[![:space:]]}"}"
    fi
    # First unchecked task
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]\[[[:space:]]\][[:space:]]*(.*) ]]; then
      local task="${BASH_REMATCH[1]}"
      echo "spec_version: $version"
      echo "spec_name: $name"
      echo "spec_file: ${spec_file:-not found}"
      echo "phase: ${phase:-unknown}"
      echo "task: $task"
      return 0
    fi
  done < "$README"

  echo "NO_TASKS_REMAINING"
  return 0
}

# All tasks in the current working phase
cmd_next_phase() {
  require_readme

  local version="" name="" phase="" spec_file=""
  local in_target_phase=0 found_phase=0
  local target_version="" target_phase=""

  # First pass: find which spec+phase has the first unchecked item
  while IFS= read -r line; do
    if [[ "$line" =~ ^##[[:space:]]+v([0-9]+(\.[0-9]+)?)[[:space:]]*[:—–-][[:space:]]*(.*) ]]; then
      version="v${BASH_REMATCH[1]}"
      name="${BASH_REMATCH[3]}"
      name="${name%"${name##*[![:space:]]}"}"
      phase=""
      spec_file=$(ls specs/spec-v"${BASH_REMATCH[1]}"-*.md 2>/dev/null | head -1 || true)
    fi
    if [[ "$line" =~ ^###[[:space:]]+(.*) ]]; then
      phase="${BASH_REMATCH[1]}"
      phase="${phase%"${phase##*[![:space:]]}"}"
    fi
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]\[[[:space:]]\] ]]; then
      target_version="$version"
      target_phase="$phase"
      found_phase=1
      break
    fi
  done < "$README"

  # Save from first pass
  local target_name="$name"
  local target_spec_file="$spec_file"

  if (( ! found_phase )); then
    echo "NO_TASKS_REMAINING"
    return 0
  fi

  # Second pass: output all tasks in that phase
  version="" name="" phase=""
  local printing=0

  echo "spec_version: $target_version"
  echo "spec_name: $target_name"
  echo "spec_file: ${target_spec_file:-not found}"
  echo "phase: $target_phase"
  echo "---"
  echo "TASKS:"

  while IFS= read -r line; do
    if [[ "$line" =~ ^##[[:space:]]+v([0-9]+(\.[0-9]+)?)[[:space:]]*[:—–-][[:space:]]*(.*) ]]; then
      version="v${BASH_REMATCH[1]}"
      name="${BASH_REMATCH[3]}"
      name="${name%"${name##*[![:space:]]}"}"
      phase=""
      if (( printing )); then
        break
      fi
    fi
    if [[ "$line" =~ ^###[[:space:]]+(.*) ]]; then
      local new_phase="${BASH_REMATCH[1]}"
      new_phase="${new_phase%"${new_phase##*[![:space:]]}"}"
      if (( printing )); then
        # We've moved to a new phase, stop
        break
      fi
      if [[ "$version" == "$target_version" && "$new_phase" == "$target_phase" ]]; then
        printing=1
      fi
      phase="$new_phase"
    fi
    if (( printing )); then
      if [[ "$line" =~ ^[[:space:]]*-[[:space:]]\[x\][[:space:]]*(.*) ]]; then
        echo "[x] ${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]\[[[:space:]]\][[:space:]]*(.*) ]]; then
        echo "[ ] ${BASH_REMATCH[1]}"
      fi
    fi
  done < "$README"
}

# Check staleness of README vs spec files
cmd_staleness() {
  require_readme

  local readme_mtime
  readme_mtime=$(file_mtime "$README")
  echo "readme_mtime: $readme_mtime"

  local stale_found=0
  echo "STALE_FILES:"
  for f in specs/spec-v*.md specs/completed/spec-v*.md; do
    [[ -f "$f" ]] || continue
    local f_mtime
    f_mtime=$(file_mtime "$f")
    if (( f_mtime > readme_mtime )); then
      echo "  $f"
      stale_found=1
    fi
  done

  if (( ! stale_found )); then
    echo "  (none — README is current)"
  fi
}

# Check specs/ directory structure
cmd_structure() {
  echo "specs_dir: $([ -d specs ] && echo exists || echo missing)"
  echo "readme: $([ -f specs/README.md ] && echo exists || echo missing)"
  echo "template: $([ -f specs/TEMPLATE.md ] && echo exists || echo missing)"

  # Find spec files not linked in README (check for ## v{N} header)
  echo "UNLINKED_SPECS:"
  if [[ -f "$README" ]]; then
    for f in specs/spec-v*.md; do
      [[ -f "$f" ]] || continue
      local basename
      basename=$(basename "$f")
      # Extract version number (supports decimal like v2.1, v4.2)
      if [[ "$basename" =~ spec-v([0-9]+(\.[0-9]+)?) ]]; then
        local vnum="${BASH_REMATCH[1]}"
        if ! grep -qE "^## v${vnum}[[:space:]]*[:—–-]" "$README" 2>/dev/null; then
          echo "  $f"
        fi
      fi
    done
  fi
}

# List all spec files with versions
# Usage: cmd_spec_list [--all]
# --all: include specs/completed/ in addition to specs/
cmd_spec_list() {
  local include_completed=0
  for arg in "$@"; do
    [[ "$arg" == "--all" ]] && include_completed=1
  done

  echo "SPECS:"
  local search_dirs=("specs")
  (( include_completed )) && search_dirs+=("specs/completed")

  for dir in "${search_dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    for f in "$dir"/spec-v*.md; do
      [[ -f "$f" ]] || continue
      local basename
      basename=$(basename "$f")
      if [[ "$basename" =~ spec-v([0-9]+(\.[0-9]+)?) ]]; then
        printf "v%s\t%s\n" "${BASH_REMATCH[1]}" "$f"
      fi
    done
  done
}

# --- Main dispatch ---
case "${1:-}" in
  status)     cmd_status ;;
  next-task)  cmd_next_task ;;
  next-phase) cmd_next_phase ;;
  staleness)  cmd_staleness ;;
  structure)  cmd_structure ;;
  spec-list)  cmd_spec_list "${@:2}" ;;
  *)
    echo "Usage: specs-parse.sh <status|next-task|next-phase|staleness|structure|spec-list>"
    exit 1
    ;;
esac
