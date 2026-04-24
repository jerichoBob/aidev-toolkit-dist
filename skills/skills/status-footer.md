---
name: status-footer
description: Enable/disable the Claude Code status footer and toggle individual components (dir, branch, ctx%, model, effort, vim mode).
argument-hint: [on|off] [--show <component>] [--hide <component>]
allowed-tools: Read, Edit, Write, Bash(cat:*), Bash(jq:*), Bash(mkdir:*), Bash(chmod:*)
model: inherit
---

# Status Footer Configuration

Configure the Claude Code status line footer — toggle it on/off and control which components appear.

## Available Components

| Component | Default | Description |
|-----------|---------|-------------|
| `dir`     | on      | Current directory name in magenta brackets, e.g. `[aidev-toolkit]` |
| `branch`  | on      | Git branch + dirty status symbols (✈ staged, ✭ modified, ✗ deleted, ✱ untracked) |
| `ctx`     | on      | Context window usage % — green (<60%), yellow (60–80%), red (>80%) |
| `model`   | off     | Shortened model name, e.g. `haiku-4.5` |
| `effort`  | off     | Reasoning effort level, e.g. `effort:high` |
| `vim`     | off     | Vim mode indicator — `INSERT`, `NORMAL`, `VISUAL` (color-coded) |

## Arguments

- **(empty)** — Show current footer config
- **on** — Enable the footer
- **off** — Disable the footer
- **--show `<component>`** — Enable a specific component (e.g. `--show model`)
- **--hide `<component>`** — Disable a specific component (e.g. `--hide ctx`)
- **--reset** — Reset to defaults (dir, branch, ctx on; model, effort, vim off)

## Config File

`~/.claude/statusline-config.json` — created automatically with defaults on first run.

## Instructions

### 1. Read current config

```bash
CONFIG="$HOME/.claude/statusline-config.json"
cat "$CONFIG" 2>/dev/null || echo '{"enabled":true,"components":{"dir":true,"branch":true,"ctx":true,"model":false,"effort":false,"vim":false}}'
```

### 2. If no arguments — display status table

Show a formatted table of the current state:

```text
Status Footer: ON

Component  Status
─────────  ──────
dir        ✓ on
branch     ✓ on
ctx        ✓ on
model      ✗ off
effort     ✗ off
vim        ✗ off
```

Then exit.

### 3. Apply the requested change

**`on`** — set `enabled: true` in config.

**`off`** — set `enabled: false` in config.

**`--show <component>`** — set `components.<component>: true`. Valid components: `dir`, `branch`, `ctx`, `model`, `effort`, `vim`. Error on unknown component.

**`--hide <component>`** — set `components.<component>: false`. Same validation.

**`--reset`** — write the default config:
```json
{"enabled":true,"components":{"dir":true,"branch":true,"ctx":true,"model":false,"effort":false,"vim":false}}
```

Use `jq` to update the JSON in place:

```bash
# Example: enable model component
tmp=$(mktemp)
jq '.components.model = true' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
```

### 4. Update settings.json statusLine command

After updating the config, ensure `~/.claude/settings.json` is pointing to the statusline script:

- **If footer is enabled**: set `statusLine` to:
  ```json
  {
    "type": "command",
    "command": "bash ~/.claude/aidev-toolkit/scripts/statusline.sh"
  }
  ```

- **If footer is disabled**: remove the `statusLine` key from settings.json entirely.

Use `jq` to update settings.json:

```bash
SETTINGS="$HOME/.claude/settings.json"

# Enable:
tmp=$(mktemp)
jq '.statusLine = {"type":"command","command":"bash ~/.claude/aidev-toolkit/scripts/statusline.sh"}' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

# Disable:
tmp=$(mktemp)
jq 'del(.statusLine)' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
```

### 5. Confirm the change

Display one line summarizing what changed:

```text
Footer enabled.
```
```text
Footer disabled.
```
```text
model: on
```
```text
ctx: off
```
```text
Footer reset to defaults.
```
