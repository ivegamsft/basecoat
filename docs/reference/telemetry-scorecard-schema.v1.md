# Telemetry Scorecard Schema v1

Schema version: **1.0.0**

Tracking: #1834

This document defines the BaseCoat onboarding telemetry scorecard — a reusable per-repo
output artifact emitted during the weekly `adoption-metrics` run. It tracks four
goal-based loop metrics that indicate whether a repo's Copilot-assisted workflows are
producing measurable outcomes.

The machine-readable contract lives at
`docs/reference/telemetry-scorecard-schema.v1.schema.json`.

## Purpose

The scorecard bridges the gap between raw adoption metrics (`latest.json`) and loop
effectiveness. Where `latest.json` measures presence and CI health, the scorecard
answers: **are the loops closing?**

## Goal-based loop metrics

| Metric | Signal | Window | Healthy threshold | Warning threshold |
|---|---|---|---|---|
| `reviewer_closure` | PRs reviewed before merge / total PRs merged | 28 days | >= 0.90 | >= 0.70 |
| `intake_completeness` | Issues with complete template fields / total issues opened | 28 days | >= 0.80 | >= 0.60 |
| `merge_health` | CI pass rate over last 20 measurable runs | 20-run | >= 0.90 | >= 0.75 |
| `drift_trend` | Change in `basecoat_coverage.percentage` vs prior snapshot | 1 snapshot | >= 0 (no drift) | >= -5 |

### Metric definitions

#### `reviewer_closure`

Measures whether code review is happening before merge. A high value means PRs are
reviewed; a low value indicates merges bypassing review gates or reviewer engagement
is low.

**Data source:** GitHub Pull Requests API — filter for merged PRs in the 28-day window,
check `requested_reviewers`, `review_comments`, and `reviews` for at least one completed
review before the merge timestamp.

#### `intake_completeness`

Measures whether issues contain enough information for actionable triage. Completeness
is determined by the presence of a non-empty body and at least one label assigned within
24 hours of opening.

**Data source:** GitHub Issues API — filter for issues opened in the 28-day window,
check `body` length (> 20 characters) and whether at least one label is present.

#### `merge_health`

CI reliability over the most recent 20 measurable workflow runs. This mirrors the
`ci_pass_rate_last_20_runs` field from `latest.json` and is included in the scorecard
to give a single-artifact view of loop health.

**Data source:** `latest.json` field `ci.ci_pass_rate_last_20_runs`.

#### `drift_trend`

Detects regression in BaseCoat asset coverage. A zero or positive value means coverage
is stable or improving. Negative values indicate assets have been removed or the repo
has diverged from the expected coverage baseline.

**Data source:** `history.json` — compare `basecoat_coverage.percentage` between the
current and prior snapshot. Value is a signed percentage-point delta.

## Profile-aware thresholds

Thresholds tighten with profile posture:

| Metric | `solo-dev` warn | `solo-dev` critical | `team-dev` warn | `team-dev` critical | `regulated-team` warn | `regulated-team` critical |
|---|---|---|---|---|---|---|
| `reviewer_closure` | 0.50 | 0.30 | 0.70 | 0.50 | 0.90 | 0.70 |
| `intake_completeness` | 0.40 | 0.20 | 0.60 | 0.40 | 0.80 | 0.60 |
| `merge_health` | 0.70 | 0.50 | 0.75 | 0.60 | 0.90 | 0.75 |
| `drift_trend` | -10 | -20 | -5 | -10 | 0 | -5 |

## App Insights integration

When `APPLICATIONINSIGHTS_CONNECTION_STRING` is configured, the adoption-metrics
workflow emits one custom event per repo per run:

- **Event name:** `BaseCoatScorecardSnapshot`
- **Custom dimensions:** `repo`, `profile`, `telemetry_mode`, `collected_at`
- **Custom measurements:** all four metric `value` fields and `app_insights_connected`

This enables cross-repo trend analysis and anomaly detection in Azure Monitor.

## Readiness block

Each scorecard includes a `readiness` block that surfaces missing dependencies:

```json
{
  "readiness": {
    "overall": "partial",
    "missing_dependencies": [
      "APPLICATIONINSIGHTS_CONNECTION_STRING not set — App Insights emission disabled",
      "COPILOT_METRICS_TOKEN not set — reviewer_closure metric unavailable"
    ],
    "warnings": [
      "drift_trend data unavailable: fewer than 2 snapshots in history.json"
    ]
  }
}
```

`overall` values:

- `ready` — all required dependencies present, all four metrics have non-null values
- `partial` — at least one metric has data but at least one dependency is missing
- `not-ready` — no metric data available; telemetry setup is incomplete

## Scorecard artifact location

Scorecards are emitted as `dashboard/metrics/scorecard-<repo-slug>.json` on `gh-pages`
alongside the existing telemetry artifacts (`latest.json`, `history.json`, etc.).

## Related files

- `docs/reference/telemetry-scorecard-schema.v1.schema.json`
- `docs/operations/onboarding-telemetry-readiness.md`
- `docs/reference/metrics-schema-glossary.md`
- `.github/workflows/adoption-metrics.yml`
