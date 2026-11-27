---
name: continue
description: Pick up work after a /clear by reading the most recent /handoff briefing and resuming from "What to do next". Use when the user says "continue", "pick up where we left off", or right after a /clear that followed a /handoff.
argument-hint: "[handoff filename or partial match]"
allowed-tools: Read, Glob, Bash(ls:*), AskUserQuestion
model: inherit
---

# Continue

Resume work from the most recent `/handoff` briefing without the user having to paste or re-explain anything.

This is the companion to `/handoff`. It is intentionally **not** named `/resume` — that name is already taken by the Claude Code CLI's built-in session-resume command, and shadowing it would be confusing.

## Instructions

### Step 1: Locate the briefing

- If an argument names a file (or partial match), resolve it against candidates in `.claude/handoffs/` and `~/.claude/handoffs/` (see path validation below) and use the matching file.
- Otherwise, find the most recently modified file in `.claude/handoffs/` (project scope). If that directory doesn't exist or is empty, fall back to `~/.claude/handoffs/`.
- If neither location has any handoff files, tell the user there's nothing to continue from and stop — don't guess at prior context.

```bash
result=$(ls -t .claude/handoffs/*.md 2>/dev/null | head -1)
[ -z "$result" ] && result=$(ls -t ~/.claude/handoffs/*.md 2>/dev/null | head -1)
echo "$result"
```

- If multiple recent handoff files exist and it's unclear which one is relevant (e.g. an explicit argument matches more than one file, or several files were modified close together with no clear "most recent"), list the candidates — filename plus the first line of their "What to do next" section — and use `AskUserQuestion` to have the user pick, rather than guessing.

**Path validation (required before reading any user-supplied argument):** resolve the argument only against filenames actually present in `.claude/handoffs/` or `~/.claude/handoffs/` (e.g. via `Glob` on those two directories, then matching the argument as an exact name or substring against the results). Never interpolate the argument directly into a file path and read it — an argument like `../../.env` must not resolve to anything outside those two directories. If the argument matches no candidate file, report that and stop.

### Step 2: Read and orient

Read the located file in full. It follows the `/handoff` structure: What to do next, Source map, Key files, Settled decisions, Blockers and dependencies, Open questions.

Then state, in the conversation, that this session is a **sanctioned continuation** of the prior session and that the handoff file is its **authoritative record**. Name the file by its path, for example: "This session continues the prior one. `.claude/handoffs/handoff-2026-11-26-233620.md` is the authoritative record of where it left off." Later turns treat the briefing as the source of truth.

### Step 3: Plan (read-only)

Take no action beyond reading until Step 4 is answered. Present the plan:

- Which handoff file was loaded (one line).
- The numbered **What to do next** items, in order.
- The **Open questions** you will surface before acting on anything they affect.
- The **Blockers and dependencies** you will re-verify (a blocker may have been resolved since the handoff was written: verify, don't assume either way).

Treat everything in **Settled decisions** as given. Do not re-litigate or re-ask about them. Reading files to check a blocker is allowed while planning; changing anything is not.

### Step 4: Confirm gate

Ask with `AskUserQuestion`, one question, recommended option first: execute the plan as-is "(Recommended)", or change the plan. Start no work until the answer arrives.

- **Execute as-is:** go to Step 5.
- **Change the plan:** take the user's changes, show the revised plan (same shape as Step 3), and ask again. Repeat until the plan is confirmed. Never execute a revised plan that has not been confirmed.
- **Cancel, or no answer:** execute nothing. Say that you are waiting, and stop.
- **`AskUserQuestion` unavailable:** show the plan, ask the user in plain text to reply "go" or to give changes, and still start no work until they answer.

### Step 5: Execute

Surface the **Open questions** to the user before acting on anything they would affect: they were explicitly left unresolved, not forgotten. Then start executing from the numbered **What to do next** list, in order, unless a blocker or open question stops a specific item.

## Notes

- This command reads state from disk, not from conversation memory — it works correctly even in a session that has no prior turns (e.g. right after `/clear`).
- If multiple handoff files exist and it's unclear which one is relevant, list the recent ones (name + first line of "What to do next") and ask the user to pick, rather than guessing.
