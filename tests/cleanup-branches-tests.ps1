#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$scriptPath = Join-Path $repoRoot 'scripts\cleanup-branches.ps1'
$workflowPath = Join-Path $repoRoot '.github\workflows\sprint-closeout-branch-audit.yml'

if (-not (Test-Path $scriptPath)) {
    throw 'Cleanup script is missing: scripts/cleanup-branches.ps1'
}

if (-not (Test-Path $workflowPath)) {
    throw 'Branch audit workflow is missing: .github/workflows/sprint-closeout-branch-audit.yml'
}

$scriptContent = Get-Content $scriptPath -Raw
$workflowContent = Get-Content $workflowPath -Raw

$requiredScriptSnippets = @(
    'param(',
    '[int]$StaleDays = 30',
    '[switch]$ApplyChanges',
    'git for-each-ref refs/remotes/origin',
    'git branch -r --merged',
    'gh pr list --state open',
    'GITHUB_STEP_SUMMARY'
)

foreach ($snippet in $requiredScriptSnippets) {
    if ($scriptContent -notmatch [regex]::Escape($snippet)) {
        throw "Cleanup script is missing required snippet: $snippet"
    }
}

$requiredWorkflowSnippets = @(
    'schedule:',
    'workflow_dispatch:',
    'apply_changes',
    'stale_days',
    'contents: write',
    'timeout-minutes: 20',
    'group: ${{ github.workflow }}-${{ github.ref }}',
    'scripts/cleanup-branches.ps1'
)

foreach ($snippet in $requiredWorkflowSnippets) {
    if ($workflowContent -notmatch [regex]::Escape($snippet)) {
        throw "Branch audit workflow is missing required snippet: $snippet"
    }
}

if ($workflowContent -notmatch 'name:\s*"?BaseCoat\s*-\s*Sprint Closeout Branch Audit"?' ) {
    throw 'Branch audit workflow is missing required BaseCoat-prefixed workflow name'
}

if ($workflowContent -notmatch 'uses:\s*actions/checkout@[a-f0-9]{40}') {
    throw 'Branch audit workflow must pin actions/checkout to a full commit SHA'
}

Write-Host 'cleanup-branches tests passed' -ForegroundColor Green
