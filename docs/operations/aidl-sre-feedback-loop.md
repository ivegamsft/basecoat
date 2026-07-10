# AIDL SRE Feedback Loop

This runbook standardizes the reliability feedback loop from incident detection through remediation verification.

## Objectives

1. Reduce incident recurrence by enforcing incident-to-remediation-to-verification closure.
2. Improve mean time to recovery and reliability posture trend per sprint.
3. Ensure reliability learnings are captured and reused across portfolio teams.

## Loop Stages

| Stage | Trigger | Owner | Required output |
| --- | --- | --- | --- |
| Detect | Alert or incident ticket opened | On-call SRE | Incident record with severity and service impact |
| Stabilize | Incident acknowledged | Incident commander | Mitigation actions and customer impact update |
| Diagnose | Service stabilized | SRE + engineering | Root cause summary and contributing factors |
| Remediate | Root cause confirmed | Engineering owner | Linked remediation issues with priorities |
| Verify | Fix merged/deployed | SRE + QA owner | Verification evidence and recurrence check |
| Learn | Verification complete | Portfolio owner | Learning candidate and memory promotion decision |

## Stage Gates

## 1) Detect and stabilize

- [ ] Incident has severity, owner, and affected service metadata.
- [ ] SLA/SLO impact and customer risk are recorded.
- [ ] Temporary mitigation is documented and timestamped.

## 2) Diagnose and remediate

- [ ] Root cause and contributing factors are captured.
- [ ] Remediation issue links are attached to incident record.
- [ ] Remediation has priority, owner, due date, and acceptance criteria.

## 3) Verify and learn

- [ ] Validation evidence exists (test, monitor trend, or canary result).
- [ ] Recurrence check completed within two release cycles.
- [ ] Learning candidate created with adoption owner.

## Reliability KPI Set

Track these KPIs weekly and at sprint closeout:

1. Mean time to acknowledge (MTTA)
2. Mean time to recovery (MTTR)
3. Incident-to-remediation linkage rate
4. Remediation closure latency
5. Repeat-incident rate (30-day window)
6. Verification completeness rate

## Escalation Rules

1. Sev-0/Sev-1 incident without remediation issue within 24 hours escalates to engineering manager and portfolio governance lead.
2. Repeat incident with same root cause escalates to blocking corrective plan.
3. Verification missing after remediation due date escalates to release gate warning.

## Reporting Template

Use this minimum structure in reliability review notes:

1. Incident summary and service impact
2. Root cause and contributing factors
3. Remediation backlog status
4. Verification status and trend change
5. Learning capture and memory promotion decision

## Integration with Portfolio Audit

The SRE feedback loop contributes to:

1. Reliability and SRE loop domain score (`docs/operations/aidl-portfolio-audit-suite.md`)
2. Portfolio posture assessment reliability and operational excellence dimensions (`docs/operations/aidl-portfolio-posture-assessment.md`)

## References

1. `docs/operations/aidl-portfolio-operator-playbook.md`
2. `docs/operations/aidl-portfolio-audit-suite.md`
3. `docs/operations/aidl-portfolio-posture-assessment.md`
