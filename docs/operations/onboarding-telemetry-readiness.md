# Onboarding Telemetry Readiness

Tracking: #1834

This document defines the telemetry readiness checklist for newly onboarded BaseCoat
repos. It is profile-aware: requirements tighten with profile posture. Missing
dependencies are surfaced here so teams know exactly what to configure before their
first scorecard run.

## Overview

Telemetry readiness has three states:

| State | Meaning |
|---|---|
| `ready` | All required dependencies are present. All four goal-based loop metrics emit data. |
| `partial` | Some dependencies are missing. Metrics run with reduced coverage. |
| `not-ready` | No metric data can be collected. Telemetry setup is incomplete. |

The `adoption-metrics` workflow emits a `readiness` block in each repo scorecard.
Use this document to interpret what each missing dependency means and how to resolve it.

## Profile-aware requirements

### `solo-dev`

Minimum viable telemetry for solo use.

| Dependency | Required | How to configure |
|---|---|---|
| `GITHUB_TOKEN` | Yes (automatic) | Provided by GitHub Actions; no action required. |
| `DASHBOARD_REPOS` | Yes | Set as a repository or organization variable: `["owner/repo"]`. |
| `COPILOT_METRICS_TOKEN` | No | Optional; enables `reviewer_closure` metric. Set as a repo secret with `read:org` scope. |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | No | Optional; enables App Insights emission. Set as a repo secret. |

Weekly cadence: the `adoption-metrics` workflow runs every Monday at 09:00 UTC. No
additional scheduling configuration is required.

### `team-dev`

Standard team telemetry. All of the `solo-dev` requirements plus:

| Dependency | Required | How to configure |
|---|---|---|
| `COPILOT_METRICS_TOKEN` | Yes | Set as an **organization** secret with `read:org` scope so all team repos share one token. |
| `DASHBOARD_ORG` | Yes | Set as a repository or organization variable matching the GitHub org login. |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Recommended | Set as an organization secret so all team repos emit to a shared App Insights workspace. |

### `regulated-team`

All of the `team-dev` requirements plus:

| Dependency | Required | How to configure |
|---|---|---|
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Yes | Required for org-managed telemetry. Must be set as an organization secret. |
| `DASHBOARD_ORG` | Yes | Must match the regulated org login. |
| `COPILOT_METRICS_TOKEN` | Yes | Must be an organization-scoped service account token with `read:org` scope. |

## Telemetry readiness checklist

Use this checklist before the first `adoption-metrics` run on a newly onboarded repo.

### Step 1 — Verify workflow is scheduled

- [ ] `adoption-metrics.yml` is present in `.github/workflows/`.
- [ ] The `schedule` trigger is set to `0 9 * * 1` (every Monday 09:00 UTC).
- [ ] The workflow has been triggered at least once via `workflow_dispatch` to confirm it runs successfully.

### Step 2 — Configure required secrets and variables

- [ ] `DASHBOARD_REPOS` variable is set (repo or org level) and includes this repo.
- [ ] `DASHBOARD_ORG` variable is set and matches the GitHub org login.
- [ ] `COPILOT_METRICS_TOKEN` secret is set with `read:org` scope (required for `reviewer_closure`).
- [ ] `APPLICATIONINSIGHTS_CONNECTION_STRING` secret is set (required for App Insights emission).

### Step 3 — Verify metric collection

After the first successful run:

- [ ] `dashboard/metrics/latest.json` is present on `gh-pages`.
- [ ] `dashboard/metrics/scorecard-<repo-slug>.json` is present on `gh-pages`.
- [ ] All four goal-based loop metrics have non-null values in the scorecard.
- [ ] `readiness.overall` is `ready` in the scorecard.

### Step 4 — App Insights validation (when connected)

- [ ] At least one `BaseCoatScorecardSnapshot` event appears in the Application Insights
  instance within 10 minutes of the workflow run completing.
- [ ] Custom dimensions include `repo`, `profile`, `telemetry_mode`, `collected_at`.
- [ ] Custom measurements include `reviewer_closure`, `intake_completeness`,
  `merge_health`, `drift_trend`.

## Surfacing missing dependencies

When the `adoption-metrics` workflow runs and dependencies are missing, the `readiness`
block in the scorecard will include a `missing_dependencies` array describing each gap.

Common messages and resolutions:

| Message | Resolution |
|---|---|
| `APPLICATIONINSIGHTS_CONNECTION_STRING not set — App Insights emission disabled` | Add the secret at repo or org level. See `.env.example` for the variable name. |
| `COPILOT_METRICS_TOKEN not set — reviewer_closure metric unavailable` | Add a PAT with `read:org` scope as a repo or org secret named `COPILOT_METRICS_TOKEN`. |
| `DASHBOARD_REPOS not configured — no repos scanned` | Set the `DASHBOARD_REPOS` variable to a JSON array of repo slugs. |
| `drift_trend data unavailable: fewer than 2 snapshots in history.json` | This warning clears automatically after the second weekly run. No action required. |
| `intake_completeness data unavailable: COPILOT_METRICS_TOKEN missing` | The intake completeness check requires the Copilot metrics token. Add it to resolve. |

## App Insights connection surface

The following secret and variable names are the canonical references for App Insights
integration in BaseCoat onboarded repos:

| Name | Type | Scope | Description |
|---|---|---|---|
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Secret | Repo or Org | Full connection string for the App Insights workspace. Preferred over instrumentation key. |
| `APPLICATIONINSIGHTS_INSTRUMENTATION_KEY` | Secret | Repo or Org | Legacy instrumentation key. Use connection string instead where possible. |

The connection string format is:

```text
InstrumentationKey=<key>;IngestionEndpoint=https://<region>.in.applicationinsights.azure.com/;LiveEndpoint=https://<region>.livediagnostics.monitor.azure.com/
```

Obtain it from the Azure Portal under:
**Application Insights resource > Overview > Connection String**.

## Weekly metrics cadence

All BaseCoat onboarded repos participate in a weekly metrics cadence:

- **Frequency:** Every Monday at 09:00 UTC
- **Workflow:** `adoption-metrics.yml`
- **Output:** `dashboard/metrics/latest.json`, `history.json`, `alerts.json`, `SUMMARY.md`,
  and one `scorecard-<repo-slug>.json` per monitored repo
- **Weekly summary issue:** Filed automatically by the workflow each Monday when
  `SUMMARY.md` is present

The cadence is the same for all profiles. Profile posture affects thresholds and which
metrics require secrets — not the schedule itself.

## Related files

- `docs/reference/telemetry-scorecard-schema.v1.md`
- `docs/reference/telemetry-scorecard-schema.v1.schema.json`
- `docs/reference/onboarding-profile-contract.v1.md`
- `docs/reference/metrics-schema-glossary.md`
- `.env.example`
- `.github/workflows/adoption-metrics.yml`
