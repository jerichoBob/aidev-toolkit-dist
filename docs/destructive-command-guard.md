# Destructive-Command Guard

A `PreToolUse` hook that stops Claude Code from running commands that delete or overwrite things. It ships with the toolkit but is **not installed by default** (see [How to install it](#how-to-install-it)); once wired up it needs no configuration.

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

## How to install it

Since spec v136 (2026-11-17), `scripts/install.sh` no longer wires this guard into `~/.claude/settings.json`, and `scripts/uninstall.sh` no longer removes it. The reason is recorded in `specs/spec-v136-guard-hook-not-installed-by-default.md`: a maintainer who already runs a personal delete guard was checked twice on every Bash command.

To use this guard, add one entry to the `Bash` matcher under `hooks.PreToolUse` in `~/.claude/settings.json` (global) or in a project's `.claude/settings.json` (that project only):

```json
{
  "type": "command",
  "command": "python3 -I ~/.claude/aidev-toolkit/scripts/guard-destructive-commands.py",
  "statusMessage": "Checking for destructive commands..."
}
```

Do not run two delete guards at once unless you want every command checked twice.

If an earlier toolkit install already added this entry, it stays in your `settings.json` until you remove it by hand. Whether `uninstall.sh` or `/aid-update` should clean it up is Open Question 3 in the v136 spec.

## Turning it off

Only the person who starts Claude Code can do this, and a command cannot do it for itself. Set `AIDEV_DESTRUCTIVE_GUARD=off` in the environment Claude Code starts with, either as a shell `export` or in the `env` block of `~/.claude/settings.json`.

## Heredoc text

The word `rm` in the body of a heredoc is text, not a command, when the heredoc feeds a data sink: `cat`, `tee`, `gh`, or `git commit -F -` (also inside `"$(cat <<'EOF' ...)"`). So filing an issue or writing a doc that mentions `rm` is not blocked. The body is still checked, exactly as before, when any of these hold:

- the receiver is a shell or interpreter (`bash`, `sh`, `zsh`, `python`, `eval`, `source`, ...), or is not on the short list above
- the body is piped or chained onward (`cat <<EOF | bash`)
- the heredoc is unquoted and the body contains `$(...)` or backticks, which the shell would run
- the closing terminator line is missing
- the `<<` marker sits inside a quoted string

Known gap: writing a script with `cat > script.sh <<'EOF' ... EOF` and then running `bash script.sh` hides the body from this check, as writing the same text with `echo` always has.

## Limits

This is a guardrail, not a security boundary. It reads the text of a command, so a determined or unusual spelling can get past it, and it only covers commands Claude runs, not commands you type. If the check itself fails, a crude pattern still blocks anything that looks like a delete.

## Optional: the rm review panel

`modules/rm-review/` is a Claude Code mod that shows the files from a blocked `rm` in a side panel, with a **Move to Trash** button for each. See its README.

## Tests

`tests/test-guard-destructive-commands.sh` runs `tests/guard_destructive_commands_test.py`. It checks the command text the guard blocks and allows (including the heredoc cases above), the file listing, the exit codes, the off switch, and the real installer and uninstaller against a temporary `HOME`. Nothing in it executes a delete.
