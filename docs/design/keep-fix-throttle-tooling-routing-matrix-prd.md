# Product Requirements Document: Keep/Fix/Throttle Tooling Routing Matrix

## Problem Statement

Execution routing is currently inconsistent across local, background, cloud, and manual paths, which increases orchestration overhead and causes avoidable rerouting.

## Goals

1. Publish a default routing matrix for four execution modes.
2. Define enforceable routing checkpoints and override policy.
3. Improve run consistency so most fleet runs map to defaults without manual reroute.

## Non-Goals

1. Replacing existing risk-tier governance.
2. Implementing workflow automation changes in this slice.
3. Rewriting existing runner-capability contracts.

## User Personas and Use Cases

- **Operator/maintainer:** chooses execution mode for incoming work quickly.
- **Control-plane owner:** audits whether routing behavior follows policy and reduces overhead.

## User Experience Summary

Operators get one table-based default map, explicit escalation triggers, and a constrained override policy. Selection and rerouting decisions become deterministic and auditable.

## Functional Requirements

1. Provide a four-mode routing matrix (`local`, `background`, `cloud`, `manual`).
2. Define mandatory enforcement points across intake, mid-run, pre-merge, and post-run stages.
3. Define allowed override scenarios and required justification metadata.
4. Provide scenario examples to reduce interpretation ambiguity.

## Non-Functional Requirements

1. Documentation must be concise and operationally actionable.
2. Routing rules must align with Keep/Fix/Throttle risk expectations.
3. Guidance must support low-overhead execution (decision clarity with minimal reroute churn).

## Success Metrics

1. >=90% of fleet runs map cleanly to default matrix routes.
2. Mean orchestration overhead (events per run) reduced by >=25% from baseline.
3. Exceptions include explicit rationale in 100% of overrides.

## Constraints and Assumptions

1. This first PR is documentation-first and does not modify automation code paths.
2. Existing risk-tier controls remain authoritative for high-risk operations.
3. Teams can collect route/override telemetry through current run reporting mechanisms.

## Risks and Open Questions

- **Risk:** Guidance-only rollout may produce uneven adoption before automation guardrails are added.
- **Open question:** Which existing workflow(s) should become the first hard enforcement point in follow-up slices.

## Dependencies

- `docs/operations/keep-fix-throttle-model.md`
- `docs/reference/governance-contract.md`

## Rollout and Adoption Plan

1. Publish matrix and route policy runbook.
2. Reference the runbook from the Keep/Fix/Throttle tracker doc.
3. Use follow-up slices to add hard checks where needed.

## References

- Issue: [#2048](https://github.com/ivegamsft/basecoat/issues/2048)
- Epic: [#1452](https://github.com/ivegamsft/basecoat/issues/1452)
