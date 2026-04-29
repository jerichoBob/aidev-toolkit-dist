---
name: deal-desk
tier: extended
description: Deal qualification and risk assessment for project documents.
argument-hint: "[path|@doc] [--side vendor|buyer] [--quick|--deep] [--comprehensive] [--codebase] [--pdf] [--category <cat>]"
allowed-tools: "Read, Glob, Grep, Bash(ls:*), Bash(find:*), Bash(file:*), Bash(wc:*), Bash(pandoc:*)"
model: inherit
---

# Deal Desk

Perform deal qualification and risk assessment on project documents or codebase. Produces a Bid/No-Bid recommendation with detailed risk breakdown.

Primary use case: "Sales caught a big fish - should we clean it or throw it back?"

## IMPORTANT: Model Recommendation

**This skill produces best results with Claude Opus 4.5.** Before proceeding, check if you are running on Opus 4.5.

If you are NOT running on Opus 4.5, output this notice to the user:

```text
⚠️ MODEL RECOMMENDATION

This analysis is running on [current model]. For best results with deal
qualification and risk assessment, Opus 4.5 is recommended.

To run with Opus 4.5:
  claude --model opus /deal-desk [your arguments]

Proceeding with current model...
```

Then continue with the analysis.

## When to Use

- User asks "should we bid on this?", "what are the risks?", or "is this deal worth it?"
- Evaluating RFPs, RFQs, proposals, or SOWs for go/no-go decisions
- Assessing project risk before commitment
- Generating risk registers and mitigation plans for proposals

## Arguments

- **Directory path**: `/deal-desk ./deal-docs/` - Analyze all documents in directory
- **@document**: `/deal-desk @rfq.pdf` - Analyze a single document
- **--side `<vendor|buyer>`**: Analysis perspective (default: vendor)
  - `vendor`: We are selling services/products (protections for us = strengths)
  - `buyer`: We are purchasing from another vendor (protections for them = risks)
- **--codebase**: Analyze current project (code quality + health signals)
- **--quick**: Deal score and summary only (no output files)
- **--deep**: Deep analysis with all 10 dimensions (adds files 04-09)
- **--comprehensive**: Rich output format with visual scores, financial analysis, governance
- **--category `<cat>`**: Focus on specific category (technical, schedule, scope, resource, financial, compliance, integration, operational, organizational, market)
- **--output `<dir>`**: Custom output directory (default: ./deal-desk-output/)
- **--pdf**: Generate PDF files from markdown output (requires pandoc + typst)

## Natural Language (Claude Desktop)

Users can trigger options conversationally instead of using flags:

| Say this...                                          | Equivalent to...  |
| ---------------------------------------------------- | ----------------- |
| "vendor side", "we're selling", "we're bidding"      | `--side vendor`   |
| "buyer side", "we're purchasing", "we're the client" | `--side buyer`    |
| "quick analysis", "just a quick look"                | `--quick`         |
| "deep analysis", "full analysis", "deep dive"        | `--deep`          |
| "comprehensive format", "detailed format"            | `--comprehensive` |

**Examples:**

- "Do a vendor-side deal-desk analysis of this RFP"
- "We're evaluating a vendor contract - do a buyer-side risk analysis"
- "Quick deal-desk on this SOW - should we bid?"
- "Deep dive analysis on these procurement docs, we're the buyer"

## Perspective: Vendor vs Buyer

**CRITICAL**: The analysis perspective fundamentally changes how contract terms and risks are evaluated. The same clause can be a strength or a red flag depending on which side of the deal you're on.

### Vendor Perspective (default: `--side vendor`)

You are **selling** services/products. Evaluate whether this is a good deal **for you to deliver**.

| Element                       | Vendor View                                             |
| ----------------------------- | ------------------------------------------------------- |
| IP stays with us              | ✅ Strength - retain reusable assets                    |
| No guaranteed outcomes        | ✅ Strength - protects against unrealistic expectations |
| T&M billing                   | ✅ Strength - paid for actual effort                    |
| Strong assumption clauses     | ✅ Strength - protects against scope creep              |
| Client responsibility clauses | ✅ Strength - shared accountability                     |
| Change order requirements     | ✅ Strength - scope discipline                          |
| Unclear acceptance criteria   | ⚠️ Neutral - flexibility but potential disputes         |

