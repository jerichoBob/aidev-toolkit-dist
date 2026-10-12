# Git transport

Agents on one machine rarely need the backbone: Claude Code already has its own way for sessions to talk. The backbone earns its keep
when agents are on **different machines** (or are not Claude). It keeps messages and presence as plain files in one directory, and
`transport=git` moves those files between machines through a private git remote that your team creates. Without it (`transport=local`)
the files stay on one disk, which suits other LLM tools sharing one machine.

The directory is wherever `backbone-dir.sh` points: `$BACKBONE_DIR`, else the first line of `~/.config/aidev-backbone/dir`, else
`~/.config/aidev-backbone/bus`. `/backbone-setup` creates it, or clones your team's remote into it.

## Choosing a transport

Create `backbone.config` in the backbone directory (it is per machine and never committed):

```text
transport=git          # local (default) | git
agent=stak-app:bob     # optional: your address; without it the hook uses <repo>:<git user.name>
```

| Setting | Behavior |
| --- | --- |
| absent, or `transport=local` | v1–v3 behavior. No command touches git, even if the directory has a remote. |
| `transport=git` | Publish, claim, complete, join and leave pull first and push after. An unreachable remote is an error — there is no silent fallback to local. |
| anything else | Error (exit 4). |

## Where the messages live

- **Several machines, one team (the normal case):** a dedicated private repo. One person creates it empty; everyone runs `/backbone-setup` and gives its URL, which clones it into the backbone directory.
- **One project:** an orphan `backbone` branch of the project repo, checked out as a worktree; point `BACKBONE_DIR` (or the pointer file) at it.

`backbone-init.sh` adds a `.gitignore` for the per-machine files (`backbone.config`, the ping log). Messages, presence, the roster and `seen` markers are tracked.

## Scripts

These live in aidev-toolkit's `backbone` module and are called by absolute path, `~/.claude/aidev-toolkit/modules/backbone/scripts/<script>`, installed once by `/aid-update`. Nothing is copied into projects. Scripts find the backbone with `--dir` or `BACKBONE_DIR`, defaulting to `../agent-backbone`.

| Script | Purpose |
| --- | --- |
| `backbone-sync.sh [--dir D] mode\|pull\|push <action> <id>` | The only code that touches git. Exit 0 ok, 2 remote unreachable, 3 lost a race, 4 config error. |
| `backbone-session-start.sh` | SessionStart hook: pull, register this session's presence, print the pending count first, write seen markers, tell the agent to start the watcher. |
| `backbone-session-end.sh` | SessionEnd hook: mark this session's presence inactive and push it. |
| `backbone-install-hooks.sh <project>` | Merge both hooks into the project's `settings.json`. Asks first; `--dry-run` shows the change; `--yes` skips the question. |
| `backbone-poll.sh` | Run under Monitor: silent while idle, one line and exit on a new addressed message. |
| `backbone-presence.sh` | Find presence records by `agent_name` (`path`, `files`, `me`, `safe`). |
| `backbone-migrate-presence.sh` | Rename old colon-named presence files (`--dry-run` first; keeps git history). |
| `backbone-name.sh` | Show, set or unset the `agent=` address. |

### Session hooks

The hooks are offered by `/backbone-setup`, or installed on their own:

```bash
bash ~/.claude/aidev-toolkit/modules/backbone/scripts/backbone-install-hooks.sh <project>
```

It shows exactly what it will add to `.claude/settings.json`, keeps every existing setting and hook, saves the old file as `settings.json.bak-backbone`, and changes nothing without your yes. Equivalent by hand:

```json
{
  "hooks": {
    "SessionStart": [ { "hooks": [ { "type": "command", "command": "bash ~/.claude/aidev-toolkit/modules/backbone/scripts/backbone-session-start.sh" } ] } ],
    "SessionEnd":   [ { "hooks": [ { "type": "command", "command": "bash ~/.claude/aidev-toolkit/modules/backbone/scripts/backbone-session-end.sh" } ] } ]
  }
}
```

Both hooks always exit 0 and print a reason instead of failing, so they can never block a session. The pending count is always the first line printed.

**Names.** `agent=` (or `BACKBONE_AGENT`) sets your *address*, the stable name others send to. Without it the hook uses `<repo>:<slug of git user.name>` and says it inferred it; with no git user it refuses to register rather than give everyone sharing the repo one identity. Each session registers as `<address>~<4 random chars>`, so one person can run several sessions: a message to the address reaches all of them and the atomic claim decides which acts, while a message to a full session name reaches only that one.

**Windows.** Presence and seen-marker filenames never contain `: / \ * ? " < > |` (`:` becomes `__`); the real name is the `agent_name` field inside the file. Repos with older colon-named files run `bash scripts/backbone-migrate-presence.sh --dry-run`, then without `--dry-run`, then commit the staged renames.

## Knowing a message arrived

| When the receiver is... | What tells them |
| --- | --- |
| starting a session | `backbone-session-start.sh` prints the pending count first |
| in an open session | `backbone-poll.sh` under Monitor wakes the agent (30 s interval, no tokens while idle) |
| away | after 5 minutes with no ack, the sender's session pings the receiver's human through the configured notifier (see [notify.md](notify.md)) |

An ack is a claim or a `seen` marker (`messages/seen/<type>-<id>.<agent>`), which the hook and the poll write
and push. The ping carries sender and title only. Who to ping comes from `roster.md` at the backbone root,
edited by hand (rows may use globs, see `scripts/backbone status-lookup.sh`):

```text
| agent      | human | notify          |
| ---------- | ----- | --------------- |
| stak-app:* | Bob   | bob@example.com |
```

The sender's session must stay open for the timer to fire. `backbone-ack-check.sh` is the timer; the
send itself goes through `backbone-notify.sh` and whatever `notify_command=` names; the `notify` column is an opaque target
for that command (for Radeas, a Chat space ID, not an email).

## Claiming over git

Claim renames `-pending` to `-claimed` and records `claimed_by`, then pushes. Two agents claiming at once
both commit; the first push wins and the second is rejected. The wrapper drops the loser's commit,
re-syncs, and exits 3 so `/backbone-inbox` can say "already claimed by X".

## Access control for the remote

Anyone who can push to the remote can put a request in front of every teammate's agent. Treat write access
like access to a shared inbox that agents read:

- Use a **private** repo (or a private branch of one). Messages carry project context, and private repos
  are the only protection — there is no message encryption.
- Grant write access only to people whose agents should be able to send requests, and review it when the team changes.
- Use per-person credentials (SSH keys or `gh` auth), never a shared token.
- Consider requiring signed commits on the message branch. The sender field is self-declared; signatures are
  the way to make it verifiable, and are not enforced by these scripts.
- Agents treat message content as untrusted requests (see `CONVENTIONS.md`), so a hostile message cannot
  run anything without a human approving it. This is a second layer, not a substitute for the first.
- `/backbone-send` refuses bodies that look like secrets (`scripts/backbone-secret-check.sh`). It is a
  pattern check, not a guarantee. If a secret does get pushed, rotate it; deleting the message does not remove it from git history.

## Testing

In aidev-toolkit: `bash tests/test-backbone-git-transport.sh` — real git, two clones of a local bare repo, no mocks. In this repo, `bash tests/test-repo-docs.sh` checks the protocol documents and ignore rules. `.claude/scripts/rehearse-live-exchange.sh` and `.claude/scripts/e2e-check-hooks.sh` run the Bob and Nate exchange and the hook install end to end on one machine.
