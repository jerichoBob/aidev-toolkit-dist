---
name: backbone-done
tier: extended
description: "/backbone-done — Finish a claimed message and archive it"
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(bash:*), Bash(ls:*), Bash(git:*), Bash(mv:*), Bash(rm:*), Bash(mkdir:*), Bash(date:*)
---

# /backbone-done — Finish a claimed message and archive it

Replaces `/backbone-complete`. Writes the completion notes, marks the message complete, and moves it to `messages/archive/`, which takes it out of the active scan path.

## Setup

```bash
SCRIPTS=~/.claude/aidev-toolkit/modules/backbone/scripts
SYNC="$SCRIPTS/backbone-sync.sh"; PRES="$SCRIPTS/backbone-presence.sh"
bash "$SYNC" --dir ../agent-backbone mode      # prints: local | git
```

In `local` mode skip every `$SYNC` step. In `git` mode run `bash "$SYNC" --dir ../agent-backbone pull` first. Exit codes: `2` remote unreachable (stop; do NOT fall back to local), `3` lost a race, `4` config error.

## Find the message

This session's name is the one the SessionStart hook printed, or `bash "$PRES" --dir ../agent-backbone me`.

```bash
ls ../agent-backbone/messages/*-claimed.md 2>/dev/null
```

Read each frontmatter and keep the ones whose `claimed_by` is this session's name or its address. If none: "No claimed messages for this session. Run /backbone-inbox to claim one first." If several, list them and ask which.

## Write the completion notes

Read `../agent-backbone/messages/types/{type}.md` for the completion section: `cr` has **Implementation Notes** (endpoints added, schema changes, migration path, breaking changes); `task` has **Completion Notes** (what was done, acceptance criteria met or unmet, follow-on work). Be specific enough that the sender can act without a follow-up question. Do not put secrets in them; the same rule as `/backbone-send` applies, so run `backbone-secret-check.sh` on the notes first.

## Archive

1. In the message file, fill in the completion section, set `status: complete` and `updated: {today}`.
2. `mkdir -p ../agent-backbone/messages/archive`, then move `{type}-{id}-claimed.md` to `archive/{type}-{id}-complete.md`. Never delete it: the archive is the audit trail.
3. git mode: `bash "$SYNC" --dir ../agent-backbone push complete {type}-{id}`.

## Confirm

```
Done: ../agent-backbone/messages/archive/{type}-{id}-complete.md
Type: {type}    From: {from}

Completion notes written:
{short bullet summary}

Archived: this message will no longer appear in /backbone-inbox.
{if direct: The sender ({from}) can read the archived file for the details.}
```

If the sender needs to follow up after reading the notes, they send a new message.