**Key Questions**:

- Are we protected if scope expands?
- Is the timeline achievable?
- Are rates acceptable for our cost structure?
- Do we have the skills and availability?
- Is the client capable of fulfilling their obligations?

### Buyer Perspective (`--side buyer`)

You are **purchasing** services/products. Evaluate whether this is a good deal **for you as the client**.

| Element                       | Buyer View                                     |
| ----------------------------- | ---------------------------------------------- |
| IP stays with vendor          | 🚩 Red Flag - paying for work you don't own    |
| No guaranteed outcomes        | 🚩 Red Flag - no accountability for results    |
| T&M billing                   | ⚠️ Risk - cost uncertainty                     |
| Strong assumption clauses     | 🚩 Red Flag - vendor can blame you for delays  |
| Client responsibility clauses | ⚠️ Risk - significant internal effort required |
| Change order requirements     | ⚠️ Neutral - protects both parties             |
| Unclear acceptance criteria   | 🚩 Red Flag - no way to prove completion       |

**Key Questions**:

- Are we getting value for the investment?
- Who owns the deliverables?
- What's actually guaranteed?
- Are we protected if they underperform?
- What are the exit options?

## Output Dimensions

Two independent dimensions control output:

### Depth (what to analyze)

| Flag      | Categories | Output Files |
| --------- | ---------- | ------------ |
| `--quick` | R1-R3      | Console only |
| (default) | R1-R7      | 00-03        |
| `--deep`  | R1-R10     | 00-09        |

### Format (how to present)

| Flag              | Style  | Description                                                         |
| ----------------- | ------ | ------------------------------------------------------------------- |
| (default)         | Simple | Clean, scannable tables. Single-table risk register.                |
| `--comprehensive` | Rich   | Visual score breakdown, financial analysis, governance, risk cards. |

**Templates**: Reference `~/.claude/aidev-toolkit/templates/deal-desk/simple/` or `comprehensive/` for exact formats.

## Risk Dimensions

| ID  | Category        | Description                              | Depth     |
| --- | --------------- | ---------------------------------------- | --------- |
| R1  | Technical       | Complexity, dependencies, integration    | All       |
| R2  | Schedule        | Timeline, milestones, critical path      | All       |
| R3  | Scope           | Requirements gaps, ambiguity, creep      | All       |
| R4  | Resource        | Skills, availability, team capacity      | Standard+ |
| R5  | Financial       | Cost drivers, budget, cash flow          | Standard+ |
| R6  | Compliance      | Regulatory, security, data protection    | Standard+ |
| R7  | Integration     | External systems, APIs, third-parties    | Standard+ |
| R8  | Operational     | Day-2, support, incidents, SLAs          | Deep      |
| R9  | Organizational  | Change management, adoption, training    | Deep      |
| R10 | Market/Business | Adoption, competition, value proposition | Deep      |

## CRITICAL: Format Standards

**You MUST follow these standards exactly. Do NOT deviate or invent new formats.**

| Element        | Required Format                  | Do NOT Use                     |
| -------------- | -------------------------------- | ------------------------------ |
| Deal Score     | `X/10`                           | ~~X/100~~, ~~68/100~~          |
| Risk IDs       | `R1.1`, `R1.2`, `R2.1`           | ~~R1-001~~, ~~R1-002~~         |
| Likelihood     | Low (1), Medium (2), High (3)    | ~~High (4/5)~~, ~~1-5 scale~~  |
| Impact         | Low (1), Medium (2), High (3)    | ~~High (4/5)~~, ~~1-5 scale~~  |
| Score          | Likelihood × Impact = 1-9        | ~~1-25 scale~~, ~~1-16 scale~~ |
| Severity bands | Low: 1-2, Medium: 3-4, High: 6-9 | ~~Critical/High/Med/Low~~      |

**Do NOT add sections not specified in the templates.** The templates define exactly what sections to include.

## Instructions

### Step 1: Determine Context & Read Inputs

Identify what you're analyzing:

