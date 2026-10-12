# Backbone Module — agent-to-agent coordination across machines

A message bus and presence registry for agents that **cannot** talk to each other directly: sessions on different machines, or on tools other than Claude Code. Agents on one machine can usually just use Claude Code's own inter-agent features, and do not need this.

Messages, presence records and a roster are plain files in one directory. With `transport=git`, a private git remote that your team creates moves those files between machines. With `transport=local` they stay on one disk.

The module stands alone, like `sdd`: everything it needs ships here and is installed once by `/aid-update`. No other repo is required.

## Layout

| Dir | Holds | Installed to |
| --- | ----- | ------------ |
| `scripts/` | `backbone-*.sh`: dir, init, sync (the only code that touches git), poll, session hooks, notifier, ack timer, presence, roster lookup, secret check, name, migrate | stays in place; called as `~/.claude/aidev-toolkit/modules/backbone/scripts/<script>` |
| `skills/` | `/backbone`, `/backbone-send`, `/backbone-inbox`, `/backbone-done`, `/backbone-setup` | `~/.claude/commands/` and `~/.claude/skills/` by `scripts/install.sh` (`BACKBONE_SKILLS`) |
| `types/` | message-type schemas (`cr`, `task`, `feedback`, `story-status-update`) | stays in place; a `messages/types/` in the state directory overrides it |
| `docs/` | `git-transport.md`, `notify.md`, `CONVENTIONS.md` | stays in place |
| `templates/` | `backbone.config.example`, `roster.md`, `hooks-settings.json` | read by `backbone-init.sh` and `backbone-install-hooks.sh` |

## The state directory

Everything that changes at runtime (messages, presence, roster, `backbone.config`, ping log) lives in one **state directory**, never in the toolkit. Each machine finds it the same way (`scripts/backbone-dir.sh`):

1. `$BACKBONE_DIR`
2. the first line of `~/.config/aidev-backbone/dir` (a pointer you set once)
3. `~/.config/aidev-backbone/bus`

Nothing is read from `~/.claude` and no sibling repo is assumed.

## Setup

1. `/aid-update` installs the module.
2. `/backbone-setup` asks how this machine joins:
   - **your team's shared remote** (`--remote URL`): clones it into the state directory, `transport=git`. This is the cross-machine case. One person first creates an empty private repo;
   - **local only**: creates the directory with `transport=local`;
   - **`--import DIR`**: copies messages, archive, presence and roster from an older checkout.
3. Optionally add the session hooks to a project: `backbone-install-hooks.sh <project>` (asks first, merges without overwriting). The hooks name no directory, so one `settings.json` works on every machine.

## Migrating a project that has old per-project copies

Re-run the hook installer, then after checking `git status` delete `.claude/scripts/backbone/` and `.claude/.backbone-copied`. Old `.claude/commands/backbone-*.md` copies in the project override the global ones until removed. The old per-project command names (`/backbone-publish`, `-complete`, `-join`, `-leave`, `-roster`, `-subscribe`, `-unsubscribe`, `-update`) are not part of this module.

## Rollback

Revert the toolkit change and run `/aid-update`; the installer's stale-skill cleanup removes the module's skills and restores `skills/backbone-setup.md`. State is untouched: it lives in the state directory.

## Tests

`tests/test-backbone-git-transport.sh`, `test-backbone-presence.sh`, `test-backbone-commands.sh`, `test-backbone-standalone.sh` (resolution, init, import, and two machines exchanging a message through a shared remote with no sibling repo). Real git, no mocks.
