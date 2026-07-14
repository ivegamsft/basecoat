# Rollup Metrics and Publisher Contract (Sprint 41)

Execution contract for issue #2491. Defines the required inputs, calculations, publication
format, evidence link, and refresh cadence for the delivery-flow portfolio rollup.
Implemented by `scripts/aidl-portfolio-rollup-kpi-publisher.ps1`; grounded in
[`audit-framework.md`](../audit-framework.md).

## 1. Required inputs

| Input | Source |
|---|---|
| Repositories | One or more `owner/repo` targets (workflow input or `AIDL_PORTFOLIO_ROLLUP_REPOS`). |
| Lookback window | Trailing days used for lagging indicators (default 14). |
| Live project data | Open/closed issues and PRs, labels, timestamps, and incidents, retrieved via `gh api`. |
| Precomputed snapshot | Optional `-SnapshotPath` to a JSON file of per-repository metric snapshots (already containing `leading_indicators`/`lagging_indicators`) for deterministic runs, bypassing live retrieval. |
| Publish target | Optional. Issue repo + a positive issue number to receive the KPI report comment. When `PublishIssueNumber` is `0` (the default) the run is artifact-only (no comment); the repo/positive-number pair is required only when comment publication is requested. |

## 2. Calculations

Metrics are separated into leading (current-state) and lagging (trailing-window) indicators.
The window is `[now - LookbackDays, now]` in UTC; an item is in-window when its relevant
timestamp falls inside it.

- **Leading indicators** (current snapshot, not windowed):
  - `blocked_open_issues` - open issues labelled `blocked`, `status:block`, `status:blocked`, or `needs-unblock`.
  - `open_review_queue` - open, non-draft PRs.
  - `open_risk_high_issues` - open issues labelled `risk:high`, `risk-high`, `priority:high`, or `priority:critical`.
  - `open_incidents` - open issues labelled `incident` or `type:incident`.
- **Lagging indicators** (trailing `LookbackDays` window):
  - `throughput_items_closed_or_merged` = count(issues with `closed_at` in-window) + count(PRs with `merged_at` in-window).
  - `merged_prs` = count(PRs with `merged_at` in-window).
  - `closed_issues` = count(issues with `closed_at` in-window).
  - `closed_incidents` = count(incident issues closed in-window).
  - `incident_median_resolution_hours` = median over closed incidents of `(closed_at - created_at)` in hours (rounded to 2 dp).
  - `average_pr_lead_time_hours` = mean over merged PRs of `(merged_at - created_at)` in hours (rounded to 2 dp).

Label taxonomy (blocked, risk:high, incident, sprint, roadmap) drives classification; a
missing/empty label set is treated as no match (not an error).

The **portfolio aggregate** across repositories sums the count metrics (blocked, review
queue, incidents, throughput, merged PRs, closed issues/incidents) and computes each duration
metric (`incident_median_resolution_hours`, `average_pr_lead_time_hours`) as the unweighted
mean of the non-zero per-repository values. These duration fields are therefore
repository-level means, not true portfolio-wide statistics: `incident_median_resolution_hours`
is the mean of per-repository medians (not the median across all incidents), and
`average_pr_lead_time_hours` is an unweighted mean of per-repository averages (not weighted by
`merged_prs`). A known limitation is that a value of `0` is used as both a genuine rounded
duration and a "no samples" sentinel, so excluding zero-valued repositories drops legitimate
fast resolutions/merges and biases the aggregate; the target representation distinguishes
missing data (`null` plus an explicit sample count) from a real `0` before averaging. Consumers
must read the current fields as such; producing volume-weighted or raw-distribution
aggregates (or renaming the fields to reflect the repository-level mean) is a documented
publisher enhancement. It also emits a `roadmap_vs_sprint` summary with
`roadmap_open_items` (open issues labelled `roadmap`/`status:roadmap`/`plan:roadmap`),
`sprint_open_items` (open issues labelled `sprint:<n>`), `sprint_closed_items` (sprint-labelled
issues whose `closed_at` falls within `LookbackDays`), and `sprint_completion_pct`
(`round(sprint_closed_items * 100 / (sprint_open_items + sprint_closed_items), 1)`, emitting
`0.0` when there are no sprint items), plus `data_quality_caveats`.

A precomputed `-SnapshotPath` fixture must supply, per repository, a `repository` discriminator
(the `owner/repo` string the loader matches each requested target against) plus the full set of
objects the publisher aggregates and renders: `leading_indicators`, `lagging_indicators`, a
nested `roadmap_vs_sprint` object with the four named fields `roadmap_open_items`,
`sprint_open_items`, `sprint_closed_items`, and `sprint_completion_pct` (the publisher
dereferences these directly, so loose top-level counts fail under StrictMode),
`data_quality_caveats`, and
`drill_down_links` (a nested object whose six named groups the renderer reads directly:
`blocked`, `risk_high`, `incidents_open`, `review_queue`, `merged_prs`, and
`recently_closed_issues`, each an array of link entries). The publisher runs under `Set-StrictMode -Version Latest` and dereferences
these objects directly, so a snapshot that omits any of them fails fast with an error (rather
than silently emitting zeros or empty drill-downs); deterministic fixtures must include every
required object to reproduce the full report.

## 3. Publication format

