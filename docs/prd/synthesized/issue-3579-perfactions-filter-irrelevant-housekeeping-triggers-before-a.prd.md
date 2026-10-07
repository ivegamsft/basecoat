---
issue: 3579
title: "perf(actions): filter irrelevant housekeeping triggers before allocating runners"
status: implemented
author: ibuyspy
created: 2026-10-06
labels: ["enhancement", "priority:medium"]
---

# PRD: perf(actions): filter irrelevant housekeeping triggers before allocating runners

## Problem Statement

Housekeeping triggers can start jobs that cannot perform useful work. A job-level
or event path filter can avoid runner allocation without removing useful
schedule, manual, cleanup, or failure-recovery behavior.

## User Impact

On the observed two-day audit window in #3579, Build Guard had 335
`workflow_run` executions, including 270 successes and 57 cancellations that
could not trigger recovery. Filtering these out at the job boundary leaves
failed runs eligible for diagnosis and preserves manual invocations.
Token-inventory already filters pushes to the generator's source directories.
The implementation keeps that existing filter and avoids adding redundant
trigger logic.

Skipped workflow records are not counted as allocated jobs. The audit data
supports a 327-job reduction opportunity for the Build Guard resolver in the
observed sample (335 existing resolver allocations minus 8 failed completions).
No production job-minute savings are claimed because per-job timing data is
not available for those 335 executions.

## Scope

- Filter Build Guard's resolver job before runner allocation for success and
  cancellation completions; preserve failure recovery and manual dispatch.
- Preserve token-inventory's existing `push.paths` filter for `agents/**`,
  `skills/**`, and `instructions/**`, matching generator inputs.
- Leave dependency-graph, model-refresh, and memory-contribution trigger
  semantics unchanged because their existing trigger/job conditions already
  preserve intended runs and avoid irrelevant job allocation; test these
  conditions directly.
- Preserve workflow permissions, producer-based approval recovery, same-repo
  and current-head approval trust checks, and explicit failure reporting.

## Success Criteria

- [x] Extracted workflow predicates prove success/cancellation are filtered,
  while failures and manual dispatch remain eligible.
- [x] Failure with empty logs escalates as unknown; cancellation remains
  no-action.
- [x] Existing token-inventory paths match generator inputs, without removing
  schedule, manual, or closed-PR cleanup events.
- [x] Dependency-graph, model-refresh, and memory-contribution job predicates
  preserve legitimate routes and avoid irrelevant runner allocation.
- [x] Delayed same-repository/current-head approval holds remain recoverable
  after trusted producer completion.
- [x] A deterministic fixture calculates before/after allocated jobs and
  minutes; fixture minutes are explicitly not production savings.
- [x] Root and distributed workflow copies are consistent.

## References

- Spec: `docs/spec/synthesized/issue-3579-perfactions-filter-irrelevant-housekeeping-triggers-before-a.spec.md`
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3579>
