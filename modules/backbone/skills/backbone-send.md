---
name: backbone-send
tier: extended
description: "/backbone-send — Send a message to another agent or a topic"
argument-hint: "[--type TYPE] [--to AGENT | --topic TOPIC]"
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(bash:*), Bash(ls:*), Bash(git:*), Bash(mv:*), Bash(rm:*), Bash(mkdir:*), Bash(date:*)
---

# /backbone-send — Send a message to another agent or a topic

Replaces `/backbone-publish`. Drafts a typed message, refuses it if it holds a secret, writes it, pushes it in git mode, and starts the no-ack timer.

## Setup

```bash
SCRIPTS=~/.claude/aidev-toolkit/modules/backbone/scripts
SYNC="$SCRIPTS/backbone-sync.sh"; PRES="$SCRIPTS/backbone-presence.sh"
ls ../agent-backbone/messages/types/ 2>/dev/null || echo "MISSING"
bash "$SYNC" --dir ../agent-backbone mode      # prints: local | git
```

If `MISSING`: stop; `../agent-backbone/` is not accessible. In `local` mode skip every `$SYNC` step. In `git` mode run `bash "$SYNC" --dir ../agent-backbone pull` now. Exit codes: `2` remote unreachable (stop and tell the developer; do NOT fall back to local), `3` lost a race, `4` config error.

## Step 0: Clarify intent

**MUST ask this before doing anything else, even if context seems obvious. Never infer intent and skip it.**

```
What is the intent of this message?
  a) Informational — share context or artifacts; no action required from the receiver
  b) Task — delegate a unit of work with acceptance criteria
  c) Change request — ask the receiver to make a code/schema change
  d) Other — describe:
```

Informational: a lightweight prose message with no acceptance criteria or to-do list. Task: use type `task`. Change request: use type `cr`. Other: ask a follow-up first.

## Step 1: Type

Use `--type <type>` if given. Otherwise list `../agent-backbone/messages/types/*.md` (excluding `README.md`) and ask. Read the chosen `messages/types/{type}.md` before drafting.

## Step 2: Routing

Use `--to <agent>` or `--topic <topic>` if given; otherwise ask: a specific agent (direct) or a topic (pub/sub).

- **Direct:** show active agents from `/backbone status`. A person's address (`stak-app:nate`) reaches all of their live sessions and the first to claim wins; a full session name (`stak-app:nate~ab12`) targets one session; `any` is an unclaimed broadcast. Set `routing: direct`, `to: {name}`.
- **Topic:** ask for the topic name. Set `routing: topic`, `topic: {topic}`.

## Step 3: Sender

Use this session's name (printed by the SessionStart hook, or `bash "$PRES" --dir ../agent-backbone me`). If neither gives one: "No session registered. Run /backbone join first." and stop.

## Step 4: Draft

Using the conversation, draft the type-specific frontmatter and every prose section the type schema defines. If context is sparse for a section, ask one focused question rather than leaving it blank.

## Step 5: Secret check

Before writing the message, write the drafted body to a scratch file **inside the backbone directory** (not `/tmp`) and scan it:

```bash
bash "$SCRIPTS/backbone-secret-check.sh" {draft-file}
```

Exit `1` means a possible secret (credentials in a connection string, bearer token, private key, API key, long token). The script prints `line N: <what matched>`, never the text. **Refuse to send.** Tell the sender which lines matched, ask them to remove it or refer to it by name ("the Atlas URI in your .env"), and re-draft. Never offer to bypass the check. Delete the scratch file afterwards. This applies to every transport.

## Step 6: Write

Id: `YYYYMMDD-HHMMSS`. Write `../agent-backbone/messages/{type}-{id}-pending.md`:

```markdown
---
id: "{id}"
type: {type}
status: pending
routing: {direct|topic}
from: {session name}
to: {name}              # routing: direct
topic: {topic}          # routing: topic
{type-specific fields}
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

{prose sections from the type schema}
```

git mode: `bash "$SYNC" --dir ../agent-backbone push publish {type}-{id}`. If it fails, report the error: the message is on disk but the recipient will not see it until a push succeeds.

## Step 7: No-ack ping (git mode, direct messages to a named agent)

Skip for `local` transport, topic routing and `to: any`: there is no single recipient to ping.

After a successful push, start the sender-side timer with the **Monitor** tool:

```bash
bash "$SCRIPTS/backbone-ack-check.sh" --dir ../agent-backbone --id {type}-{id} --to {to} --from {from} --title "{title}"
```

Defaults: 5-minute timeout, 15-second interval. It stays silent if the receiver claims the message or writes a `seen` marker in time. What it prints on timeout depends on `notify_confirm` (project override, machine default, then `ask`, read only from the machine-local `backbone.config`):

- `PING <human>|<notify> :: <text>` (`ask`): show the developer the exact target (`<notify>`) and text, and run the notifier only if they approve: `bash "$SCRIPTS/backbone-notify.sh" --dir ../agent-backbone --target "<notify>" --from {from} --title "{title}" --id {type}-{id}`. Pass the title as one quoted argument and never build a shell string from message text. Sender and title only, never the body.
- `SENT ...` (`auto`): the notifier already ran. Tell the developer who was pinged.
- `NOTIFYFAILED ...` (`auto`): it ran and failed. Tell the developer and show the ping text instead.
- `NONOTIFIER ...`: no `notify_command` is configured; nothing was attempted. See `docs/notify.md`.
- `NOPING`: there is no `roster.md` entry for the recipient (see `docs/git-transport.md`).

The timer lives in this session. If the session closes before the 5 minutes pass, no ping is sent.

## Step 8: Confirm

```
Sent: ../agent-backbone/messages/{type}-{id}-pending.md
Type: {type}    From: {from}    {To: {to} | Topic: {topic}}

direct:  Switch to the {to} session and run /backbone-inbox to pick this up.
topic:   Any agent subscribed to "{topic}" will see this in /backbone-inbox.
any:     Any registered agent can claim this via /backbone-inbox.
```
