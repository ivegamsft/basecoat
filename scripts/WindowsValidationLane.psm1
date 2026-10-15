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
        $stageOutput = [System.Collections.Generic.List[object]]::new()
        Write-Host "Running Windows $LaneName stage: $stageName"
        try {
            $global:LASTEXITCODE = 0
            & $stage.Command 2>&1 | ForEach-Object {
                [void]$stageOutput.Add($_)
            }
            $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
            if ($exitCode -ne 0) {
                $failures += [PSCustomObject]@{
                    Stage = $stageName
                    ExitCode = $exitCode
                    Error = ''
                    Output = $stageOutput.ToArray()
                }
                Write-Host "::error::Windows $LaneName stage failed: $stageName exited $exitCode"
            }
        }
        catch {
            $failures += [PSCustomObject]@{
                Stage = $stageName
                ExitCode = 1
                Error = $_.Exception.Message
                Output = $stageOutput.ToArray()
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
