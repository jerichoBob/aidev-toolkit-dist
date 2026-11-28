# Leftover Walk Snippet

A reusable block for any command that ends by listing open items (skipped questions, blocked tasks, loose ends). Paste it at the end of the command's skill file and adapt the "Collect the items" list. The toolkit's own use is Step 3 of `/sdd-code` (spec v121). Project-local commands such as `/sdd-owner-spec-x` and `/commit-push-x` can copy it as is.

## When to use it

Use it when the command's last output is a list the user must act on, not a report. A bullet list at the end is easy to skim past; one question per turn gets an answer.

Do not use it for pure results (a test summary, a changelog) or for a document written for a later session (a handoff briefing). Those are records, not decisions.

## The snippet

```markdown
## Walk the Leftover Items One at a Time

After the summary, raise each leftover item on its own turn and let the user decide it.

**Skip this step entirely** when there are no leftover items (no extra prompt appears) or when `$ARGUMENTS` contains `--skip-questions`.

### Collect the items

List, in this order, only what really exists (never invent an item to have something to ask):

1. {the open questions this command left unanswered}
2. {the tasks this command left blocked}
3. {loose ends noted while working: an assumption, a deferred decision, a follow-up}

### One item per turn

For each item, in order, one item per turn and one single-question `AskUserQuestion` call. Never batch items into one call, and wait for the answer before the next, because later items often depend on earlier answers.

Before the call, print a message of at most four lines that makes sense with no prior context:

    {Item n of N}: {what the item is, in plain words}
    Why it came up: {what happened that raised it}
    What each answer changes: {the effect of the recommended option vs. the others}
    If left undecided: {what happens next run or next session}

The call offers 2-4 options: the recommended one first and labelled "(Recommended)", then the alternatives, then "Leave open". The reason for the recommendation goes in the message text, not only in the label.

### Record the answer

Write the decision where it lasts ({the spec, the task line, or the file this command owns}), not only in the conversation.

### Failure paths

- No answer, cancel, or "Leave open": leave the item open, note it, and continue with the next item. Never block on an unanswered item.
- `AskUserQuestion` unavailable: fall back to the summary lists and say that the walk could not run.

End with one line: `Leftover items: {decided} decided, {open} left open.`
```

## What to fill in

- **Collect the items**: name the three sources your command actually has. Delete a source it does not have.
- **Record the answer**: say exactly where each kind of answer is written, so a later run can find it.
- **`--skip-questions`**: keep the flag name so users learn one switch for every command.

## Audit result for toolkit commands

Checked 2026-11-28 against every skill in `skills/` and `modules/*/skills/`:

| Command | Ends with open items? | Result |
| ------- | --------------------- | ------ |
| `/sdd-code` | Yes | Walk added (v121) |
| `/sdd-spec-loop` | Yes (parked questions) | Already walks them one per call (its Step 5) |
| `/sdd-spec` | Yes (overlap findings) | Qualifies; interactive resolution is tracked in spec v128 Phase 2, so no second change here |
| `/aid-feedback` | Asks which items to spec | Already interactive |
| `/commit`, `/commit-push` | No (a report and warnings) | Does not qualify |
| `/handoff` | Open questions go into a document for the next session | Does not qualify; `/continue` raises them (v124) |
| `/sdd-spec-prioritize`, `/test-run`, `/test-status` | No (ranked list, results) | Does not qualify |
| `/sdd-owner-spec-x`, `/commit-push-x` | Project-local, not in this repo | Copy the snippet above |
