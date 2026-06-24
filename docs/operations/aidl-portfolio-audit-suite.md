# AIDL Portfolio Audit Suite

This document defines the audit set for AIDL portfolio management.

## Audit Domains

1. Framework and rubric audit
2. Project conformance audit (fields, views, rules)
3. Governance and exception hygiene audit
4. Security posture audit
5. Reliability and SRE loop audit
6. Learning and memory quality audit
7. Delivery-flow economics audit

## Cadence

| Audit domain | Cadence | Owner |
| --- | --- | --- |
| Framework/rubric | Quarterly or major change | Governance lead |
| Conformance | Weekly | Platform operations |
| Governance/waivers | Weekly | Policy owner |
| Security posture | Weekly + release gate | Security operations |
| Reliability/SRE loop | Weekly + post-incident | SRE |
| Learning/memory | Sprint closeout | Feedback/memory owner |
| Flow economics | Sprint closeout | Agentic operations |

## Scoring Model

Each control is scored:

1. `Pass`: fully compliant with evidence.
2. `Warn`: partially compliant or stale evidence.
3. `Fail`: non-compliant or missing control.

Aggregate score:

- `>= 90`: green
- `75-89`: yellow
- `< 75`: red

Critical control failures force red regardless of aggregate score.

## Required Evidence

1. Links to affected issue/PR/project items
2. Current control values (field/view/rule snapshots)
3. Drift diff and severity
4. Owner and due date for remediation
5. Waiver metadata (if applicable): owner, rationale, expiry

## Domain Checklists

## 1) Framework and rubric audit

- [ ] Control catalog matches current feature contract
- [ ] Scoring model and thresholds are current
- [ ] Escalation matrix is documented

## 2) Project conformance audit

- [ ] Required fields exist with canonical values
- [ ] Required views exist and filters/grouping are correct
- [ ] Required automation rules exist and are active
- [ ] Drift report generated

Runbook command for this check:

```powershell
pwsh -File scripts/aidl-portfolio-project-bootstrap.ps1 `
  -ManifestPath docs/specs/aidl-portfolio/project-bootstrap-manifest.json `
  -Mode validate `
  -CurrentStatePath <project-state-export.json>
```

## 3) Governance and exception hygiene audit

- [ ] `Waived` states include owner/rationale/expiry
- [ ] Expired waivers have follow-up actions
- [ ] Policy gates match live settings

## 4) Security posture audit

- [ ] Branch/ruleset protections align to baseline
- [ ] Workflow permissions are least privilege
- [ ] Secret/config exposure scan completed
- [ ] Security findings are routed to tracked remediation work

## 5) Reliability and SRE loop audit

- [ ] High-severity incidents create remediation issues
- [ ] Incident -> remediation -> verification linkage exists
- [ ] Repeat incidents are flagged with references

## 6) Learning and memory quality audit

- [ ] Candidate extraction is evidence-backed
- [ ] Promotion decisions are documented
- [ ] Sensitive content controls are applied
- [ ] Adoption impact is measured

## 7) Delivery-flow economics audit

- [ ] Token and turn baseline is tracked
- [ ] Top waste drivers are identified
- [ ] Optimization actions are linked to owners
- [ ] Before/after trend is measured per sprint

## Escalation Policy

1. Critical security or policy failure: open blocking issue and escalate immediately.
2. Red audit score: open remediation wave and block enforcement expansion.
3. Repeated yellow score for 2 cycles: trigger focused corrective plan.

## Reporting

Minimum report sections:

1. Summary scorecard
2. Critical findings
3. Drift and trend deltas
4. Remediation backlog with owners/dates
5. Waiver status

## Linked Operational Controls

1. Portfolio posture rollup and scoring: `docs/operations/aidl-portfolio-posture-assessment.md`
2. Reliability incident closure loop: `docs/operations/aidl-sre-feedback-loop.md`

## Related Issues

See the AIDL Portfolio Audit issue set for implementation and tracking.
