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
    foreach ($failure in $result.Failures) {
        $diagnostics = @($failure.Output | ForEach-Object { "$_" })
        if ($failure.Error) {
            $diagnostics += $failure.Error
        }
        if ($diagnostics.Count -gt 0) {
            Write-Host "::group::Windows $LaneName stage $($failure.Stage) diagnostics"
            foreach ($diagnostic in $diagnostics) {
                foreach ($line in ($diagnostic -split "`r?`n")) {
                    Write-Host "  $line"
                }
            }
            Write-Host '::endgroup::'
        }
    }

    $failedStages = ($result.Failures | ForEach-Object {
        if ($_.Error) {
            $errorMessage = $_.Error -replace '[\r\n]+', ' '
            "$($_.Stage)=$($_.ExitCode) ($errorMessage)"
        } else {
            "$($_.Stage)=$($_.ExitCode)"
        }
    }) -join ', '
    Write-Host "::error::Windows $LaneName lane failed: $failedStages"
}

exit $result.ExitCode
