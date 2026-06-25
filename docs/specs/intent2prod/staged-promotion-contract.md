# Intent2Prod Staged Promotion Contract

## Objective

Define and enforce deterministic release gates for each promotion stage so that
production cutover only occurs with approved environment controls, complete
evidence, and a validated rollback path.

## Promotion Stages

The staged promotion order is fixed:

1. `validate`
2. `canary`
3. `staging`
4. `production`

Each stage depends on the previous stage result (`pass`) before promotion can continue.

## Required Gates by Risk Band

| Risk band | Required gates |
|---|---|
| `low` | `lint`, `build`, `smoke` |
| `medium` | `lint`, `build`, `type`, `smoke` |
| `high` | `lint`, `build`, `type`, `e2e`, `security`, `smoke` |
| `critical` | `lint`, `build`, `type`, `e2e`, `security`, `smoke` |

Any required gate with `status != pass` blocks promotion.

## Lane Policy Overlay

Execution lanes can add stricter rules on top of risk-band defaults.

| Execution lane | Added required gates | Added required artifacts |
|---|---|---|
| `standard` | none | none |
| `pilot-luxesite` | `lint`, `build`, `type`, `e2e`, `security`, `smoke` | `spec`, `docs`, `tests`, `runbook`, `release_notes` |

The lane overlay is additive: the final requirement set is the union of
risk-band rules and lane rules.

## Environment Protection and Approvals

Promotion is blocked unless:

- `environment_protection_status = configured`
- required approval is present when any of the following is true:
  - promotion stage is `production`
  - risk band is `high` or `critical`
  - explicit approval requirement is enabled

Approval state must be `approved` when approval is required.

## Rollback Contract (Production Cutover)

Before `production` promotion:

- rollback runbook reference must exist
- rollback validation status must be `validated`

If either condition fails, promotion is blocked.

## Evidence Bundle Contract

The release gate enforcer writes:

- `test-results/ship-it/promotion-evidence-bundle.json`
- `test-results/ship-it/promotion-evidence-bundle.md`

The JSON bundle includes:

- risk band, stage, required gate evaluations, and blockers
- progressive promotion status
- environment protection and approval results
- rollback contract evaluation
- immutable references (`repo`, `branch`, `sha`, `workflow_ref`, `run_id`, stage, risk band)
- SHA-256 bundle digest for tamper-evident traceability

## Workflow Surface

Use `.github/workflows/ship-it-release-gate.yml` to evaluate promotion requests.
The workflow emits the promotion evidence bundle as the `ship-it-release-gate`
artifact and fails the run when promotion is blocked (unless `dry_run=true`).
