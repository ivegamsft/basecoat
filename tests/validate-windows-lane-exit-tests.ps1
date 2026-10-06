#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Import-Module (Join-Path $repoRoot 'scripts\WindowsValidationLane.psm1') -Force

Write-Host 'Running validate-windows lane exit propagation tests...'

$failures = @()
$coreStageNames = @(
    'validate-basecoat',
    'run-tests',
    'validate-basecoat-strict',
    'check-coherence-conflicts'
)

function New-TestStage {
    param(
        [string]$Name,
        [int]$ExitCode = 0,
        [switch]$Throw
    )

    if ($Throw) {
        return @{
            Name = $Name
            Command = { throw 'injected terminating failure' }
        }
    }

    @{
        Name = $Name
        Command = [scriptblock]::Create("& pwsh -NoProfile -Command `"exit $ExitCode`"")
    }
}

function Assert-LaneResult {
    param(
        [object]$Result,
        [bool]$Succeeded,
        [string]$ExpectedFailedStage,
        [string]$CaseName
    )

    if ($Result.Succeeded -ne $Succeeded) {
        $script:failures += "$CaseName expected Succeeded=$Succeeded, got $($Result.Succeeded)"
    }
    $expectedExit = if ($Succeeded) { 0 } else { 1 }
    if ($Result.ExitCode -ne $expectedExit) {
        $script:failures += "$CaseName expected ExitCode=$expectedExit, got $($Result.ExitCode)"
    }
    if ($ExpectedFailedStage) {
        if (-not ($Result.Failures | Where-Object { $_.Stage -eq $ExpectedFailedStage })) {
            $script:failures += "$CaseName expected failed stage '$ExpectedFailedStage'"
        }
    } elseif ($Result.Failures.Count -ne 0) {
        $script:failures += "$CaseName expected no failed stages, got $($Result.Failures.Count)"
    }
}

foreach ($failedStage in $coreStageNames) {
    $stages = foreach ($stageName in $coreStageNames) {
        New-TestStage -Name $stageName -ExitCode $(if ($stageName -eq $failedStage) { 1 } else { 0 })
    }
    $result = Invoke-WindowsValidationLane -LaneName core -Stages $stages
    Assert-LaneResult -Result $result -Succeeded $false -ExpectedFailedStage $failedStage -CaseName "core exit propagation for $failedStage"
}

$exceptionStages = @(
    (New-TestStage -Name 'validate-basecoat' -Throw),
    (New-TestStage -Name 'run-tests'),
    (New-TestStage -Name 'validate-basecoat-strict'),
    (New-TestStage -Name 'check-coherence-conflicts')
)
$exceptionResult = Invoke-WindowsValidationLane -LaneName core -Stages $exceptionStages
Assert-LaneResult -Result $exceptionResult -Succeeded $false -ExpectedFailedStage 'validate-basecoat' -CaseName 'core terminating exception propagation'

$syncResult = Invoke-WindowsValidationLane -LaneName sync -Stages @(
    (New-TestStage -Name 'sync-tests' -ExitCode 1)
)
Assert-LaneResult -Result $syncResult -Succeeded $false -ExpectedFailedStage 'sync-tests' -CaseName 'sync lane failure propagation'

$successStages = foreach ($stageName in $coreStageNames) {
    New-TestStage -Name $stageName
}
$successResult = Invoke-WindowsValidationLane -LaneName core -Stages $successStages
Assert-LaneResult -Result $successResult -Succeeded $true -CaseName 'all-success lane'

if ($failures.Count -gt 0) {
    Write-Host 'validate-windows lane exit propagation tests FAILED.' -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'validate-windows lane exit propagation tests passed.' -ForegroundColor Green
exit 0
