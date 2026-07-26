# Keep/Fix/Throttle Weekly Scorecard Spec

## Context

Workstream 5 of epic #1452 requires a weekly scorecard/readout that tracks
throughput, failure rate, MTTR, and manual intervention metrics with trend
classification and linked remediation actions.

Related issue: [#2050](https://github.com/ivegamsft/basecoat/issues/2050)

## Functional Requirements

1. Generate a weekly scorecard artifact in JSON and Markdown formats.
2. Include the following metrics per run:
   - `throughput`
   - `failure_rate`
   - `mttr_hours`
   - `manual_intervention_rate`
3. Classify each metric trend as:
   - `improving`
   - `stable`
   - `regressing`
   - `insufficient-data` (when no baseline window exists)
4. Emit a repository-level `overall_trend`.
5. Attach remediation links for regressing metrics.
6. Support deterministic fixture-driven execution for tests.
7. Support live GitHub data collection for scheduled production runs.

## Metric Semantics

| Metric | Source | Desired direction | Trend threshold |
|---|---|---|---|
| Throughput | Merged PR count in lookback window | Higher is better | 1 PR/week |
| Failure rate | Failed/timed out/cancelled workflow runs | Lower is better | 0.02 |
| MTTR hours | Average PR lead time (created -> merged) | Lower is better | 4 hours |
| Manual intervention rate | Share of merged PRs with APPROVED review | Lower is better | 0.05 |

## Trend Classification

For each metric, compare current value to average of prior samples in the trend
window.

- If the delta exceeds the metric threshold in the favorable direction:
  `improving`
- If the delta exceeds threshold in the unfavorable direction: `regressing`
- Otherwise: `stable`

## Operational Contract

1. Weekly workflow must run on a schedule and via manual dispatch.
2. Workflow must upload scorecard artifacts for traceability.
3. Workflow must post weekly readout comments to #2050 by default.

## Non-Goals

1. Persisting long-term metric history in-repo.
2. Replacing incident response or SRE workflows.
3. Enforcing merge gates directly from scorecard status.
