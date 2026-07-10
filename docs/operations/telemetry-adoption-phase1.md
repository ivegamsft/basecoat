# Telemetry Adoption — Phase 1

This document captures the initial, low-risk telemetry implementation path for BaseCoat.
Canonical terminology for adoption telemetry and dashboard participation is defined
in [Dashboard Metrics Schema and Glossary](../reference/metrics-schema-glossary.md#canonical-vocabulary-and-usage-rules).

## Scope

Phase 1 focuses on signals that are available today without private or speculative APIs:

1. Organization Copilot metrics reports (28-day NDJSON report endpoint)
2. Repository health and delivery metrics already collected in `collect-metrics.py`
3. Optional metadata-only local telemetry for CLI plugin invocations (future follow-up)

## Available signals (today)

| Signal | Source |
|---|---|
| Active Copilot users (rollup over report window) | `GET /orgs/{org}/copilot/metrics/reports/organization-28-day/latest` |
| Daily active CLI users (sum over report window) | NDJSON report rows (`daily_active_cli_users`) |
| Daily active cloud-agent users (sum over report window) | NDJSON report rows (`daily_active_copilot_cloud_agent_users`) |
| PR cycle time, CI pass rate (last 20 and 100 measurable runs), issue resolution | Existing repo metrics collectors in `scripts/metrics/collect-metrics.py` |

## Not available (public API)

These are out of scope for Phase 1:

- Per-session Copilot internal telemetry (turn-by-turn context size, handoffs, retries, prompt content)
- Per-model billing breakdown via API

## Permissions

- `read:org` (or equivalent org access) for Copilot metrics reports
- `repo`/workflow read scopes for repository-level CI/PR/issue metrics

## Privacy guardrails

Telemetry collection in this phase is metadata only:

- No prompt bodies
- No response content
- No user-authored code snippets

## Implementation notes

- `scripts/metrics/collect-metrics.py` now uses the reports endpoint and parses NDJSON rows.
- Dashboard summaries continue to consume `latest.json` with backward-compatible `total_active_users`.
- CI metrics expose backward-compatible `success_rate` and explicit `pass_rate` / `ci_pass_rate_last_20_runs` fields for retrospective use.

## Follow-up split candidates

1. Add opt-in local JSONL telemetry for BaseCoat CLI plugin invocations
2. Add usage-signals aggregation output (`usage-signals.json`) for weekly dashboard trending
3. Add a dedicated VS Code spike for custom participant telemetry (public APIs only)
