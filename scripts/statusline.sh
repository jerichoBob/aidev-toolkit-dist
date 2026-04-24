#!/usr/bin/env bash
# Claude Code status footer script
# Reads JSON from stdin (statusLine input), config from ~/.claude/statusline-config.json
# Prints a colored one-line status string to stdout

CONFIG="${HOME}/.claude/statusline-config.json"

# Bootstrap default config if absent
if [[ ! -f "$CONFIG" ]]; then
  mkdir -p "$(dirname "$CONFIG")"
  cat > "$CONFIG" <<'EOF'
{
  "enabled": true,
  "components": {
    "dir": true,
    "branch": true,
    "ctx": true,
    "model": false,
    "effort": false,
    "vim": false
  }
}
EOF
fi

enabled=$(jq -r '.enabled // true' "$CONFIG" 2>/dev/null)
[[ "$enabled" != "true" ]] && exit 0

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""' 2>/dev/null)

parts=()

# dir — basename of working directory
if [[ "$(jq -r '.components.dir // true' "$CONFIG" 2>/dev/null)" == "true" ]]; then
  dir=$(basename "$cwd")
  parts+=("\033[35m[${dir}]\033[0m")
fi

# branch — git branch + status symbols
if [[ "$(jq -r '.components.branch // true' "$CONFIG" 2>/dev/null)" == "true" ]] && [[ -n "$cwd" ]]; then
  branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ -n "$branch" ]]; then
    symbols=""
    gs=$(git -C "$cwd" -c core.useBuiltinFSMonitor=false status --porcelain 2>/dev/null)
    echo "$gs" | grep -q "^[MARC]"   && symbols+="✈"
    echo "$gs" | grep -q "^ M\|^M " && symbols+="✭"
    echo "$gs" | grep -q "^ D\|^D " && symbols+="✗"
    echo "$gs" | grep -q "^R"        && symbols+="➦"
    echo "$gs" | grep -q "^U"        && symbols+="✂"
    echo "$gs" | grep -q "^??"       && symbols+="✱"
    parts+=("\033[36m${branch}${symbols}\033[0m")
  fi
fi

# ctx — context window usage % with color
if [[ "$(jq -r '.components.ctx // true' "$CONFIG" 2>/dev/null)" == "true" ]]; then
  ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
  if [[ -n "$ctx_pct" ]]; then
    ctx_int=${ctx_pct%.*}
    if   (( ctx_int >= 80 )); then color="\033[31m"
    elif (( ctx_int >= 60 )); then color="\033[33m"
    else                           color="\033[32m"
    fi
    parts+=("${color}ctx:${ctx_int}%\033[0m")
  fi
fi

# model — shortened model display name
if [[ "$(jq -r '.components.model // false' "$CONFIG" 2>/dev/null)" == "true" ]]; then
  model=$(echo "$input" | jq -r '.model.display_name // empty' 2>/dev/null)
  if [[ -n "$model" ]]; then
    short=$(echo "$model" | sed 's/Claude //i' | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
    parts+=("\033[90m${short}\033[0m")
  fi
fi

# effort — reasoning effort level
if [[ "$(jq -r '.components.effort // false' "$CONFIG" 2>/dev/null)" == "true" ]]; then
  effort=$(echo "$input" | jq -r '.effort.level // empty' 2>/dev/null)
  [[ -n "$effort" ]] && parts+=("\033[90meffort:${effort}\033[0m")
fi

# vim — current vim mode with color
if [[ "$(jq -r '.components.vim // false' "$CONFIG" 2>/dev/null)" == "true" ]]; then
  vim_mode=$(echo "$input" | jq -r '.vim.mode // empty' 2>/dev/null)
  if [[ -n "$vim_mode" ]]; then
    case "$vim_mode" in
      INSERT)      color="\033[32m" ;;
      NORMAL)      color="\033[34m" ;;
      VISUAL*)     color="\033[35m" ;;
      *)           color="\033[0m"  ;;
    esac
    parts+=("${color}${vim_mode}\033[0m")
  fi
fi

[[ ${#parts[@]} -eq 0 ]] && exit 0

# Join parts with a space separator
result=""
for part in "${parts[@]}"; do
  [[ -n "$result" ]] && result+=" "
  result+="$part"
done
printf '%b' "$result"
