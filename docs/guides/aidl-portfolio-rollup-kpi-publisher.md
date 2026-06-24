# AIDL Portfolio Rollup and KPI Publisher

Issue #1744 implements cross-repo portfolio rollups and scheduled KPI publishing
for the AIDL portfolio management track.

## Artifacts

1. Script: `scripts/aidl-portfolio-rollup-kpi-publisher.ps1`
2. Workflow: `.github/workflows/aidl-portfolio-rollup-kpi-publisher.yml`
3. Output JSON: `artifacts/aidl-portfolio-rollup/portfolio-kpi-rollup.json`
4. Output Markdown report: `artifacts/aidl-portfolio-rollup/portfolio-kpi-rollup.md`
5. Output dashboard: `artifacts/aidl-portfolio-rollup/portfolio-dashboard.md`

## Control-plane pattern

This flow follows the ship-it/intent-to-prod control-plane model:

1. **Intent trigger**: scheduled run or manual workflow dispatch.
2. **Governed aggregation**: cross-repo metric collection with explicit KPI definitions.
3. **Published evidence**: artifact upload plus optional report comment on a target issue.
4. **Traceable drill-down**: links back to source issues and pull requests.

## KPI model

The report separates leading and lagging indicators.

| Indicator | Type | Definition |
|---|---|---|
| Blocked Open Issues | Leading | Open issues with blocked/status:block labels |
| Open Review Queue | Leading | Open non-draft pull requests |
| Open Risk High Issues | Leading | Open issues labeled high risk or high/critical priority |
| Open Incidents | Leading | Open issues labeled incident/type:incident |
| Throughput | Lagging | Closed issues + merged PRs in the lookback window |
| Incident Median Resolution Hours | Lagging | Median time from incident issue creation to close |
| Average PR Lead Time Hours | Lagging | Mean time from PR creation to merge |
| Sprint Completion % | Lagging | Sprint closed items / total sprint items |

## Workflow usage

### Scheduled publisher

The workflow runs on weekdays and publishes rollup artifacts each run.

### Manual execution

```powershell
pwsh -File scripts/aidl-portfolio-rollup-kpi-publisher.ps1 `
  -Repositories @(
    "IBuySpy-Shared/basecoat",
    "IBuySpy-Shared/consumer-a"
  ) `
  -LookbackDays 14 `
  -PublishIssueRepo "IBuySpy-Shared/basecoat" `
  -PublishIssueNumber 1744
```

### Deterministic dry-run with snapshot input

```powershell
pwsh -File scripts/aidl-portfolio-rollup-kpi-publisher.ps1 `
  -Repositories @("IBuySpy-Shared/basecoat","IBuySpy-Shared/consumer-a") `
  -SnapshotPath .\tmp\rollup-snapshot.json `
  -DryRun
```

## Data quality caveats

The report emits caveats when repository data is incomplete or not consistently
labeled. Common caveats include:

1. Missing `sprint:*` labels, which reduces sprint status fidelity.
2. Missing roadmap labels (`roadmap`, `status:roadmap`, `plan:roadmap`).
3. Dry-run placeholder data (explicitly marked when `-DryRun` is used without snapshot input).

Use these caveats as an operational checklist to improve taxonomy consistency
across repositories.
