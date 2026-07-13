# Intent Contract v1

## Overview

This document is the versioned contract for the Intent-to-Production (Intent2Prod)
control plane. It defines the accepted intent types, parameter schema, lifecycle
state machine, and governance expectations for all governed execution runs.

## Version

`v1` — established as part of Sprint 2 of control plane #1874.

## Accepted Intent Types

| Intent | Trigger Phrase | Primary Use Case |
|---|---|---|
| `ship-it` | `/ship-it <goal>` | Feature, fix, or enhancement delivery |
| `spec-2-prod` | Workflow dispatch | Spec-driven production promotion |
| `onboarding-conductor` | Workflow dispatch | Repository onboarding to a profile |

## Parameter Schema

| Parameter | Type | Required | Default | Constraints |
|---|---|---|---|---|
| `intent` | string | Yes | — | Must be a value from the accepted intent types table |
| `goal` | string | Yes | — | Non-empty; trimmed before use |
| `target_repo` | string | Yes | `$GITHUB_REPOSITORY` | `owner/repo` format |
| `spec_ref` | string | No | `""` | URL or issue reference |
| `risk_band` | string | Yes | `"medium"` | `low`, `medium`, `high`, `critical` |
| `profile` | string | No | `"team-dev"` | `solo-dev`, `team-dev`, `regulated-team`, `pilot-luxesite` |
| `project_number` | integer | No | `0` | If non-zero, `project_owner` is required |
| `project_owner` | string | Conditional | `""` | Required when `project_number` is set |
| `dry_run` | boolean | No | `false` | Set `true` to skip live side effects |

## Lifecycle State Machine

```text
CREATED
  |
  v
SCOPING (Sprint 1 active)
  |  exit: spec validated, scope confirmed, risk acknowledged
  v
IMPLEMENTING (Sprint 2 active)
  |  exit: code merged, required gates green, rollback documented
  v
VALIDATING
  |  exit: staged promotion evidence collected
  v
PROMOTING
  |  exit: release gates passed, staged rollout complete
  v
SHIPPED
  |  exit: post-release verification passed
  v
CLOSED (learning captured, all child issues closed)
```

### State Transitions

| From | To | Trigger | Guard |
|---|---|---|---|
| `CREATED` | `SCOPING` | Sprint 1 issue created | Parent issue exists |
| `SCOPING` | `IMPLEMENTING` | Sprint 1 exit criteria met | All Sprint 1 checkboxes checked |
| `IMPLEMENTING` | `VALIDATING` | Sprint 2 PR merged | Required CI checks green |
| `VALIDATING` | `PROMOTING` | Evidence collected | Promotion gate score sufficient |
| `PROMOTING` | `SHIPPED` | Staged rollout complete | No rollback triggered |
| `SHIPPED` | `CLOSED` | Learning log updated | All sprint issues closed |

### Terminal States

- `CLOSED`: Normal completion.
- `ROLLED_BACK`: Any state can transition to `ROLLED_BACK` if rollback is triggered.
  After rollback validation, the run may be `CLOSED` with a rollback evidence record.

## Autonomy Band Contract

The autonomy band is derived from `risk_band` and `profile`:

| risk_band | profile | Default Autonomy Band |
|---|---|---|
| `low` | any | A3 (automated with exception escalation) |
| `medium` | `solo-dev` | A3 |
| `medium` | `team-dev` | A2 (automated with human gate approvals) |
| `medium` | `regulated-team` | A1 (human-approved start, automated execution) |
| `high` | any | A1 |
| `critical` | any | A0 (fully human-gated) |

`pilot-luxesite` uses the `onboarding-conductor` path with lane-specific policy overlays
for release gates and artifact completeness.

## Idempotency Contract

Intent dispatch is idempotent. Re-running the same intent with identical parameters
(`intent + target_repo + goal + profile`) detects the existing control-plane parent
issue using a SHA-256 content hash marker embedded in the issue body and reuses it
rather than creating a duplicate.

The marker format is:

```text
<!-- basecoat-intent-parent:<run_key_hash> -->
```

Child sprint issues use phase-scoped markers:

```text
<!-- basecoat-intent-child:<run_key_hash>:<phase_slug> -->
```

## Governance Labels

All control-plane issues are labeled with:

- `intent-control-plane` — identifies the parent or child as a governed execution artifact
- `ship-it` / `spec-2-prod` / `onboarding-conductor` — intent type
- `risk-<band>` — risk classification (`risk-low`, `risk-medium`, `risk-high`, `risk-critical`)
- `sprint` — (child issues only) marks child sprint tracking issues

## Output Artifacts

Each dispatch produces:

| Artifact | Path | Format |
|---|---|---|
| Machine-readable summary | `test-results/ship-it/summary.json` | JSON |
| Human-readable summary | `test-results/ship-it/summary.md` | Markdown |
| Parent intent issue | GitHub Issues | Issue body with governance checklist |
| Sprint child issues (3) | GitHub Issues | One per sprint phase with latest-main sync and predecessor-wait guardrails |

## Non-Goals

- Replacing required branch protection rules.
- Bypassing `prd-spec-gate` or `release-label-gate` validation.
- Automated production deployments without a staged promotion gate.
- Provisioning infrastructure (handled by separate IaC pipelines).

## Change History

| Version | Date | Change |
|---|---|---|
| v1 | 2026-06-23 | Initial contract; established intent types, state machine, idempotency, and autonomy bands |
