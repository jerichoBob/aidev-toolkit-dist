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

- **(empty)**: Full setup — clone backbone if missing, install commands into this project
- **--install-only**: Skip clone check, just install commands (backbone already exists)
- **--check**: Verify backbone is accessible and commands are installed, no changes

## What it Does

1. Checks whether `../agent-backbone/` exists as a sibling to the current working directory
2. If missing: clones `jerichoBob/agent-backbone` there via `gh repo clone`
3. Runs `../agent-backbone/scripts/install-backbone-commands.sh` to copy `backbone-*.md` commands into `.claude/commands/`
4. Confirms setup and prints next steps

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

- Also verify commands are installed: `ls .claude/commands/backbone-join.md 2>/dev/null`
- Report status and stop — no changes made

**If EXISTS and not `--check`:**

- Skip clone, go to Step 4

**If MISSING and `--install-only`:**

```
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

### Step 4: Install backbone commands

```bash
bash ../agent-backbone/scripts/install-backbone-commands.sh "$(pwd)"
```

This copies all `backbone-*.md` commands from `../agent-backbone/.claude/commands/` into `./.claude/commands/`.

If the script fails, show the error and stop.

### Step 5: Confirm

```
Backbone Setup Complete
=======================

Backbone:  ../agent-backbone/   ✓
Commands:  .claude/commands/backbone-*.md   ✓

Next steps:
  1. Run /backbone-join to register this session
  2. Run /backbone-publish to send a message to another agent
  3. From agent-backbone/, join as agent-backbone:maintainer to receive feedback

For help: see ../agent-backbone/README.md
```

## Notes

- The backbone is a **shared, stateful repo** — messages, presence records, and archived CRs accumulate there over time. Keep it version-controlled and backed up alongside your project repos.
- All backbone commands use `../agent-backbone/` relative paths. If your directory layout differs from the standard sibling layout, the pre-flight check in each command will tell you.
- Running `/backbone-setup` on an already-configured project is safe — it overwrites command files with the latest versions from the backbone.
