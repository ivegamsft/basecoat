# Keep/Fix/Throttle Tooling Routing Matrix Spec

## Context

Workstream 3 of epic #1452 requires deterministic execution-mode routing across local, background, cloud, and manual paths.

Related issue: [#2048](https://github.com/IBuySpy-Shared/basecoat/issues/2048)

## Scope

1. Define execution-mode routing matrix defaults.
2. Define enforcement points for route selection and reroute control.
3. Define override policy and required exception evidence.
4. Provide operational examples.

## Out of Scope

1. New workflow automation or CI enforcement logic.
2. Changes to runner class contracts or existing deployment routing scripts.
3. Tier policy redesign.

## Architecture Overview

This slice introduces a documentation control plane:

1. A mode matrix maps request shape to default execution mode.
2. Enforcement points define where route compliance is checked.
3. Override policy constrains deviations and requires rationale.

## Data Model and Storage Changes

No schema or persisted storage changes in this slice.

## API and Interface Contracts

No API contract changes in this slice.

## Security and Privacy Considerations

Manual mode remains mandatory for high-risk operations requiring explicit human approval. The routing matrix does not relax existing governance controls.

## Reliability and Failure Modes

Primary failure mode is route drift (frequent rerouting). The spec mitigates drift with fixed checkpoints and bounded override cases.

## Performance and Capacity Considerations

Expected outcome is lower orchestration overhead by reducing unnecessary reroutes and routing ambiguity.

## Implementation Plan

1. Add `docs/operations/keep-fix-throttle-tooling-routing-matrix.md`.
2. Link routing matrix deliverables from `docs/operations/keep-fix-throttle-model.md`.
3. Publish PRD/spec references for PR gate compatibility.

## Testing Strategy

1. Run repository validation suite (`pwsh tests/run-tests.ps1`).
2. Confirm markdown formatting/lint compatibility for new/updated docs.

## Rollout, Migration, and Rollback Plan

- **Rollout:** docs-first publication.
- **Migration:** teams adopt matrix defaults and capture override rationale.
- **Rollback:** remove the new runbook link and revert to prior ad hoc routing guidance.

## Observability and Operational Readiness

Track:

1. Default-route adoption rate.
2. Reroute count per run.
3. Override rationale completeness.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Guidance-only policy under-adopted | Follow-up enforcement in workflow checks |
| Overuse of manual overrides | Require explicit rationale and approver context |

## Open Questions

1. Which workflow should enforce the first hard route-compliance check?
2. Should override metadata be emitted via workflow summary or issue comment first?

## References

- PRD: `docs/design/keep-fix-throttle-tooling-routing-matrix-prd.md`
- Runbook: `docs/operations/keep-fix-throttle-tooling-routing-matrix.md`
- KFT model: `docs/operations/keep-fix-throttle-model.md`
