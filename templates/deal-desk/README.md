# Risk Analysis Templates

Output templates for the `/risk-analysis` skill. Two independent dimensions:

- **Depth** (`--quick`, default, `--deep`): Controls which categories and files
- **Format** (`--comprehensive`): Controls presentation style

## Dimensions

### Depth (what to analyze)

| Flag      | Categories | Output Files |
| --------- | ---------- | ------------ |
| `--quick` | R1-R3      | Console only |
| (default) | R1-R7      | 00-03        |
| `--deep`  | R1-R10     | 00-09        |

### Format (how to present)

| Flag              | Style  | Use Case                               |
| ----------------- | ------ | -------------------------------------- |
| (default)         | Simple | Most deals, quick review               |
| `--comprehensive` | Rich   | Executive presentations, complex deals |

## File Matrix

| Depth    | Format        | Files Generated       |
| -------- | ------------- | --------------------- |
| standard | simple        | `simple/00-03`        |
| standard | comprehensive | `comprehensive/00-03` |
| deep     | simple        | `simple/00-09`        |
| deep     | comprehensive | `comprehensive/00-09` |

## Simple Template (`simple/`)

Clean, scannable output. Single-table risk register, concise mitigations.

**Standard files (00-03):**

- `README.md` - Deal overview and risk summary
- `00-deal-summary.md` - Score, recommendation, key risks
- `01-risk-register.md` - Single table with all risks
- `02-risk-heatmap.md` - ASCII grid and distribution
- `03-mitigations.md` - Grouped by priority with action items

**Deep files (04-09):**

- `04-technical-deep-dive.md` - R1 + R7 detailed analysis
- `05-business-deep-dive.md` - R5 + R9 + R10 detailed analysis
- `06-operational-deep-dive.md` - R8 detailed analysis
- `07-compliance-deep-dive.md` - R6 detailed analysis
- `08-recommendations.md` - Prioritized action plan
- `09-open-questions.md` - Questions requiring answers

## Comprehensive Template (`comprehensive/`)

Rich output with visual score breakdown, financial analysis, governance.

**Standard files (00-03):**

- `README.md` - Deal overview with work order breakdown
- `00-deal-summary.md` - Visual score, financial analysis, approval checklist
- `01-risk-register.md` - Individual risk cards with triggers/consequences
- `02-risk-heatmap.md` - Trend indicators, concentration analysis
- `03-mitigations.md` - Detailed strategies with owners, timelines, governance

**Deep files (04-09):**

- Same as simple (deep analysis content is consistent across formats)

## Format Standards (Both Templates)

These standards apply regardless of template:

| Element        | Format                              |
| -------------- | ----------------------------------- |
| Deal Score     | `X/10` (not X/100)                  |
| Risk IDs       | `R1.1`, `R1.2`, `R2.1` (not R1-001) |
| Likelihood     | Low (1), Medium (2), High (3)       |
| Impact         | Low (1), Medium (2), High (3)       |
| Score          | Likelihood × Impact = 1-9           |
| Severity bands | Low: 1-2, Medium: 3-4, High: 6-9    |

## Risk Categories (R1-R10)

| ID  | Category        | Depth Level |
| --- | --------------- | ----------- |
| R1  | Technical       | All         |
| R2  | Schedule        | All         |
| R3  | Scope           | All         |
| R4  | Resource        | Standard+   |
| R5  | Financial       | Standard+   |
| R6  | Compliance      | Standard+   |
| R7  | Integration     | Standard+   |
| R8  | Operational     | Deep only   |
| R9  | Organizational  | Deep only   |
| R10 | Market/Business | Deep only   |

## Usage Examples

```bash
# Simple format, standard depth (default)
/risk-analysis ./deal-docs/

# Simple format, deep depth
/risk-analysis ./deal-docs/ --deep

# Comprehensive format, standard depth
/risk-analysis ./deal-docs/ --comprehensive

# Comprehensive format, deep depth
/risk-analysis ./deal-docs/ --deep --comprehensive
```