Artifacts written under the rollup output directory (metric values are reproducible from a
committed snapshot; the artifacts themselves are not byte-deterministic because each embeds a
fresh `generated_at_utc`, per section 4):

- `portfolio-kpi-rollup.json` - machine-readable: `generated_at_utc`, per-repository
  `leading_indicators`/`lagging_indicators`, and a `portfolio` aggregate.
- `portfolio-kpi-rollup.md` and `portfolio-dashboard.md` - human-readable dashboard
  (leading vs lagging tables).
- A control-plane **issue comment** published to the configured issue. `publish_state`
  reflects the outcome: `skipped` when `PublishIssueNumber` is `0` (artifact-only mode, an
  accepted input), `dry-run-skipped` when a positive `PublishIssueNumber` is combined with
  `-DryRun`, and otherwise the result of the publish attempt. Callers must not expect a
  published comment merely because a run is not a dry run.
- A **delivery-flow scorecard** derived from the rollup by
  `scripts/aidl-portfolio-rollup-scorecard.ps1`: `portfolio-rollup-scorecard.json` (and a
  markdown companion) grading the portfolio aggregate's delivery-flow indicators
  (`sprint_completion_pct`, `blocked_open_issues`, `open_incidents`, `open_risk_high_issues`,
  `incident_median_resolution_hours`, `average_pr_lead_time_hours`) against configurable
  targets into a per-metric `pass`/`warn`/`fail` and a worst-wins `overall_outcome`. Targets
  default to the documented values below and are overridable via `-ThresholdsPath`; inverted
  threshold pairs (a lower-is-better `pass` above its `warn`, or a higher-is-better `pass` below
  its `warn`) are rejected. Metrics that use a sentinel `0` for "no samples" grade as `no-data`
  (not a healthy `pass`) when their sample count is zero: `incident_median_resolution_hours`
  (via `closed_incidents`), `average_pr_lead_time_hours` (via `merged_prs`), and
  `sprint_completion_pct` (via `sprint_open_items + sprint_closed_items`); any `no-data` metric
  forces the overall outcome to at least `warn`. The scorecard is deterministic: its
  `generated_at_utc` is the source rollup's timestamp (not wall-clock), so identical rollups
  produce byte-identical scorecards. The `evidence` block links the source rollup
  (`rollup_source`, and a required, valid `rollup_generated_at_utc`) and the producing run
  (`run_url`, a required non-blank input so every scorecard is auditable). The scorecard emits a
  normalized 0-100 `maturity_score` (mean of per-metric scores: pass 100, warn 70, no-data 60,
  fail 30) and a `maturity_tier` per `audit-framework.md`, so it feeds the weighted portfolio
  composite. `overall_outcome` is derived from the score band (pass `>= 85`, warn `60-84`, fail
  `< 60`) so status and score never disagree, using worst-status-in-band capping: a blocking
  `fail` caps the score in the fail band and any `warn` or missing-evidence (`no-data`) metric
  caps it in the warn band, so a single degraded control cannot yield a passing tier. Unknown
  threshold-override keys are rejected. The graded output is a reusable, auditable artifact.

  | Metric | Direction | Default pass | Default warn |
  |---|---|---|---|
  | `sprint_completion_pct` | higher-is-better | `>= 80` | `>= 60` |
  | `blocked_open_issues` | lower-is-better | `<= 0` | `<= 3` |
  | `open_incidents` | lower-is-better | `<= 0` | `<= 2` |
  | `open_risk_high_issues` | lower-is-better | `<= 0` | `<= 2` |
  | `incident_median_resolution_hours` | lower-is-better | `<= 24` | `<= 72` |
  | `average_pr_lead_time_hours` | lower-is-better | `<= 48` | `<= 96` |

## 4. Evidence link requirements

- Every published report includes `generated_at_utc` and the repository set covered.
- Because an issue comment is editable, it does not by itself satisfy the immutable-evidence
  requirement in `audit-framework.md`. The evidence of record is the immutable workflow run
  plus its uploaded artifacts (`portfolio-kpi-rollup.json`/`.md`), which are retained for 14
  days; durable retention beyond that window (and appending an explicit attempt-specific
  `actions/runs/<id>/attempts/<n>` link to the published comment) is the required publisher
  enhancement for full immutable-evidence linkage. A bare `actions/runs/<id>` is insufficient
  because the run id is stable across reruns while `GITHUB_RUN_ATTEMPT` increments, so the
  attempt must be recorded to identify the exact artifacts that produced the rollup.
- Runs are reproducible from a committed `-SnapshotPath` for deterministic validation.
  Reproducibility is scoped to metric values only: the top-level `generated_at_utc` is set from
  `Get-Date` on every invocation and is written into both `portfolio-kpi-rollup.json` and the
  rendered Markdown (`Convert-MetricsToMarkdown` emits it as a "Generated at" line), so neither
  artifact is byte-identical across runs. Byte-level reproducibility requires adding a fixed
  as-of timestamp input to the implementation.

## 5. Refresh cadence

- Scheduled on weekdays via cron `23 13 * * 1-5` (13:23 UTC, Monday through Friday), with
  on-demand `workflow_dispatch`.
- The lookback window (default 14 days) bounds the lagging indicators per run.

## Acceptance criteria mapping

- Required rollup inputs defined -> section 1.
- Publication format defined -> section 3.
- Evidence link requirements defined -> section 4.
- Refresh cadence defined -> section 5.
