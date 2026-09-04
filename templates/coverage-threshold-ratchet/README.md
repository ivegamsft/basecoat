# Coverage threshold ratchet (optional)

Opt-in guardrail that caps how far a PR may raise Istanbul-family coverage
thresholds in one change. Downstream origin: example-org/COECheck#737 / #754.

This template is not enabled by default. Copy the workflow into the consumer
repository and add a policy file. The script is configuration-driven; adoption
should not require script edits.

## What it enforces

1. Load proposed thresholds from each target `thresholdsFile`.
2. Load the baseline policy from the PR **base ref**, not the PR branch.
3. Fail if any metric increases by more than `maxIncreasePerRatchet`.
4. Fail if the PR mutates baseline values or target mapping (anti-bypass).
5. Allow an explicit exception only via the `coverage-ratchet-override` PR label.

## Bootstrap (first adoption)

The gate fails closed when the policy file is missing on the base branch.

1. Commit `coverage-threshold-ratchet-policy.json` to the default branch with
   `baseline.metrics` equal to the current threshold file values.
2. Copy `coverage-threshold-ratchet.yml` to `.github/workflows/`.
3. After that first baseline lands, later PRs can raise thresholds only within
   `maxIncreasePerRatchet` (default 2 points) per metric.

Do not raise the baseline and the thresholds in the same PR. That is the bypass
the base-ref check exists to stop.

## Override

Apply the `coverage-ratchet-override` label. The check records a warning and
passes. Keep the label attributable in the PR record; do not disable the job.

## Portability

| Layer | Reusable |
|---|---|
| Delta cap, base-ref baseline, drift detection, override | Yes |
| Policy schema (`targets[]` with `name`, `thresholdsFile`, `baseline.metrics`) | Yes |
| Metric keys (`statements`, `branches`, `functions`, `lines`) | Istanbul-family (Vitest, Jest, nyc, c8) |
| Threshold paths, baseline values, CI wiring, label name | Consumer config |
| Go / coverage.py / Cobertura | Needs an adapter (different metric keys) |

## Files

- `check-coverage-threshold-ratchet.js` — ratchet script
- `coverage-threshold-ratchet-policy.example.json` — policy schema
- `coverage-threshold-ratchet.yml` — reference CI job
