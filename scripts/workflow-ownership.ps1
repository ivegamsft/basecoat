function Get-WorkflowOwnershipManifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Workflow ownership manifest not found: $Path"
    }

    try {
        $manifest = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        throw "Workflow ownership manifest is invalid JSON: $Path ($($_.Exception.Message))"
    }

    if ($manifest.schemaVersion -ne 1 -or
        $manifest.defaultOwnership -ne 'repo-owned' -or
        $null -eq $manifest.workflows) {
        throw "Workflow ownership manifest has an unsupported schema: $Path"
    }

    $seenFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in @($manifest.workflows)) {
        if ([string]::IsNullOrWhiteSpace($entry.file) -or
            $entry.ownership -ne 'factory-owned' -or
            -not $seenFiles.Add($entry.file)) {
            throw "Workflow ownership manifest contains an invalid or duplicate entry: $Path"
        }
    }

    return $manifest
}

function Resolve-WorkflowOwnershipFileName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkflowName
    )

    $fileName = Split-Path -Path $WorkflowName -Leaf
    if ([string]::IsNullOrWhiteSpace($fileName) -or $fileName -ne $WorkflowName) {
        throw "Workflow name must be a file name without a path: $WorkflowName"
    }

    if ([System.IO.Path]::GetExtension($fileName) -notin @('.yml', '.yaml')) {
        throw "Workflow name must end in .yml or .yaml: $WorkflowName"
    }

    return $fileName
}

function Assert-FactoryOwnedWorkflow {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkflowName,
        [Parameter(Mandatory = $true)]
        [string]$OwnershipManifestPath
    )

    $fileName = Resolve-WorkflowOwnershipFileName -WorkflowName $WorkflowName
    $manifest = Get-WorkflowOwnershipManifest -Path $OwnershipManifestPath
    $entry = @($manifest.workflows | Where-Object { $_.file -ieq $fileName })

    if ($entry.Count -ne 1 -or $entry[0].ownership -ne 'factory-owned') {
        throw "Refusing to remove repository-owned workflow '$fileName'. Only workflows explicitly marked factory-owned in '$OwnershipManifestPath' may be retired."
    }

    return $fileName
}

function Assert-FactoryOwnershipManifestCoverage {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$WorkflowNames,
        [Parameter(Mandatory = $true)]
        [string]$OwnershipManifestPath
    )

    foreach ($workflowName in $WorkflowNames | Sort-Object -Unique) {
        [void](Assert-FactoryOwnedWorkflow -WorkflowName $workflowName -OwnershipManifestPath $OwnershipManifestPath)
    }
}

function Remove-FactoryOwnedWorkflow {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkflowName,
        [Parameter(Mandatory = $true)]
        [string]$WorkflowDirectory,
        [Parameter(Mandatory = $true)]
        [string]$OwnershipManifestPath,
        [Parameter(Mandatory = $true)]
        [string]$Reason,
        [switch]$DryRun
    )

    $fileName = Assert-FactoryOwnedWorkflow -WorkflowName $WorkflowName -OwnershipManifestPath $OwnershipManifestPath
    $workflowPath = Join-Path $WorkflowDirectory $fileName
    if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
        return $false
    }

    if ($DryRun) {
        Write-Host "INFO: Would retire factory-owned workflow ($Reason): $fileName"
    } else {
        Remove-Item -LiteralPath $workflowPath -Force
        Write-Host "OK:   Retired factory-owned workflow ($Reason): $fileName"
    }

    return $true
}
