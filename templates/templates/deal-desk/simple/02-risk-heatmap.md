# Risk Heat Map

```text
                    IMPACT
              Low    Med    High
         +--------+--------+--------+
    High |        |        |        |
         |        |        |        |
L        +--------+--------+--------+
I   Med  |        |        |        |
K        |        |        |        |
E        +--------+--------+--------+
L   Low  |        |        |        |
Y        |        |        |        |
         +--------+--------+--------+
```

<!--
Place risk IDs in appropriate cells based on:
- Row = Likelihood (High/Med/Low)
- Column = Impact (Low/Med/High)

Example:
    High |        | R3.2   | R1.1   |
         |        | R5.1   | R7.2   |
-->

## Distribution

- **High Severity (6-9)**: {{HIGH_COUNT}} risks
- **Medium Severity (3-4)**: {{MED_COUNT}} risks
- **Low Severity (1-2)**: {{LOW_COUNT}} risks

## Risk Concentration Analysis

**Technical (R1.x)**: {{R1_COUNT}} risks - {{R1_ANALYSIS}}

**Schedule (R2.x)**: {{R2_COUNT}} risks - {{R2_ANALYSIS}}

**Scope (R3.x)**: {{R3_COUNT}} risks - {{R3_ANALYSIS}}

**Resource (R4.x)**: {{R4_COUNT}} risks - {{R4_ANALYSIS}}

**Financial (R5.x)**: {{R5_COUNT}} risks - {{R5_ANALYSIS}}

**Compliance (R6.x)**: {{R6_COUNT}} risks - {{R6_ANALYSIS}}

**Integration (R7.x)**: {{R7_COUNT}} risks - {{R7_ANALYSIS}}

## Key Observation

{{KEY_OBSERVATION}}
