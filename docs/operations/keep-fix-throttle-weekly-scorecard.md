# Keep/Fix/Throttle Weekly Scorecard

This runbook defines the weekly scorecard/readout path for workstream 5 of epic
[#1452](https://github.com/ivegamsft/basecoat/issues/1452).

## Objective

Publish a weekly operating scorecard that reports:

1. Throughput
2. Workflow failure rate
3. MTTR
4. Manual intervention rate

Each metric includes trend classification (`improving`, `stable`, `regressing`)
and links to remediation issues when regressions appear.

## Execution Path

1. Workflow: `.github/workflows/keep-fix-throttle-weekly-scorecard.yml`
2. Generator: `scripts/keep-fix-throttle-weekly-scorecard.ps1`
3. Artifacts:
   - `keep-fix-throttle-weekly-scorecard.json`
   - `keep-fix-throttle-weekly-scorecard.md`
4. Weekly readout comment target: issue
   [#2050](https://github.com/ivegamsft/basecoat/issues/2050)

## Local Run

```powershell
pwsh -NoProfile -File scripts/keep-fix-throttle-weekly-scorecard.ps1 `
  -Repository ivegamsft/basecoat `
  -LookbackDays 7 `
  -TrendWindowWeeks 4 `
  -OutputDir artifacts\keep-fix-throttle-weekly-scorecard
```

## Fixture-Driven Run (deterministic)

```powershell
pwsh -NoProfile -File scripts/keep-fix-throttle-weekly-scorecard.ps1 `
  -Repository ivegamsft/basecoat `
  -SnapshotPath tests\fixtures\keep-fix-throttle-weekly-snapshots.example.json `
  -DryRun `
  -OutputDir artifacts\keep-fix-throttle-weekly-scorecard
```

## Review Workflow

1. Verify all four metrics are present in the weekly readout.
2. Check `overall_trend` and per-metric trend statuses.
3. If any metric is `regressing`, update linked remediation issue(s) before the
   next sprint planning cycle.
4. Keep weekly artifacts for at least 4 runs to satisfy cadence validation.
