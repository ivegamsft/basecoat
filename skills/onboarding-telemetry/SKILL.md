---
name: onboarding-telemetry
compatibility: [github-copilot-cli]
description: "Configure App Insights connection surfaces, wire adoption metrics, and emit a telemetry readiness checklist for a newly onboarded BaseCoat repo. USE FOR: set up APPLICATIONINSIGHTS_CONNECTION_STRING and COPILOT_METRICS_TOKEN for an onboarded repo, configure the adoption-metrics weekly cadence, review the telemetry readiness scorecard, add goal-based loop metrics to a repo dashboard. DO NOT USE FOR: general observability instrumentation, OpenTelemetry SDK setup, production APM configuration."
category: operations

visibility: public
capabilities:
  reasoning_depth: low
  tool_use: optional
  context_window: small
  latency_profile: interactive
  cost_tier: low
  safety_level: standard
model_policy:
  fallback: true
  preferred_families:
    - claude-haiku
    - gpt-5-mini
metadata:
  category: operations
  maturity: stable
  audience:
    - developer
allowed-tools: []
---

# Onboarding Telemetry Skill

Configure App Insights connection surfaces and wire the adoption metrics weekly cadence
for a newly onboarded BaseCoat repo.

## Reference Files

| File | Contents |
|---|---|
| [`docs/operations/onboarding-telemetry-readiness.md`](../../docs/operations/onboarding-telemetry-readiness.md) | Profile-aware checklist and dependency table |
| [`docs/reference/telemetry-scorecard-schema.v1.md`](../../docs/reference/telemetry-scorecard-schema.v1.md) | Goal-based loop metrics and scorecard schema |

## Steps

1. Identify profile (`solo-dev`, `team-dev`, `regulated-team`).
2. Confirm `adoption-metrics.yml` exists under `.github/workflows/` (opt-in
   template, not installed by default -- see
   `scripts/configure-downstream-workflows.ps1`'s `onboarding-telemetry`
   class). If missing, stop and report it with installation guidance:
   `pwsh scripts/configure-downstream-workflows.ps1 -InstallClass onboarding-telemetry`
   (or `-IncludeTemplates`). Never assume it is present.
3. Check `APPLICATIONINSIGHTS_CONNECTION_STRING` and `COPILOT_METRICS_TOKEN` are set per profile requirements.
4. Confirm `DASHBOARD_REPOS` includes the target repo.
5. Trigger `adoption-metrics.yml` via `workflow_dispatch` to generate first readiness snapshot.
6. Review `dashboard/metrics/telemetry-readiness.json` on `gh-pages`; surface any `missing_dependencies`.

## Inputs and Outputs

- **Input**: onboarding profile, target repo slug, secret/variable state
- **Output**: readiness summary with missing dependencies and resolution steps
