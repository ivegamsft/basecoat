# Dashboard Metrics Schema and Glossary

Schema version: **2.0.0**

This document defines the published contract for dashboard output artifacts under
`dashboard/metrics/` on `gh-pages`.

## Canonical vocabulary and usage rules

Use these terms consistently across docs, issues, and dashboard summaries:

| Canonical term | Definition | Use this term instead of |
|---|---|---|
| **Dashboard monitored repository** | Repository explicitly listed in `DASHBOARD_REPOS` and scanned by `adoption-metrics.yml` | participant repo, enrolled repo, tracked repo |
| **Dashboard participating repository** | Dashboard monitored repository that appears in the current `latest.json` output | active repo, included repo, onboarded repo |
| **Telemetry artifact** | One generated output file in `dashboard/metrics/` (`latest.json`, `history.json`, `alerts.json`, `SUMMARY.md`) | metrics file, dashboard file |
| **Snapshot** | One collection run keyed by `collected_at` | weekly dump, sample |
| **Coverage** | Presence-based estimate of BaseCoat asset adoption from `basecoat_coverage` fields | adoption score, install score |
| **Pass rate** | CI reliability metric from measurable run conclusions only | CI health score, success score |

Usage rules:

1. Use **dashboard monitored repository** when discussing configuration (`DASHBOARD_REPOS`).
2. Use **dashboard participating repository** when discussing current output records.
3. Use **telemetry artifact** when referencing files under `dashboard/metrics/`.
4. Use **pass rate** with a window qualifier (`20-run` or `100-run`) when precision matters.

## Compatibility policy

- Additive changes (new fields) are backward-compatible.
- Renaming/removing fields or changing their allowed value types requires a
  major schema version bump.
- Existing compatibility aliases (for example `ci.success_rate` and
  `ci.pass_rate`) remain available through all `1.x` versions.
- Version 2 retains those aliases but makes unknown PR/CI measurements nullable.
  Consumers must check availability and null before numeric operations; a null
  is not a measured zero. Historical version-1 snapshots without nested
  availability fields remain readable, but failed collection must not be
  inferred as healthy from their zero-valued placeholders.

## Artifact schema

## `latest.json`

Top-level object:

- `collected_at` (string, ISO-8601 UTC timestamp)
- `organization` (string, GitHub org login)
- `copilot` (object)
- `repos` (object keyed by `owner/repo`)

`copilot` object:

- `available` (boolean)
- `report_start_day` (string, `YYYY-MM-DD`, optional when unavailable)
- `report_end_day` (string, `YYYY-MM-DD`, optional when unavailable)
- `total_active_users` (number, 28-day sum of daily active users)
- `daily_active_cli_users_sum` (number)
- `daily_active_cloud_agent_users_sum` (number)
- `days` (array of raw daily report rows; up to 28 rows)

Each `repos["owner/repo"]` object contains:

- `available` (boolean; false for inaccessible repositories or incomplete PR/CI samples)
- `error` (string, present when unavailable)
- `pull_requests`
  - `available` (boolean)
  - `error` (string, present when unavailable)
  - `prs_merged_28d` (number or null; merges within 28 days in the 50 most recently updated closed PRs, ordered descending)
  - `cycle_time_median_hours` (number or null)
  - `cycle_time_p95_hours` (number or null)
- `ci`
  - `available` (boolean)
  - `error` (string, present when unavailable)
  - `success_rate` (number or null, pass rate over last 100 measurable runs)
  - `pass_rate` (number or null, alias of `success_rate`)
  - `ci_pass_rate_last_20_runs` (number or null, pass rate over last 20 measurable runs)
  - `ci_pass_rate_last_100_runs` (number or null, pass rate over last 100 measurable runs)
  - `total_runs_sampled` (number or null, measurable runs in 100-run window)
  - `runs_sampled_last_20` (number or null, measurable runs in 20-run window)
  - `successful_runs_last_20` (number or null)
- `issues`
  - `issues_closed_28d` (number)
  - `resolution_time_median_hours` (number)
