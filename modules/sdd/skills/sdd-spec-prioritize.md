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

## Step 0: Check for Milestone Definition

Before scoring, check whether `specs/README.md` has a `## Milestones` section — a milestone name mapped to the list of spec versions that gate it, e.g.:

```markdown
## Milestones

- **M2**: v6, v7, v8, v9.1, v9.3
```

- If the section **is present**, parse it into `{milestone_name: [gating_spec_versions]}` and proceed to Step 1 with milestone-aware ranking active (see Steps 3–4).
- If the section is **absent**, use `AskUserQuestion` to ask: "No milestones defined. Define one for this run, or use standard feasibility-only ranking?"
  - If the user chooses to define one: collect a milestone name and the list of gating spec versions inline. This is ad-hoc for the current run only — do **not** write it back to `specs/README.md` unless the user explicitly asks you to persist it.
  - If the user declines: proceed with the unchanged legacy feasibility-only rubric (skip Steps 3's Milestone Path factor and Step 3.5 entirely).

This feature is fully opt-in — projects that never define a milestone see identical behavior to before this change.

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

**Exception**: if Step 0 found an active milestone, once Step 2.5 has determined which candidates are on-path, `Grep` each on-path candidate's file for `^## Open Questions` and `^Blocked by:` and `Read` those small line ranges too (needed for Step 3.5's blocker scan). Off-path candidates never need this extra read.

Skip specs with status `🔀 Consolidated` or `⏸ Deferred` unless no other candidates exist.

## Step 2.5: Determine Milestone Path (only if a milestone is defined in Step 0)

If Step 0 produced a milestone definition (from the README's `## Milestones` section or the ad-hoc per-run answer), build the on-path/off-path split before scoring:

1. Start with the milestone's gating spec list (e.g. `v6, v7, v8, v9.1, v9.3`).
2. For each gating spec, read its `depends_on` frontmatter (already extracted in Step 2) and recurse: add each dependency's own `depends_on` values, and so on, until the set stops growing. This is the transitive dependency set.
3. Mark every candidate from Step 1 as **on-path** if it is itself a gating spec or is in the transitive dependency set; otherwise mark it **off-path**.

If no milestone is defined, skip this step — every candidate is treated as off-path/unranked-by-path, which is equivalent to the legacy behavior.

## Step 3: Score and Rank

Apply this rubric to rank candidates:

| Factor              | Weight                        | Notes                                                                             |
| ------------------- | ------------------------------ | ---------------------------------------------------------------------------------- |
| **Milestone Path**  | Critical — overrides all else | Only applies when a milestone is defined (Step 0/2.5). On-path candidates rank above every off-path candidate, full stop — the factors below never override this. |
| **Type**            | High                           | Bug fixes > new features > enhancements > living specs                            |
| **Scope**           | High                           | Fewer tasks = faster to ship = higher rank                                        |
| **Value**           | High                           | Direct user-facing pain > internal tooling > nice-to-have                         |
| **Blockers**        | Critical                       | Skip or deprioritize any spec with unresolved `depends_on`                        |
| **Status**          | Medium                         | In Progress > Draft > Deferred                                                    |
| **Independence**    | Medium                         | Standalone work preferred over work that requires other specs first               |

When a milestone is active, Type/Scope/Value/Blockers/Status/Independence are used **only to break ties within the same path group** (on-path vs. on-path, or off-path vs. off-path) — they never move an off-path candidate above an on-path one. When no milestone is defined, ranking is unchanged from before this feature: Type/Scope/Value/Blockers/Status/Independence alone.

## Step 3.5: Blocker Detection (only if a milestone is defined and on-path candidates exist)

For each **on-path** candidate, scan the "Open Questions" and "Technical Notes" text extracted in Step 2's exception for external/non-code blocker language. This is a conservative keyword heuristic, not a general classifier — it's intentionally biased toward missing a blocker over falsely flagging one:

- Keyword match terms: `confirm`, `approval`, `waiting on`, `stakeholder`, `access`, `credentials`, `pending decision from` — or an explicit `Blocked by:` line naming a person/team rather than a spec version.
- The match must appear in the "Open Questions" section specifically, or as an explicit `Blocked by:` line — a mention anywhere else in the document (e.g. an internal design note like "confirm the schema matches") does not count. This avoids false positives on a spec's own implementation notes.
- The blocker must not be resolvable by implementing another tracked spec (i.e. it doesn't name a spec version) — if it does, it's a dependency, not a real-priority blocker.

If one or more on-path candidates have such a blocker:

- Surface each as a first-class line **above** the Top N ranking (not folded into it): `⚠ Real priority: resolve "{open question text}" (blocks v{N}, v{M}, ...)`
- If multiple candidates are blocked, order these lines by how early they sit on the dependency chain — blockers closer to the milestone's root dependency surface first.

If no blocking open question is found on the milestone path, skip this step's output entirely and proceed straight to Step 4's Top N ranking.

## Step 4: Display Top N

Determine N from `$ARGUMENTS` (default: 5 if empty or not a positive integer).

If Step 3.5 produced any `⚠ Real priority:` lines, print them first, above everything else.

When a milestone is active (Step 0/2.5), order the list on-path candidates first (each annotated `(on milestone path)`), then off-path candidates filling any remaining N slots (AC-7 — the list doesn't shrink just because the on-path set is small). When no milestone is defined, order is unchanged from before this feature (Type/Scope/Value/Blockers/Status/Independence only).

Present the top N ranked specs with a one-paragraph reasoning for each. When a milestone is active, the reasoning must state *why* the candidate ranks where it does **relative to the milestone** — e.g. "gates M2 directly" or "off milestone path; ranked on feasibility only" — not just feasibility language.

```text
{⚠ Real priority: resolve "{open question text}" (blocks v{N}, v{M}, ...)}
{⚠ Real priority: ... (repeat per Step 3.5 finding, if any)}

Top {N} Specs to Focus On

#1 v{N} — {Name} ({task_count} tasks, {type}) {(on milestone path) if applicable}
   {1-2 sentence reasoning: why this ranks here relative to the milestone (or feasibility, if no milestone), what value it delivers, why now}

#2 v{N} — {Name} ({task_count} tasks, {type}) {(on milestone path) if applicable}
   {reasoning}

...

#N v{N} — {Name} ({task_count} tasks, {type}) {(on milestone path) if applicable}
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
