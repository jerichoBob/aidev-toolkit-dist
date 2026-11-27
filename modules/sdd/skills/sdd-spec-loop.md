---
name: sdd-spec-loop
tier: extended
description: "Build eligible specs in turn until the queue, a pass limit or a token budget runs out; gated tasks are parked and asked at the end"
argument-hint: "[--dry-run] [--priority STRATEGY] [--max-passes N] [--budget-tokens N | --budget-usd N]"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion, Skill
---

# Spec Loop

Keep asking "what's next?" on its own: pick the next spec the developer can build, build it, test it, move on. Stop at an empty queue, the pass limit or the budget. Anything that needs a person is parked, never performed, and asked at the end.

Design: `specs/spec-v137-spec-loop.md`. Token measurement: `docs/spec-loop-token-spend.md`.

Helper scripts (all read-only except `park` and the run record):

```bash
Q=~/.claude/aidev-toolkit/modules/sdd/scripts/spec-loop-queue.py
B=~/.claude/aidev-toolkit/modules/sdd/scripts/spec-loop-budget.py
G=~/.claude/aidev-toolkit/modules/sdd/scripts/spec-loop-gates.py
```

## Arguments

- `--dry-run` — print the queue and what each next task would do; change nothing (AC-2).
- `--priority <strategy>` — how the queue is ordered; overrides `priority` in config (default `default`):
  `default` (in progress first, then fewest tasks left), `oldest` (lowest version first), `newest` (highest version first), `fewest-gated` (fewest tasks the loop must park first), `roi` (highest value per unit of work: the spec's `value: 1-5` frontmatter, else its category's Value in `specs/spec-categories.md` (`categories_file` in config), else 3, divided by buildable tasks left plus `gated_cost` (default 2) per gated task, since a gate stops the automation), `work-order` (follow `work_order_file`, default `specs/work-order.md`: one `vN` per line, `#` comments; unlisted specs follow in default order).
- `--max-passes N` — default from config `max_passes` (4 if no config) (AC-6).
- `--budget-tokens N` / `--budget-usd N` — stop before starting a pass once spend reaches it (AC-5). Neither given: pass limit only.

## Step 1: Config and queue

