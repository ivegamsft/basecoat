# Behavioral Evaluation (Phase 1)

This guide describes the Phase 1 behavioral evaluation harness for BaseCoat assets.

## Related harness docs

- [Agent Testing Harness](./AGENT_TESTING_HARNESS.md)
- [Per-Model Behavior Matrix](./AGENT_TESTING_HARNESS.md#per-model-behavior-matrix)

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

## Dataset and rubric files

- Cases: `tests/evals/smoke.behavior.json`
- Rubrics:
  - `tests/eval-rubrics/agents.json`
  - `tests/eval-rubrics/skills.json`
  - `tests/eval-rubrics/instructions.json`

## Current scope limits

Phase 1 uses deterministic fixture responses (`mock_responses`) and assertion-based scoring.
Live model invocation and judge-model scoring are explicitly deferred to follow-up work.
