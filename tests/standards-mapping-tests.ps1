#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Contract tests for the advisory standards-mapping layer.
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$taxonomyPath = Join-Path $repoRoot 'docs\reference\governance\standards-mapping-taxonomy.json'
$referencePath = Join-Path $repoRoot 'docs\reference\governance\standards-mapping.md'
$skillPath = Join-Path $repoRoot 'skills\standards-mapping\SKILL.md'
$evalPath = Join-Path $repoRoot 'skills\standards-mapping\eval.yaml'

Write-Host 'Running standards mapping contract tests...'

$failures = @()

foreach ($path in @($taxonomyPath, $referencePath, $skillPath, $evalPath)) {
    if (-not (Test-Path $path)) {
        $failures += "missing $($path.Replace($repoRoot, '').TrimStart('\'))"
    }
}

if (Test-Path $taxonomyPath) {
    try {
        $taxonomy = Get-Content $taxonomyPath -Raw | ConvertFrom-Json
    } catch {
        $failures += "taxonomy JSON is invalid: $($_.Exception.Message)"
        $taxonomy = $null
    }

    if ($taxonomy) {
        foreach ($frameworkId in @('owasp', 'nist-csf', 'microsoft-caf', 'microsoft-waf', 'nist-ai-rmf')) {
            $framework = @($taxonomy.supportedFrameworks | Where-Object { $_.id -eq $frameworkId })
            if ($framework.Count -ne 1) {
                $failures += "taxonomy must contain exactly one '$frameworkId' framework entry"
                continue
            }

            if (-not $framework[0].freshnessDate) {
                $failures += "framework '$frameworkId' must define freshnessDate"
            }

            if (-not $framework[0].allowedCitationMode -or $framework[0].allowedCitationMode -notmatch 'BaseCoat-owned summaries') {
                $failures += "framework '$frameworkId' must constrain citations to safe summaries"
            }

            if (@($framework[0].categories).Count -lt 1) {
                $failures += "framework '$frameworkId' must define at least one category"
            }
        }

        foreach ($status in @('covered', 'partial', 'gap', 'not-applicable')) {
            $outcome = @($taxonomy.sampleOutcomes | Where-Object { $_.coverageStatus -eq $status })
            if ($outcome.Count -lt 1) {
                $failures += "taxonomy sampleOutcomes must include '$status'"
            }
        }

        if ($taxonomy.advisoryDisclaimer -notmatch 'not compliance attestations') {
            $failures += 'taxonomy disclaimer must state mappings are not compliance attestations'
        }
    }
}

if (Test-Path $referencePath) {
    $reference = Get-Content $referencePath -Raw
    foreach ($requiredText in @(
        'Input Contract',
        'Output Contract',
        'Unknown framework IDs must fail',
        'Missing evidence must be reported as `gap`',
        'not compliance attestations'
    )) {
        if ($reference -notmatch [regex]::Escape($requiredText)) {
            $failures += "standards mapping reference missing '$requiredText'"
        }
    }
}

if (Test-Path $skillPath) {
    $skill = Get-Content $skillPath -Raw
    foreach ($requiredText in @(
        'USE FOR:',
        'DO NOT USE FOR:',
        'standards-mapping-taxonomy.json',
        'covered',
        'partial',
        'gap',
        'not-applicable',
        'Unknown framework',
        'Stale taxonomy entry',
        'not compliance'
    )) {
        if ($skill -notmatch [regex]::Escape($requiredText)) {
            $failures += "standards-mapping skill missing '$requiredText'"
        }
    }
}

if (Test-Path $evalPath) {
    $eval = Get-Content $evalPath -Raw
    foreach ($requiredText in @(
        'expect_activation: true',
        'expect_activation: false',
        'OWASP',
        'NIST AI RMF',
        'Certify that this system is compliant'
    )) {
        if ($eval -notmatch [regex]::Escape($requiredText)) {
            $failures += "standards-mapping eval missing '$requiredText'"
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'Standards mapping contract FAILED.' -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'Standards mapping contract passed.' -ForegroundColor Green
