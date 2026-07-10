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
    'name: "BaseCoat - Agent Merge Automation"',
    'Duplicate merged agent name',
    'Tool permission conflict for merged agent',
    'Agent Merge Frontmatter Changelog',
    'eval.yaml',
    '<!-- agent-merge-changelog -->',
    'mode == ''rollback''',
    'agent-merge-rollback-${{ github.run_id }}',
    'gh pr create'
)

foreach ($snippet in $requiredSnippets) {
    if ($workflowContent -notmatch [regex]::Escape($snippet)) {
        throw "Agent merge workflow is missing required snippet: $snippet"
    }
}

Write-Host 'Agent merge workflow test passed' -ForegroundColor Green

