param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('core', 'sync')]
    [string]$LaneName,

    [bool]$GuidanceAuditFailOnError = $true
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Import-Module (Join-Path $PSScriptRoot 'WindowsValidationLane.psm1') -Force

if ($LaneName -eq 'core') {
    $stages = @(
        @{
            Name = 'validate-basecoat'
            Command = { & .\scripts\validate-basecoat.ps1 }
        },
        @{
            Name = 'run-tests'
            Command = { & .\tests\run-tests.ps1 -GuidanceAuditFailOnError:$GuidanceAuditFailOnError -SkipSyncProcessTests }.GetNewClosure()
        },
        @{
            Name = 'validate-basecoat-strict'
            Command = { & .\scripts\validate-basecoat.ps1 -Strict }
        },
        @{
            Name = 'check-coherence-conflicts'
            Command = { & .\scripts\check-coherence.ps1 -Strict -Category conflicts }
        }
    )
} else {
    $stages = @(
        @{
            Name = 'sync-tests'
            Command = { & pwsh -NoProfile -File tests\sync-tests.ps1 }
        }
    )
}

$result = Invoke-WindowsValidationLane -LaneName $LaneName -Stages $stages
if (-not $result.Succeeded) {
    $failedStages = ($result.Failures | ForEach-Object {
        if ($_.Error) {
            "$($_.Stage)=$($_.ExitCode) ($($_.Error))"
        } else {
            "$($_.Stage)=$($_.ExitCode)"
        }
    }) -join ', '
    Write-Host "::error::Windows $LaneName lane failed: $failedStages"
}

exit $result.ExitCode
