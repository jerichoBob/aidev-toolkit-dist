# Risk Heatmap: {{PROJECT_NAME}}

**Analysis Date:** {{DATE}}

## Likelihood x Impact Matrix

```text
                              IMPACT
                 Low(1)    Medium(2)     High(3)
              +----------+------------+------------+
   High(3)    |          |            |            |
              |          |            |            |
              +----------+------------+------------+
              |          |            |            |
   Medium(2)  |          |            |            |
              |          |            |            |
   L          +----------+------------+------------+
   I          |          |            |            |
   K   Low(1) |          |            |            |
   E          |          |            |            |
   L          +----------+------------+------------+
   Y
```

<!--
Place risk IDs in appropriate cells based on:
- Row = Likelihood (High/Med/Low)
- Column = Impact (Low/Med/High)
-->

## Risk Distribution by Severity

```text
High (6-9):    {{HIGH_BAR}}  {{HIGH_COUNT}} risks
Medium (3-4):  {{MED_BAR}}   {{MED_COUNT}} risks
Low (1-2):     {{LOW_BAR}}   {{LOW_COUNT}} risks
```

## Heat Map by Dimension

| Dimension       | Low               | Medium            | High               | Total               |
| --------------- | ----------------- | ----------------- | ------------------ | ------------------- |
| R1: Technical   | {{R1_LOW}}        | {{R1_MED}}        | {{R1_HIGH}}        | {{R1_TOTAL}}        |
| R2: Schedule    | {{R2_LOW}}        | {{R2_MED}}        | {{R2_HIGH}}        | {{R2_TOTAL}}        |
| R3: Scope       | {{R3_LOW}}        | {{R3_MED}}        | {{R3_HIGH}}        | {{R3_TOTAL}}        |
| R4: Resource    | {{R4_LOW}}        | {{R4_MED}}        | {{R4_HIGH}}        | {{R4_TOTAL}}        |
| R5: Financial   | {{R5_LOW}}        | {{R5_MED}}        | {{R5_HIGH}}        | {{R5_TOTAL}}        |
| R6: Compliance  | {{R6_LOW}}        | {{R6_MED}}        | {{R6_HIGH}}        | {{R6_TOTAL}}        |
| R7: Integration | {{R7_LOW}}        | {{R7_MED}}        | {{R7_HIGH}}        | {{R7_TOTAL}}        |
| **Total**       | **{{TOTAL_LOW}}** | **{{TOTAL_MED}}** | **{{TOTAL_HIGH}}** | **{{GRAND_TOTAL}}** |

## High Risks Summary

### High Risks (Immediate Attention Required)

| ID     | Risk           | Score     | Dimension     |
| ------ | -------------- | --------- | ------------- |
| {{ID}} | {{RISK_TITLE}} | {{SCORE}} | {{DIMENSION}} |

## Risk Trend Indicators

| Dimension   | Trend     | Rationale     |
| ----------- | --------- | ------------- |
| Technical   | {{ARROW}} | {{RATIONALE}} |
| Schedule    | {{ARROW}} | {{RATIONALE}} |
| Scope       | {{ARROW}} | {{RATIONALE}} |
| Resource    | {{ARROW}} | {{RATIONALE}} |
| Financial   | {{ARROW}} | {{RATIONALE}} |
| Compliance  | {{ARROW}} | {{RATIONALE}} |
| Integration | {{ARROW}} | {{RATIONALE}} |

<!--
TREND ARROWS:
- ↗ Increasing - Risk may grow as project progresses
- → Stable - Risk level expected to remain constant
- ↘ Decreasing - Risk reduces as team gains context
-->

## Risk Concentration Analysis

### By Workstream

<!-- Include if multiple workstreams -->

| Workstream       | Risk Count      | Highest Risk      |
| ---------------- | --------------- | ----------------- |
| {{WO1_NAME}}     | {{WO1_COUNT}}   | {{WO1_HIGHEST}}   |
| {{WO2_NAME}}     | {{WO2_COUNT}}   | {{WO2_HIGHEST}}   |
| Cross-Workstream | {{CROSS_COUNT}} | {{CROSS_HIGHEST}} |

### By Phase

| Phase       | Risk Count       | Highest Risk       |
| ----------- | ---------------- | ------------------ |
| Define      | {{DEFINE_COUNT}} | {{DEFINE_HIGHEST}} |
| Design      | {{DESIGN_COUNT}} | {{DESIGN_HIGHEST}} |
| Cross-Phase | {{CROSS_COUNT}}  | {{CROSS_HIGHEST}}  |

## Visual Risk Summary

```text
+------------------------------------------------------------------+
|                    RISK PROFILE SUMMARY                           |
+------------------------------------------------------------------+
|                                                                   |
|  Overall Risk Level:  {{OVERALL_BAR}}  {{OVERALL_LEVEL}}         |
|                                                                   |
|  High Risks:          {{HIGH_BAR}}  {{HIGH_COUNT}} ({{HIGH_PCT}})|
|  Medium Risks:        {{MED_BAR}}   {{MED_COUNT}} ({{MED_PCT}})  |
|  Low Risks:           {{LOW_BAR}}   {{LOW_COUNT}} ({{LOW_PCT}})  |
|                                                                   |
|  Top Risk Dimensions:                                             |
|    1. {{TOP_DIM_1}} - {{TOP_DIM_1_COUNT}} risks                  |
|    2. {{TOP_DIM_2}} - {{TOP_DIM_2_COUNT}} risks                  |
|    3. {{TOP_DIM_3}} - {{TOP_DIM_3_COUNT}} risks                  |
|                                                                   |
|  Recommended Focus:                                               |
|    - {{FOCUS_1}}                                                 |
|    - {{FOCUS_2}}                                                 |
|    - {{FOCUS_3}}                                                 |
|                                                                   |
+------------------------------------------------------------------+
```
