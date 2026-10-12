# Destructive-Command Guard

A `PreToolUse` hook that stops Claude Code from running commands that delete or overwrite things. It is installed by default by `scripts/install.sh` and needs no configuration.

## Why

Claude runs shell commands on your behalf, and some of them cannot be undone. `rm -rf` in the wrong directory, a force push, or `git reset --hard` can destroy hours of work in one call. Nobody can be held accountable for a command Claude ran on a guess, so the default is that Claude does not run them. If something needs to go, Claude says what and why, and you remove it.

## What it blocks

| Command | Blocked forms |
| ------- | ------------- |
| `rm`, `unlink`, `rmdir` | every form, with or without `-f`, including `sudo`, `command`, `env`, `nice`, `xargs`, `\rm`, `/bin/rm`, `sh -c "..."`, `eval`, `$(...)`, backticks, and `find -exec rm` |
| `find` | `-delete` |
| `shred`, `srm` | all |
| `git` | `clean -f`, `reset --hard`, `push --force`, `push -f`, `push --force-with-lease` |
| `dd` | any `of=` target |
| Python | `shutil.rmtree`, `os.remove`, `os.unlink`, `os.rmdir`, `Path.unlink` in a command |

Plain `git rm` is not blocked, and neither are `git clean -n` or `git push` without force.

When an `rm` is blocked, the message Claude receives lists the files it would have removed (globs expanded, folders counted), so the conversation can carry on without the delete.

## How it is installed

`scripts/install.sh` adds one entry to the `Bash` matcher under `hooks.PreToolUse` in `~/.claude/settings.json`:

```json
{
  "type": "command",
  "command": "python3 -I ~/.claude/aidev-toolkit/scripts/guard-destructive-commands.py",
  "statusMessage": "Checking for destructive commands..."
}
```

Your other hooks are left alone, and running the installer again does not add a second copy. `scripts/uninstall.sh` removes only this entry.

## Turning it off

Only the person who starts Claude Code can do this, and a command cannot do it for itself. Set `AIDEV_DESTRUCTIVE_GUARD=off` in the environment Claude Code starts with, either as a shell `export` or in the `env` block of `~/.claude/settings.json`.

## Limits

This is a guardrail, not a security boundary. It reads the text of a command, so a determined or unusual spelling can get past it, and it only covers commands Claude runs, not commands you type. If the check itself fails, a crude pattern still blocks anything that looks like a delete.

## Optional: the rm review panel

`modules/rm-review/` is a Claude Code mod that shows the files from a blocked `rm` in a side panel, with a **Move to Trash** button for each. See its README.

## Tests

`tests/test-guard-destructive-commands.sh` runs `tests/guard_destructive_commands_test.py`. It checks the command text the guard blocks and allows, the file listing, the exit codes, the off switch, and the real installer and uninstaller against a temporary `HOME`. Nothing in it executes a delete.
