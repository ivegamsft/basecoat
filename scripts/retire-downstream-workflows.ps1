<#
.SYNOPSIS
    Retires only explicitly factory-owned workflows from a consumer repository.

.DESCRIPTION
    Workflows absent from the ownership manifest are repository-owned by default
    and cannot be removed by this command. Review the offboarding checklist
    before retiring workflows.

.EXAMPLE
    pwsh .github/base-coat/scripts/retire-downstream-workflows.ps1 `
        -Workflow basecoat-secret-scan.yml -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Workflow,
    [string]$SourceDir = '.github/base-coat/workflows',
    [string]$DestinationDir = '.github/workflows',
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    throw 'This script must be run inside a git repository.'
}

function Resolve-ConsumerPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path $repoRoot $Path
}

$resolvedSource = Resolve-ConsumerPath -Path $SourceDir
$resolvedDestination = Resolve-ConsumerPath -Path $DestinationDir
$ownershipManifestPath = Join-Path $resolvedSource 'workflow-ownership-manifest.json'
$ownershipModulePath = Join-Path $PSScriptRoot 'workflow-ownership.ps1'

if (-not (Test-Path -LiteralPath $resolvedDestination -PathType Container)) {
    throw "Workflow destination directory not found: $resolvedDestination"
}
if (-not (Test-Path -LiteralPath $ownershipModulePath -PathType Leaf)) {
    throw "Workflow ownership guard not found: $ownershipModulePath"
}

. $ownershipModulePath

$retired = 0
foreach ($workflowName in $Workflow) {
    if (Remove-FactoryOwnedWorkflow `
            -WorkflowName $workflowName `
            -WorkflowDirectory $resolvedDestination `
            -OwnershipManifestPath $ownershipManifestPath `
            -Reason 'explicit retirement' `
            -DryRun:$DryRun) {
        $retired++
    }
}

Write-Host "Summary: retired $retired factory-owned workflow(s)."
