#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Evaluates #1361 backlog efficiency acceptance criteria from session metrics.

.DESCRIPTION
    Reads a JSON array of backlog-session records and computes whether the
    efficiency target is operationally met:
      - Next 5 sessions measured
      - Token target range (35M-45M) tracked
      - Practice compliance for compaction, template reuse, file references,
        and delegated triage/scan work

.PARAMETER InputFile
    Path to a JSON file containing an array of session objects.

.PARAMETER RequiredSessions
    Number of sessions required for scorecard readiness. Default: 5.

.PARAMETER TargetMinTokens
    Lower bound for in-target session token count. Default: 35000000.

.PARAMETER TargetMaxTokens
    Upper bound for in-target session token count. Default: 45000000.

.PARAMETER Json
    Emit machine-readable JSON output.

.EXAMPLE
    pwsh scripts/backlog-efficiency-scorecard.ps1 -InputFile docs/templates/backlog-efficiency-sessions.example.json

.EXAMPLE
    pwsh scripts/backlog-efficiency-scorecard.ps1 -InputFile .\session-metrics.json -Json | ConvertFrom-Json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,
    [int]$RequiredSessions = 5,
    [long]$TargetMinTokens = 35000000,
    [long]$TargetMaxTokens = 45000000,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -Path $InputFile)) {
    throw "Input file not found: $InputFile"
}
if ($RequiredSessions -le 0) {
    throw 'RequiredSessions must be greater than 0.'
}
if ($TargetMinTokens -lt 0 -or $TargetMaxTokens -lt 0) {
    throw 'Token targets must be non-negative.'
}
if ($TargetMaxTokens -lt $TargetMinTokens) {
    throw 'TargetMaxTokens must be greater than or equal to TargetMinTokens.'
}

$sessions = Get-Content -Path $InputFile -Raw | ConvertFrom-Json
if ($null -eq $sessions) {
    throw 'Input file must contain a JSON array of session records.'
}

$sessionList = @($sessions)
foreach ($session in $sessionList) {
    foreach ($requiredField in @(
        'sessionId',
        'inputTokens',
        'phaseCompactionApplied',
        'sprintTemplateUsed',
        'fileReferencesOnly',
        'delegatedScanOrTriage'
    )) {
        if (-not ($session.PSObject.Properties.Name -contains $requiredField)) {
            throw "Session record is missing required field: $requiredField"
        }
    }
}

$sessionCount = $sessionList.Count
$measurementReady = $sessionCount -ge $RequiredSessions
$sessionsForTarget = @($sessionList | Select-Object -First $RequiredSessions)
$inTargetSessions = @(
    $sessionsForTarget | Where-Object {
        [long]$_.inputTokens -ge $TargetMinTokens -and [long]$_.inputTokens -le $TargetMaxTokens
    }
)

$averageTokens = if ($sessionsForTarget.Count -gt 0) {
    [math]::Round((($sessionsForTarget | Measure-Object -Property inputTokens -Average).Average), 2)
}
else {
    0
}

$targetMet = $measurementReady -and ($averageTokens -ge $TargetMinTokens) -and ($averageTokens -le $TargetMaxTokens)

$practiceStats = [ordered]@{
    phaseCompactionApplied = [ordered]@{
        compliant = @($sessionsForTarget | Where-Object { $_.phaseCompactionApplied }).Count
        total     = $sessionsForTarget.Count
    }
    sprintTemplateUsed     = [ordered]@{
        compliant = @($sessionsForTarget | Where-Object { $_.sprintTemplateUsed }).Count
        total     = $sessionsForTarget.Count
    }
    fileReferencesOnly     = [ordered]@{
        compliant = @($sessionsForTarget | Where-Object { $_.fileReferencesOnly }).Count
        total     = $sessionsForTarget.Count
    }
    delegatedScanOrTriage  = [ordered]@{
        compliant = @($sessionsForTarget | Where-Object { $_.delegatedScanOrTriage }).Count
        total     = $sessionsForTarget.Count
    }
}

$allPracticesCompliant = $true
foreach ($practiceName in $practiceStats.Keys) {
    $practice = $practiceStats[$practiceName]
    $practice['compliancePercent'] = if ($practice.total -gt 0) {
        [math]::Round(($practice.compliant / [double]$practice.total) * 100.0, 2)
    }
    else {
        0.0
    }

    if ($practice.compliant -ne $practice.total) {
        $allPracticesCompliant = $false
    }
}

$result = [ordered]@{
    timestamp                   = (Get-Date).ToString('o')
    requiredSessions            = $RequiredSessions
    measuredSessions            = $sessionCount
    measurementReady            = $measurementReady
    evaluatedSessions           = $sessionsForTarget.Count
    tokenTarget                 = [ordered]@{
        minTokens = $TargetMinTokens
        maxTokens = $TargetMaxTokens
    }
    averageTokens               = $averageTokens
    inTargetSessionCount        = $inTargetSessions.Count
    targetMetByAverage          = $targetMet
    practices                   = $practiceStats
    allPracticesCompliant       = $allPracticesCompliant
    overallPass                 = $measurementReady -and $targetMet -and $allPracticesCompliant
    recommendation              = if (-not $measurementReady) {
        "Collect at least $RequiredSessions backlog sessions before evaluating pass/fail."
    }
    elseif (-not $targetMet) {
        'Token target is outside 35M-45M average. Apply compact/template/delegation controls before next run.'
    }
    elseif (-not $allPracticesCompliant) {
        'Token target may be met, but one or more required practices were not consistently applied.'
    }
    else {
        'Target achieved with required practices consistently applied.'
    }
}

if ($Json) {
    $result | ConvertTo-Json -Depth 8
    exit 0
}

Write-Host 'Backlog Efficiency Scorecard'
Write-Host '----------------------------'
Write-Host "Measured sessions:        $($result.measuredSessions) / $($result.requiredSessions)"
Write-Host "Measurement ready:        $($result.measurementReady)"
Write-Host "Average tokens:           $($result.averageTokens)"
Write-Host "In-target sessions:       $($result.inTargetSessionCount) / $($result.evaluatedSessions)"
Write-Host "Target met by average:    $($result.targetMetByAverage)"
Write-Host "All practices compliant:  $($result.allPracticesCompliant)"
Write-Host "Overall pass:             $($result.overallPass)"
Write-Host ''

foreach ($practiceName in $result.practices.Keys) {
    $practice = $result.practices[$practiceName]
    Write-Host "$practiceName`: $($practice.compliant)/$($practice.total) ($($practice.compliancePercent)%)"
}

Write-Host ''
Write-Host "Recommendation: $($result.recommendation)"
exit 0
