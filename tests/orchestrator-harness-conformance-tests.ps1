#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$orchestratorPath = Join-Path $repoRoot 'agents\orchestrator.agent.md'
if (-not (Test-Path $orchestratorPath)) {
    throw 'Missing orchestrator agent file: agents/orchestrator.agent.md'
}

$content = Get-Content $orchestratorPath -Raw
$requiredSnippets = @(
    '## Harness Conformance',
    'canonical-sub-agent-harness-contract',
    '`task_id`',
    '`goal`',
    '`scope`',
    '`acceptance_criteria`',
    '`execution`',
    '`output_contract`',
    '`inputs`',
    '`retry_context`',
    '`allowed_files`',
    '`allowed_tools`',
    '`allowed_skills`',
    '`model`',
    '`status`',
    '`summary`',
    '`changed_files`',
    '`acceptance_results`',
    '`evidence`',
    '`blockers`',
    '`follow_ups`',
    '`blocked`',
    '`failed`'
)

$failures = @()
foreach ($snippet in $requiredSnippets) {
    if ($content -notmatch [regex]::Escape($snippet)) {
        $failures += "Missing required harness contract token: $snippet"
    }
}

if ($content -inotmatch 'retry_context') {
    $failures += 'Missing retry policy guidance that references retry_context'
}

if ($content -inotmatch 'escalat') {
    $failures += 'Missing escalation policy guidance for unresolved branch failures'
}

if ($failures.Count -gt 0) {
    Write-Host 'Orchestrator harness conformance checks failed:' -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host 'Orchestrator harness conformance checks passed' -ForegroundColor Green
exit 0
