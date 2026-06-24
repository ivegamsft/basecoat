#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$workflowPath = Join-Path $repoRoot '.github\workflows\pr-flow-hygiene.yml'
if (-not (Test-Path $workflowPath)) {
    throw 'PR flow hygiene workflow is missing: .github/workflows/pr-flow-hygiene.yml'
}

$workflowContent = Get-Content $workflowPath -Raw

$requiredSnippets = @(
    'name: "BaseCoat - PR Flow Hygiene"',
    'pull_request_target:',
    'ready_for_review',
    'review_requested',
    'review_request_removed',
    'assigned',
    'unassigned',
    'labeled',
    'unlabeled',
    'schedule:',
    'workflow_dispatch:',
    'pr_number:',
    'wip_limit',
    'draft_drift_days',
    'ready_stale_days',
    'max_items',
    'issues: write',
    'pull-requests: write',
    'timeout-minutes: 20',
    'group: ${{ github.workflow }}-${{ github.ref }}',
    'actions/github-script@3a2844b7e9c422d3c10d287c895573f7108da1b3',
    'PR_NUMBER_INPUT',
    'PR readiness routing nudge',
    'pr-readiness-blocked',
    'const isHotfixBranch = ref => /^hotfix\//i.test(String(ref || ''''))',
    'Hotfix fast path',
    'Event-driven readiness checks run on pull_request_target transitions; this weekly report is summary/audit only.',
    'PR Lifecycle Hygiene Report - Week of',
    'PR lifecycle hygiene nudge'
)

foreach ($snippet in $requiredSnippets) {
    if ($workflowContent -notmatch [regex]::Escape($snippet)) {
        throw "PR flow hygiene workflow is missing required snippet: $snippet"
    }
}

Write-Host 'pr-flow-hygiene tests passed' -ForegroundColor Green
