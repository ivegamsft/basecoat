# Technical Specification: AIDL Portfolio Audit Suite

## Context

The AIDL portfolio feature needs a formal audit suite to verify conformance, governance, security, reliability, learning quality, and delivery-flow economics.

## Scope

1. Define audit domains and controls.
2. Define scoring and severity model.
3. Define evidence contracts and report outputs.
4. Define cadence and ownership.
5. Define escalation and remediation workflow.

## Out of Scope

1. Implementing every remediation control in this spec.
2. Replacing team-level incident management systems.

## Architecture Overview

## Audit domains

1. Framework and rubric
2. Project conformance
3. Governance and exception hygiene
4. Security posture
5. Reliability and SRE loop quality
6. Learning and memory quality
7. Delivery-flow economics

## Data Model and Storage Changes

No new database is required for baseline.

Audit artifacts are GitHub-native:

1. Audit reports as markdown artifacts
2. Remediation issues with severity labels
3. Linked evidence references to project items and workflows

## API and Interface Contracts

## Input contract

- Project configuration state (fields, views, rules)
- Workflow and controls state
- Incident and remediation linkage data
- Learning and memory promotion records

## Output contract

- Domain scorecards
- Critical findings
- Drift report
- Remediation issue payloads

## Security and Privacy Considerations

1. Redact sensitive data in audit reports intended for broad audiences.
2. Restrict audit execution identities to least privilege.
3. Track all waiver and exception mutations with audit trail.

## Reliability and Failure Modes

1. Missing evidence references produce false green.
   - Mitigation: hard fail controls on missing required evidence.
2. Non-deterministic scoring across runs.
   - Mitigation: deterministic scoring rubric and static thresholds.
3. Alert fatigue from noisy low-severity findings.
   - Mitigation: severity gates and grouped remediation waves.

## Performance and Capacity Considerations

1. Run weekly full audit and lightweight daily checks.
2. Batch API queries by repo to reduce rate-limit pressure.
3. Reuse cached metadata when supported by workflow runtime.

## Implementation Plan

1. Publish audit domain checklists and rubric.
2. Implement conformance and drift collection.
3. Implement security and governance checks.
4. Implement reliability and learning loop checks.
5. Implement economics trend reporting.

## Testing Strategy

1. Test scoring with synthetic pass/warn/fail fixtures.
2. Test drift detection with controlled configuration changes.
3. Test remediation issue generation and owner routing.

## Rollout, Migration, and Rollback Plan

1. Advisory mode for one sprint.
2. Enforce mode for critical controls in wave 1 repos.
3. Expand enforcement after two stable cycles.
4. Rollback by returning to advisory mode and pausing blockers.

## Observability and Operational Readiness

Track:

1. Audit completion success rate
2. Average domain score by repo
3. Critical finding volume and closure latency
4. Waiver expiry compliance
5. Repeat-finding rate

## Risks and Mitigations

1. **Risk**: Overhead from too many controls.
   - **Mitigation**: phased domain enablement and priority tiers.
2. **Risk**: Ambiguous ownership for findings.
   - **Mitigation**: explicit owner mapping by domain.

## Open Questions

1. Which controls should be blocking in wave 1?
2. Should economics metrics be weekly or sprint-only in early rollout?

## References

1. `docs/spec/aidl-portfolio-management.spec.md`
2. `docs/operations/aidl-portfolio-audit-suite.md`
3. `docs/operations/aidl-portfolio-operator-playbook.md`
