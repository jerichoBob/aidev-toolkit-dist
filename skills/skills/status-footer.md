---
name: status-footer
tier: extended
description: Enable/disable the Claude Code status footer and toggle individual components (dir, branch, ctx%, model, effort, vim mode).
argument-hint: [<number>|on|off|--show <component>|--hide <component>|--reset]
allowed-tools: Read, Edit, Write, Bash(cat:*), Bash(jq:*), Bash(mkdir:*), Bash(chmod:*)
model: inherit
---

# Status Footer Configuration

Configure the Claude Code status line footer — toggle it on/off and control which components appear.

## Config File

`~/.claude/statusline-config.json` — created automatically with defaults on first run.

## Instructions

### 1. Read current config

```bash
CONFIG="$HOME/.claude/statusline-config.json"
cat "$CONFIG" 2>/dev/null || echo '{"enabled":true,"components":{"dir":true,"branch":true,"ctx":true,"model":false,"effort":false,"vim":false}}'
```

### 2. Determine the argument

The argument is one of:
- **(empty)** — show the interactive menu (see step 3)
- **a number 1–7** — toggle that menu item (see step 4), then show the updated menu
- **`on`** — set `enabled: true`, confirm, done
- **`off`** — set `enabled: false`, confirm, done
- **`--show <component>`** — set that component to true, confirm, done
- **`--hide <component>`** — set that component to false, confirm, done
- **`--reset`** — write defaults, confirm, done

### 3. Display the interactive menu

Show the menu using this exact format, substituting `●` for enabled/on and `○` for disabled/off:

```
Status Footer Configuration
────────────────────────────
  1  Footer   ● enabled     — master on/off switch
  2  dir      ● on          — current directory in brackets
  3  branch   ● on          — git branch + dirty symbols
  4  ctx      ● on          — context window usage %
  5  model    ○ off         — shortened model name
  6  effort   ○ off         — reasoning effort level
  7  vim      ○ off         — vim mode indicator
────────────────────────────
/status-footer <number> to toggle
```

Then stop — do not ask a follow-up question.

### 4. Toggle by number (argument is 1–7)

Map number to field:

| # | Field    | Config key              |
|---|----------|-------------------------|
| 1 | Footer   | `enabled` (top-level)   |
| 2 | dir      | `components.dir`        |
| 3 | branch   | `components.branch`     |
| 4 | ctx      | `components.ctx`        |
| 5 | model    | `components.model`      |
| 6 | effort   | `components.effort`     |
| 7 | vim      | `components.vim`        |

Read the current value for that field, flip it (true→false, false→true), write it back with `jq`, then show the updated menu (step 3).

```bash
# Example: toggle ctx (number 4)
CONFIG="$HOME/.claude/statusline-config.json"
tmp=$(mktemp)
jq '.components.ctx = (.components.ctx | not)' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
```

For number 1 (Footer master switch):
```bash
tmp=$(mktemp)
jq '.enabled = (.enabled | not)' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
```

### 5. Apply named changes (on/off/--show/--hide/--reset)

**`on`** — set `enabled: true`.

**`off`** — set `enabled: false`.

**`--show <component>`** — set `components.<component>: true`. Valid: `dir`, `branch`, `ctx`, `model`, `effort`, `vim`. Error on unknown component.

**`--hide <component>`** — set `components.<component>: false`. Same validation.

**`--reset`** — write the default config:
```json
{"enabled":true,"components":{"dir":true,"branch":true,"ctx":true,"model":false,"effort":false,"vim":false}}
```

```bash
# Example: enable model component
CONFIG="$HOME/.claude/statusline-config.json"
tmp=$(mktemp)
jq '.components.model = true' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
```

### 6. Sync settings.json statusLine

After any config change, sync `~/.claude/settings.json`:

- **If `enabled` is now true**: set `statusLine` to:
  ```json
  {"type":"command","command":"bash ~/.claude/aidev-toolkit/scripts/statusline.sh"}
  ```
- **If `enabled` is now false**: remove the `statusLine` key entirely.

```bash
SETTINGS="$HOME/.claude/settings.json"

# Enable:
tmp=$(mktemp)
jq '.statusLine = {"type":"command","command":"bash ~/.claude/aidev-toolkit/scripts/statusline.sh"}' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

# Disable:
tmp=$(mktemp)
jq 'del(.statusLine)' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
```

For component-only changes (steps 2–7 toggles), only sync settings.json when the `enabled` field changes. Component changes don't require settings.json updates.

### 7. Confirm named changes

For `on`/`off`/`--show`/`--hide`/`--reset`, print one confirmation line then show the updated menu:

```
Footer enabled.
```
```
model: on
```
```
Footer reset to defaults.
```
