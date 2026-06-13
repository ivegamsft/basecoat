#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Computes session token/event cost status and compaction signals.

.DESCRIPTION
    Sidecar command for cost-tracking observability in BaseCoat workflows.
    Reports token/event metrics, ratio, elapsed time, and remaining budget.
    Emits warning markers at configured thresholds and flags auto-compact
    when session cost crosses configured limits.

.PARAMETER InputTokens
    Input tokens sent so far in the session.

.PARAMETER OutputTokens
    Output tokens produced so far in the session.

.PARAMETER Events
    Event count accumulated in the session.

.PARAMETER ElapsedMinutes
    Elapsed session time in minutes.

.PARAMETER TokenBudget
    Token budget used to estimate remaining budget. Default: 50000000.

.PARAMETER InputFile
    Optional JSON file with metric fields. Supported keys:
    inputTokens, outputTokens, events, elapsedMinutes, tokenBudget.

.PARAMETER Json
    Output structured JSON.

.EXAMPLE
    pwsh scripts/token-status.ps1 -InputTokens 42000000 -OutputTokens 140000 -Events 380 -ElapsedMinutes 34

.EXAMPLE
    pwsh scripts/token-status.ps1 -InputFile .\session-metrics.json -Json | ConvertFrom-Json

.LINK
    https://github.com/IBuySpy-Shared/basecoat/issues/1363
#>