**Directory input** (e.g., `/deal-desk ./deal-docs/`):

- Read all PDFs, CSVs, XLSX, DOCX files in the directory
- Use the pdf skill for PDF files, xlsx skill for spreadsheets, docx skill for Word documents
- Compile a summary of all documents found

**Single document** (e.g., `/deal-desk @rfq.pdf`):

- Read and analyze the specified document
- Extract requirements, constraints, and expectations

**Codebase mode** (`--codebase`):

- Analyze the current project structure
- Check for test coverage, dependency health, code quality signals
- Look at README, CLAUDE.md, package files

### Step 2: Identify Red Flags (Quick Scan)

Before detailed analysis, look for immediate deal-breakers. **Red flags differ based on perspective.**

#### Vendor Red Flags (`--side vendor`)

| Red Flag                        | Signal                                                             |
| ------------------------------- | ------------------------------------------------------------------ |
| Unrealistic timeline            | Aggressive dates without phasing                                   |
| Undefined scope                 | Heavy use of "TBD", "to be determined"                             |
| Fixed price + variable scope    | Recipe for cost overruns                                           |
| Penalty clauses                 | Liquidated damages without caps                                    |
| Unlimited liability             | No liability cap in contract                                       |
| Client incapable of obligations | Client lacks resources/authority to fulfill their responsibilities |
| Compliance beyond capability    | Regulatory requirements beyond team capability                     |
| Payment terms unfavorable       | Net 90+, milestone-heavy, retainage                                |
| Single source dependency        | We rely on client-provided resources that may not materialize      |

#### Buyer Red Flags (`--side buyer`)

| Red Flag                     | Signal                                         |
| ---------------------------- | ---------------------------------------------- |
| Unrealistic timeline         | Aggressive dates without phasing               |
| Undefined scope              | Heavy use of "TBD", "to be determined"         |
| IP ownership unfavorable     | Paying for work product we don't own           |
| No guaranteed outcomes       | Disclaimers on accuracy, performance, results  |
| Missing acceptance criteria  | No objective way to accept/reject deliverables |
| Vendor-favorable assumptions | Clauses that shift all risk to buyer           |
| Cost uncertainty             | T&M with wide ranges, no caps                  |
| No exit provisions           | Locked in with no termination rights           |
| Single point of failure      | One vendor, one person, one system             |

Count red flags found. Each red flag subtracts from deal score.

### Step 3: Assess Each Risk Dimension

For each applicable category (based on depth level), identify specific risks:

**R1: Technical**

- Complexity of required solution
- Unknown technologies or integrations
- Performance requirements
- Security requirements
- Technical debt signals

**R2: Schedule**

- Timeline pressure and feasibility
- Dependencies on external parties
- Milestone reasonableness
- Buffer for unknowns

**R3: Scope**

