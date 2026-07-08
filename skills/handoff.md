---
name: handoff
description: Compress the current conversation into an actionable briefing for a new thread. Use this when starting a new Claude session to continue unfinished work, when context is running low and work must continue, or when the user says "hand this off", "new thread", "context handoff", or "create a handoff". Produces a launch-pad document, not a summary — everything a cold reader needs to pick up and act immediately.
argument-hint: "[--task <scope>] [--save]"
allowed-tools: Read, Write, Glob, Bash(git:*), Bash(date:*), Bash(mkdir:*)
model: inherit
---

# Handoff

Produce an actionable briefing that lets a new Claude session (or human) continue the current work without re-reading the conversation.

The difference between a summary and a handoff:

- A **summary** says what happened.
- A **handoff** says what to do next, where to find everything, and what not to re-debate.

## Arguments

- **--task `<description>`**: Narrow scope to a specific task or feature. Without this, cover all open work in the conversation.
- **--save**: Write the output to `.claude/handoffs/handoff-<YYYY-MM-DD-HHMMSS>.md` in the project root (or `~/.claude/handoffs/` if no project detected). Always confirm the file path at the end.

## Instructions

### Step 1: Reconstruct what matters

Scan the conversation for:

1. **Work in progress** — tasks started but not finished, features partially built, specs planned but not created
2. **Decisions made** — architectural choices, naming decisions, rejected alternatives. State these as settled facts.
3. **Open questions** — things explicitly deferred, debated without resolution, or flagged as "figure this out later"
4. **Key files** — any file that was created, edited, or is a direct dependency of next steps
5. **Blockers** — missing dependencies, waiting on external input, prerequisite tasks not yet done

### Step 2: Build the handoff document

Use this exact structure:

```markdown
# Handoff — <date> [<task scope if --task was given>]

## What to do next

Numbered list of concrete next actions. Each item must have:
- What exactly to do (imperative, not "we should consider")
- Why it matters (one short clause)
- Source pointer: file path, spec ID, or conversation context

Example:
1. Create specs v29–v33 from `mvp-strategy/CHECKLIST_COMBINED.md` — each spec maps one feature area to its story IDs. Use `/sdd-spec` for each. Source: v29 covers US-04–US-07 (progress tracking), v30 covers US-08–US-09 (notifications).

## Source map

Table linking pending work to its origin in files or specs. New thread should read these before acting.

| Work Item | Source File / Section | Story IDs |
|-----------|----------------------|-----------|
| ... | ... | ... |

## Key files

Files a new thread must know about — either to continue work or to avoid breaking.

- `path/to/file.ts` — one-line description of why it matters
- ...

## Settled decisions — do not re-litigate

Facts about this project. A new thread must treat these as given, not re-open them for debate.

- **Decision**: What was decided. **Reason**: Why (one sentence).
- ...

## Blockers and dependencies

Things that must happen before specific work can proceed.

- `<work item>` blocked on: `<what's needed>` [who/what provides it]
- ...

## Open questions

Explicitly unresolved. A new thread should surface these to the user, not guess.

- [Q]: The question, stated clearly.
  Context: What we know so far, what options were considered.
```

### Step 3: Apply writing rules

**Required on every work item:** a source pointer (file path, spec ID, story ID, or section name). A task without a source is not actionable.

**Forbidden phrases:** "as discussed", "we agreed", "we decided", "it was noted". Rewrite as facts:

- ❌ "We agreed to use GroStak LLC for all infra."
- ✅ "GroStak LLC owns all AWS infra, BAAs, and the Apple Developer account. PB&J Labs LLC is the holding company."

**Decisions go in "Settled decisions"** — not buried in the work items or source map.

**Tone:** Write for someone who has 60 seconds to scan before starting work. Bullet points and short sentences. No narrative paragraphs.

**Length:** Aim for one screen of content per major work stream. If the handoff is longer than ~150 lines, you are summarizing, not focusing — apply `--task` scope or cut ruthlessly.

### Step 4: Handle --save

If `--save` was passed:

1. Get the current timestamp:

   ```bash
   date +%Y-%m-%d-%H%M%S
   ```

2. Determine the output directory:
   - If a `specs/` or `.claude/` directory exists (project context): write to `.claude/handoffs/`
   - Otherwise: write to `~/.claude/handoffs/`
3. Create the directory if it doesn't exist:

   ```bash
   mkdir -p .claude/handoffs
   ```

4. Write the file: `handoff-<timestamp>.md`
5. Report the full path at the end of your response.

## Anti-patterns to avoid

| Anti-pattern | Fix |
|---|---|
| Task list without source pointers | Every item needs `Source:` or a file reference |
| Settled decisions buried in task list | Move to "Settled decisions" section |
| "We discussed X" | Rewrite as the fact: "X is Y because Z" |
| Missing dependency map | Blockers section must list what's waiting on what |
| Restating the whole conversation | Only what a new thread needs to ACT |
| Open questions stated as facts | Move to "Open questions" and label them as unresolved |

## Output

Print the full handoff document directly in the response. If `--save` was passed, also write it to disk and report the path.

Do not add any preamble like "Here is the handoff:" — start directly with the `# Handoff` heading.
