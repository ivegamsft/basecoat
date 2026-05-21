# Extension Intent Routing Eval Suite

This document defines the prompt-to-tool routing eval baseline for the BaseCoat Copilot Extension.

## Scope

- Golden prompt-to-tool mappings for the 10 planned extension tools
- Coverage checks requiring at least 5 positive prompts per tool
- Adversarial and ambiguous negative prompts that should not route to tools
- Optional prediction-mode scoring with misroute logs and suggestion hints

## Current dependency gap

Issue [#1075](https://github.com/IBuySpy-Shared/basecoat/issues/1075) (extension scaffold with `@github/copilot-sdk`) is still open.
Until that project exists, this suite runs in baseline mode and validates eval assets plus routing expectations.
Once #1075 lands, connect runtime routing outputs to `-PredictionsFile` to enforce pass-rate gates in CI.

## Files

- Eval dataset: `mcp/basecoat-extension/evals/intent-routing-golden.yaml`
- Eval runner: `scripts/eval-extension-intent-routing.ps1`
- Test: `tests/extension-intent-routing-eval-tests.ps1`
- Prediction fixture: `tests/evals/extension-intent-routing/predictions.fixture.json`

## Eval data format

Each case in `intent-routing-golden.yaml` contains:

- `id`: unique case id
- `prompt`: natural language user request
- `expected_tool`: one of the 10 tools or `none`
- `tags`: classification labels
- `suggestion_if_misrouted`: description-improvement hint
- `forbidden_tools` (negative cases only): tools that must not be selected

## Local validation

```powershell
pwsh tests/extension-intent-routing-eval-tests.ps1
```

To run prediction mode manually with real outputs from the extension runtime:

```powershell
pwsh scripts/eval-extension-intent-routing.ps1 `
  -PredictionsFile path\to\routing-predictions.json `
  -OutputDir test-results\extension-intent-routing `
  -MinPassRate 0.90
```

Prediction file shape:

```json
[
  { "id": "sa-01", "predicted_tool": "search-assets" },
  { "id": "neg-01", "predicted_tool": "none" }
]
```

If pass rate is below threshold, misroutes are logged to `misroutes.jsonl` with suggested tool-description improvements.
