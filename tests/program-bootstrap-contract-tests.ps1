#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$agentPath = Join-Path $repoRoot 'agents\program-bootstrap.agent.md'
$evalPath = Join-Path $repoRoot 'agents\program-bootstrap.agent.eval.yaml'
$contractsPath = Join-Path $repoRoot 'docs\agents\program-bootstrap-stage-contracts.md'
$runbookPath = Join-Path $repoRoot 'docs\guides\program-bootstrap-runbook.md'

$requiredPaths = @($agentPath, $evalPath, $contractsPath, $runbookPath)
foreach ($path in $requiredPaths) {
    if (-not (Test-Path $path)) {
        throw "Missing required program-bootstrap artifact: $path"
    }
}

$agentContent = Get-Content $agentPath -Raw
$evalContent = Get-Content $evalPath -Raw
$contractsContent = Get-Content $contractsPath -Raw
$runbookContent = Get-Content $runbookPath -Raw

$failures = @()

$requiredAgentSnippets = @(
    'capabilities:',
    'model_policy:',
    '`execution_model`',
    '`output_root`',
    '`checkpoint_store`',
    '## Session model',
    '## Output directory contract',
    '## Review-mode policy',
    'child-sessions',
    'single-session'
)

foreach ($snippet in $requiredAgentSnippets) {
    if ($agentContent -notmatch [regex]::Escape($snippet)) {
        $failures += "program-bootstrap.agent.md missing required contract snippet: $snippet"
    }
}

$requiredEvalScenarioIds = @(
    'happy-path',
    'dry-run',
    'resume-retry',
    'review-gated-apply',
    'output-directory-contract',
    'neg-specialist-only',
    'neg-taxonomy-overwrite',
    'neg-delete-preserved-labels'
)

foreach ($scenarioId in $requiredEvalScenarioIds) {
    if ($evalContent -notmatch "(?m)^\s*-\s+id:\s*`"$([regex]::Escape($scenarioId))`"\s*$") {
        $failures += "program-bootstrap.agent.eval.yaml missing scenario id: $scenarioId"
    }
}

$requiredContractSnippets = @(
    '| `execution_model` | string | Yes |',
    '## Session model contract',
    '## Output directory contract',
    '.github/bootstrap/<program_name>',
    '## Review-mode contract',
    'attempted_mutations'
)

foreach ($snippet in $requiredContractSnippets) {
    if ($contractsContent -notmatch [regex]::Escape($snippet)) {
        $failures += "program-bootstrap-stage-contracts.md missing required contract snippet: $snippet"
    }
}

$requiredRunbookSnippets = @(
    '## Canonical output structure',
    '.github/bootstrap/<program_name>/',
    'execution_model: "child-sessions"',
    '## Review-gated issue creation policy'
)

foreach ($snippet in $requiredRunbookSnippets) {
    if ($runbookContent -notmatch [regex]::Escape($snippet)) {
        $failures += "program-bootstrap-runbook.md missing required runbook snippet: $snippet"
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'Program bootstrap contract checks failed:' -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host 'Program bootstrap contract checks passed' -ForegroundColor Green
exit 0
