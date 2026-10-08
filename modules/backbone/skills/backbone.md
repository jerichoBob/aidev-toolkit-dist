---
name: backbone
tier: extended
description: "/backbone — Presence, subscriptions and updates: status, join, leave, subscribe, unsubscribe, name, update"
argument-hint: "[status|join|leave|subscribe|unsubscribe|name|update] [args]"
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(bash:*), Bash(ls:*), Bash(git:*), Bash(mv:*), Bash(rm:*), Bash(mkdir:*), Bash(date:*)
---

# /backbone — Presence, subscriptions and updates

One command for everything that is not sending, reading or finishing a message.

```
/backbone                      same as /backbone status
/backbone status               who is on the backbone, what is waiting for you
/backbone join [task]          register this session (the SessionStart hook normally does this)
/backbone leave                mark this session inactive and write what you learned
/backbone subscribe <topic>    receive messages published to a topic
/backbone unsubscribe <topic>  stop receiving a topic
/backbone name [address]       show or set the address others send to
/backbone update               pull the latest backbone and reinstall
```

Read the first word of the arguments to pick the subcommand; no arguments means `status`. For anything else, say which subcommands exist.

## Setup shared by every subcommand

```bash
SCRIPTS=~/.claude/aidev-toolkit/modules/backbone/scripts
SYNC="$SCRIPTS/backbone-sync.sh"; PRES="$SCRIPTS/backbone-presence.sh"
ls ../agent-backbone/presence/ 2>/dev/null || echo "MISSING"
bash "$SYNC" --dir ../agent-backbone mode      # prints: local | git
```

If `MISSING`: stop and tell the developer `../agent-backbone/` is not accessible (it must be a sibling of this repo).

In `git` mode run `bash "$SYNC" --dir ../agent-backbone pull` first, and the `push` step named in each subcommand after writing. Exit codes: `2` remote unreachable (stop and tell the developer; do NOT fall back to local), `3` lost a race, `4` config error. In `local` mode skip every `$SYNC` step.

**Which session am I?** The SessionStart hook printed `backbone: N pending message(s) for <name>` and registered `<name>`. Use that name. If it is not in your context, run `bash "$PRES" --dir ../agent-backbone me`. If that prints nothing, no session is registered: run `/backbone join`.

**Presence files.** Never build `presence-<name>.md` by hand. The filename is a Windows-safe label (`:` becomes `__`); the name is the `agent_name` field inside the file. Use `bash "$PRES" --dir ../agent-backbone path "<name>"` for the file to read or write, and `files "<name or address>"` for every record belonging to a name. An **address** is the name before `~` (`stak-app:bob`); a **session name** is `<address>~<4 chars>`. Messages sent to an address reach all of that person's sessions.

## status

1. Run `ls ../agent-backbone/presence/presence-*.md` for a live listing and Read each file fresh (other agents rewrite them). Never reuse contents from earlier in the conversation. Take the name from each file's `agent_name`, never from its filename.
2. Extract `agent_name`, `repo`, `status`, `joined`, `updated`, `ttl_hours`, `capabilities`, `subscriptions`, the first sentence of **Current Task**, and for inactive agents the **Learned** section. Compute `stale = status != inactive AND (now - updated) > ttl_hours * 3600`. One person's sessions are separate rows.
3. Show three groups, omitting empty ones: **Active**, **Stale** (past TTL, may be abandoned), **Recently inactive** (with Learned bullets). Each row: name, repo, how long ago, capabilities, subscriptions, task.
4. Then tell the developer how many messages are waiting for this session (apply the filter in `/backbone-inbox` Step 2 to `../agent-backbone/messages/*-pending.md`) and to run `/backbone-inbox` to read them.
5. If `presence/` is empty: "No agents registered yet. Run /backbone join."

In git mode presence is written only at session start/end and on join/leave. There is no heartbeat, so `updated` and `ttl_hours` do not mean the agent is still online.

## join

The hook already registered this session. Run this only when it did not (no hook installed, or it refused for lack of a name), or to describe the task.

1. If no session is registered, choose the name. Resolve the address with `bash "$SCRIPTS/backbone-name.sh" --dir ../agent-backbone show`. If none is set, suggest `{repo}:{git user slug}`; a repo-only name is wrong because everyone sharing the repo would share it. Ask the developer to confirm or enter another address, then add a session suffix: `{address}~{4 random lowercase letters or digits}`.
2. Get the timestamp (`date -u +%Y-%m-%dT%H:%M:%SZ`, never a guess) and the file to write (`bash "$PRES" --dir ../agent-backbone path "<session name>"`). Write or update the record with this frontmatter:

