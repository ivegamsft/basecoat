# Dashboard Metrics Schema and Glossary

Schema version: **1.0.0**

This document defines the published contract for dashboard output artifacts under
`dashboard/metrics/` on `gh-pages`.

## Compatibility policy

- Additive changes (new fields) are backward-compatible.
- Renaming or removing existing fields requires a major schema version bump.
- Existing compatibility aliases (for example `ci.success_rate` and
  `ci.pass_rate`) remain available through all `1.x` versions.

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

- `pull_requests`
  - `prs_merged_28d` (number)
  - `cycle_time_median_hours` (number)
  - `cycle_time_p95_hours` (number)
- `ci`
  - `success_rate` (number, pass rate over last 100 measurable runs)
  - `pass_rate` (number, alias of `success_rate`)
  - `ci_pass_rate_last_20_runs` (number, pass rate over last 20 measurable runs)
  - `ci_pass_rate_last_100_runs` (number, pass rate over last 100 measurable runs)
  - `total_runs_sampled` (number, measurable runs in 100-run window)
  - `runs_sampled_last_20` (number, measurable runs in 20-run window)
  - `successful_runs_last_20` (number)
- `issues`
  - `issues_closed_28d` (number)
  - `resolution_time_median_hours` (number)
- `basecoat_coverage`
  - `agents` (number of entries found in `.github/agents`)
  - `instructions` (number of entries found in `.github/instructions`)
  - `skills` (number of entries found in `.github/skills`)
  - `prompts` (number of entries found in `.github/prompts`)
  - `percentage` (number)

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

- **Artifact**: One output file produced by the weekly metrics collector.
- **Snapshot**: A single run's metric output at `collected_at`.
- **Measurable run**: A workflow run with conclusions included in CI denominator.
- **Pass rate (20-run)**: Short-window CI reliability signal for recent behavior.
- **Pass rate (100-run)**: Longer-window CI reliability baseline.
- **Coverage**: Presence-based estimate of BaseCoat asset adoption.
- **Degradation alert**: Regression signal derived by comparing latest vs previous
  snapshot.
