# Mitigation Strategies: {{PROJECT_NAME}}

**Analysis Date:** {{DATE}}

## Mitigation Summary

| Priority | Mitigations | Risk Coverage |
|----------|-------------|---------------|
| High | {{HIGH_COUNT}} | {{HIGH_IDS}} |
| Medium | {{MED_COUNT}} | {{MED_IDS}} |
| Standard | {{LOW_COUNT}} | {{LOW_IDS}} |

---

## High Risk Mitigations

### MIT-R{{X}}.{{Y}}: {{MITIGATION_TITLE}}

**Risk:** R{{X}}.{{Y}} - {{RISK_TITLE}} (High, Score: {{SCORE}})

**Mitigation Strategy:**

1. **{{STRATEGY_PHASE_1}}**

   - {{ACTION_1}}
   - {{ACTION_2}}
   - {{ACTION_3}}

2. **{{STRATEGY_PHASE_2}}**

   - {{ACTION_1}}
   - {{ACTION_2}}

3. **{{STRATEGY_PHASE_3}}**

   - {{ACTION_1}}
   - {{ACTION_2}}

4. **{{STRATEGY_PHASE_4}}**

   - {{ACTION_1}}
   - {{ACTION_2}}

**Owner:** {{OWNER_ROLE}}<br/>
**Timeline:** {{TIMELINE}}<br/>
**Success Criteria:** {{SUCCESS_CRITERIA}}

---

<!-- Repeat for each high-severity risk -->

## Medium Risk Mitigations

### MIT-R{{X}}.{{Y}}: {{MITIGATION_TITLE}}

**Risk:** R{{X}}.{{Y}} - {{RISK_TITLE}}

**Actions:**

- {{ACTION_1}}
- {{ACTION_2}}
- {{ACTION_3}}

**Owner:** {{OWNER_ROLE}}<br/>
**Timeline:** {{TIMELINE}}

---

<!-- Repeat for each medium-severity risk -->

## Low Risk Mitigations

### MIT-R{{X}}.{{Y}}: {{MITIGATION_TITLE}}

**Risk:** R{{X}}.{{Y}} - {{RISK_TITLE}}

**Actions:**

- {{ACTION_1}}
- {{ACTION_2}}

**Owner:** {{OWNER_ROLE}}<br/>
**Timeline:** {{TIMELINE}}

---

## Mitigation Tracking Checklist

| ID | Mitigation | Owner | Due | Status |
|----|------------|-------|-----|--------|
| MIT-R{{X}}.{{Y}} | {{SHORT_DESCRIPTION}} | {{OWNER}} | {{DUE}} | Not Started |

---

## Recommended Governance

### Weekly Risk Review

**Frequency:** Weekly ({{DAY}})<br/>
**Attendees:** {{ATTENDEES}}

**Agenda:**

1. Risk status updates
2. New risks identified
3. Mitigation progress
4. Escalations to client

### Monthly Risk Report

**Frequency:** Monthly<br/>
**Distribution:** {{DISTRIBUTION}}

**Contents:**

1. Risk heatmap update
2. High risk status
3. Mitigations effectiveness
4. Recommendations

### Escalation Triggers

| Condition | Action | Timeline |
|-----------|--------|----------|
| High risk impact realized | Escalate to {{ESCALATION_CONTACT}} | Within 24 hours |
| Medium risk impact realized | Escalate to {{SPONSOR}} | Within 48 hours |
| Budget >75% consumed | Review scope and timeline | Within 1 week |
| Timeline slip >1 week | Assess recovery options | Immediate |
