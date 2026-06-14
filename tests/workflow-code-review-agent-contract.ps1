#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Contract gate for code-review-agent model pinning.

.DESCRIPTION
    Prevents regression where repo-level model variables select unsupported
    Copilot models and crash the code-review-agent workflow.
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$lockPaths = @(
    (Join-Path $repoRoot '.github/workflows/code-review-agent.lock.yml'),
    (Join-Path $repoRoot '.github/base-coat/workflows/code-review-agent.lock.yml')
)

$failures = @()

foreach ($path in $lockPaths) {
    if (-not (Test-Path $path)) {
        $failures += "Missing workflow lock file: $path"
        continue
    }

    $content = Get-Content $path -Raw

    if ($content -match 'GH_AW_MODEL_AGENT_COPILOT' -or $content -match 'GH_AW_MODEL_DETECTION_COPILOT') {
        $failures += "Model variable override still present: $path"
    }

    $infoModelMatches = [regex]::Matches($content, 'GH_AW_INFO_MODEL:\s*"gpt-5-mini"').Count
    if ($infoModelMatches -lt 1) {
        $failures += "Missing pinned GH_AW_INFO_MODEL in: $path"
    }

    $copilotModelMatches = [regex]::Matches($content, 'COPILOT_MODEL:\s*"gpt-5-mini"').Count
    if ($copilotModelMatches -lt 2) {
        $failures += "Expected at least 2 pinned COPILOT_MODEL entries in: $path"
    }
}

Write-Host 'Running code-review-agent workflow contract checks...'

if ($failures.Count -gt 0) {
    Write-Host 'Code-review-agent workflow contract FAILED.' -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'Code-review-agent workflow contract passed.' -ForegroundColor Green
exit 0
