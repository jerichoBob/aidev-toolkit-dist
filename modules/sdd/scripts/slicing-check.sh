#!/bin/bash
#
# slicing-check.sh — heuristic horizontal-slicing detector for /sdd-spec (Step 2.45)
#
# Usage: slicing-check.sh <draft-file>   (use "-" to read stdin)
#
# Scans `### Phase N: Name` sections of a drafted spec/README section and flags
# the horizontal-slicing trap: a spec that bundles a core logic/API phase with a
# UI/frontend phase whose tasks lean on shared infrastructure that may not exist.
#
# Output (stdout, tab-separated, only when the check fires):
#   WARN<TAB><phase heading><TAB><infra phrase that triggered the match>
# Silent (no output) and exit 0 otherwise. Per AC-5 the check is conservative:
# a phase whose heading is ambiguous (matches both logic and UI keywords, or
# neither) is never classified, so it can never trigger a warning.
#
# This only seeds /sdd-spec's judgment — the skill still decides whether the
# named infra is already covered by an existing spec (specs-parse.sh spec-list).

set -u

src="${1:-}"
if [ -z "$src" ]; then
    echo "usage: slicing-check.sh <draft-file|->" >&2
    exit 2
fi
if [ "$src" = "-" ]; then
    input=$(cat)
elif [ -r "$src" ]; then
    input=$(cat "$src")
else
    echo "slicing-check.sh: cannot read '$src'" >&2
    exit 2
fi

LOGIC_RE='backend|back-end|service|api|logic|model|database|schema|parser|engine'
UI_RE='ui|frontend|front-end|admin panel|component|page|screen|dashboard|view'
INFRA_RE='requires[^.;]*|depends on[^.;]*|once [^.;]* exists|authenticated[- ]fetch|shared (frontend|front-end|api client|component|ui|auth)[a-z -]*|api client|component library'

# Whole-word match so "ui" does not hit "build"/"guide" and "api" does not hit "capital".
has_word() { # $1=text $2=alternation
    printf '%s' "$1" | grep -Eiq "(^|[^[:alnum:]])($2)([^[:alnum:]]|$)"
}

logic_phases=0
ui_headings=()
ui_bodies=()

heading=""
body=""
flush() {
    [ -z "$heading" ] && return
    local is_logic=0 is_ui=0
    has_word "$heading" "$LOGIC_RE" && is_logic=1
    has_word "$heading" "$UI_RE" && is_ui=1
    if [ $is_logic -eq 1 ] && [ $is_ui -eq 0 ]; then
        logic_phases=$((logic_phases + 1))
    elif [ $is_ui -eq 1 ] && [ $is_logic -eq 0 ]; then
        ui_headings+=("$heading")
        ui_bodies+=("$body")
    fi
}

while IFS= read -r line; do
    if [[ "$line" =~ ^###[[:space:]]+Phase ]]; then
        flush
        heading="${line#\#\#\# }"
        body=""
    elif [[ "$line" =~ ^##[[:space:]] ]]; then
        flush
        heading=""
        body=""
    elif [ -n "$heading" ]; then
        body+="$line"$'\n'
    fi
done <<< "$input"
flush

[ "$logic_phases" -ge 1 ] || exit 0

for i in "${!ui_headings[@]}"; do
    match=$(printf '%s' "${ui_bodies[$i]}" | grep -Eio "$INFRA_RE" | head -1)
    if [ -n "$match" ]; then
        printf 'WARN\t%s\t%s\n' "${ui_headings[$i]}" "$match"
    fi
done
exit 0
