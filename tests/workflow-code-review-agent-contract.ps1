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
$infoModelPattern = '(?m)^[ \t]*GH_AW_INFO_MODEL:[ \t]*(?:"gpt-5-mini"|gpt-5-mini)[ \t]*\r?$'
$copilotModelPattern = '(?m)^[ \t]*COPILOT_MODEL:[ \t]*(?:"gpt-5-mini"|gpt-5-mini)[ \t]*\r?$'

foreach ($path in $lockPaths) {
    if (-not (Test-Path $path)) {
        $failures += "Missing workflow lock file: $path"
        continue
    }

    $content = Get-Content $path -Raw

    if ($content -match 'GH_AW_MODEL_AGENT_COPILOT' -or $content -match 'GH_AW_MODEL_DETECTION_COPILOT') {
        $failures += "Model variable override still present: $path"
    }

    $infoModelMatches = [regex]::Matches($content, $infoModelPattern).Count
    if ($infoModelMatches -ne 1) {
        $failures += "Expected exactly 1 pinned GH_AW_INFO_MODEL in $path; found $infoModelMatches"
    }

    $copilotModelMatches = [regex]::Matches($content, $copilotModelPattern).Count
    if ($copilotModelMatches -ne 2) {
        $failures += "Expected exactly 2 pinned COPILOT_MODEL entries in $path; found $copilotModelMatches"
    }
}

$invalidModelFixtures = @(
    'gpt-5-mini"',
    '"gpt-5-mini',
    'gpt-5-mini-extra',
    '"gpt-5-mini-extra"'
)

foreach ($invalidModel in $invalidModelFixtures) {
    if ([regex]::IsMatch("GH_AW_INFO_MODEL: $invalidModel", $infoModelPattern)) {
        $failures += "GH_AW_INFO_MODEL regex accepted malformed value: $invalidModel"
    }
    if ([regex]::IsMatch("COPILOT_MODEL: $invalidModel", $copilotModelPattern)) {
        $failures += "COPILOT_MODEL regex accepted malformed value: $invalidModel"
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
