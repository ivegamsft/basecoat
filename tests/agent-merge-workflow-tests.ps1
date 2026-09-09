#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$workflowPath = Join-Path $repoRoot '.github\workflows\agent-merge.yml'

if (-not (Test-Path $workflowPath)) {
    throw 'Agent merge workflow is missing: .github/workflows/agent-merge.yml'
}

$workflowContent = Get-Content $workflowPath -Raw

$requiredSnippets = @(
    'name: "BaseCoat - Agent Merge"',
    'duplicate agent name',
    'conflicting tool permissions',
    'Agent Merge Changelog',
    'eval.yaml',
    'agent-merge-changelog',
    'rollback_ref',
    'rollback_apply',
    'agent-merge-rollback.patch'
)

foreach ($snippet in $requiredSnippets) {
    if ($workflowContent -notmatch [regex]::Escape($snippet)) {
        throw "Agent merge workflow is missing required snippet: $snippet"
    }
}

Write-Host 'Agent merge workflow test passed' -ForegroundColor Green

