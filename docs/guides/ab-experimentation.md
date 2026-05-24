# A/B Experimentation for Agents

Use A/B experiments to compare two agent variants before promotion to `agents/`.

## Directory convention

Create experiment assets under:

```text
tests/experiments/<name>/
  v1.agent.md
  v2.agent.md
  prompts.json
```

- `v1.agent.md`: baseline variant
- `v2.agent.md`: candidate variant
- `prompts.json`: shared prompt set and evaluation criteria

## Run an experiment

```powershell
pwsh scripts/run-experiment.ps1 -Experiment code-review-improvement -OutputDir test-results
```

Outputs:

- `test-results/<name>-ab-report.json`
- `test-results/<name>-ab-report.md`

The report includes prompt-level winner (`v1` / `v2` / `tie`), scores, and rationale.

## Promotion workflow

1. Run experiment and review report.
2. If `v2` wins consistently, copy/promote changes into `agents/<target>.agent.md`.
3. Open PR referencing the experiment report.
4. Archive losing variant by keeping it under `tests/experiments/<name>/` for traceability.

## Phase 1 limits

Phase 1 uses fixture responses in `prompts.json` (`v1_response`, `v2_response`) and
heuristic scoring. Live-model invocation and LLM judge modes can be added later.