- Clarity of requirements
- Gap analysis (what's missing?)
- Scope creep indicators
- Change control process

**R4: Resource** (Standard+)

- Skills required vs. available
- Team availability
- Ramp-up time needed
- Key person dependencies

**R5: Financial** (Standard+)

- Budget adequacy
- Payment terms and cash flow
- Cost drivers and unknowns
- Margin risk

**R6: Compliance** (Standard+)

- Regulatory requirements (HIPAA, SOC2, PCI, etc.)
- Security certifications needed
- Data protection requirements
- Audit requirements

**R7: Integration** (Standard+)

- External system dependencies
- API availability and documentation
- Third-party reliability
- Data migration complexity

**R8: Operational** (Deep)

- Day-2 support requirements
- SLA commitments
- Incident response expectations
- Monitoring and alerting needs

**R9: Organizational** (Deep)

- Change management complexity
- User adoption challenges
- Training requirements
- Political/stakeholder risks

**R10: Market/Business** (Deep)

- Competitive landscape
- Timing sensitivity
- Strategic fit
- Long-term value

### Step 4: Score Each Risk

For each identified risk, assign:

- **Likelihood**: Low (1), Medium (2), High (3)
- **Impact**: Low (1), Medium (2), High (3)
- **Score**: Likelihood × Impact (1-9)

| Score | Severity |
| ----- | -------- |
| 1-2   | Low      |
| 3-4   | Medium   |
| 6-9   | High     |

### Step 5: Calculate Deal Score

Deal Score (1-10) is calculated based on:

1. **Baseline**: Start at 10
2. **High-severity risks**: Subtract 1 per high-severity (6-9) risk, max -4
3. **Red flags**: Subtract 1 per red flag, max -3
4. **Requirement clarity**: Subtract 0-2 based on how unclear requirements are
5. **Capability alignment**: Subtract 0-1 if skills gap exists

**Recommendation based on Deal Score:**

| Score | Recommendation     | Meaning                               |
| ----- | ------------------ | ------------------------------------- |
| 8-10  | **GO**             | Low risk, well-defined, good fit      |
| 5-7   | **CONDITIONAL GO** | Manageable risks, needs clarification |
| 3-4   | **CAUTION**        | Significant risks, consider carefully |
| 1-2   | **NO-GO**          | High risk, unclear scope, poor fit    |

### Step 6: Generate Output

#### Quick Mode (`--quick`)

Output directly to console (no files):

```markdown
# Deal Assessment: <project/deal name>

**Perspective**: VENDOR | BUYER
**Deal Score: X/10 - <RECOMMENDATION>**

## Risk Summary

| Category  | Risk Count | Highest Severity | Key Concern  |
| --------- | ---------- | ---------------- | ------------ |
| Technical | X          | High/Med/Low     | <brief note> |
| Schedule  | X          | High/Med/Low     | <brief note> |
| Scope     | X          | High/Med/Low     | <brief note> |
| ...       | ...        | ...              | ...          |

## Red Flags (X found)

- <red flag 1>
- <red flag 2>

## Top 5 Risks

1. **R1.1**: <description> (Score: X)
2. **R2.3**: <description> (Score: X)
   ...

## Bottom Line

<2-3 sentence summary of whether to pursue and key caveats>
```

Also update `.aid/risks.yml` (see persistence format below).

#### Standard Mode - Simple Format (default)

Create output directory and files following the **simple template** exactly:

```text
deal-desk-output/
├── README.md                 # Summary with deal score and links
├── 00-deal-summary.md        # Deal score, recommendation, red flags
├── 01-risk-register.md       # Full risk register table (SINGLE TABLE)
├── 02-risk-heatmap.md        # Visual likelihood x impact grid
├── 03-mitigations.md         # Mitigation strategies by risk
└── source-docs/              # Copies of input documents (if provided)
```

**Reference**: `~/.claude/aidev-toolkit/templates/deal-desk/simple/`

Key characteristics of Simple format:

- Risk register is a **single table** with all risks
- Mitigations grouped by priority with action checklists
- No financial analysis section
- No governance section
- No visual score breakdown box

#### Standard Mode - Comprehensive Format (`--comprehensive`)

Create output directory and files following the **comprehensive template** exactly:

```text
deal-desk-output/
├── README.md                 # Summary with work order breakdown
├── 00-deal-summary.md        # Visual score breakdown, financial analysis, approval checklist
├── 01-risk-register.md       # Individual risk CARDS with triggers/consequences
├── 02-risk-heatmap.md        # Trend indicators, concentration by workstream/phase
├── 03-mitigations.md         # Detailed strategies with Owner, Timeline, Success Criteria, Governance
└── source-docs/
```

**Reference**: `~/.claude/aidev-toolkit/templates/deal-desk/comprehensive/`

Key characteristics of Comprehensive format:

- Risk register uses **individual cards** per risk with Triggers and Consequences
- Deal summary includes visual ASCII score breakdown box
- Deal summary includes Financial Analysis (Best/Expected/Worst case)
- Deal summary includes Approval Checklist
- Heatmap includes Risk Trend Indicators (↗ → ↘)
- Heatmap includes concentration analysis by workstream and phase
- Mitigations include Owner, Timeline, Success Criteria for each
- Mitigations include Governance section (Weekly review, Monthly report, Escalation triggers)

#### Deep Mode (`--deep`)

All standard outputs plus additional deep-dive files:

```text
deal-desk-output/
├── ...standard files (00-03)...
├── 04-technical-deep-dive.md    # Deep dive: R1, R7
├── 05-business-deep-dive.md     # Deep dive: R5, R9, R10
├── 06-operational-deep-dive.md  # Deep dive: R8
├── 07-compliance-deep-dive.md   # Deep dive: R6
├── 08-recommendations.md        # Prioritized action plan
└── 09-open-questions.md         # Questions requiring answers
```

**Reference**: `~/.claude/aidev-toolkit/templates/deal-desk/simple/` or `comprehensive/` (files 04-09 are the same for both formats)

### Step 7: Persist to .aid/risks.yml

Create or update `.aid/risks.yml` for tracking:

```yaml
project: <project/deal name>
analyzed: <YYYY-MM-DD>
deal_score: <1-10>
recommendation: <GO | CONDITIONAL GO | CAUTION | NO-GO>
red_flags:
  - <flag 1>
  - <flag 2>
risks:
  - id: R1.1
    category: Technical
    description: <description>
    likelihood: High
    impact: High
    score: 9
    status: Open
    mitigation: <strategy>
    notes: []
  - id: R2.1
    category: Schedule
    description: <description>
    likelihood: Medium
    impact: High
    score: 6
    status: Open
    mitigation: <strategy>
    notes: []
```

Create the `.aid/` directory if it doesn't exist.

### Step 8: Generate PDFs (`--pdf`)

If the `--pdf` flag is provided, convert all generated markdown files to PDF.

**Requirements**:

- `pandoc` (3.8+)
- `typst` (PDF engine)

**Templates** (in `aidev-toolkit/templates/pdf/`):

- `clean.typ` - Portrait layout (default)
- `clean-landscape.typ` - Landscape layout (for wide tables)

**Template Selection**:

| File                  | Template              | Reason                     |
| --------------------- | --------------------- | -------------------------- |
| `01-risk-register.md` | `clean-landscape.typ` | 9-column table needs width |
| All others            | `clean.typ`           | Standard portrait          |

**Conversion Commands**:

```bash
# Get template directory
TEMPLATE_DIR="$HOME/.claude/aidev-toolkit/templates/pdf"

# Portrait documents
pandoc README.md -o README.pdf --pdf-engine=typst --template="$TEMPLATE_DIR/clean.typ"
pandoc 00-deal-summary.md -o 00-deal-summary.pdf --pdf-engine=typst --template="$TEMPLATE_DIR/clean.typ"
pandoc 02-risk-heatmap.md -o 02-risk-heatmap.pdf --pdf-engine=typst --template="$TEMPLATE_DIR/clean.typ"
pandoc 03-mitigations.md -o 03-mitigations.pdf --pdf-engine=typst --template="$TEMPLATE_DIR/clean.typ"

# Landscape document (wide table)
pandoc 01-risk-register.md -o 01-risk-register.pdf --pdf-engine=typst --template="$TEMPLATE_DIR/clean-landscape.typ"
```

**Deep mode additional files** (all portrait):

```bash
pandoc 04-technical-deep-dive.md -o 04-technical-deep-dive.pdf --pdf-engine=typst --template="$TEMPLATE_DIR/clean.typ"
# ... repeat for 05-09
```

## Important Notes

- **FOLLOW THE TEMPLATES EXACTLY** - Do not add sections, change formats, or invent new structures
- **RESPECT THE PERSPECTIVE** - Apply vendor or buyer lens consistently throughout:
  - State the perspective in the output header: "Analysis Perspective: VENDOR" or "BUYER"
  - Evaluate every contract clause through that lens
  - Red flags, strengths, and mitigations must align with the stated perspective
- Be specific and reference actual content from documents
- Don't make up risks - only identify risks supported by evidence
- For --codebase mode, focus on technical risks visible in the code
- When documents are ambiguous, note the ambiguity itself as a risk
- Deal Score should be defensible based on the formula
- Always provide actionable mitigations, not just risk descriptions
- For Quick mode, keep output concise (fit on one screen)
- Use risk IDs consistently (R1.1, R1.2, R2.1, etc.) for traceability
- **Ensure all 7 categories (R1-R7) are assessed** for standard depth, all 10 for deep
