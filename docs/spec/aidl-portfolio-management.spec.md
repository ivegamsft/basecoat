# Technical Specification: AIDL Portfolio Management

## Context

BaseCoat needs a canonical portfolio-management feature for AI-assisted software delivery where:

1. **BaseCoat** provides guardrails, policy, and validation.
2. **GitHub Projects** provides tracking, workflow state, and visibility.

This spec implements the scoped work tracked in the implementation issue set (AIDL Portfolio).

## Scope

1. Define the canonical AIDL lifecycle and control points.
2. Define the repo-scoped GitHub Project baseline (fields, views, automation rules).
3. Define guardrail-state semantics (`Pass`, `Warn`, `Block`, `Waived`).
4. Define rules-vs-actions boundaries.
5. Define task ownership mapping for agent/skill routing.
6. Define known gaps and workaround contracts.

## Out of Scope

1. Building a standalone portfolio SaaS.
2. Replacing native GitHub issue and PR workflows.
3. ML training registry and model-lifecycle-first controls as default requirements.

## Architecture Overview

## Layer model

1. Entry and Intake
2. Planning and Prioritization
3. Build
4. Review
5. Release
6. Operate
7. Maintenance
8. Learning
9. Memory and Efficiency
10. Governance
11. SRE Fast Feedback Loop

## Responsibility split

| Concern | System | Contract |
| --- | --- | --- |
| Guardrails and policy decisions | BaseCoat | Evaluate and set guardrail state |
| Work item lifecycle and visibility | GitHub Projects | Record issue/PR state, ownership, risk, and evidence |
| Audit and conformance reporting | BaseCoat + GitHub workflows | Detect drift and open remediation actions |

## Data Model and Storage Changes

No new external datastore is required for baseline operation.

Use GitHub-native artifacts:

1. Project fields as canonical state metadata.
2. Project views as role-based operational surfaces.
3. Rules and workflows as automation configuration.
4. Linked issues/PRs for traceability.

## Canonical project fields

1. `Status`: Backlog, Ready, In Progress, In Review, Release Ready, Done, Blocked
2. `Type`: Feature, Bug, Security, Tech Debt, Incident, Maintenance, Docs, Chore
3. `Priority`: Critical, High, Medium, Low
4. `Iteration`: Sprint cadence
5. `Area`: Component or domain
6. `Effort`: Numeric estimate
7. `Risk`: Critical, High, Medium, Low
8. `Guardrail State`: Pass, Warn, Block, Waived
9. `SRE Impact`: None, Latency, Availability, Error Rate, Capacity
10. `Runbook Link`
11. `Learning Capture`: None, Candidate, Promoted

## Canonical views

1. Sprint Delivery
2. Backlog
3. PR and Review Queue
4. Security and High Risk
5. Incidents and Reliability
6. Maintenance and Audit
7. Learning and Memory
8. Roadmap

## API and Interface Contracts

## Guardrail contract

- Input: issue or PR context, field values, linked artifacts, policy profile
- Output: `Pass`, `Warn`, `Block`, or `Waived` with reason and owner

## Rules-vs-actions contract

Use **Project Rules** by default for:

1. Auto-add items
2. Label-to-field mapping
3. Basic lifecycle transitions

Use **GitHub Actions** for:

1. Cross-repo rollups
2. External API integration
3. Complex conditional logic
4. Learning-to-memory promotion pipelines

## Security and Privacy Considerations

1. Enforce least privilege for workflow tokens and project mutation actions.
2. Prevent sensitive data leakage in learning/memory promotion artifacts.
3. Require exception records for `Waived` states with owner and expiry.

## Reliability and Failure Modes

1. **Configuration drift**: project fields/views/rules deviate from baseline.
   - Mitigation: scheduled conformance audit and drift remediation issues.
2. **Orphaned incidents**: incidents not linked to remediation work.
   - Mitigation: incident-to-backlog router and closure checks.
3. **Policy bypass**: unauthorized transitions to release or done.
   - Mitigation: guardrail checks plus workflow-level gates.

## Performance and Capacity Considerations

1. Prefer rules over actions for low-latency, low-overhead state transitions.
2. Batch audit data collection to limit API cost.
3. Track token/turn cost per lifecycle stage and optimize top waste drivers.

## Implementation Plan

1. Publish baseline spec and operations docs.
2. Implement project bootstrap manifest and validator.
3. Implement project rules drift auditor.
4. Implement cross-repo rollup and KPI publisher.
5. Implement incident-to-backlog router.
6. Implement learning-to-memory pipeline.
7. Normalize routing and naming ambiguity.

## Testing Strategy

1. Validate baseline field and view creation on test repos.
2. Validate rule application and idempotent re-apply behavior.
3. Validate drift detection against synthetic drift scenarios.
4. Validate routing outcomes for incident and learning workflows.

## Rollout, Migration, and Rollback Plan

1. Phase 1: advisory mode (docs, reports, no enforcement).
2. Phase 2: enforce on selected repos.
3. Phase 3: scale to portfolio default.
4. Rollback: revert to advisory mode and pause blocking automation.

## Observability and Operational Readiness

Track:

1. Conformance score by repo
2. Drift count and severity
3. Incident-to-remediation latency
4. Waiver count and expiry compliance
5. Learning candidate promotion rate
6. Token/turn efficiency trend

## Risks and Mitigations

1. **Risk**: over-governance slows delivery.
   - **Mitigation**: staged enforcement and explicit waiver path.
2. **Risk**: role ambiguity across overlapping agents and skills.
   - **Mitigation**: canonical routing table with primary owner per task.
3. **Risk**: cross-repo visibility gaps in native GitHub model.
   - **Mitigation**: rollup publisher and documented constraints.

## Open Questions

1. Which repos enter enforcement in wave 1?
2. What threshold moves conformance from advisory to blocking?
3. Should memory promotion be weekly or sprint-based by default?

## References

1. `docs/spec/rca-automation-agents-skills.spec.md`
2. `docs/guides/prd-and-spec-guidance.md`
3. `docs/operations/aidl-portfolio-audit-suite.md`
4. `docs/operations/aidl-portfolio-operator-playbook.md`
5. `docs/operations/aidl-portfolio-posture-assessment.md`
6. `docs/operations/aidl-sre-feedback-loop.md`
