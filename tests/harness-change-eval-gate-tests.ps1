#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$workflowPath = Join-Path $repoRoot '.github\workflows\harness-change-eval-gate.yml'

if (-not (Test-Path $workflowPath)) {
    throw 'Harness eval gate workflow is missing: .github/workflows/harness-change-eval-gate.yml'
}

$workflowContent = Get-Content $workflowPath -Raw
$requiredSnippets = @(
    'requires-harness-eval',
    'skip-harness-eval-gate',
    'scripts/eval-assets.ps1',
    'tests/evals/smoke.behavior.json',
    'Harness Eval Gate',
    'threshold = 7.0'
)

foreach ($snippet in $requiredSnippets) {
    if ($workflowContent -notmatch [regex]::Escape($snippet)) {
        throw "Harness eval gate workflow is missing required snippet: $snippet"
    }
}

Write-Host 'Harness change eval gate workflow test passed' -ForegroundColor Green
