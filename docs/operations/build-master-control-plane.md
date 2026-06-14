# Build Master Control Plane

## Summary

This document specifies a generic Build Master pattern: a background merge
controller that keeps healthy lanes moving while isolating broken lanes and
delegating eligible build repairs to cloud agents through PR-only workflows.

## Debate

### Option A: Stop-the-world on any break

- Pros: minimal risk spread.
- Cons: throughput collapses and unrelated lanes stall.

### Option B: Continue merging everywhere during incidents

- Pros: maximum short-term velocity.
- Cons: cascade risk and poor incident containment.

### Option C: Lane-isolated continuity (selected)

- Pros: balances velocity and containment.
- Cons: needs explicit lane state policy and escalation rules.

Selected approach is Option C because it aligns with existing Basecoat guidance:
serialized merge pacing, PR-only changes, and policy-gated autonomy.

## Components

1. **Build Master agent** (`build-master`)
   - Owns queue state, lane state, and merge decisions.
2. **Cloud break-fix worker**
   - Receives eligible incidents and submits repair PRs.
3. **Policy skill**
   - Encodes state transitions, eligibility, retry budgets, and escalation.

## State model

- Lane states: `healthy`, `degraded`, `paused`, `recovering`.
- Global states: `normal`, `incident-contained`, `global-hold`.

See:

- `skills/build-master-control-plane/references/state-machine.md`
- `skills/build-master-control-plane/references/policy-matrix.md`

## Inputs/Outputs

### Inputs

- Repo and protected target branch.
- Lane mapping policy.
- Risk-tier policy (Tier 1/2/3).
- Break-fix eligibility matrix.
- Retry and auto-revert thresholds.

### Outputs

- Per-lane state report.
- Incident log with fix PR linkage.
- Explicit merge decision (`continue`, `pause-lane`, `global-hold`) with rationale.

## Guardrails

- Merge serialized per lane.
- PR-only fixes and rollbacks.
- Never bypass branch protection or required checks.
- No autonomous high-risk fixes (security/auth/infra-sensitive surfaces).
- Threshold-based escalation to blocking issues and human owner review.

## Operational runbook

1. **Queue intake**
   - Classify PR into lane and risk tier.
2. **Pre-merge gate**
   - Verify approvals, required checks, and lane health.
3. **Merge execution**
   - Merge one PR per healthy lane in policy order.
4. **Incident detection**
   - Map failure to lane and classify failure type.
5. **Repair decision**
   - If eligible, dispatch cloud worker to open fix PR.
   - If ineligible, pause lane and open escalation issue.
6. **Recovery**
   - Resume lane only after fix verification passes on target branch.
7. **Escalation**
   - Trigger `global-hold` for cross-lane/high-risk incidents.

## Compatibility with existing guidance

This pattern is intentionally aligned with existing repository guidance:

- Fleet merge pacing (serialized merges, verified checks).
- Worktree and PR-first operations.
- Governance gates for risk-tiered change authority.

It does not replace `merge-coordinator` or `ci-failure-escalation`; it composes
with them as a higher-level control plane.
