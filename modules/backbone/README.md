# Backbone Module — agent-to-agent coordination for aidev toolkit

Tooling for [agent-backbone](https://github.com/jerichoBob/agent-backbone): a message bus and presence registry that Claude Code sessions in different repos (and on different machines) use to hand work to each other.

## Layout

| Dir | Holds | Installed to |
| --- | ----- | ------------ |
| `scripts/` | `backbone-*.sh`: sync (the only code that touches git), poll, session hooks, notifier, ack timer, presence, roster lookup, secret check, name, migrate | stays in place; called as `~/.claude/aidev-toolkit/modules/backbone/scripts/<script>` |
| `skills/` | `/backbone`, `/backbone-send`, `/backbone-inbox`, `/backbone-done`, and `/backbone-setup` | `~/.claude/commands/` and `~/.claude/skills/` by `scripts/install.sh` (`BACKBONE_SKILLS`) |
| `templates/` | `backbone.config.example`, `roster.md`, `hooks-settings.json` | copied by hand or by `/backbone-setup` |

## What is not here

State. Messages, presence records, the roster, the message-type schemas and the specs live in the agent-backbone repo (a sibling of your project, `../agent-backbone`). Scripts find it with `--dir` or `BACKBONE_DIR`, defaulting to `../agent-backbone`, never through their own location.

## Setup

1. `/aid-update` installs the module (skills + executable scripts).
2. `/backbone-setup` clones agent-backbone as a sibling if missing and offers the hooks.
3. Hooks go into a project's `.claude/settings.json` with `backbone-install-hooks.sh <project>` (asks first, merges without overwriting). They reference the module by `~` path, so the same settings work on every machine.

## Migrating a project that has the old per-project copies

Re-run the hook installer (it adds hooks that point at the module), then, after checking `git status`, delete `.claude/scripts/backbone/` and `.claude/.backbone-copied`. Old `.claude/commands/backbone-*.md` copies in the project override the global ones until removed.

## Rollback

Revert the toolkit PR (or `git revert` the merge) and run `/aid-update`; the installer's stale-skill cleanup removes the module's skills and restores `skills/backbone-setup.md`. In a project, re-run the previous agent-backbone `scripts/install-backbone-commands.sh <project>` (kept in agent-backbone's git history at the commit before the cutover) and restore the old hook commands.

## Tests

`tests/test-backbone-git-transport.sh`, `test-backbone-presence.sh`, `test-backbone-commands.sh` (real git, two clones, no mocks).