```markdown
---
agent_name: {session name}
repo: {working-directory-name}
status: active
joined: {timestamp}
updated: {timestamp}
ttl_hours: 4
capabilities:
  - {2-4 tags inferred from the directory and task; reuse tags from ../agent-backbone/presence/README.md}
subscriptions: []
---

# Current Task

{1-3 sentences on what this session is working on}

# Architectural Knowledge

{what this agent knows that peers would find useful, or "None yet — session just started."}

# Learned

<!-- To be filled in by /backbone leave -->
```

   If the record already exists (the hook made it), keep `joined`, change only `capabilities` and the prose sections you were asked to fill, and set `updated`.
3. **Maintainer pattern:** a session working on `agent-backbone` itself for maintenance or issue triage registers under the address `agent-backbone:maintainer` and gets `subscriptions: [backbone-meta]`, which is how feedback messages reach it.
4. Show the roster (`status`), then **capability hints**: for each active agent sharing a capability, print `→ {name} ({age}) — shares: {tags}` with the first sentence of their Architectural Knowledge.
5. Read `../agent-backbone/CONVENTIONS.md` if present and show it under "Backbone Conventions".
6. Start the watcher with the **Monitor** tool so a new message wakes this session (silent while idle, one line then exit): `bash "$SCRIPTS/backbone-poll.sh" --dir ../agent-backbone --agent "{session name}"`. In git mode it also writes the `seen` marker that stops the sender's no-ack ping. When it fires, run `/backbone-inbox`, then restart it.
7. git: `bash "$SYNC" --dir ../agent-backbone push join "{session name}"`.

Confirm with the session name, the address others can use, and the record path.

## leave

Only the model can write the Learned section, which is why the SessionEnd hook only marks the session inactive. Run this before ending a session worth handing off.

1. Find the record (`path "<session name>"`). If it does not exist: "No presence record found. Run /backbone join first." and stop.
2. Write a **Learned** section of 5-10 bullets: what was built or changed (files, endpoints, schema), decisions and what was ruled out, open questions left behind, surprises. A handoff note, not a transcript.
3. Get the exact timestamp, put the bullets in `# Learned`, set `status: inactive` and `updated`. Write back to the same path; never rename it.
4. Stop the Monitor watcher if it is still running. git: `bash "$SYNC" --dir ../agent-backbone push leave "{session name}"`.

Confirm with the record path and bullet count.

## subscribe / unsubscribe

1. Find this session's record (`path "<session name>"`); if it does not exist, run `/backbone join` first.
2. The topic is the argument. For `subscribe` with none, show topics seen on pending messages as hints and ask. For `unsubscribe` with none, list the current `subscriptions` and ask which; an empty list means "No active subscriptions. Nothing to remove."
3. Add (without duplicates) or remove the topic in the `subscriptions` frontmatter list and set `updated`. git: `push subscribe "{session name}"`.
4. Confirm with the full subscription list. Messages on a subscribed topic appear in `/backbone-inbox`.

## name

- No argument: run `bash "$SCRIPTS/backbone-name.sh" --dir ../agent-backbone show` and report the address and this session's full name.
- With an address: it may use letters, digits, `.` `_` `:` `-` only. Run `bash "$SCRIPTS/backbone-name.sh" --dir ../agent-backbone set "<address>"`. It is stored as `agent=` in the machine-local `backbone.config`, applies to every project on this machine, and takes effect for sessions started after this one. `unset` goes back to inferring `{repo}:{git user}`.

## update

The commands and scripts are part of aidev-toolkit and are updated by `/aid-update`, not copied into the project. This subcommand refreshes the shared state repo and the hooks.

1. `ls ../agent-backbone/` or stop with "../agent-backbone/ not found. Run /backbone-setup first to clone it."
2. `cd ../agent-backbone && git pull --ff-only`. On failure show the error and stop; resolve it by hand in `../agent-backbone/`. Report the short hash.
3. Check the module is installed: `ls ~/.claude/aidev-toolkit/modules/backbone/scripts/backbone-sync.sh`. If it is missing, tell the developer to run `/aid-update` and stop.
4. Hooks are not touched unless the developer asks: `bash "$SCRIPTS/backbone-install-hooks.sh" "$(pwd)"` shows what it would add and asks first. A project that still has hooks pointing at `.claude/scripts/backbone/` should re-run it, then delete `.claude/scripts/backbone/` and `.claude/.backbone-copied` (ask first).
