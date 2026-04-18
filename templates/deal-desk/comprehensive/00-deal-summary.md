# Deal Summary: {{PROJECT_NAME}}

## Deal Score

```text
+------------------------------------------------------------------+
|                      DEAL SCORE: {{SCORE}}/10                     |
|                    {{RECOMMENDATION}}                             |
+------------------------------------------------------------------+
|  Technical Risk:     {{R1_BAR}}  ({{R1_SCORE}}/10)               |
|  Schedule Risk:      {{R2_BAR}}  ({{R2_SCORE}}/10)               |
|  Scope Risk:         {{R3_BAR}}  ({{R3_SCORE}}/10)               |
|  Resource Risk:      {{R4_BAR}}  ({{R4_SCORE}}/10)               |
|  Financial Risk:     {{R5_BAR}}  ({{R5_SCORE}}/10)               |
|  Compliance Risk:    {{R6_BAR}}  ({{R6_SCORE}}/10)               |
|  Integration Risk:   {{R7_BAR}}  ({{R7_SCORE}}/10)               |
+------------------------------------------------------------------+
```

<!--
BAR FORMAT: Use filled/empty blocks to show score
Example for 6/10: ██████░░░░
-->

**Score Breakdown:**

- Base Score: 10
- Technical Deductions: -{{TECH_DEDUCT}} ({{TECH_REASON}})
- Schedule Deductions: -{{SCHED_DEDUCT}} ({{SCHED_REASON}})
- Scope Deductions: -{{SCOPE_DEDUCT}} ({{SCOPE_REASON}})
- Resource Deductions: -{{RES_DEDUCT}} ({{RES_REASON}})
- Financial Deductions: -{{FIN_DEDUCT}} ({{FIN_REASON}})
- Integration Deductions: -{{INT_DEDUCT}} ({{INT_REASON}})

## Recommendation

### {{RECOMMENDATION_HEADER}}

{{RECOMMENDATION_SUMMARY}}

#### Proceed If

1. {{PROCEED_CONDITION_1}}
2. {{PROCEED_CONDITION_2}}
3. {{PROCEED_CONDITION_3}}
4. {{PROCEED_CONDITION_4}}

#### Key Conditions

1. {{KEY_CONDITION_1}}
2. {{KEY_CONDITION_2}}
3. {{KEY_CONDITION_3}}
4. {{KEY_CONDITION_4}}

---

## Executive Summary

### Engagement Overview

{{ENGAGEMENT_OVERVIEW}}

### Contract Structure

| Element | Details |
|---------|---------|
| **Pricing Model** | {{PRICING_MODEL}} |
| **Per-WO Cap** | {{WO_CAP}} |
| **Total Maximum** | {{TOTAL_MAX}} |
| **Monthly Range** | {{MONTHLY_RANGE}} |
| **Duration** | {{DURATION}} |
| **Termination** | {{TERMINATION_TERMS}} |

### Workstream Details

<!-- Repeat for each workstream -->

#### WO{{N}}: {{WO_NAME}}

- **Objective:** {{WO_OBJECTIVE}}
- **Complexity:** {{HIGH/MEDIUM/LOW}} - {{COMPLEXITY_REASON}}
- **Key Risk:** {{WO_KEY_RISK}}

### Strengths

| Strength | Impact |
|----------|--------|
| {{STRENGTH_1}} | {{IMPACT_1}} |
| {{STRENGTH_2}} | {{IMPACT_2}} |
| {{STRENGTH_3}} | {{IMPACT_3}} |
| {{STRENGTH_4}} | {{IMPACT_4}} |

### Concerns

| Concern | Severity | Mitigation |
|---------|----------|------------|
| {{CONCERN_1}} | {{SEV_1}} | {{MIT_1}} |
| {{CONCERN_2}} | {{SEV_2}} | {{MIT_2}} |
| {{CONCERN_3}} | {{SEV_3}} | {{MIT_3}} |
| {{CONCERN_4}} | {{SEV_4}} | {{MIT_4}} |

### Financial Analysis

**Best Case (Minimum Monthly):**

- {{BEST_CASE_CALC}}

**Expected Case (Mid-Range):**

- {{EXPECTED_CASE_CALC}}

**Worst Case (Cap):**

- {{WORST_CASE_CALC}}

**Resource Economics:**

- {{RESOURCE_1}}: {{RATE_1}} -> {{CALC_1}}
- {{RESOURCE_2}}: {{RATE_2}} -> {{CALC_2}}

### Phase 2 Considerations

<!-- Include if Phase 1 only engagement -->

{{PHASE_2_OVERVIEW}}

**Recommendation:** {{PHASE_2_RECOMMENDATION}}

---

## Approval Checklist

- [ ] Risk register reviewed by delivery leadership
- [ ] Resource availability confirmed for {{START_DATE}} start
- [ ] Client kickoff scheduled within first week
- [ ] {{CUSTOM_CHECKLIST_ITEM_1}}
- [ ] {{CUSTOM_CHECKLIST_ITEM_2}}
