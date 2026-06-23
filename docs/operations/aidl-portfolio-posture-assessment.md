# AIDL Portfolio Posture Assessment

This document defines how to score current architecture and reliability posture across AIDL-managed repositories.

## Assessment Goals

1. Establish a repeatable baseline for portfolio architecture and reliability posture.
2. Detect drift early and route corrective actions before release risk accumulates.
3. Provide one scorecard that leaders can use for prioritization and sprint planning.

## Scoring Dimensions

| Dimension | Weight | Primary question |
| --- | --- | --- |
| Architecture conformance | 30% | Are baseline standards and control contracts implemented as designed? |
| Reliability posture | 30% | Are SLO/SLA controls and failure-handling practices meeting target health? |
| Delivery resilience | 20% | Can delivery continue safely through incidents and dependency failures? |
| Operational excellence | 20% | Are runbooks, ownership, and feedback loops producing measurable improvement? |

## Dimension Criteria

## 1) Architecture conformance

- [ ] Canonical project fields, views, and rules match the AIDL baseline.
- [ ] Guardrail states are applied consistently (`Pass`, `Warn`, `Block`, `Waived`).
- [ ] Exceptions include owner, rationale, expiry, and remediation plan.

## 2) Reliability posture

- [ ] Critical services have current SLA/SLO targets and alert policies.
- [ ] Incident-to-remediation linkage exists for high-severity events.
- [ ] Repeat incidents are tracked and reduced over time.

## 3) Delivery resilience

- [ ] PR/merge quality gates are active for release-critical paths.
- [ ] Rollback and recovery runbooks are current and exercised.
- [ ] Dependency and workflow failures have documented fallback paths.

## 4) Operational excellence

- [ ] Reliability reviews run on a fixed cadence with owners assigned.
- [ ] Audit findings generate tracked remediation work with due dates.
- [ ] Learning and memory promotions include evidence of adoption impact.

## Score Calculation

1. Score each checklist item as `Pass`, `Warn`, or `Fail`.
2. Map status to points: `Pass=1.0`, `Warn=0.5`, `Fail=0.0`.
3. Compute per-dimension score as percentage of maximum points.
4. Apply dimension weights and sum for total posture score.

Thresholds:

- `>= 90`: Green
- `75-89`: Yellow
- `< 75`: Red

Critical reliability or security failures force a red result regardless of total score.

## Required Evidence

1. Link to source issue/PR or workflow run for each scored control.
2. Snapshot or reference for current project configuration state.
3. Incident and remediation links for reliability findings.
4. Owner and due date for each non-pass control.

## Cadence and Ownership

| Cadence | Scope | Owner | Output |
| --- | --- | --- | --- |
| Weekly | Active repos | SRE + platform operations | Posture delta report |
| Sprint closeout | Portfolio rollup | Portfolio governance lead | Sprint posture summary |
| Quarterly | Full baseline revalidation | Governance + security | Baseline refresh report |

## Remediation Routing

1. Red posture: open a blocking remediation wave issue within one business day.
2. Yellow posture for two consecutive cycles: open focused corrective plan issue.
3. Critical control fail: immediate escalation to domain owner and security/SRE lead.

## References

1. `docs/spec/aidl-portfolio-management.spec.md`
2. `docs/spec/aidl-portfolio-audit-suite.spec.md`
3. `docs/operations/aidl-portfolio-audit-suite.md`
4. `docs/operations/aidl-sre-feedback-loop.md`
