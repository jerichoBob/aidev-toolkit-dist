---
name: browser-harness
description: Install and use browser-harness for direct Chrome CDP control via LLM.
argument-hint: [task description]
allowed-tools: Read, Bash(git:*), Bash(uv:*), Bash(command:*), Bash(osascript:*), Bash(open:*), Bash(pkill:*), Bash(rm:*), Bash(mkdir:*), Bash(ln:*), Bash(rg:*)
model: inherit
---

# browser-harness

Gives Claude direct, self-healing control of your real Chrome browser via CDP (Chrome DevTools Protocol). No framework, no recipes — one WebSocket to Chrome, nothing between.

The agent writes missing helpers mid-task. If `upload_file()` doesn't exist, it adds it to `helpers.py` and keeps going.

## When to Use

- User wants to automate, scrape, test, or interact with web pages
- User says "open", "click", "fill in", "go to", "download from", or "do X in the browser"
- User wants to run a browser task as a sub-agent

## Arguments

- **task description**: What to do in the browser (e.g., `star browser-use/browser-harness on GitHub`)
- **No argument**: Install browser-harness and connect to Chrome

## Instructions

### Step 1: Check if browser-harness is installed

```bash
command -v browser-harness 2>/dev/null
```

If it returns a path, skip to Step 3. Otherwise, proceed with install.

### Step 2: Install browser-harness

Clone into a durable location and install as an editable global tool:

```bash
git clone https://github.com/browser-use/browser-harness ~/Developer/browser-harness
cd ~/Developer/browser-harness
uv tool install -e .
command -v browser-harness
```

To make the runtime skill available in every future Claude Code session, add this import to `~/.claude/CLAUDE.md`:

```markdown
@~/Developer/browser-harness/SKILL.md
```

Tell the user to add that line manually (or ask them to approve if the setting allows it).

### Step 3: Connect to Chrome

Try attaching first — if this works, skip the rest of Step 3:

```bash
browser-harness <<'PY'
print(page_info())
PY
```

**Read the error and escalate from there — do not assume you need `chrome://inspect`.**

| Error | Action |
|---|---|
| No Chrome process | `open -a "Google Chrome"` then retry |
| `DevToolsActivePort` missing | Open `chrome://inspect/#remote-debugging`, ask user to tick checkbox and click Allow |
| Connection refused / port not live | Keep polling every 3s for up to 30s |
| `no close frame received` (stale socket) | Run `restart_daemon()` once (see below), then retry |

To open the inspect page without losing the current profile on macOS:

```bash
osascript -e 'tell application "Google Chrome" to activate' \
          -e 'tell application "Google Chrome" to open location "chrome://inspect/#remote-debugging"'
```

To restart a stale daemon:

```bash
uv run python - <<'PY'
from admin import restart_daemon
restart_daemon()
PY
```

Nuclear reset (if restart_daemon also hangs):

```bash
pkill -9 -f "Google Chrome"
rm -f /tmp/bu-default.sock /tmp/bu-default.pid
open -a "Google Chrome"
```

Wait 5s then retry.

### Step 4: Read helpers.py before doing any task

```bash
cat ~/Developer/browser-harness/helpers.py
```

Always read `helpers.py` first — it contains all available functions. When a needed function is missing, add it there.

### Step 5: Check domain-skills for the target site

```bash
rg --files ~/Developer/browser-harness/domain-skills
```

If a skill exists for the target domain, read it before starting. It contains stable selectors, private APIs, waits, and known traps.

### Step 6: Run the task

```bash
browser-harness <<'PY'
# task code here — helpers pre-imported
PY
```

- First navigation: `new_tab(url)`, not `goto(url)` — `goto` runs in the user's active tab
- After every navigation: `wait_for_load()`
- After every action: `screenshot()` to verify
- Auth wall: stop and ask the user — never type credentials from screenshots

### Step 7: Contribute back

If you figured out something non-obvious about a site (private API, stable selector, framework quirk, required wait, trap), file a domain skill before finishing:

```bash
mkdir -p ~/Developer/browser-harness/domain-skills/<site>
# write domain-skills/<site>/README.md with durable patterns (not task narration)
```

Then open a PR to `browser-use/browser-harness`.

## Notes

- The remote-debugging checkbox is per-profile sticky in Chrome — once ticked, every future Chrome launch auto-enables CDP on that profile
- Parallel sub-agents should use distinct `BU_NAME` env vars so they don't share the same socket
- For remote/cloud browsers: grab a free API key at `cloud.browser-use.com/new-api-key` and use `start_remote_daemon()` from `admin.py`
- Full runtime guidance lives in `~/Developer/browser-harness/SKILL.md` — read it for advanced usage
