---
issue: 3579
title: "perf(actions): filter irrelevant housekeeping triggers before allocating runners"
status: implemented
author: ibuyspy
created: 2026-10-06
labels: ["enhancement", "priority:medium"]
---

# Spec: perf(actions): filter irrelevant housekeeping triggers before allocating runners

## Problem Statement

Several housekeeping workflows receive events that cannot produce useful work.
When the only rejection happens inside a step, a runner has already been
allocated. Workflow run records marked skipped are not themselves evidence of
runner use, so measurements must distinguish runs, allocated jobs, and job
minutes.

## Audit Evidence

Issue #3579 records a read-only window from 2026-10-04T14:41:06Z through
2026-10-06T14:41:06Z: 5,761 unique workflow runs and a 98-run job-timing sample.
Build Guard had 335 `workflow_run` executions: 270 successful, 57 cancelled, and
8 failed. The existing resolver job runs for each completion, while recovery
continues only for failures. The new job predicate therefore avoids resolver
allocation for 327 of these observed completions; it does not claim 327 fewer
workflow run records or any production job-minute savings.

The reproducible fixture at
`tests/fixtures/issue-3579-routing-minutes.json` uses explicit deterministic
test durations. Its 4-event calculation is 6 jobs / 17 fixture minutes before
filtering and 4 jobs / 14 fixture minutes after filtering. These are test
arithmetic only, not production telemetry or forecast savings.

## Scope and Design

1. **Build Guard resolver:** Add a job-level predicate that allocates the
   resolver for manual dispatch and failed upstream `workflow_run` completions
   only. Success and cancellation are intentionally not remediation triggers.
   Keep failure handling in the resolver and detector so failure runs with
   absent/empty logs still reach the existing unknown-classification escalation
   path; GH/API errors continue to fail visibly.
2. **Token Context Inventory:** Preserve its existing `push.paths` filter for
   `agents/**`, `skills/**`, and `instructions/**`, the complete input set read
   by its generator. Preserve its weekly schedule, manual dispatch, closed-PR
   cleanup, permissions, concurrency, and publication behavior.
3. **Other named surfaces:** Do not change dependency-graph publication or model
   capability refresh, which use legitimate schedule/manual runs and have
   branch-scoped cleanup jobs. Do not change Process Memory Contribution, whose
   issue-label job condition already prevents runner allocation for unrelated
   labels. Test these current pre-runner filters rather than adding redundant
   workflow changes.
4. Keep root and `.github/base-coat/workflows/` Build Guard copies consistent.
   Do not alter permissions, trust boundaries, runner types, or review gates.

## Recovery and Compatibility

Build Guard retains manual targeting, named producer events, same-repository
authentication, cross-repository credential checks, retry limits, and
failure-only log/recovery behavior. A cancelled producer is not automatically
retried.

The cloud-agent approval recovery remains producer-driven for same-repository
`workflow_run` completions, while the schedule and manual dispatch remain as
backstops. Recovery continues to require an open same-repository PR and matching
current head SHA, and still fails explicitly on API errors or insufficient
permissions. A delayed hold that registers after its producer completes must be
discoverable on a later trusted producer sweep.

## Acceptance Criteria

- [x] Build Guard filters successful and cancelled workflow completions before
  the resolver job allocates a runner.
- [x] Manual dispatch and failed producer completions still allocate the
  resolver and allow existing recovery behavior.
- [x] Missing/empty failure logs are tested and remain explicit unknown
  escalations; cancellation is tested as no-action.
- [x] Existing token-inventory push path filters match all and only generator
  input directories; schedule, manual, and cleanup routes are preserved.
- [x] Dependency graph, model refresh, and memory contribution predicates
  retain their legitimate schedule/manual/label routes without allocating
  jobs for irrelevant event types.
- [x] Delayed same-repository/current-head approval holds remain recoverable
  through producer-driven sweeps; schedule/manual recovery remains available.
- [x] Tests execute the predicates extracted from workflow definitions and
  report reproducible fixture job/minute counts separately from observed
  production counts.
- [x] Distributed workflow copies remain synchronized; no permission or
  approval-boundary changes are introduced.

## References

- PRD: `docs/prd/synthesized/issue-3579-perfactions-filter-irrelevant-housekeeping-triggers-before-a.prd.md`
- Issue: https://github.com/IBuySpy-Shared/basecoat/issues/3579
- Draft spec source: https://github.com/IBuySpy-Shared/basecoat/pull/3588
