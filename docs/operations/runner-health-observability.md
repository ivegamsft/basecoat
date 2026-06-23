# Runner Health Observability

This repository tracks release/deploy lane health with a dedicated workflow:

- `.github/workflows/runner-health-observability.yml`
- `scripts/report-runner-health.ps1`

## Signals reported

The workflow reports these operational signals over a configurable lookback
window:

1. Queue wait for release/deploy workflows (P50/P95/max and threshold breaches).
2. Offline runner capacity for repository-scoped self-hosted runners.
3. Potential wrong-runner failure patterns, including lane workflow failures with
   no assigned runner or failures occurring on GitHub-hosted runners.

## Execution model

- Schedule: daily at 06:00 UTC.
- Manual trigger: `workflow_dispatch` with optional `lookback_days` and
  `queue_warn_seconds`.
- Runner lane: `${{ vars.RUNNER_RELEASE || vars.RUNNER_DEPLOY || 'ubuntu-latest' }}`
  so reporting follows release/deploy isolation.

## Outputs

Each run publishes:

- A markdown summary in the workflow step summary.
- `runner-health-report.md` artifact.
- `runner-health-report.json` artifact for downstream automation.

Use this report to spot routing debt quickly (queue backlog growth, offline
capacity, and likely runner mismatch failures) before release reliability
degrades.
