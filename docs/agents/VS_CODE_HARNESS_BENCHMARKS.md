# VS Code Harness Benchmarks

## Purpose

This document defines the benchmark execution contract for the VS Code harness and links benchmark assets used for regression checks in PR and release validation.

## Benchmark assets

- Suite definition: `tests/evals/vscode-harness-benchmark-suite.json`
- Regression thresholds: `tests/evals/vscode-harness-regression-thresholds.json`
- Comparison script: `scripts/compare-vscode-harness-benchmarks.ps1`

## Scope

The suite covers product-specific harness behavior that generic eval suites can miss:

- Multi-turn tool orchestration quality
- MCP and external tool routing
- Terminal and browser interaction flow handling
- Stop conditions, budget limits, and cancellation behavior

## Metrics and thresholds

The thresholds file defines pass/fail gates for:

- Resolution rate regression
- Prompt token increase
- Completion token increase
- p95 latency increase
- Tool calls per resolved run increase

Thresholds are defined globally and per benchmark category.

## Repeatable execution path

Run this from the repository root:

```powershell
pwsh scripts/compare-vscode-harness-benchmarks.ps1 `
  -BaselineFile test-results/vscode-harness-baseline.json `
  -CandidateFile test-results/vscode-harness-candidate.json `
  -ThresholdFile tests/evals/vscode-harness-regression-thresholds.json `
  -OutputDir test-results `
  -SummaryFile test-results/vscode-harness-regression-summary.md
```

Outputs for PR/release checks:

- `test-results/vscode-harness-regression.json`
- `test-results/vscode-harness-regression-summary.md`

Non-zero exit indicates threshold failure.
