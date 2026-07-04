#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Compares token volume and estimated cost across multiple scenarios.

.DESCRIPTION
    Accepts scenario inputs from JSON and computes per-scenario cost using
    configurable rates for fresh input, cached input, and output tokens.
    Intended for evidence-based cost discussions and CI-safe comparisons.

.PARAMETER InputFile
    JSON file containing either a raw JSON array of scenarios, or an object
    with a top-level "scenarios" property that holds the array.
    Each scenario supports:
      - name (required)
      - inputTokens (optional, default 0)
      - cachedInputTokens (optional, default 0)
      - outputTokens (optional, default 0)

.PARAMETER FreshInputCostPer1M
    Cost per 1M fresh input tokens. Default: 1.0

.PARAMETER CachedInputCostPer1M
    Cost per 1M cached input tokens. Default: 0.1

.PARAMETER OutputCostPer1M
    Cost per 1M output tokens. Default: 4.0

.PARAMETER Json
    Emit structured JSON output.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,
    [double]$FreshInputCostPer1M = 1.0,
    [double]$CachedInputCostPer1M = 0.1,
    [double]$OutputCostPer1M = 4.0,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $InputFile)) {
    throw "Input file not found: $InputFile"
}

if ($FreshInputCostPer1M -lt 0 -or $CachedInputCostPer1M -lt 0 -or $OutputCostPer1M -lt 0) {
    throw 'Cost rates must be non-negative.'
}

$raw = Get-Content -LiteralPath $InputFile -Raw
$payload = $raw | ConvertFrom-Json

$scenarios = @()
if ($payload -is [System.Array]) {
    $scenarios = @($payload)
}
elseif ($null -ne $payload.scenarios) {
    $scenarios = @($payload.scenarios)
}
else {
    throw 'Input JSON must be an array or contain a top-level "scenarios" array.'
}

if ($scenarios.Count -eq 0) {
    throw 'At least one scenario is required.'
}

function Get-ScenarioLong {
    param(
        [Parameter(Mandatory = $true)]$Scenario,
        [Parameter(Mandatory = $true)][string]$FieldName
    )

    if ($null -eq $Scenario.PSObject.Properties[$FieldName]) {
        return 0L
    }

    $value = $Scenario.PSObject.Properties[$FieldName].Value
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
        return 0L
    }

    return [long]$value
}

$results = @()
foreach ($scenario in $scenarios) {
    if (-not $scenario.name) {
        throw 'Every scenario requires a "name".'
    }

    $inputTokens = Get-ScenarioLong -Scenario $scenario -FieldName 'inputTokens'
    $cachedInputTokens = Get-ScenarioLong -Scenario $scenario -FieldName 'cachedInputTokens'
    $outputTokens = Get-ScenarioLong -Scenario $scenario -FieldName 'outputTokens'

    if ($inputTokens -lt 0 -or $cachedInputTokens -lt 0 -or $outputTokens -lt 0) {
        throw "Scenario '$($scenario.name)' has negative token values."
    }

    $inputCost = [math]::Round(($inputTokens / 1000000.0) * $FreshInputCostPer1M, 6)
    $cachedInputCost = [math]::Round(($cachedInputTokens / 1000000.0) * $CachedInputCostPer1M, 6)
    $outputCost = [math]::Round(($outputTokens / 1000000.0) * $OutputCostPer1M, 6)
    $totalCost = [math]::Round($inputCost + $cachedInputCost + $outputCost, 6)

    $results += [ordered]@{
        name = [string]$scenario.name
        inputTokens = $inputTokens
        cachedInputTokens = $cachedInputTokens
        outputTokens = $outputTokens
        totalTokens = ($inputTokens + $cachedInputTokens + $outputTokens)
        inputCost = $inputCost
        cachedInputCost = $cachedInputCost
        outputCost = $outputCost
        totalCost = $totalCost
    }
}

$baselineEntry = $results | Where-Object { $_.name -eq 'baseline' } | Select-Object -First 1
$baseline = if ($baselineEntry) { $baselineEntry } else { $results[0] }
$comparison = foreach ($result in $results) {
    $deltaCost = [math]::Round($result.totalCost - $baseline.totalCost, 6)
    $deltaPercent = if ($baseline.totalCost -gt 0) {
        [math]::Round((($result.totalCost - $baseline.totalCost) / $baseline.totalCost) * 100.0, 2)
    }
    elseif ($deltaCost -eq 0) {
        0.0
    }
    else {
        $null
    }

    [ordered]@{
        name = $result.name
        totalTokens = $result.totalTokens
        totalCost = $result.totalCost
        deltaCostVsBaseline = $deltaCost
        deltaPercentVsBaseline = $deltaPercent
    }
}

$report = [ordered]@{
    pricing = [ordered]@{
        freshInputCostPer1M = $FreshInputCostPer1M
        cachedInputCostPer1M = $CachedInputCostPer1M
        outputCostPer1M = $OutputCostPer1M
    }
    scenarioCount = $results.Count
    baseline = $baseline.name
    scenarios = @($results)
    comparison = @($comparison)
}

if ($Json) {
    $report | ConvertTo-Json -Depth 6
    exit 0
}

Write-Host 'Token Cost Comparison'
Write-Host '---------------------'
Write-Host "Rates (per 1M): fresh-input=$FreshInputCostPer1M cached-input=$CachedInputCostPer1M output=$OutputCostPer1M"
Write-Host ''
foreach ($entry in $report.comparison) {
    Write-Host ("{0}: tokens={1}, cost={2}, delta={3} ({4}%)" -f $entry.name, $entry.totalTokens, $entry.totalCost, $entry.deltaCostVsBaseline, $entry.deltaPercentVsBaseline)
}

exit 0
