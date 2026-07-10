# Technical Specification: actions/checkout Upgrade (4.3.1 to 7.0.0)

## Context

All BaseCoat CI/CD workflows use `actions/checkout` to check out repository code. Dependabot raised PR #1903 to bump this action from `4.3.1` to `7.0.0` across all 59 workflow files that reference it. This spec documents the scope, validation approach, and rollout criteria.

## Scope

- Update all `.github/workflows/*.yml` files referencing `actions/checkout@v4` or a pinned v4 SHA to the new v7 SHA.
- Confirm no behavioral changes to checkout configuration across all affected workflows.

## Out of Scope

- Changing `actions/checkout` step inputs (depth, token, submodules, etc.).
- Upgrading any other action dependencies.
- Changes to workflow logic, job structure, or trigger configuration.

## Architecture Overview

`actions/checkout` is a leaf dependency: it has no downstream action consumers within BaseCoat workflows. Upgrading it in place (same step name, same inputs) carries no cross-action compatibility risk.

## Data Model and Storage Changes

None.

## API and Interface Contracts

The `actions/checkout` public input API (ref, fetch-depth, token, submodules, persist-credentials) is stable across v4 to v7. No input keys are changed or removed.

## Security and Privacy Considerations

- Upgrading from an older major version reduces exposure to known issues fixed in the newer release.
- All action references must continue to be pinned to a full commit SHA per BaseCoat guardrails (`tests/workflow-guardrails-tests.ps1`).

## Reliability and Failure Modes

- If the new SHA is malformed or the action is unavailable, workflows will fail at the checkout step. This is surfaced immediately in CI.
- Rollback: revert the Dependabot PR to restore the previous SHA.

## Performance and Capacity Considerations

No measurable impact. Checkout action execution time is not materially affected by version.

## Implementation Plan

1. Dependabot opens PR with updated SHA across all 59 workflow files.
2. CI runs `validate-basecoat.yml`, `prd-spec-gate.yml`, and `workflow-guardrails-tests.ps1` to confirm no guardrail violations.
3. Merge after all checks pass.

## Testing Strategy

- Existing workflow guardrail tests (`tests/workflow-guardrails-tests.ps1`) validate SHA pinning.
- Full CI suite runs on PR open and before merge queue entry.
- No new tests required for a pure version bump.

## Rollout, Migration, and Rollback Plan

- **Rollout:** Merge PR; all workflows adopt the new version on next trigger.
- **Rollback:** Revert the Dependabot PR branch and merge the revert.

## Observability and Operational Readiness

Monitor workflow run logs for 24 hours post-merge. No new alerts or dashboards required.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Breaking change in checkout v5-v7 API | Review CHANGELOG; all step inputs verified unchanged |
| SHA pinning mismatch | CI guardrail tests enforce correct SHA format |

## Open Questions

None.

## References

- [actions/checkout releases](https://github.com/actions/checkout/releases)
- [actions/checkout CHANGELOG](https://github.com/actions/checkout/blob/main/CHANGELOG.md)
- PRD: `docs/design/actions-checkout-upgrade-prd.md`
- Workflow guardrails: `tests/workflow-guardrails-tests.ps1`
