param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('core', 'sync')]
    [string]$LaneName
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Import-Module (Join-Path $PSScriptRoot 'WindowsValidationLane.psm1') -Force

if ($LaneName -eq 'core') {
    $stages = @(
        @{
            Name = 'windows-path-tests'
            Command = { & pwsh -NoProfile -File tests\aidl-incident-routing-verification-tests.ps1 }
        },
        @{
            Name = 'dogfood-junction-tests'
            Command = { & pwsh -NoProfile -File tests\dogfood-install-tests.ps1 }
        },
        @{
            Name = 'portable-skill-junction-tests'
            Command = { & pwsh -NoProfile -File tests\portable-skill-export-preview-tests.ps1 }
        },
        @{
            Name = 'powershell-51-bootstrap-tests'
            Command = {
                $powershell51 = Get-Command powershell.exe -ErrorAction Stop
                & $powershell51.Source -NoProfile -ExecutionPolicy Bypass -File tests\bootstrap-pr-counter-tests.ps1
            }
        },
        @{
            Name = 'powershell-51-guidance-lock-tests'
            Command = { & pwsh -NoProfile -File tests\guidance-lock-tests.ps1 }
        }
    )
} else {
    $stages = @(
        @{
            Name = 'sync-tests-powershell-7'
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
