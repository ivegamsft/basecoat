#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Contract tests for Responsible AI and privacy planning and review.
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$skillPath = Join-Path $repoRoot 'skills\rai-privacy-review\SKILL.md'
$evalPath = Join-Path $repoRoot 'skills\rai-privacy-review\eval.yaml'

Write-Host 'Running RAI/privacy review contract tests...'

$failures = @()
foreach ($path in @($skillPath, $evalPath)) {
    if (-not (Test-Path $path)) {
        $failures += "missing $($path.Replace($repoRoot, '').TrimStart('\'))"
    }
}

if (Test-Path $skillPath) {
    $skill = Get-Content $skillPath -Raw
    foreach ($requiredText in @(
        'Trigger Model',
        'No review is needed',
        'no-review-needed',
        'artifact_type: rai-privacy-plan',
        'intended_use:',
        'data_classes:',
        'affected_users:',
        'automation_role:',
        'mitigations:',
        'review_owner:',
        'artifact_type: rai-privacy-review',
        'decision: <allow|revise|block|defer>',
        'Missing data classification',
        'not legal'
    )) {
        if ($skill -notmatch [regex]::Escape($requiredText)) {
            $failures += "RAI/privacy skill missing '$requiredText'"
        }
    }
}

$cases = @(
    @{ Name = 'low-risk-docs'; Triggered = $false; DataClasses = @(); HighRiskMitigation = $true; Expected = 'no-review-needed' },
    @{ Name = 'user-recommendation'; Triggered = $true; DataClasses = @('customer-data'); HighRiskMitigation = $true; Expected = 'allow' },
    @{ Name = 'missing-classification'; Triggered = $true; DataClasses = @(); HighRiskMitigation = $true; Expected = 'block' },
    @{ Name = 'missing-high-risk-mitigation'; Triggered = $true; DataClasses = @('sensitive-data'); HighRiskMitigation = $false; Expected = 'block' }
)

function Get-RaiPrivacyDecision {
    param([hashtable]$Case)

    if (-not $Case.Triggered) { return 'no-review-needed' }
    if ($Case.DataClasses.Count -eq 0) { return 'block' }
    if (-not $Case.HighRiskMitigation) { return 'block' }
    return 'allow'
}

foreach ($case in $cases) {
    $actual = Get-RaiPrivacyDecision $case
    if ($actual -ne $case.Expected) {
        $failures += "$($case.Name) expected $($case.Expected), got $actual"
    }
}

if (Test-Path $evalPath) {
    $eval = Get-Content $evalPath -Raw
    foreach ($requiredText in @('expect_activation: true', 'expect_activation: false', 'customer-facing', 'read-only internal guide')) {
        if ($eval -notmatch [regex]::Escape($requiredText)) {
            $failures += "RAI/privacy eval missing '$requiredText'"
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'RAI/privacy review contract FAILED.' -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'RAI/privacy review contract passed.' -ForegroundColor Green
