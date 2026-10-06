---
issue: 3580
title: "feat(ci): measure delivery stages and distinguish reruns from duplicate work"
status: reviewed
author: ibuyspy
created: 2026-10-06
labels: ["enhancement", "priority:medium", "needs-triage", "needs-prd", "needs-info", "synthesize-spec"]
---

# PRD: feat(ci): measure delivery stages and distinguish reruns from duplicate work

## Problem Statement

Current delivery reporting conflates execution, runner acquisition, approval
holds, queue wait, cancellations, and rerun attempts. The source audit covered
2026-10-04T14:41:06Z through 2026-10-06T14:41:06Z: 5,761 unique workflow runs,
but only 98 sampled job timings and no historical attempt expansion.
Those numbers cannot establish either build duration or duplicate work.

## Why This Matters

Operators need to distinguish slow tests from event fan-out and missing
authorization or runner capacity. Optimization must preserve separate PR,
merge-group, and main validation rather than declaring equivalent SHAs redundant.

## Scope

Extend existing GitHub-based reporting, starting with
`scripts/report-runner-health.ps1` and `scripts/metrics/collect-metrics.py`;
do not introduce an external telemetry service. Produce a read-only,
reproducible JSON report and Markdown summary for two equal UTC windows.
Include run inventory, every available attempt, job timing, delivery stages,
sample coverage, and actionable failures.

Do not mutate approvals, queue entries, rulesets, tags, or releases. A spec
merge defines the contract; it does not complete #3580 or authorize production.
Automatic tag ownership and event coalescing belong to separate workstreams.

## Success Criteria

- [ ] Equal-window reports state boundaries, collection time, pagination
      completeness, unique runs, attempts, events, cancellations, and targets.
- [ ] Execution and each observable wait are separate, with sample counts and
      explicit unknowns for missing timestamps or jobs that never acquired a runner.
- [ ] PR head, merge-group, and main validations are distinct contexts; repeated
      SHA alone is never classified as duplicate work.
- [ ] Deterministic fixtures reproduce p50/p95 values and expose truncated
      inventory, reruns, failed acquisition, and unobserved stages.
- [ ] Fan-out/cancellation changes and current delivery failures link to evidence;
      incomplete data cannot produce an unqualified healthy result.

## References

- Refs #3580
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3580>
