# Coverage Threshold Ratchet

Optional, config-driven template for incremental coverage-threshold increases.

Use this when coverage thresholds are a merge or deploy gate and a large jump
would block the release lane. The template lives at
`templates/coverage-threshold-ratchet/` and syncs with BaseCoat (`templates/`
is part of the managed overlay).

## Why a ratchet

Raising a coverage floor is a control-plane change. If CI must be green before
deploy, an over-ambitious bump is functionally a production change. Cap the
delta per PR and review exceptions in the open.

## Config contract

Consumer repository root:

- Policy file: `coverage-threshold-ratchet-policy.json` (copy from
  `templates/coverage-threshold-ratchet/coverage-threshold-ratchet-policy.example.json`)
- Threshold files: one JSON object per target with numeric
  `statements`, `branches`, `functions`, and `lines` (0-100)
- Cadence: `ratchetCadence` is documentation for humans (for example
  `once per sprint`); the script enforces `maxIncreasePerRatchet`
- Override label: `override.label` (default `coverage-ratchet-override`)

The script always reads baseline policy from `--base-ref` (typically
`origin/<base>`). A policy file that exists only on the PR branch is not a
control.

## Bootstrap

When the policy file is absent on the base branch, the check fails closed.

Land the first policy on the default branch with `baseline.metrics` matching
current thresholds. After that, PRs may raise thresholds by at most
`maxIncreasePerRatchet` points per metric.

## Override semantics

The `coverage-ratchet-override` label is the auditable exception path. The job
warns and passes. Do not delete the workflow to skip a bump.

## Portability limits

Istanbul-family reporters only (Vitest, Jest, nyc, c8). Other coverage formats
need an adapter because metric keys differ.

## Related

- Template: `templates/coverage-threshold-ratchet/`
- Downstream proof: IBuySpy-Dev/COECheck#737 and IBuySpy-Dev/COECheck#754
