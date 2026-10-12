---
name: backbone-setup
tier: extended
description: Set up the backbone on this machine: create or join the shared message directory, then offer the session hooks.
argument-hint: "[--remote URL] [--import DIR] [--dir DIR] [--check]"
allowed-tools: Read, Bash(bash:*), Bash(ls:*), Bash(git:*), AskUserQuestion
model: inherit
---

# backbone-setup

Set up the agent backbone on this machine. The backbone is a directory of plain files (messages, presence, a roster) that agents read and write. The commands and scripts come with the toolkit (`/aid-update`); this skill only prepares the **state directory** and, optionally, the session hooks.

## When to Use

- First time on a machine, or `/backbone-send` says the backbone is not set up
- Joining your team's shared backbone (agents on different machines): you need its git remote URL
- Moving state from an older backbone checkout (`--import`)

Agents on one machine can usually talk through Claude Code itself. The backbone matters when agents run on **different machines**, or are not Claude.

## Arguments

- **--remote URL**: clone the team's shared backbone repo into the state directory and use `transport=git`
- **--import DIR**: copy messages, archive, presence and roster from an older checkout
- **--dir DIR**: put the state directory somewhere other than the default (also records it, see Step 3)
- **--check**: report what is set up, change nothing

## Instructions

### Step 1: Where is it, and is the module installed?

```bash
SCRIPTS=~/.claude/aidev-toolkit/modules/backbone/scripts
ls "$SCRIPTS/backbone-init.sh" || echo "NOMODULE"
bash "$SCRIPTS/backbone-dir.sh" --check
```

If `NOMODULE`: stop. "The backbone module is not installed. Run /aid-update, then /backbone-setup again."

`backbone-dir.sh` prints the directory this machine uses: `$BACKBONE_DIR`, else the first line of `~/.config/aidev-backbone/dir`, else `~/.config/aidev-backbone/bus`. With `--check` it exits 1 if that directory has no `messages/` and `presence/` yet. If it exits 0 and `--check` was passed, report it (transport, roster entries, hook status) and stop.

### Step 2: Choose how this machine joins

If neither `--remote` nor `--import` was given, ask once with AskUserQuestion:

1. **Join my team's shared backbone (git remote)**: ask for the remote URL. This is the normal case, because the point is agents on different machines.
2. **Create a new shared backbone**: tell the developer to make an empty private git repo first, then give its URL (same as option 1; the first publish populates it).
3. **Local only**: no remote; files stay on this machine. For other LLM tools sharing one machine.

### Step 3: Create it

```bash
bash "$SCRIPTS/backbone-init.sh" [--dir DIR] [--remote URL] [--import OLD]
```

It is safe to run twice. It creates `messages/`, `presence/`, a starter `roster.md` and a per-machine `backbone.config` (`transport=git` with `--remote`, else `local`), and a `.gitignore` for the per-machine files. Exit `5` means the target is not empty or the clone failed: show the message and stop.

If `--dir` was used, or the developer wants the directory elsewhere, record it once for this machine so every project finds it:

```bash
mkdir -p ~/.config/aidev-backbone && printf '%s\n' "<dir>" > ~/.config/aidev-backbone/dir
```

### Step 4: Say who you are

Show `bash "$SCRIPTS/backbone-name.sh" show` (the address others will send to; default `<repo>:<git user>`). Offer `/backbone name set <address>` if they want another. Remind them to add teammates to `roster.md` in the backbone directory (agent pattern, human, notify target).

### Step 5: Offer the hooks

Ask whether to add the SessionStart/SessionEnd hooks to this project (they register the session and print the pending count). If yes:

```bash
bash "$SCRIPTS/backbone-install-hooks.sh" "$(pwd)"
```

It shows exactly what it will add to `.claude/settings.json` and asks before writing. Skip if declined; nothing else depends on it.

### Step 6: Confirm

```text
Backbone Setup Complete
=======================

Directory:  <dir>                       ✓
Transport:  <local | git (remote URL)>
Module:     ~/.claude/aidev-toolkit/modules/backbone/   ✓
Hooks:      <installed | declined>

Next steps:
  1. New session: the hook registers you and prints the pending count (or /backbone join)
  2. /backbone-send to send, /backbone-inbox to read
  3. Notifications and git details: ~/.claude/aidev-toolkit/modules/backbone/docs/
```

## Notes

- The backbone directory holds state that accumulates (messages, presence, archives). In git mode the remote is the backup; in local mode back it up like any other data.
- Nothing here edits `~/.claude`: the pointer file lives in `~/.config/aidev-backbone/`.
- Message-type schemas (`cr`, `task`, ...) ship with the module. A `messages/types/` folder in the backbone directory overrides them if a team wants its own.
