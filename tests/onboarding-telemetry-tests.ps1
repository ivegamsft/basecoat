#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$skillPath = Join-Path $repoRoot 'skills\onboarding-telemetry\SKILL.md'
$evalPath = Join-Path $repoRoot 'skills\onboarding-telemetry\eval.yaml'

$failures = @()

foreach ($path in @($skillPath, $evalPath)) {
    if (-not (Test-Path $path)) {
        $failures += "missing $($path.Replace($repoRoot, '').TrimStart('\'))"
    }
}

if (Test-Path $skillPath) {
    $skill = Get-Content $skillPath -Raw
    foreach ($required in @(
        'tool_use: required',
        'allowed-tools:',
        '  - gh',
        '## Execution Modes',
        '### Execute Mode',
        '### Advisory Mode',
        'run URL or ID',
        'must not claim they occurred'
    )) {
        if ($skill -notmatch [regex]::Escape($required)) {
            $failures += "onboarding telemetry skill missing '$required'"
        }
    }

    if ($skill -match '(?m)^\s*tool_use:\s+optional\s*$') {
        $failures += 'onboarding telemetry execution must not declare tool_use optional'
    }
}

if (Test-Path $evalPath) {
    $eval = Get-Content $evalPath -Raw
    foreach ($required in @(
        'ready-state-validation',
        'expected_tools:',
        '      - gh',
        'advisory-tool-free-readiness',
        'expected_tools: []',
        'does not claim the workflow was dispatched'
    )) {
        if ($eval -notmatch [regex]::Escape($required)) {
            $failures += "onboarding telemetry eval missing '$required'"
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'Onboarding telemetry contract tests FAILED.' -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'Onboarding telemetry contract tests passed.' -ForegroundColor Green