[CmdletBinding()]
param(
    [Nullable[long]]$InputTokens,
    [Nullable[long]]$OutputTokens,
    [Nullable[long]]$Events,
    [Nullable[double]]$ElapsedMinutes,
    [long]$TokenBudget = 50000000,
    [string]$InputFile,
    [long]$AutoCompactEventThreshold = 400,
    [long]$AutoCompactTokenThreshold = 50000000,
    [double]$WarningRatioThreshold = 300.0,
    [long]$WarningEventThreshold = 500,
    [long]$WarningTokenThreshold = 50000000,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LongFromSource {
    param(
        [string]$Name,
        [Nullable[long]]$ExplicitValue,
        [hashtable]$FileData,
        [string]$EnvName,
        [long]$DefaultValue = 0
    )

    if ($null -ne $ExplicitValue) {
        return [long]$ExplicitValue
    }

    if ($FileData.ContainsKey($Name) -and $null -ne $FileData[$Name]) {
        return [long]$FileData[$Name]
    }

    if ($EnvName) {
        $envValue = [System.Environment]::GetEnvironmentVariable($EnvName)
        if (-not [string]::IsNullOrWhiteSpace($envValue)) {
            return [long]$envValue
        }
    }

    return $DefaultValue
}

function Get-DoubleFromSource {
    param(
        [string]$Name,
        [Nullable[double]]$ExplicitValue,
        [hashtable]$FileData,
        [string]$EnvName,
        [double]$DefaultValue = 0.0
    )

    if ($null -ne $ExplicitValue) {
        return [double]$ExplicitValue
    }

    if ($FileData.ContainsKey($Name) -and $null -ne $FileData[$Name]) {
        return [double]$FileData[$Name]
    }

    if ($EnvName) {
        $envValue = [System.Environment]::GetEnvironmentVariable($EnvName)
        if (-not [string]::IsNullOrWhiteSpace($envValue)) {
            return [double]$envValue
        }
    }

    return $DefaultValue
}

$fileData = @{}
if ($InputFile) {
    if (-not (Test-Path $InputFile)) {
        throw "Input file not found: $InputFile"
    }

    $inputSnapshot = Get-Content -Path $InputFile -Raw | ConvertFrom-Json -AsHashtable
    foreach ($key in @('inputTokens', 'outputTokens', 'events', 'elapsedMinutes', 'tokenBudget')) {
        if ($inputSnapshot.ContainsKey($key)) {
            $fileData[$key] = $inputSnapshot[$key]
        }
    }
}

$resolvedInputTokens = Get-LongFromSource -Name 'inputTokens' -ExplicitValue $InputTokens -FileData $fileData -EnvName 'COPILOT_SESSION_INPUT_TOKENS'
$resolvedOutputTokens = Get-LongFromSource -Name 'outputTokens' -ExplicitValue $OutputTokens -FileData $fileData -EnvName 'COPILOT_SESSION_OUTPUT_TOKENS'
$resolvedEvents = Get-LongFromSource -Name 'events' -ExplicitValue $Events -FileData $fileData -EnvName 'COPILOT_SESSION_EVENTS'
$resolvedElapsedMinutes = Get-DoubleFromSource -Name 'elapsedMinutes' -ExplicitValue $ElapsedMinutes -FileData $fileData -EnvName 'COPILOT_SESSION_ELAPSED_MINUTES'

if (-not $PSBoundParameters.ContainsKey('TokenBudget') -and $fileData.ContainsKey('tokenBudget')) {
    $TokenBudget = [long]$fileData['tokenBudget']
}

if ($resolvedInputTokens -lt 0 -or $resolvedOutputTokens -lt 0 -or $resolvedEvents -lt 0) {
    throw 'InputTokens, OutputTokens, and Events must be non-negative.'
}
if ($resolvedElapsedMinutes -lt 0) {
    throw 'ElapsedMinutes must be non-negative.'
}
if ($TokenBudget -lt 0) {
    throw 'TokenBudget must be non-negative.'
}

$ratioDisplay = '0.00x'
$ratioForWarnings = 0.0
if ($resolvedOutputTokens -le 0) {
    if ($resolvedInputTokens -gt 0) {
        $ratioDisplay = 'Infinity'
        $ratioForWarnings = [double]::PositiveInfinity
    }
}
else {
    $ratioForWarnings = [math]::Round($resolvedInputTokens / [double]$resolvedOutputTokens, 2)
    $ratioDisplay = "$ratioForWarnings" + 'x'
}

$autoCompactReasons = [System.Collections.Generic.List[string]]::new()
if ($resolvedEvents -ge $AutoCompactEventThreshold) {
    $autoCompactReasons.Add("event-count>=$AutoCompactEventThreshold")
}
if ($resolvedInputTokens -ge $AutoCompactTokenThreshold) {
    $autoCompactReasons.Add("input-tokens>=$AutoCompactTokenThreshold")
}
$autoCompactTriggered = $autoCompactReasons.Count -gt 0

$warnings = [System.Collections.Generic.List[string]]::new()
if (($ratioForWarnings -ge $WarningRatioThreshold) -or ([double]::IsPositiveInfinity($ratioForWarnings) -and $resolvedInputTokens -gt 0)) {
    $warnings.Add("Input/output ratio exceeded threshold ($ratioDisplay >= ${WarningRatioThreshold}x).")
}
if ($resolvedEvents -ge $WarningEventThreshold) {
    $warnings.Add("Event count exceeded threshold ($resolvedEvents >= $WarningEventThreshold).")
}
if ($resolvedInputTokens -ge $WarningTokenThreshold) {
    $warnings.Add("Input token volume exceeded threshold ($resolvedInputTokens >= $WarningTokenThreshold).")
}

$markers = @($warnings | ForEach-Object { "[COST-WARN] $_" })

$estimatedRemainingBudget = [math]::Max([double]($TokenBudget - $resolvedInputTokens), 0.0)
$budgetConsumedPercent = if ($TokenBudget -gt 0) {
    [math]::Round(($resolvedInputTokens / [double]$TokenBudget) * 100.0, 2)
}
else {
    0.0
}

$recommendation = if ($autoCompactTriggered) {
    'Run /compact now and delegate low-signal scans to background agents.'
}
elseif ($warnings.Count -gt 0) {
    'Approaching or crossing expensive-session thresholds; compact at the next phase boundary.'
}
else {
    'Session is within configured cost thresholds.'
}

$result = [ordered]@{
    timestamp                = (Get-Date).ToString('o')
    inputTokens              = $resolvedInputTokens
    outputTokens             = $resolvedOutputTokens
    eventCount               = $resolvedEvents
    inputOutputRatio         = $ratioDisplay
    elapsedMinutes           = [math]::Round($resolvedElapsedMinutes, 2)
    tokenBudget              = $TokenBudget
    estimatedRemainingBudget = [math]::Round($estimatedRemainingBudget, 2)
    budgetConsumedPercent    = $budgetConsumedPercent
    autoCompactTriggered     = $autoCompactTriggered
    autoCompactReasons       = @($autoCompactReasons)
    autoCompactThresholds    = @{
        events = $AutoCompactEventThreshold
        tokens = $AutoCompactTokenThreshold
    }
    warningThresholds        = @{
        ratioX = $WarningRatioThreshold
        events = $WarningEventThreshold
        tokens = $WarningTokenThreshold
    }
    warnings                 = @($warnings)
    markers                  = $markers
    recommendation           = $recommendation
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
    exit 0
}

Write-Host 'Token Status'
Write-Host '------------'
Write-Host "Input tokens:               $($result.inputTokens)"
Write-Host "Output tokens:              $($result.outputTokens)"
Write-Host "Input/output ratio:         $($result.inputOutputRatio)"
Write-Host "Event count:                $($result.eventCount)"
Write-Host "Elapsed time (minutes):     $($result.elapsedMinutes)"
Write-Host "Token budget:               $($result.tokenBudget)"
Write-Host "Estimated remaining budget: $($result.estimatedRemainingBudget)"
Write-Host "Budget consumed:            $($result.budgetConsumedPercent)%"
Write-Host "Auto-compact:               $($result.autoCompactTriggered)"
if ($autoCompactTriggered) {
    Write-Host "Auto-compact reasons:       $($result.autoCompactReasons -join ', ')"
}

if ($result.markers.Count -gt 0) {
    Write-Host ''
    foreach ($marker in $result.markers) {
        Write-Host $marker -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host "Recommendation: $($result.recommendation)"
exit 0
