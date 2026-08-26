---
name: sdd-spec-prioritize
tier: extended
description: "Recommend the top N specs to focus on next, with reasoning"
argument-hint: "[N]"
disable-model-invocation: false
allowed-tools: Read, Grep, AskUserQuestion
---

# Prioritize Next Specs

Analyze all active (incomplete) specs and recommend the top N specs to focus on next.

**N** defaults to 5 if not provided. Example: `/sdd-spec-prioritize 10` shows the top 10.

## Step 1: Load Active Specs

Read `specs/README.md`. Extract every row from the Quick Status table where Status does **not** contain `✅ Complete` or `🗄 Archived`. These are the candidates.

## Step 2: Read Each Spec File (targeted extraction only)

For each candidate spec, avoid reading the full spec file — most of it (What/How/Technical Notes/Security) is not needed for ranking. Use a targeted read instead:

1. `Grep` the file for `^---$` to find the YAML frontmatter block boundaries, then `Read` only that line range to get `depends_on`, `tags`, and `status`.
2. `Grep` the file for `^## Why` to find where the Why section starts, then `Read` a small line range starting there (through the next `^##` heading or ~15 lines, whichever comes first) to get the problem statement/blockquote.

Extract:

- **Type**: bug fix, enhancement, new feature, or living spec (infer from title/Why text)
- **Scope**: task count from Progress column (skip `∞` and `→ vN` rows) — already available from the README table in Step 1, no file read needed
- **Dependencies**: `depends_on` values from the frontmatter range read above
- **Status**: Draft / In Progress / Deferred / Consolidated (already available from the README table)
- **Problem statement**: the "Why" section text extracted above — what pain does this solve?

Do not read the file's What, How, Technical Notes, Security, or Open Questions sections — they are irrelevant to ranking and only add read cost.

Skip specs with status `🔀 Consolidated` or `⏸ Deferred` unless no other candidates exist.

## Step 3: Score and Rank

Apply this rubric to rank candidates:

| Factor           | Weight   | Notes                                                               |
| ---------------- | -------- | ------------------------------------------------------------------- |
| **Type**         | High     | Bug fixes > new features > enhancements > living specs              |
| **Scope**        | High     | Fewer tasks = faster to ship = higher rank                          |
| **Value**        | High     | Direct user-facing pain > internal tooling > nice-to-have           |
| **Blockers**     | Critical | Skip or deprioritize any spec with unresolved `depends_on`          |
| **Status**       | Medium   | In Progress > Draft > Deferred                                      |
| **Independence** | Medium   | Standalone work preferred over work that requires other specs first |

## Step 4: Display Top N

Determine N from `$ARGUMENTS` (default: 5 if empty or not a positive integer).

Present the top N ranked specs with a one-paragraph reasoning for each.

```text
Top {N} Specs to Focus On

#1 v{N} — {Name} ({task_count} tasks, {type})
   {1-2 sentence reasoning: why this ranks here, what value it delivers, why now}

#2 v{N} — {Name} ({task_count} tasks, {type})
   {reasoning}

...

#N v{N} — {Name} ({task_count} tasks, {type})
   {reasoning}

---
To implement: /sdd-code v{N}
```

If fewer than N viable candidates exist, show all of them and note that the backlog is nearly clear.

## Step 5: Hand Off to Implementation

After displaying the ranked list, use `AskUserQuestion` to ask:

> "Which spec would you like to implement? Enter a number (1–{N}), a spec version (e.g. v19), or 'skip' to exit."

- If the user enters a number, map it to the corresponding ranked spec
- If the user enters a spec version directly, use that
- If the user enters 'skip' or dismisses, exit gracefully with no further action

Once a spec is selected, invoke `/sdd-code` for that spec version by following the full instructions in `~/.claude/skills/sdd-code.md` (read it and execute its workflow for the chosen spec).
