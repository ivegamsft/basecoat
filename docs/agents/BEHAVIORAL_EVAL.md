# Behavioral Evaluation (Phase 1)

This guide describes the Phase 1 behavioral evaluation harness for BaseCoat assets.

## Related harness docs

- [Agent Testing Harness](./AGENT_TESTING_HARNESS.md)
- [VS Code Harness Context Assembly Contract](./CONTEXT_ASSEMBLY_CONTRACT.md)
- [Per-Model Behavior Matrix](./AGENT_TESTING_HARNESS.md#per-model-behavior-matrix)
- [VS Code Harness Benchmarks](./VS_CODE_HARNESS_BENCHMARKS.md)

## What it does

The evaluator runs smoke cases from `tests/evals/smoke.behavior.json` and scores:

- Instruction-following
- Determinism
- Safety
- Usefulness
- Latency proxy

Scores are normalized to a 0-10 total and exported to:

- `test-results/eval-agents.json`
- `test-results/eval-summary.md`

## Run locally

```powershell
pwsh scripts/eval-assets.ps1 `
  -CaseFile tests/evals/smoke.behavior.json `
  -OutputDir test-results `
  -SummaryFile test-results/eval-summary.md
```

## CI workflow

The scheduled workflow `.github/workflows/behavioral-eval.yml` runs weekly and publishes:

- Job summary table
- Artifact `behavioral-eval-results`

## Harness change PR gate

The PR gate workflow `.github/workflows/harness-change-eval-gate.yml` enforces behavioral eval checks for harness-critical changes.

### Detection and label trigger

When a pull request changes harness-critical files (eval script, eval fixtures/rubrics, harness docs, or behavioral eval workflows), the workflow applies the `requires-harness-eval` label.

If no harness-critical files are changed, the label is removed automatically.

### Pass/fail criteria

- Run `scripts/eval-assets.ps1` against `tests/evals/smoke.behavior.json`
- Produce `test-results/eval-agents.json` and `test-results/eval-summary.md`
- Gate passes when average score is at least `7.0 / 10`
- Gate fails when average score is below `7.0` or eval artifacts are missing

### Evidence and rollout policy

- The workflow posts (or updates) a PR comment titled `Harness Eval Gate` with pass/fail status, average score, case count, and threshold.
- Artifacts are uploaded as `harness-eval-results` for reviewer inspection.
- Emergency bypass is available via the `skip-harness-eval-gate` label and should be used only for time-sensitive exceptions with follow-up remediation.

## Dataset and rubric files

- Cases: `tests/evals/smoke.behavior.json`
- Rubrics:
  - `tests/eval-rubrics/agents.json`
  - `tests/eval-rubrics/skills.json`
  - `tests/eval-rubrics/instructions.json`

## Current scope limits

Phase 1 uses deterministic fixture responses (`mock_responses`) and assertion-based scoring.
Live model invocation and judge-model scoring are explicitly deferred to follow-up work.
