# Pluggable notification

When a direct message has no ack after the timeout, the sender's session pings the receiver's human.
The backbone does not know how: it runs a command **you** configure on **your** machine.

## Configure (machine-local `backbone.config`, never committed)

```text
notify_command=bash /Users/you/bin/backbone-chat.sh   # unset = no notifier, nothing is attempted
notify_confirm=ask                                     # ask (default) or auto, the machine default
notify_confirm.radeas-analyst-amplifier=ask            # per-project override (project = repo name)
notify_confirm.stak-app=auto
```

Resolution for a ping sent as `stak-app:bob`: `notify_confirm.stak-app`, then `notify_confirm`, then `ask`.
These keys are read only from `backbone.config` in the backbone directory, never from a message, the
roster, or any file inside a project repo, because anyone with push access to a repo could otherwise
switch your machine to `auto` or run a command on it.

| Mode | On timeout |
| ---- | ---------- |
| `ask` | `backbone-ack-check.sh` prints `PING <human>\|<notify> :: <text>`. The sender's session shows the exact target and text and runs `backbone-notify.sh` only if you approve. |
| `auto` | `backbone-ack-check.sh` calls `backbone-notify.sh` itself and prints `SENT` or `NOTIFYFAILED`. |
| no `notify_command` | Prints `NONOTIFIER`. Nothing is attempted, in either mode. |

## The contract

`backbone-notify.sh --target T --from AGENT --title TEXT --id TYPE-ID` runs `notify_command` with these
environment variables. Message text is never placed on the command line or interpolated into a shell
string, so quotes, `$(...)`, backticks and newlines in a title arrive unchanged and are not executed.

| Variable | Value |
| -------- | ----- |
| `BACKBONE_NOTIFY_TARGET` | The `notify` column of the roster row (opaque to the backbone; for Radeas, a Chat space ID) |
| `BACKBONE_NOTIFY_TEXT` | `<from> sent you "<title>" on the backbone (<id>)` |
| `BACKBONE_NOTIFY_FROM` | Sender agent name |
| `BACKBONE_NOTIFY_TITLE` | Message title, unchanged |
| `BACKBONE_NOTIFY_ID` | Message id, such as `task-12` |

The **message body is never passed**. Exit 0 means sent; anything else is a failure
(`backbone-notify.sh` then exits 1). Your command must read the environment and not re-evaluate it in a shell.

Each attempt is appended to `<backbone dir>/.claude/data/backbone/pings.log` as tab-separated
`time  result  target  id` (`sent` or `failed`). The title, text and body are never logged. The directory is
git-ignored.

## Roster

`roster.md` maps agents to humans. The last column is the opaque target handed to the notifier:

```text
| agent      | human | notify                |
| ---------- | ----- | --------------------- |
| stak-app:* | Bob   | spaces/AAAAAAAAAAA    |
| radeas-*:* | Nate  | spaces/BBBBBBBBBBB    |
```

## Example: Radeas Google Chat

The only Chat sender found is project-local: `send.py` in
`radeas-analyst-amplifier/.claude/skills/gchat/scripts/`. It needs that project's `venv`, your own
`@radeas.com` OAuth token and a space resource name. Chat has no draft, so a message is live the moment it
is sent. That project's skill requires showing the exact space and text and getting confirmation every time,
which is why `ask` is the default and why Radeas should keep `ask`. Save this wrapper somewhere you own
(it is not part of this repo):

```bash
#!/usr/bin/env bash
# ~/bin/backbone-chat.sh — notifier for backbone-notify.sh. Reads BACKBONE_NOTIFY_* from the environment.
set -euo pipefail
RADEAS="$HOME/wgh/radeas-analyst-amplifier"
cd "$RADEAS"
exec venv/bin/python3 .claude/skills/gchat/scripts/send.py \
  --space "$BACKBONE_NOTIFY_TARGET" --text "$BACKBONE_NOTIFY_TEXT"
```

Then `notify_command=bash /Users/you/bin/backbone-chat.sh`. The wrapper passes the target and text as
separate quoted arguments; do not build one command string from them. Writing and maintaining this wrapper
belongs to the Radeas project, not the backbone. Other notifiers (email, a webhook, a desktop notification)
follow the same shape.
