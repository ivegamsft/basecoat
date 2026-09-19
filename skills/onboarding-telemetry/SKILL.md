---
name: onboarding-telemetry
compatibility: [github-copilot-cli]
description: "Configure App Insights connection surfaces, wire adoption metrics, and emit a telemetry readiness checklist for a newly onboarded BaseCoat repo. USE FOR: set up APPLICATIONINSIGHTS_CONNECTION_STRING and COPILOT_METRICS_TOKEN for an onboarded repo, configure the adoption-metrics weekly cadence, review the telemetry readiness scorecard, add goal-based loop metrics to a repo dashboard. DO NOT USE FOR: general observability instrumentation, OpenTelemetry SDK setup, production APM configuration."
category: operations

visibility: public
capabilities:
  reasoning_depth: low
  tool_use: required
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
allowed-tools:
  - bash
  - gh
---

# Onboarding Telemetry Skill

## Reference Files

- [Readiness checklist](../../docs/operations/onboarding-telemetry-readiness.md)
- [Scorecard schema](../../docs/reference/telemetry-scorecard-schema.v1.md)

## Execution Modes

### Execute Mode

Requires authenticated `gh` access. Use for dispatching `adoption-metrics.yml` or
inspecting its run and `gh-pages` readiness artifact.

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

Report completion only with the run URL or ID, terminal status, and artifact source.
Otherwise report the blocker; never claim dispatch, completion, or verification.

### Advisory Mode

Advisory mode is tool-free and must be labeled **advisory only**. Assess only supplied
evidence:

- profile, repo slug, and workflow presence;
- presence only, never values, of secrets/variables and `DASHBOARD_REPOS` membership;
- run URL/status and readiness JSON for result analysis.

Mark missing evidence unknown and provide next-step `gh` commands. Advisory mode may
describe dispatch and inspection, but must not claim they occurred or that readiness was
verified.

## Output

Return an evidence-backed run/readiness summary in execute mode, or labeled guidance
with unknowns and next steps in advisory mode.