- `basecoat_coverage`
  - `agents` (number of entries found in `.github/agents`)
  - `instructions` (number of entries found in `.github/instructions`)
  - `skills` (number of entries found in `.github/skills`)
  - `prompts` (number of entries found in `.github/prompts`)
  - `percentage` (number)

PR/CI endpoint failures emit null measurements and a stable surface error:
`inaccessible_repo`, `pr_collection_failed`, or `ci_collection_failed`.
`no_measurable_runs` has null CI percentages but known zero sample counts.
An otherwise readable repository with either PR/CI surface unavailable has
`available: false` and `error: incomplete_pr_ci_metrics`; verified fields are
retained, but the sample is excluded from dashboard aggregates and both sides
of degradation comparisons. A successful zero-merge sample or all-failed
measurable CI sample remains available and numeric.

## `history.json`

- JSON array of `latest.json` snapshots.
- Append-only per run, capped to the most recent 52 snapshots.

## `alerts.json`

JSON array of alert objects. Common fields:

- `type` (string)
- `severity` (`warning` or `info`)
- `message` (string)
- `previous` (number)
- `current` (number)
- `repo` (string, present for repo-scoped alerts)

Known `type` values:

- `copilot_active_users_drop` (warning; >10% drop from prior snapshot)
- `ci_success_drop` (warning; >15 point drop from prior snapshot)
- `cycle_time_increase` (info; >50% increase from prior snapshot)

## `SUMMARY.md`

Human-readable weekly summary generated from `latest.json`. Includes:

- collection date
- Copilot availability and active users
- per-repo table with PR, CI, and coverage values

`SUMMARY.md` is for readability and should not be treated as the primary machine
contract.

## Metric rules and definitions

## CI pass-rate windows and denominator rules

- 100-run window fields: `success_rate`, `pass_rate`, `ci_pass_rate_last_100_runs`
- 20-run window field: `ci_pass_rate_last_20_runs`
- Denominator includes only measurable conclusions:
  `success`, `failure`, `timed_out`, `startup_failure`
- Excluded from denominator: `cancelled`, `skipped`, `neutral`, `action_required`,
  and other non-measurable conclusions
- Preferred workflow names for CI signal quality: `ci`, `pr validation`,
  `validate basecoat`, `validate base coat`

## `basecoat_coverage` calculation and limitations

Coverage percentage formula:

`(agents + instructions + skills + prompts) / 94 * 100`

Where denominator 94 is fixed to expected asset counts:

- agents: 43
- instructions: 27
- skills: 21
- prompts: 3

Limitations:

- Measures presence counts, not content quality or freshness.
- Counts entries in repository paths and can overstate adoption if placeholders are
  present.
- Fixed denominator may lag if canonical BaseCoat asset totals change.

## Interpretation examples

## Healthy example

- `ci_pass_rate_last_20_runs >= 90`
- `ci_pass_rate_last_100_runs >= 90`
- `basecoat_coverage.percentage >= 80`
- No `ci_success_drop` alert

## Degraded example

- `ci_pass_rate_last_20_runs < 75` or a sudden `ci_success_drop` alert
- `cycle_time_median_hours` up >50% vs previous snapshot
- `basecoat_coverage.percentage` materially below peer repos

## Glossary

- **Dashboard monitored repository**: Repository configured in `DASHBOARD_REPOS`
  for weekly dashboard scanning.
- **Dashboard participating repository**: Dashboard monitored repository present in
  the current `latest.json` output.
- **Artifact**: One output file produced by the weekly metrics collector.
- **Snapshot**: A single run's metric output at `collected_at`.
- **Measurable run**: A workflow run with conclusions included in CI denominator.
- **Pass rate (20-run)**: Short-window CI reliability signal for recent behavior.
- **Pass rate (100-run)**: Longer-window CI reliability baseline.
- **Coverage**: Presence-based estimate of BaseCoat asset adoption.
- **Degradation alert**: Regression signal derived by comparing latest vs previous
  snapshot.
