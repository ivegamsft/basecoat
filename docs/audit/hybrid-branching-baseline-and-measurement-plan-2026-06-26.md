# Hybrid branching baseline and measurement plan

**Date:** 2026-06-26
**Parent issue:** #2142
**Related strategy issues:** #2138, #2139, #2140, #2141

## Objective

Establish a repeatable measurement framework to validate whether the hybrid branching process improves delivery outcomes without increasing risk.

## Measurement hypotheses

1. Hybrid branching reduces queue wait and cycle-time variance for medium and high-risk changes.
2. Lane-aware admission improves CI signal quality by isolating failures and reducing unrelated blockage.
3. Profile-based consumer guidance increases downstream adoption without increasing operational incident rate.

## Baseline design

### Time windows

1. **Baseline window:** 4 weeks before first rollout change.
2. **Stabilization window:** first 2 weeks after rollout start (excluded from pass/fail judgment).
3. **Evaluation window:** weeks 3-6 after rollout start.

### Population

1. BaseCoat repository workflows and PR lifecycle.
2. Downstream consumer repos split by profile (`minimum`, `standard`, `strict`).

### Control and treatment

1. **Control:** repos or lanes not yet migrated to hybrid policy.
2. **Treatment:** repos or lanes migrated under approved hybrid policy contract.

## Metrics

| Domain | Metric | Definition | Target direction |
|---|---|---|---|
| Throughput | Merged PRs/day | Merged PR count divided by active days. | Increase |
| Flow efficiency | Queue wait p50/p95 | Time from checks green to merge finalization. | Decrease |
| Reliability | Workflow success rate | Successful runs / total runs for required workflows. | Increase |
| Stability | Repeat-failure signature rate | Consecutive recurring failures per workflow lane. | Decrease |
| Governance | Manual override count | Overrides of required checks or merge gating. | Decrease |
| Safety | Rollback/revert rate | Rollback or revert events per merged PR cohort. | Decrease |
| Adoption | Consumer profile completion | Repos completing profile migration checklist. | Increase |

## Data collection plan

1. Capture workflow-run samples by lane and branch class.
2. Capture PR lifecycle timestamps (open, checks green, approved, merged).
3. Capture incident and rollback events linked to merged PRs.
4. Capture consumer migration status with profile tags.
5. Persist weekly scorecards with date-stamped snapshots.

## Decision thresholds (stop/go)

### Go criteria

1. Queue wait p95 reduced by at least 20 percent in treatment lanes.
2. Required workflow success rate improved by at least 10 percentage points or remains above 90 percent for stable lanes.
3. Manual overrides reduced by at least 30 percent.
4. No increase in rollback rate beyond 5 percent relative to baseline.

### Stop and remediate criteria

1. Required workflow success drops below 80 percent for two consecutive weeks.
2. Rollback rate increases by at least 10 percent over baseline.
3. Manual overrides increase in any treatment lane for two consecutive weeks.
4. Consumer migration introduces blocking governance incidents in more than 20 percent of pilot repos.

## Dependency-aware rollout sequence

1. Finalize policy contract (#2139).
2. Finalize agent branch lifecycle contract (#2141).
3. Start one BaseCoat pilot lane and one downstream profile pilot (#2140).
4. Measure for one full evaluation window before expanding scope.

## Impact accounting

| Impact type | Expected effect | Validation method |
|---|---|---|
| Engineering productivity | Faster merge flow for low-risk work and fewer unrelated blocks. | Cycle-time trend and queue-age distribution. |
| Reliability | Better gate quality and less cross-lane failure propagation. | Required workflow success and repeat-failure signatures. |
| Governance | Improved audit trail for agent-generated changes. | PR metadata completeness and override trend. |
| Operations | Slight upfront complexity increase with lower recurring incident load. | Incident volume and monthly triage effort trend. |

## Downstream replication checklist

1. Choose consumer profile (`minimum`, `standard`, or `strict`).
2. Record 4-week local baseline before policy switch.
3. Apply branch-policy and metadata contract changes for pilot scope only.
4. Run weekly scorecards for at least 6 weeks.
5. Expand only when go criteria are met.
