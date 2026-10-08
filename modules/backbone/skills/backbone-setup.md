---
name: backbone-setup
tier: extended
description: Bootstrap the agent-backbone coordination layer as a sibling repo, then install backbone commands into the current project.
argument-hint: "[--install-only | --check]"
allowed-tools: Read, Bash(git:*), Bash(gh:*), Bash(ls:*), Bash(mkdir:*), Bash(cp:*), Bash(bash:*)
model: inherit
---

# backbone-setup

Bootstrap the [agent-backbone](https://github.com/jerichoBob/agent-backbone) coordination layer — a shared message bus and presence registry for Claude Code agents working across multiple repos.

## When to Use

- Starting a new project cluster that will use the backbone for cross-repo coordination
- A sibling repo exists but backbone commands haven't been installed into this project yet
- You want to verify the backbone is accessible and up to date

## Arguments

- **(empty)**: Full setup — clone backbone if missing, check the installed module, offer the session hooks
- **--install-only**: Skip the clone check, only check the module and offer the hooks (backbone already exists)
- **--check**: Verify the backbone and the installed module, no changes

## What it Does

1. Checks whether `../agent-backbone/` exists as a sibling to the current working directory
2. If missing: clones `jerichoBob/agent-backbone` there via `gh repo clone`
3. Checks the backbone module is installed (`~/.claude/aidev-toolkit/modules/backbone/`; the commands are global, installed by `/aid-update`, never copied into the project)
4. Offers the SessionStart/SessionEnd hooks for this project (asks first)
5. Confirms setup and prints next steps

## Instructions

### Step 1: Determine working directory

```bash
pwd
```

Note the current repo name and parent directory path. The backbone must live at `../agent-backbone/` relative to the current repo.

### Step 2: Check for existing backbone

```bash
ls ../agent-backbone/messages/ 2>/dev/null && echo "EXISTS" || echo "MISSING"
```

**If EXISTS and `--check`:**

- Also verify the module is installed: `ls ~/.claude/commands/backbone.md ~/.claude/aidev-toolkit/modules/backbone/scripts/backbone-sync.sh 2>/dev/null`
- Report status and stop — no changes made

**If EXISTS and not `--check`:**

- Skip clone, go to Step 4

**If MISSING and `--install-only`:**

```text
Error: ../agent-backbone/ not found. Remove --install-only to clone it automatically.
```

Stop.

**If MISSING:**

- Continue to Step 3

### Step 3: Clone the backbone

Check `gh` auth:

```bash
gh auth status 2>&1
```

If not authenticated, stop:
> "gh is not authenticated. Run `gh auth login` first, then re-run /backbone-setup."

Clone:

```bash
gh repo clone jerichoBob/agent-backbone ../agent-backbone
```

If clone fails, stop and show the error.

### Step 4: Check the module

```bash
ls ~/.claude/aidev-toolkit/modules/backbone/scripts/backbone-sync.sh ~/.claude/commands/backbone.md
```

If either is missing, stop: "The backbone module is not installed. Run /aid-update, then re-run /backbone-setup." With `--check`, report and stop here.

### Step 5: Offer the hooks

Ask the developer whether to add the SessionStart/SessionEnd hooks to this project. If yes:

```bash
bash ~/.claude/aidev-toolkit/modules/backbone/scripts/backbone-install-hooks.sh "$(pwd)"
```

It shows exactly what it will add to `.claude/settings.json` and asks before writing. Skip when the developer declines; nothing else depends on it.

### Step 6: Confirm

```text
Backbone Setup Complete
=======================

Backbone:  ../agent-backbone/                                    ✓
Module:    ~/.claude/aidev-toolkit/modules/backbone/             ✓
Hooks:     {installed | declined}

Next steps:
  1. Open a new session: the hook registers you and prints the pending count (or run /backbone join)
  2. /backbone-send to send a message, /backbone-inbox to read yours
  3. /backbone name set <address> to choose your address (default: {repo}:{git user})

For help: see ../agent-backbone/README.md
```

## Notes

- The backbone is a **shared, stateful repo** — messages, presence records, and archived CRs accumulate there over time. Keep it version-controlled and backed up alongside your project repos.
- All backbone commands use `../agent-backbone/` relative paths. If your directory layout differs from the standard sibling layout, the pre-flight check in each command will tell you.
- Running `/backbone-setup` on an already-configured project is safe — it changes nothing unless you accept the hooks. Commands and scripts come from `/aid-update`.