1. `python3 $G config` — effective config (`spec-loop` section of `.aid/config.yaml`, else conservative defaults: owner rule `mine`, commit not allowed, 4 passes).
2. **Category check (`roi` only; spec v139).** When the strategy is `roi` (from `--priority` or config), run `python3 $Q --check-categories` (add `--categories-file` only if config sets `categories_file`). It prints `missing`, `fresh` or `stale`, then `unlisted:` (specs in `specs/` or `specs/completed/` that no category row names) and `dangling:` (versions a row names that have no spec file). **The script decides whether to analyze, not you.** `fresh`: go on. Any other strategy: never run the check or the analysis.
   - **`--dry-run`:** report the outcome and both lists, then go on to the queue. Do not run the analysis and do not write the file.
   - **`missing` or `stale`:** run the **category analysis** below, then go on.

   **Category analysis.** Read the body of every spec in scope, completed (`specs/completed/`) and unfinished, not just titles. Think as a product manager: what is each spec *for*, and which coherent set of use-case categories covers the whole collection? Write `specs/spec-categories.md` (or `categories_file`) directly, without stopping to ask; Bob reviews the git diff, and you never commit it unless `allow_commit` is true. Format:
   - One line giving the date and scope: how many completed and how many unfinished specs, and that bodies were read.
   - A table with columns `Category | What it's for | Specs | Count | Value`. Every spec is in **exactly one** row. Write completed specs with a trailing `*` (`v12*`) so the parser can tell them apart; the queue parser accepts it. `Value` is 1-5.
   - A paragraph under the table saying how Value is used (one per category, a spec's `value:` frontmatter overrides it, no category scores 3).
   - `## Observations` and `## Open follow-ups` sections.
   - **Keep edited Values.** If the file already exists, a row whose category name still exists **keeps its Value** even if you would choose another; only new categories get a Value you propose. List each Value kept and each proposed in the run report.
   - **Re-check.** Run `python3 $Q --check-categories` again. If it is not `fresh`, fix the `unlisted` and `dangling` specs yourself (add the missing ones to the closest category, drop or correct the dangling ones) and re-check, for at most **2 repair attempts**. Still not `fresh`: stop the run with reason `categories` and list what remains. Do not give up on the first sign of difficulty and do not loop past 2.
3. `python3 $Q [--include-unowned] [--priority <strategy>]` (add `--include-unowned` only when `owner_rule` is `mine_or_unowned`; add `--priority` only when the developer passed it, else the script uses config). It prints the strategy in its header; show it in the report. Use the same flags every time the queue is re-run. It lists eligible specs (AC-1) and every excluded spec with its reason.
4. Classify each eligible spec's unchecked tasks, one per line on stdin: `python3 $G classify --stdin <<'TASKS'` ... `TASKS`. **Never put task text in a shell argument or double quotes**: it comes from a spec file and contains backticks and quotes the shell would execute. A task is **gated** or **buildable**; unknown is gated.

**`--dry-run`:** print the category check outcome (roi only), then the queue in order, and per spec the next task and whether it is gated (with the gate kind). Print the excluded list. Stop. Write nothing.

## Step 2: Start the run

1. Run id: `$(date +%Y%m%d-%H%M%S)`; `export SPEC_LOOP_RUN_ID=<run-id>` so every script log line carries it. Run directory: `.claude/tmp/spec-loop/<run-id>/` (create it).
2. Budget start reading, from this session's transcript (newest `*.jsonl` in `~/.claude/projects/<cwd with / replaced by ->/`):
   `python3 $B reading --transcript <file> > <run-dir>/start.json`. If it fails, tell the developer and run on the pass limit only.
3. Append a structured line to `<run-dir>/run.log` for every step: `ts run=<id> pass=<n> spec=<vN> step=<name> outcome=<ok|fail|stop> detail=<original message>`.

## Step 3: One pass (repeat)

Before each pass:

1. **Pass limit:** stop if passes done >= max passes (stop reason `pass-limit`).
2. **Budget:** `python3 $B check --since <run-dir>/start.json --transcript <file> [--budget-tokens N] [--budget-usd N]`. Exit 3 means stop (reason `budget`); record the reading. Exit 2 means the meter could not read spend, or cannot price it for `--budget-usd`: stop (reason `meter-error`) rather than run unmetered when a budget was given.
3. **Concurrency (AC-8):** `git fetch`. If the remote moved: with a clean working tree run `git pull --rebase`; a conflict or a dirty tree stops the loop (reason `conflict`). After a rebase re-run Step 1's queue.
4. Take the top eligible spec. If the queue is empty, stop (reason `queue-empty`).

The pass:

1. **Park gated tasks (AC-4).** For each unchecked task of the spec classified gated, run `python3 $G park --run-dir <run-dir> --spec <vN> --stdin <<'TASK'` with the task text as the body (quoted heredoc, never an argument), then append `(blocked: gate <kind>, parked by spec-loop <run-id>)` to that task line in `specs/README.md`, so `/sdd-code` skips it. Never perform a gated task.
2. If no buildable task remains, record the pass as `parked-only`, count it, and go to the next spec.
3. Snapshot the README checklist (which boxes are already ticked), then run `/sdd-code <vN> --skip-questions --no-stats` (Skill tool). It builds the buildable tasks and ticks their boxes.
4. **Tests (AC-3):** run the config `test_command` (else `tests/run-all.sh` if it exists, else none, and say so). Record the result.
   - Pass: keep the ticked boxes.
   - Fail: untick every box this pass ticked (restore from the snapshot), append `(blocked: tests failed in spec-loop <run-id>)` to those lines, and count a failing pass.
5. **Commit:** only if config `allow_commit` is true **and** tests passed: `/commit-push`. Otherwise leave changes in the working tree and say so. Never push from a failing state (AC-7).
6. **Per-pass record (AC-9):** append one JSON line to `<run-dir>/passes.jsonl`: spec, tasks built, tasks parked, test result, commit hash(es), `python3 $B delta <run-dir>/start.json --transcript <file>` (tokens and dollars so far), gates hit, pass number.

**Failure stop (AC-7):** two consecutive failing passes, or any merge conflict, stops the loop (reason `repeated-failure` / `conflict`).

## Step 4: Final report

Write `<run-dir>/report.md`: run id, stop reason, per pass (spec, tasks built, tests, commits, tokens and dollars), total spend, parked questions count, excluded specs, and any assumption made. Print a short version. Remind the developer that dollars are exact only when the transcript carries `cost-state`, otherwise estimated.

## Step 5: Parked questions (AC-10)

`python3 $G parked --run-dir <run-dir>` lists them. If none, finish. Otherwise ask them **one per `AskUserQuestion` call, in order, never batched**. For each: explain it from zero (the spec's name and what it is for, the task in plain words, why the loop stopped, what each answer changes), recommended option first, then the alternatives, then "Leave parked". Append the answer to `<run-dir>/parked.md` as `Answer ({date}): ...`. The run directory is disposable (`.claude/tmp/`, gitignored), so also record the decision where it lasts: in the spec file (`Resolved ({date}): ...` under its Open Questions, or as a note on the task) and, when the task becomes safe to build or is closed, in `specs/README.md`. If an answer makes a task safe to build, remove its `(blocked: gate ...)` marker so the next run picks it up. Never perform the gated action in this skill.

## Rules

- A gated task is never performed by the loop, whatever the answer: answers only record decisions or unblock the task for a later run (or the developer does it by hand).
- Never touch `~/.claude`, create branches, delete files, or send messages from a pass.
- Scripts live in the project (`.claude/scripts/`). Run data (logs, readings, reports, parked questions) is low-reuse and goes to `.claude/tmp/spec-loop/` (gitignored); nothing goes to a system temp file the developer cannot find.
