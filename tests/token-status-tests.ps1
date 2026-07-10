#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests for token-status cost observability command.
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running token-status tests...'

$failures = @()

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        $script:failures += $Message
    }
}

# Test 1: JSON output exposes required fields and computes remaining budget
$json = pwsh -NoProfile -File (Join-Path $repoRoot 'scripts\token-status.ps1') `
    -InputTokens 1200 -OutputTokens 12 -Events 40 -ElapsedMinutes 5 -TokenBudget 5000 -Json
$status = ($json -join "`n") | ConvertFrom-Json

Assert-True ($status.inputTokens -eq 1200) 'Expected inputTokens to be 1200'
Assert-True ($status.outputTokens -eq 12) 'Expected outputTokens to be 12'
Assert-True ($status.eventCount -eq 40) 'Expected eventCount to be 40'
Assert-True ($status.inputOutputRatio -eq '100x') 'Expected input/output ratio to be 100x'
Assert-True ($status.estimatedRemainingBudget -eq 3800) 'Expected remaining budget to be 3800'
Assert-True (-not $status.autoCompactTriggered) 'Expected autoCompactTriggered to be false below thresholds'

# Test 2: Auto-compact is triggered at event threshold (>=400)
$json = pwsh -NoProfile -File (Join-Path $repoRoot 'scripts\token-status.ps1') `
    -InputTokens 5000 -OutputTokens 100 -Events 400 -ElapsedMinutes 10 -Json
$status = ($json -join "`n") | ConvertFrom-Json

Assert-True ($status.autoCompactTriggered) 'Expected autoCompactTriggered at 400 events'
Assert-True ($status.autoCompactReasons -contains 'event-count>=400') 'Expected event threshold reason in autoCompactReasons'

# Test 3: Auto-compact is triggered at token threshold (>=50M)
$json = pwsh -NoProfile -File (Join-Path $repoRoot 'scripts\token-status.ps1') `
    -InputTokens 50000000 -OutputTokens 250000 -Events 25 -ElapsedMinutes 12 -Json
$status = ($json -join "`n") | ConvertFrom-Json

Assert-True ($status.autoCompactTriggered) 'Expected autoCompactTriggered at 50M input tokens'
Assert-True ($status.autoCompactReasons -contains 'input-tokens>=50000000') 'Expected token threshold reason in autoCompactReasons'

# Test 4: Warning markers are emitted for issue thresholds (ratio>=300x, events>=500, tokens>=50M)
$json = pwsh -NoProfile -File (Join-Path $repoRoot 'scripts\token-status.ps1') `
    -InputTokens 60000000 -OutputTokens 100000 -Events 500 -ElapsedMinutes 35 -Json
$status = ($json -join "`n") | ConvertFrom-Json

Assert-True ($status.warnings.Count -ge 3) 'Expected at least three warnings when all thresholds are crossed'
$markerCount = @($status.markers | Where-Object { $_ -match '^\[COST-WARN\]' }).Count
Assert-True ($markerCount -ge 3) 'Expected warning markers prefixed with [COST-WARN]'

# Test 5: Input file is accepted and merged into status calculations
$tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ("token-status-test-" + [Guid]::NewGuid().ToString() + '.json')
try {
    @'
{
  "inputTokens": 2000,
  "outputTokens": 20,
  "events": 10,
  "elapsedMinutes": 3,
  "tokenBudget": 6000
}
'@ | Set-Content -Path $tempFile -Encoding UTF8

    $json = pwsh -NoProfile -File (Join-Path $repoRoot 'scripts\token-status.ps1') -InputFile $tempFile -Json
    $status = ($json -join "`n") | ConvertFrom-Json

    Assert-True ($status.inputTokens -eq 2000) 'Expected inputTokens to be loaded from file'
    Assert-True ($status.outputTokens -eq 20) 'Expected outputTokens to be loaded from file'
    Assert-True ($status.eventCount -eq 10) 'Expected eventCount to be loaded from file'
    Assert-True ($status.tokenBudget -eq 6000) 'Expected tokenBudget to be loaded from file'
    Assert-True ($status.estimatedRemainingBudget -eq 4000) 'Expected remaining budget from input file values'
}
finally {
    if (Test-Path $tempFile) {
        Remove-Item -Path $tempFile -Force
    }
}

if ($failures.Count -gt 0) {
    Write-Host "token-status tests FAILED ($($failures.Count) issue(s))" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'token-status tests passed' -ForegroundColor Green
exit 0
