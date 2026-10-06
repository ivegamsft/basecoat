function Invoke-WindowsValidationLane {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('core', 'sync')]
        [string]$LaneName,

        [Parameter(Mandatory = $true)]
        [array]$Stages
    )

    $failures = @()

    foreach ($stage in $Stages) {
        $stageName = [string]$stage.Name
        Write-Host "Running Windows $LaneName stage: $stageName"
        try {
            $global:LASTEXITCODE = 0
            & $stage.Command
            $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
            if ($exitCode -ne 0) {
                $failures += [PSCustomObject]@{
                    Stage = $stageName
                    ExitCode = $exitCode
                    Error = ''
                }
                Write-Host "::error::Windows $LaneName stage failed: $stageName exited $exitCode"
            }
        }
        catch {
            $failures += [PSCustomObject]@{
                Stage = $stageName
                ExitCode = 1
                Error = $_.Exception.Message
            }
            Write-Host "::error::Windows $LaneName stage failed: $stageName threw $($_.Exception.Message)"
        }
    }

    $exitCode = if ($failures.Count -gt 0) { 1 } else { 0 }
    [PSCustomObject]@{
        Lane = $LaneName
        Succeeded = ($exitCode -eq 0)
        ExitCode = $exitCode
        Failures = $failures
    }
}

Export-ModuleMember -Function Invoke-WindowsValidationLane
