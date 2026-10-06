---
issue: 3580
title: "feat(ci): measure delivery stages and distinguish reruns from duplicate work"
status: reviewed
author: ibuyspy
created: 2026-10-06
labels: ["enhancement", "priority:medium", "needs-triage", "needs-prd", "needs-info", "synthesize-spec"]
---

# Spec: feat(ci): measure delivery stages and distinguish reruns from duplicate work

## Problem Statement

Implement the linked PRD's read-only delivery measurement contract. The original
audit's latest-attempt run counts and sampled job timings are a baseline with
limitations, not proof of duplicate execution or runner availability.

## Design and Data Contract

Reuse GitHub collection/reporting patterns in `scripts/report-runner-health.ps1`
and `scripts/metrics/collect-metrics.py`. Accept repository, two equal,
nonoverlapping UTC windows `[start, end)`, output path, and optional captured
fixtures. Use existing authentication without logging credentials.

JSON includes schema version, repository, window boundaries, collection time,
completeness/limitations, counts, stage summaries, evidence links, and alerts.
Rows identify workflow ID/path, run ID, attempt number, event, PR number when
known, head SHA, tree SHA when available, job ID, status, conclusion, and timing
sources. Missing identifiers and timestamps are null with an explanation, not
zero durations.

Partition Actions queries if the API listing limit prevents full retrieval.
Deduplicate inventory by run ID; expand attempts by `(run_id, run_attempt)`.
Enumerate jobs for each available attempt. Surface pagination truncation,
permission errors, retention gaps, and rate limits as incomplete evidence.

Classify validation contexts as PR, merge-group, or main, retaining immutable
target and workflow identity. Same-target repeats are candidates only: call them
equivalent work only when workflow, event/context, attempt, target tree, and
relevant evidence agree. A rerun is an attempt, not a second unique run.

## Stage Measurements

Measure checks, eligibility, enqueue, merge, packaging, and release only when
their evidence can be joined to the same delivery target. Record eligibility
from the status timestamp, merge from PR metadata, and packaging/release from
immutable target references. Do not substitute the current branch tip.

Job execution is `completed_at - started_at` when both are available.
Executed-step spans may additionally describe active work, but are not total
CPU time. Never use workflow `updated_at - created_at` as execution duration.
Runner acquisition is measured only from an observed queued/requested timestamp
to job start. An approval hold is a separate observed interval; do not count it
again as acquisition. Never infer either interval by subtracting unrelated
workflow/job timestamps. Jobs without a start remain visible as unacquired or
unknown. Queue wait requires observed enqueue and merge timestamps.

For each stage report unit, valid sample count, excluded/unknown count, p50/p95,
and source. Use nearest-rank percentiles on sorted nonnegative durations:
`sorted[ceil(p * n) - 1]`; empty samples yield null. Flag negative intervals as
invalid evidence. State sampling method and coverage; no invented confidence
intervals for an incomplete convenience sample.

## Failure, Alerts, and Trust

Report API failures explicitly and mark the report incomplete; partial output
must not imply healthy delivery. Compare fan-out and cancellation rates across
equal windows with denominators and configurable documented thresholds.
Never compute a relative increase from a zero baseline; report the absolute
change instead. Identify current main/package/release failures with run links,
separately from historical window statistics. Alerting never changes delivery
authorization, and dry-run gate success is not production promotion.

## Implementation and Testing

Separate fixture transformation from API collection in the existing reporting
surface. Add deterministic tests for two equal windows, pagination/truncation,
attempt expansion, event contexts, ref movement, timestamp omissions,
negative/overlapping intervals, unacquired jobs, empty samples, zero baselines,
and known nearest-rank p50/p95 values. Validate JSON and Markdown outputs from
the same normalized data. Exercise permission/rate-limit failures without
silently substituting zero counts.

## Rollout and Observability

Run on captured fixtures first, then perform a read-only live comparison.
Attach exact commands, collection boundaries, coverage, and output evidence
to the implementation PR. Keep existing reports until compatibility is proven.
Rollback removes the added collector/report path without touching delivery.
Risks include API retention, capped inventories, missing enqueue history, and
ambiguous joins; retain explicit unknowns rather than guessing.

## Acceptance Criteria

- [ ] Report follows the data contract and reproduces equal-window comparisons.
- [ ] Fixtures verify stage separation, attempt identity, context distinction,
      inventory completeness, percentile values, and failure reporting.
- [ ] Live output states sample limits and links actionable delivery failures.
- [ ] Implementation PR links this spec and records exact commands and outcomes.
- [ ] #3580 stays open until implementation and read-only live verification pass.

## References

- PRD: `docs/prd/synthesized/issue-3580-featci-measure-delivery-stages-and-distinguish-reruns-from-d.prd.md`
- Refs #3580
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3580>
