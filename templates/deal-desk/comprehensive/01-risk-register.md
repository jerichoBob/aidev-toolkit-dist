# Risk Register: {{PROJECT_NAME}}

**Last Updated:** {{DATE}}<br/>
**Total Risks:** {{TOTAL}}<br/>
**Critical Risks:** {{CRITICAL_COUNT}}<br/>
**High Risks:** {{HIGH_COUNT}}<br/>
**Medium Risks:** {{MED_COUNT}}<br/>
**Low Risks:** {{LOW_COUNT}}

---

## R1: Technical Risks

### R1.1: {{RISK_TITLE}}

| Field          | Value                        |
| -------------- | ---------------------------- |
| **ID**         | R1.1                         |
| **Category**   | Technical                    |
| **Likelihood** | {{Low/Med/High}} ({{1-3}}/3) |
| **Impact**     | {{Low/Med/High}} ({{1-3}}/3) |
| **Risk Score** | {{1-9}} ({{Low/Med/High}})   |
| **Status**     | Open                         |

**Description:**

{{DETAILED_DESCRIPTION}}

**Triggers:**

- {{TRIGGER_1}}
- {{TRIGGER_2}}
- {{TRIGGER_3}}

**Consequences:**

- {{CONSEQUENCE_1}}
- {{CONSEQUENCE_2}}
- {{CONSEQUENCE_3}}

**Mitigation:** See MIT-R1.1

---

<!-- Repeat for each risk in category -->

## R2: Schedule Risks

### R2.1: {{RISK_TITLE}}

| Field          | Value                        |
| -------------- | ---------------------------- |
| **ID**         | R2.1                         |
| **Category**   | Schedule                     |
| **Likelihood** | {{Low/Med/High}} ({{1-3}}/3) |
| **Impact**     | {{Low/Med/High}} ({{1-3}}/3) |
| **Risk Score** | {{1-9}} ({{Low/Med/High}})   |
| **Status**     | Open                         |

**Description:**

{{DETAILED_DESCRIPTION}}

**Triggers:**

- {{TRIGGER_1}}
- {{TRIGGER_2}}

**Consequences:**

- {{CONSEQUENCE_1}}
- {{CONSEQUENCE_2}}

**Mitigation:** See MIT-R2.1

---

## R3: Scope Risks

<!-- Same card format -->

## R4: Resource Risks

<!-- Same card format -->

## R5: Financial Risks

<!-- Same card format -->

## R6: Compliance Risks

<!-- Same card format -->

## R7: Integration Risks

<!-- Same card format -->

## R8: Operational Risks

<!-- Same card format - Deep mode only -->

## R9: Organizational Risks

<!-- Same card format - Deep mode only -->

## R10: Market/Business Risks

<!-- Same card format - Deep mode only -->

---

## Risk Summary by Score

| Score Range | Classification | Count          | Risk IDs     |
| ----------- | -------------- | -------------- | ------------ |
| 6-9         | High           | {{HIGH_COUNT}} | {{HIGH_IDS}} |
| 3-4         | Medium         | {{MED_COUNT}}  | {{MED_IDS}}  |
| 1-2         | Low            | {{LOW_COUNT}}  | {{LOW_IDS}}  |

<!--
SCORING GUIDE:
- Likelihood: Low (1), Medium (2), High (3)
- Impact: Low (1), Medium (2), High (3)
- Score: Likelihood × Impact (1-9)

SEVERITY BANDS:
- Low: 1-2
- Medium: 3-4
- High: 6-9

ID FORMAT: R{category}.{sequence}
-->
