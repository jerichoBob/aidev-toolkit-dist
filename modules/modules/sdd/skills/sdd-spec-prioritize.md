---
name: sdd-spec-prioritize
description: "Recommend the top N specs to focus on next, with reasoning"
argument-hint: "[N]"
disable-model-invocation: false
allowed-tools: Read, AskUserQuestion
---

# Prioritize Next Specs

Analyze all active (incomplete) specs and recommend the top N specs to focus on next.

**N** defaults to 5 if not provided. Example: `/sdd-spec-prioritize 10` shows the top 10.

## Step 1: Load Active Specs

Read `specs/README.md`. Extract every row from the Quick Status table where Status does **not** contain `✅ Complete` or `🗄 Archived`. These are the candidates.

## Step 2: Read Each Spec File

For each candidate spec, read its spec file at `specs/spec-v{N}-*.md`. Extract:

- **Type**: bug fix, enhancement, new feature, or living spec
- **Scope**: task count from Progress column (skip `∞` and `→ vN` rows)
- **Dependencies**: any `depends_on` values in YAML frontmatter
- **Status**: Draft / In Progress / Deferred / Consolidated
- **Problem statement**: the "Why" section — what pain does this solve?

Skip specs with status `🔀 Consolidated` or `⏸ Deferred` unless no other candidates exist.

## Step 3: Score and Rank

Apply this rubric to rank candidates:

| Factor | Weight | Notes |
|--------|--------|-------|
| **Type** | High | Bug fixes > new features > enhancements > living specs |
| **Scope** | High | Fewer tasks = faster to ship = higher rank |
| **Value** | High | Direct user-facing pain > internal tooling > nice-to-have |
| **Blockers** | Critical | Skip or deprioritize any spec with unresolved `depends_on` |
| **Status** | Medium | In Progress > Draft > Deferred |
| **Independence** | Medium | Standalone work preferred over work that requires other specs first |

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
To implement: /sdd-code-spec v{N}
```

If fewer than N viable candidates exist, show all of them and note that the backlog is nearly clear.

## Step 5: Hand Off to Implementation

After displaying the ranked list, use `AskUserQuestion` to ask:

> "Which spec would you like to implement? Enter a number (1–{N}), a spec version (e.g. v19), or 'skip' to exit."

- If the user enters a number, map it to the corresponding ranked spec
- If the user enters a spec version directly, use that
- If the user enters 'skip' or dismisses, exit gracefully with no further action

Once a spec is selected, invoke `/sdd-code-spec` for that spec version by following the full instructions in `~/.claude/skills/sdd-code-spec.md` (read it and execute its workflow for the chosen spec).
