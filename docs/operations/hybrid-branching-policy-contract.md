# Hybrid Branching Policy Contract

## Summary

This document captures the selected hybrid branching model for BaseCoat and
defines the implementation contract for:

1. Branch policy classes and allowed transitions.
2. Agent branch lifecycle and PR metadata requirements.
3. Scorecard metrics, rollout thresholds, and weekly governance cadence.

The model optimizes for trunk flow speed while preserving controlled release and
hotfix operations.

## Debate outcome (selected model)

### Options considered

1. Trunk-only with no release branches.
2. GitFlow-heavy with long-lived integration branches.
3. Hybrid model: trunk + release/hotfix + bounded feature/agent lanes.

### Selected

Option 3 (hybrid) is selected.

Reasoning:

- Preserves high-frequency merge flow into `main`.
- Keeps explicit release and emergency hotfix controls.
- Allows parallel AI/agent work in bounded lanes with deterministic escalation.

## Branch classes and policy table

| Class | Pattern | Purpose | Required checks | Approval policy | Primary merge target |
|---|---|---|---|---|---|
| Trunk | `main` | Canonical integration branch | Required repo checks, guardrails, PR validation | Required by branch protection | N/A (target branch) |
| Release | `release/*` | Stabilization and release prep | Release validation, deployment policy checks | Manual release owner approval | `main` -> `release/*`; hotfix back-merge |
| Hotfix | `hotfix/*` | Urgent production repair | Required checks for risk tier + deployment policy gates | Tier 3/4 explicit approval path | `hotfix/*` -> `main` and active `release/*` |
| Agent lane | `agent/*` | Cloud/local agent isolated execution lanes | Lane checks + scoped validations | Policy-based by risk tier | `agent/*` -> `main` or `feature/*` |
| Feature integration | `feature/*` | Dependency-ordered stacked PR integration | Fast lane checks (affected/test lane) | Auto-merge when green | `feature/*` -> `main` on feature completion |
| Maintenance | `maintenance/*` | Repo hygiene and non-feature upkeep | Standard required checks | Maintainer approval | `maintenance/*` -> `main` |

## Transition matrix

| From | Allowed to | Rule |
|---|---|---|
| `agent/*` | `feature/*`, `main` | Use `feature/*` for multi-PR feature stacks; direct to `main` for single-scope changes |
| `feature/*` | `main` | Single finalization PR per feature after stack completion |
| `main` | `release/*` | Release cut at planned cadence or approved release event |
| `hotfix/*` | `main`, active `release/*` | Merge hotfix back to avoid drift |
| `maintenance/*` | `main` | Small, independent PRs only |

Disallowed by policy:

- `agent/*` -> `release/*`
- `feature/*` -> `release/*`
- `release/*` -> `agent/*`

## Agent branch lifecycle contract

### Naming and metadata

- Branch naming: `agent/<skill>/<intent>-<id>`
- PR body required metadata:
  - `Agent:` name/identity
  - `Model:` model id or execution mode
  - `Risk tier:` 1-4 classification
  - `Rollback:` explicit rollback plan
  - `Evidence:` checks/tests run and scope

### Sync and rebase behavior

1. Agent lanes rebase from `main` before PR open.
2. Feature integration branches rebase daily from `main`.
3. Branch freshness fails when behind threshold is exceeded.
4. Conflict resolution escalation triggers after repeated lane failures.

### Escalation thresholds

- 2 consecutive lane CI failures on same signature: open remediation issue.
- 3 consecutive failures or >24h unresolved blocker: pause lane and escalate.
- Cross-lane repeated failure signatures: raise global coordination issue.

### Rollback and emergency override

- Standard rollback path is PR-based revert on target branch.
- Emergency override requires explicit owner approval and incident tracking.
- Every override must record rationale, blast radius, and follow-up actions.

## Scorecard and rollout guardrails

### Metrics

| Dimension | Metrics |
|---|---|
| Throughput | Merged PRs/day, queue wait p50/p95 |
| Reliability | PR validation success rate, release workflow success rate |
| Stability | Rollback count, repeated failure signatures |
| Governance | Manual override count, stale branch age distribution |
| Adoption | Consumer profile uptake, migration completion rate |

### Baseline and phase gates

1. Capture baseline for 2 weeks prior to rollout.
2. Run phased rollout with stop/go checkpoints:
   - **Go:** throughput flat-or-up and reliability not degraded.
   - **Hold:** reliability degradation >5% or rollback spike above baseline.
   - **Stop:** repeated Tier 3/4 incidents tied to branching policy changes.

### Weekly cadence and ownership

- Weekly governance review in Sprint execution thread.
- Owners:
  - Release engineering: reliability/stability gates.
  - Workflow maintainers: governance and automation compliance.
  - Sprint coordinator: throughput/adoption trend review.

## Mapping to current repository workflows

This contract is designed to align with existing workflow guardrails and merge
discipline already present in BaseCoat:

- Serialized merge pacing and required checks on protected branches.
- PR-first operations and risk-tier governance model.
- Existing issue-approval and remediation escalation patterns.

Gap tracking should be maintained as implementation tasks linked from this
document, rather than changing policy semantics ad hoc.
