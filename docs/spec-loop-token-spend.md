# Spec Loop — How Token Spend Is Measured

Findings for spec v137 Phase 0 (checked 2026-11-25 on Bob's machine, Claude Code on Bedrock, model `claude-sonnet-5-5`).

## Session transcript (`~/.claude/projects/<project>/<session>.jsonl`)

- Each `assistant` line has `message.usage` with `input_tokens`, `cache_creation_input_tokens`,
  `cache_read_input_tokens`, `output_tokens` and `output_tokens_details.thinking_tokens`, plus `message.model` and
  `message.id`.
- **The same `message.id` is written several times** (one line per content block; 228 lines for 112 distinct ids in
  one session). Summing lines double counts. Dedupe by `message.id`, keeping the last line.
- The transcript also carries a `cost-state` line: `totalCostUSD` (running session total) and a per-model
  `modelUsage` block. The last `cost-state` line gives an exact dollar figure with no price table.
- No sidechain (sub-agent) lines appeared in the checked sessions, and no per-session sub-directory held sub-agent
  transcripts. Sub-agent spend is therefore only seen if it lands in `cost-state`; the meter treats `cost-state` as
  authoritative when present.

## Headless CLI (`claude -p ... --output-format json --max-budget-usd 0.10`)

The result JSON has `total_cost_usd` (0.057359 for a one-word reply), `usage` (same four token fields),
`modelUsage.<model>.costUSD`, `num_turns`, `is_error`, `subtype`, `terminal_reason`, and `subagent_stats`.

## Decisions

- **Budget unit (Open Question 3, resolved: both).** `--budget-tokens` always works. `--budget-usd` uses, in order:
  the exact figure (`cost-state` delta or headless `total_cost_usd`); else an estimate from the price table.
- **Price table.** `modules/sdd/templates/spec-loop-prices.json`, USD per million tokens per model and token kind.
  Fixed list prices go stale, so exact figures win when present and the estimate is labelled `estimated`.
  A model missing from the table gives no dollar estimate (reported as unknown), never zero.
- **Runner model (Open Question 1).** The meter takes either source, so the scripts do not depend on the choice. The
  recommended skill design is in-session: transcript spend per pass is readable with no extra process, and parked
  questions are asked in the same session. A headless driver can be added later using `total_cost_usd`.
- **Counting rule.** A pass's spend is the difference between two meter readings (before and after the pass).
