#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests for token-cost-compare scenario and cost calculations.
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running token-cost-compare tests...'

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

$tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ("token-cost-compare-test-" + [Guid]::NewGuid().ToString() + '.json')
try {
    @'
{
  "scenarios": [
    {
      "name": "baseline",
      "inputTokens": 3000000,
      "cachedInputTokens": 0,
      "outputTokens": 500000
    },
    {
      "name": "cached-heavy",
      "inputTokens": 1000000,
      "cachedInputTokens": 2000000,
      "outputTokens": 500000
    },
    {
      "name": "output-heavy",
      "inputTokens": 1000000,
      "cachedInputTokens": 0,
      "outputTokens": 1000000
    }
  ]
}
'@ | Set-Content -Path $tempFile -Encoding UTF8

    $json = pwsh -NoProfile -File (Join-Path $repoRoot 'scripts' 'token-cost-compare.ps1') `
        -InputFile $tempFile `
        -FreshInputCostPer1M 1.0 `
        -CachedInputCostPer1M 0.1 `
        -OutputCostPer1M 4.0 `
        -Json
    if ($LASTEXITCODE -ne 0) {
        $exitCode = $LASTEXITCODE
        throw "token-cost-compare.ps1 exited with code ${exitCode}: $($json -join "`n")"
    }

    $report = ($json -join "`n") | ConvertFrom-Json

    Assert-True ($report.scenarioCount -eq 3) 'Expected three scenarios in report'
    Assert-True ($report.baseline -eq 'baseline') 'Expected baseline scenario to be "baseline"'

    $baseline = @($report.scenarios | Where-Object { $_.name -eq 'baseline' })[0]
    $cachedHeavy = @($report.scenarios | Where-Object { $_.name -eq 'cached-heavy' })[0]
    $outputHeavy = @($report.scenarios | Where-Object { $_.name -eq 'output-heavy' })[0]

    Assert-True ($baseline.totalCost -eq 5.0) 'Expected baseline total cost to be 5.0'
    Assert-True ([math]::Abs($cachedHeavy.totalCost - 3.2) -lt 0.000001) 'Expected cached-heavy total cost to be 3.2'
    Assert-True ($outputHeavy.totalCost -eq 5.0) 'Expected output-heavy total cost to be 5.0'

    $cachedComparison = @($report.comparison | Where-Object { $_.name -eq 'cached-heavy' })[0]
    $outputComparison = @($report.comparison | Where-Object { $_.name -eq 'output-heavy' })[0]

    Assert-True ([math]::Abs($cachedComparison.deltaCostVsBaseline - (-1.8)) -lt 0.000001) 'Expected cached-heavy delta cost to be -1.8'
    Assert-True ($cachedComparison.deltaPercentVsBaseline -eq -36.0) 'Expected cached-heavy percent delta to be -36%'
    Assert-True ([math]::Abs($outputComparison.deltaCostVsBaseline) -lt 0.000001) 'Expected output-heavy delta cost to be 0.0'
}
finally {
    if (Test-Path $tempFile) {
        Remove-Item -Path $tempFile -Force
    }
}

# Zero-baseline: deltaPercentVsBaseline must be null when baseline cost is 0 but delta is non-zero
$tempFileZero = Join-Path ([System.IO.Path]::GetTempPath()) ("token-cost-compare-zero-" + [Guid]::NewGuid().ToString() + '.json')
try {
    @'
{
  "scenarios": [
    {
      "name": "baseline",
      "inputTokens": 0,
      "cachedInputTokens": 0,
      "outputTokens": 0
    },
    {
      "name": "non-zero",
      "inputTokens": 1000000,
      "cachedInputTokens": 0,
      "outputTokens": 0
    }
  ]
}
'@ | Set-Content -Path $tempFileZero -Encoding UTF8

    $jsonZero = pwsh -NoProfile -File (Join-Path $repoRoot 'scripts' 'token-cost-compare.ps1') `
        -InputFile $tempFileZero `
        -FreshInputCostPer1M 1.0 `
        -CachedInputCostPer1M 0.1 `
        -OutputCostPer1M 4.0 `
        -Json
    if ($LASTEXITCODE -ne 0) {
        $exitCode = $LASTEXITCODE
        throw "token-cost-compare.ps1 (zero-baseline) exited with code ${exitCode}: $($jsonZero -join "`n")"
    }

    $reportZero = ($jsonZero -join "`n") | ConvertFrom-Json
    $nonZeroComparison = @($reportZero.comparison | Where-Object { $_.name -eq 'non-zero' })[0]

    Assert-True ($nonZeroComparison.deltaPercentVsBaseline -eq $null) 'Expected deltaPercentVsBaseline to be null when baseline cost is 0 and delta is non-zero'
    Assert-True ($nonZeroComparison.deltaCostVsBaseline -gt 0) 'Expected non-zero delta cost when baseline is 0 and compared scenario has tokens'

    $baselineZeroComparison = @($reportZero.comparison | Where-Object { $_.name -eq 'baseline' })[0]
    Assert-True ($baselineZeroComparison.deltaPercentVsBaseline -eq 0.0) 'Expected deltaPercentVsBaseline to be 0.0 when both baseline and compared cost are 0'
}
finally {
    if (Test-Path $tempFileZero) {
        Remove-Item -Path $tempFileZero -Force
    }
}

if ($failures.Count -gt 0) {
    Write-Host "token-cost-compare tests FAILED ($($failures.Count) issue(s))" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'token-cost-compare tests passed' -ForegroundColor Green
exit 0
