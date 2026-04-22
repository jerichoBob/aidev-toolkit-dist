# Risk Analysis: {{PROJECT_NAME}}

**Analysis Date:** {{DATE}}<br/>
**Analysis Type:** Comprehensive (R1-R10)<br/>
**Analyst:** aidev toolkit Risk Analysis

## Deal Overview

| Field                    | Value                                        |
| ------------------------ | -------------------------------------------- |
| **Client**               | {{CLIENT_NAME}}                              |
| **Vendor**               | {{VENDOR_NAME}}                              |
| **Engagement Type**      | {{ENGAGEMENT_TYPE}}                          |
| **Total Contract Value** | {{CONTRACT_VALUE}}                           |
| **Term**                 | {{START_DATE}} - {{END_DATE}} ({{DURATION}}) |
| **Primary Contact**      | {{PRIMARY_CONTACT}}                          |
| **MSA Reference**        | {{MSA_REFERENCE}}                            |

## Work Orders Summary

<!-- Include if multiple work orders -->

| WO  | Focus Area    | Model         | Monthly Range | Max Value   |
| --- | ------------- | ------------- | ------------- | ----------- |
| 1   | {{WO1_FOCUS}} | {{WO1_MODEL}} | {{WO1_RANGE}} | {{WO1_MAX}} |
| 2   | {{WO2_FOCUS}} | {{WO2_MODEL}} | {{WO2_RANGE}} | {{WO2_MAX}} |

## Analysis Documents

| Document                                     | Description                                       |
| -------------------------------------------- | ------------------------------------------------- |
| [00-deal-summary.md](./00-deal-summary.md)   | Deal score, recommendation, and executive summary |
| [01-risk-register.md](./01-risk-register.md) | Full risk register with all identified risks      |
| [02-risk-heatmap.md](./02-risk-heatmap.md)   | Visual likelihood x impact grid                   |
| [03-mitigations.md](./03-mitigations.md)     | Mitigation strategies and recommendations         |

## Risk Summary

| Dimension            | Risk Count          | Highest Severity     |
| -------------------- | ------------------- | -------------------- |
| R1: Technical        | {{R1_COUNT}}        | {{R1_SEVERITY}}      |
| R2: Schedule         | {{R2_COUNT}}        | {{R2_SEVERITY}}      |
| R3: Scope            | {{R3_COUNT}}        | {{R3_SEVERITY}}      |
| R4: Resource         | {{R4_COUNT}}        | {{R4_SEVERITY}}      |
| R5: Financial        | {{R5_COUNT}}        | {{R5_SEVERITY}}      |
| R6: Compliance       | {{R6_COUNT}}        | {{R6_SEVERITY}}      |
| R7: Integration      | {{R7_COUNT}}        | {{R7_SEVERITY}}      |
| R8: Operational      | {{R8_COUNT}}        | {{R8_SEVERITY}}      |
| R9: Organizational   | {{R9_COUNT}}        | {{R9_SEVERITY}}      |
| R10: Market/Business | {{R10_COUNT}}       | {{R10_SEVERITY}}     |
| **Total**            | **{{TOTAL_RISKS}}** | **{{MAX_SEVERITY}}** |

## Quick Assessment

**Deal Score:** {{SCORE}}/10 ({{RECOMMENDATION}})

**Key Concerns:**

1. {{CONCERN_1}}
2. {{CONCERN_2}}
3. {{CONCERN_3}}
4. {{CONCERN_4}}
5. {{CONCERN_5}}

**Key Strengths:**

1. {{STRENGTH_1}}
2. {{STRENGTH_2}}
3. {{STRENGTH_3}}
4. {{STRENGTH_4}}
5. {{STRENGTH_5}}
