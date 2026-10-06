---
issue: 3577
title: "perf(ci): coalesce metadata and completion-driven PR evaluation fan-out"
status: implemented
author: ibuyspy
created: 2026-10-06
labels: ["enhancement", "priority:medium"]
---

# Spec: coalesce PR evaluation notifications

## Problem Statement

Label/body changes and five required-workflow completions can request equivalent
work for one PR. Draft spec #3582 was reviewed and incorporated here; its previously
unspecified scope and acceptance criteria are refined below, not discarded.

## Scope and Design

Use native Actions concurrency as a notification mailbox, not an eligibility cache:
one running evaluation and one replaceable pending notification per PR. Wait ten
seconds before reading evidence to absorb short bursts. Completion routers still
verify current-head association and dispatch PR-number evaluations. Routing calls
are intentionally not deduplicated by SHA.

Each surviving evaluation reads current head/base, title/body, labels/holds,
reviews/permissions, acknowledgements, linked issue evidence and required checks.
No approval, hold or eligibility decision survives between runs. A second read of
required-check identities and states joins the existing final PR/review snapshot
guard; any mismatch withholds eligibility and dispatches a fresh evaluation.
The existing pre-merge guard and native current-head checks remain in force.

Pending notifications can be replaced regardless of payload ordering because
authorization uses live evidence, never the surviving event's metadata. Once a
finite burst ends, the surviving pending evaluation reads final current state.
If a mutation occurs during evaluation, the snapshot guard requests a successor.
This is a scheduling bound, not an equality cache or a guarantee against API
failures, Actions outages, or changes after the final read.

Separate PR Validation metadata and code concurrency lanes. Label events run only
the fresh release-label gate, not the six code/protection validation jobs; they
cannot cancel a code run. PRD/spec metadata bursts retain one running and one
pending run and fetch the current PR rather than authorizing an old event payload.
PR, merge-group and main CI validation remain deliberately separate. Solo-dev
approval/acknowledgement policy is unchanged. Queue admission issue #3604 is out
of scope; queueing remains an orchestrator responsibility.

## Alternatives and Prior Art

Existing completion routing and pending-check reads in `merge-latency-tests.cjs`
are retained. Existing executor metadata/review and pre-merge guards are extended.
PR size-labeler already uses per-PR dispatch concurrency. A local search found no
existing authorization-result cache or debounce utility to reuse.
Reject SHA-only deduplication, approval caching, blanket active cancellation and
removal of completion triggers: each can lose a final valid authorization update.

## Acceptance and Reproduction

Run `pwsh tests\pr-auto-merge-executor-tests.ps1`. Its burst fixture executes the
actual routing/check-read/final-guard JavaScript with mocked APIs, and models the
native concurrency contract. It covers labels, body edits, five completions and
head/base/metadata/hold/approval/check invalidation (including reruns and missing
checks). Separate static assertions bind scheduling to the workflow configuration.

Controlled baseline: eight notifications one second apart over seven seconds,
100ms policy service, no debounce; optimized service includes the ten-second wait.
All checks fit one page on one head. These are fixture measurements, not
production observations or whole-executor API totals:

| Fixture metric | Baseline | Coalesced |
| --- | ---: | ---: |
| Full eligibility evaluations started | 8 | 2 |
| Instrumented required-check API calls | 16 | 8 |
| Completion lookup / dispatch calls | 5 / 5 | 5 / 5 |
| Replaced pending executor notifications | 0 | 6 |
| Code-validation requests: opened + two labels | 3 | 1 |
| Active code cancellations for overlapping label events | 2 | 0 |

The coalesced check-call count includes two evidence reads per evaluation.
Six pending notifications are cancelled/replaced, not six running policy jobs.
The baseline's service time is deliberately controlled: longer real evaluations
already overlap and coalesce, so these counts are not inferred production savings.

## References

- PRD: [issue-3577 PRD](../../prd/synthesized/issue-3577-perfci-coalesce-metadata-and-completion-driven-pr-evaluation.prd.md)
- Source: #3577; incorporated draft: #3582
