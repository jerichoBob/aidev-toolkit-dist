# SDD Module — Spec-Driven Development for aidev toolkit

The SDD (Spec-Driven Development) module provides a complete workflow for managing specifications and tracking implementation progress.

## Table of Contents

- [Token Usage Tracking](#token-usage-tracking)
- [Quick Status](#quick-status)
- [Specs and Phases](#specs-and-phases)
- [Implementation Workflow](#implementation-workflow)

---

## Token Usage Tracking

SDD automatically tracks token usage for each task during `/sdd-code-spec` execution, enabling you to:

- Measure algorithm efficiency across different implementations
- Compare token costs for similar tasks and features
- Judge implementation trade-offs based on real cost data
- Monitor project expenses as specs progress
- Optimize workflows based on historical metrics

### Metadata Format

Token usage is stored as HTML comments in `specs/README.md`, invisible when rendered but preserved in git:

\`\`\`markdown

- [x] Task description
  <!-- task-meta: v=17,t=1,in=12453,out=8921,cache=45231,start=2026-02-15T10:30:00Z,end=2026-02-15T10:45:00Z,commit=abc1234 -->
  \`\`\`

**Fields**:

- \`v={version}\` - Spec version (e.g., 17)
- \`t={task_num}\` - Task number (sequential within spec)
- \`in={tokens}\` - Input tokens (direct input + cache creation)
- \`out={tokens}\` - Output tokens generated
- \`cache={tokens}\` - Cache read tokens (separate tracking)
- \`start={ISO8601}\` - Task start timestamp (UTC)
- \`end={ISO8601}\` - Task completion timestamp (UTC)
- \`commit={sha}\` - Git commit SHA (7 chars) at task completion

### Viewing Token Statistics

Use the \`--stats\` flag with \`/sdd-specs\` to view aggregated token usage:

\`\`\`bash
/sdd-specs --stats
\`\`\`

This displays:

- Enhanced Quick Status table with token columns
- Total tokens used (input, output, cache)
- Estimated USD cost based on Anthropic pricing
- Average tokens per task and per spec
- Time tracking across completed tasks

**Example output**:

\`\`\`

| Spec | Name                  | Progress | Status      | In Tokens | Out Tokens | Cache  | Duration |
| ---- | --------------------- | -------- | ----------- | --------- | ---------- | ------ | -------- |
| v14  | SDD Plain Text Output | 6/6      | ✅ Complete | 10,755    | 6,231      | 23,199 | 0:45:20  |

---

Estimated Cost: \$2.15
Input: \$0.03 @ \$3.00/MTok
Output: \$0.09 @ \$15.00/MTok
Cache: \$2.03 @ \$0.30/MTok
\`\`\`

### Automatic Tracking

Token tracking is **enabled by default** when running \`/sdd-code-spec\`:

1. Captures token snapshot **before** each task
2. Captures token snapshot **after** each task
3. Calculates token delta (tokens used = after - before)
4. Stores metadata as HTML comment in README
5. Continues implementation (tracking failures don't block progress)

**Disable tracking** (for privacy or testing):

\`\`\`bash
/sdd-code-spec v17 --no-stats
\`\`\`

### Data Source

Tokens are captured from \`~/.claude/stats-cache.json\`:

- Updated by Claude Code for every model interaction
- Contains cumulative usage by model (Opus, Sonnet, Haiku, etc.)
- Automatically tracked — no setup required

### Pricing Reference (2026-02)

Anthropic official rates used in cost calculations:

| Model      | Input       | Output       | Cache Read  |
| ---------- | ----------- | ------------ | ----------- |
| Opus 4.6   | \$3.00/MTok | \$15.00/MTok | \$0.30/MTok |
| Sonnet 4.5 | \$3.00/MTok | \$15.00/MTok | \$0.30/MTok |
| Haiku 4.5  | \$0.80/MTok | \$4.00/MTok  | \$0.10/MTok |

_Note: Aggregate costs shown use Opus rates; actual project costs depend on which models are used._

---

## Quick Status

The \`Quick Status\` table in \`specs/README.md\` provides at-a-glance view of all specs:

\`\`\`bash
/sdd-specs
\`\`\`

Shows:

- Spec version and name
- Progress count (done/total tasks)
- Status emoji:
  - \`✅ Complete\` - All tasks done
  - \`🔧 In Progress\` - Some tasks done
  - \`✏️ Draft\` - No tasks done yet
  - \`⬜ Empty\` - No tasks defined
- Owner (email or "—" if unowned)

**Example**:

\`\`\`

| Spec | Name                  | Progress | Status      | Owner                          |
| ---- | --------------------- | -------- | ----------- | ------------------------------ |
| v14  | SDD Plain Text Output | 6/6      | ✅ Complete | —                              |
| v15  | Spec Owner & Checkout | 0/19     | ✏️ Draft    | <bob@parallaxintelligence.com> |

\`\`\`

---

## Specs and Phases

Each spec is a markdown file (\`specs/spec-v{N}-\*.md\`) with:

- **Why**: Problem statement and context
- **What**: Requirements and acceptance criteria
- **How**: Implementation approach organized into phases

Example structure:

\`\`\`markdown

# Spec Title

## Why (Problem Statement)

> As a {role}, I want {goal} so that {benefit}.

## What (Requirements)

### User Stories

### Acceptance Criteria

## How (Approach)

### Phase 1: {Name}

- Task 1
- Task 2

### Phase 2: {Name}

- Task 1
  \`\`\`

---

## Implementation Workflow

### Step 1: View Available Specs

\`\`\`bash
/sdd-specs # Fast view (default)
/sdd-specs --deep # Full scan with validation
\`\`\`

### Step 2: Start Implementation

\`\`\`bash
/sdd-code-spec v17 # Implement spec v17
/sdd-code-spec v17 --no-stats # Without token tracking
\`\`\`

This will:

1. Read the target spec file
2. Collect all unchecked tasks
3. Implement phase by phase
4. Track progress in README
5. Capture token metrics (unless \`--no-stats\`)
6. Report completion summary

### Step 3: Check What's Next

\`\`\`bash
/sdd-next # Show next unchecked task
/sdd-next-phase # Show all tasks in current phase
\`\`\`

### Step 4: View Statistics

\`\`\`bash
/sdd-specs --stats # Token usage and cost
/sdd-specs --verify # Full validation scan
\`\`\`

---

## Script Reference

### Token Tracking Scripts

**\`token-tracker.sh\`** — Capture and analyze token usage:

- \`snapshot <file>\` - Capture current state from stats-cache.json
- \`delta <before> <after>\` - Calculate tokens used between snapshots
- \`format <tokens>\` - Format with thousands separators
- \`format-duration <seconds>\` - Format as HH:MM:SS
- \`parse-iso8601 <timestamp>\` - Parse ISO8601 to Unix time

**\`stats-parse.sh\`** — Parse and aggregate metadata:

- \`extract-spec <version>\` - Extract task metadata for one spec
- \`aggregate-spec <version>\` - Sum tokens and duration for spec
- \`aggregate-all\` - Aggregate across all specs with metadata
- \`format-tokens <count>\` - Format with thousands separators
- \`format-duration <seconds>\` - Format as HH:MM:SS
- \`calculate-cost <in> <out> <cache>\` - Estimate USD cost

**\`specs-parse.sh\`** — Parse README and extract spec data:

- \`status\` - List all specs with progress
- \`next-task\` - Find first unchecked task
- \`next-phase\` - Find all tasks in current phase
- \`staleness\` - Compare file modification times
- \`structure\` - Check specs/ directory integrity

---

## Best Practices

1. **Keep README updated**: Mark tasks as \`[x]\` immediately after completion
2. **Use phases**: Break specs into logical phases for better tracking
3. **Review stats**: Use \`--stats\` periodically to monitor costs
4. **Commit frequently**: Metadata is git-tracked; commit after each phase
5. **Document decisions**: Add Technical Notes section to specs for future reference
6. **Check blockers**: Use \`--verify\` to identify unresolved dependencies

---

## Troubleshooting

**Q: Why don't I see token columns?**

- A: Use \`/sdd-specs --stats\` to enable token display

**Q: No metadata for my completed spec?**

- A: Specs completed before token tracking was enabled won't have metadata.
  Use \`--no-stats\` to skip tracking on individual runs if needed.

**Q: Token snapshot failed?**

- A: This doesn't block implementation. Check if \`~/.claude/stats-cache.json\` exists
  and is readable. Token tracking gracefully degrades.

**Q: How do I compare costs between two implementations?**

- A: Create two separate specs (or tasks in the same spec) and compare their
  in/out token ratios using the metadata.

---

## See Also

- \`/aid sdd\` - Help for all SDD commands
- \`specs/TEMPLATE.md\` - Spec template for creating new specs
- \`specs/README.md\` - Live spec list with progress tracking
