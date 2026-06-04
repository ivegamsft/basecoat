<#
.SYNOPSIS
    Copies and configures downstream-safe BaseCoat workflows into .github/workflows.

.DESCRIPTION
    Installs only consumer-safe workflows with a bc- filename prefix so they are easy to
    identify and do not collide with repo-native workflow names.

    By default, this script also removes known unsupported workflows from the destination:
    - bc-asset-health.yml
    - bc-sync-test.yml
    - bc-template-validation.yml

    Source workflows are expected in .github/base-coat/workflows (as synced by BaseCoat).

.PARAMETER SourceDir
    Directory containing source workflow templates.

.PARAMETER DestinationDir
    Directory where configured workflows are written.

.PARAMETER IncludeUnsupported
    Also install unsupported workflows (not recommended for consumer repos).

.PARAMETER KeepUnsupported
    Keep unsupported workflow files already present in destination.

.PARAMETER KeepUnknownBc
    Keep unknown bc-* workflow files already present in destination.

.PARAMETER DryRun
    Print planned actions without modifying files.

.EXAMPLE
    pwsh scripts/configure-downstream-workflows.ps1

.EXAMPLE
    pwsh scripts/configure-downstream-workflows.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [string]$SourceDir = '.github/base-coat/workflows',
    [string]$DestinationDir = '.github/workflows',
    [switch]$IncludeUnsupported,
    [switch]$KeepUnsupported,
    [switch]$KeepUnknownBc,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) { Write-Host "INFO: $Message" }
function Write-Warn([string]$Message) { Write-Host "WARN: $Message" -ForegroundColor Yellow }
function Write-Ok([string]$Message) { Write-Host "OK:   $Message" -ForegroundColor Green }

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    throw 'This script must be run inside a git repository.'
}
Set-Location $repoRoot

$resolvedSource = if ([System.IO.Path]::IsPathRooted($SourceDir)) {
    $SourceDir
} else {
    Join-Path $repoRoot $SourceDir
}

$resolvedDest = if ([System.IO.Path]::IsPathRooted($DestinationDir)) {
    $DestinationDir
} else {
    Join-Path $repoRoot $DestinationDir
}

if (-not (Test-Path -Path $resolvedSource -PathType Container)) {
    throw "Source workflow directory not found: $resolvedSource"
}

if (-not (Test-Path -Path $resolvedDest -PathType Container)) {
    if ($DryRun) {
        Write-Info "Would create destination directory: $DestinationDir"
    } else {
        New-Item -Path $resolvedDest -ItemType Directory -Force | Out-Null
        Write-Ok "Created destination directory: $DestinationDir"
    }
}

$workflowMap = @(
    [pscustomobject]@{
        Source = 'check-version.yml'
        Destination = 'bc-check-health.yml'
        Name = 'BaseCoat Downstream - Check Health'
        Supported = $true
    }
    [pscustomobject]@{
        Source = 'version-check.yml'
        Destination = 'bc-version-check.yml'
        Name = 'BaseCoat Downstream - Version Check'
        Supported = $true
    }
    [pscustomobject]@{
        Source = 'secret-scan.yml'
        Destination = 'bc-secret-scan.yml'
        Name = 'BaseCoat Downstream - Secret Scan'
        Supported = $true
    }
    [pscustomobject]@{
        Source = 'prd-spec-gate.yml'
        Destination = 'bc-prd-spec-gate.yml'
        Name = 'BaseCoat Downstream - PRD and Spec Gate'
        Supported = $true
    }
    [pscustomobject]@{
        Source = 'dependency-update-advisor.yml'
        Destination = 'bc-dependency-update-advisor.yml'
        Name = 'BaseCoat Downstream - Dependency Update Advisor'
        Supported = $true
    }
    [pscustomobject]@{
        Source = 'sprint-closeout-branch-audit.yml'
        Destination = 'bc-sprint-closeout-branch-audit.yml'
        Name = 'BaseCoat Downstream - Sprint Closeout Branch Audit'
        Supported = $true
    }
    [pscustomobject]@{
        Source = 'asset-health.yml'
        Destination = 'bc-asset-health.yml'
        Name = 'BaseCoat Downstream - Asset Health Report'
        Supported = $false
    }
    [pscustomobject]@{
        Source = 'sync-test.yml'
        Destination = 'bc-sync-test.yml'
        Name = 'BaseCoat Downstream - Consumer Sync Validation'
        Supported = $false
    }
    [pscustomobject]@{
        Source = 'template-validation.yml'
        Destination = 'bc-template-validation.yml'
        Name = 'BaseCoat Downstream - Template Validation'
        Supported = $false
    }
)

$knownDownstreamFiles = @($workflowMap | ForEach-Object { $_.Destination })
$factoryOnlyWorkflowFiles = @(
    'database-ci-cd.yml',
    'bc-database-ci-cd.yml'
)

$copied = 0
$removed = 0
$skipped = 0

foreach ($workflow in $workflowMap) {
    $sourceFile = Join-Path $resolvedSource $workflow.Source
    $destFile = Join-Path $resolvedDest $workflow.Destination

    if (-not $workflow.Supported -and -not $IncludeUnsupported) {
        if ((Test-Path $destFile) -and -not $KeepUnsupported) {
            if ($DryRun) {
                Write-Info "Would remove unsupported workflow: $($workflow.Destination)"
            } else {
                Remove-Item -Path $destFile -Force
                Write-Ok "Removed unsupported workflow: $($workflow.Destination)"
            }
            $removed++
        } else {
            Write-Info "Skipping unsupported workflow: $($workflow.Destination)"
            $skipped++
        }
        continue
    }

    if (-not (Test-Path $sourceFile)) {
        Write-Warn "Source workflow missing, skipping: $($workflow.Source)"
        $skipped++
        continue
    }

    $content = Get-Content -Path $sourceFile -Raw

    # Ensure downstream-friendly filename and visible naming prefix.
    $lines = $content -split "`r?`n", -1
    $nameUpdated = $false
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^name:\s*".*"$') {
            $lines[$i] = "name: `"$($workflow.Name)`""
            $nameUpdated = $true
            break
        }
    }
    if (-not $nameUpdated) {
        $lines = @("name: `"$($workflow.Name)`"") + $lines
    }
    $content = [string]::Join("`n", $lines)

    # Remove repo-specific risky path rule that often does not exist in consumers.
    if ($workflow.Destination -eq 'bc-prd-spec-gate.yml') {
        $content = $content -replace "(?m)^\s*/\^docs\\/enterprise-rollout\\.md\$/,?\r?\n", ''
    }

    if ($DryRun) {
        Write-Info "Would copy $($workflow.Source) -> $($workflow.Destination)"
    } else {
        Set-Content -Path $destFile -Value $content -Encoding UTF8
        Write-Ok "Installed workflow: $($workflow.Destination)"
    }
    $copied++
}

if (-not $KeepUnknownBc) {
    $unknownBcFiles = Get-ChildItem -Path $resolvedDest -Filter 'bc-*.yml' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin $knownDownstreamFiles }

    foreach ($file in $unknownBcFiles) {
        if ($DryRun) {
            Write-Info "Would remove unknown downstream workflow: $($file.Name)"
        } else {
            Remove-Item -Path $file.FullName -Force
            Write-Ok "Removed unknown downstream workflow: $($file.Name)"
        }
        $removed++
    }
}

foreach ($factoryWorkflow in $factoryOnlyWorkflowFiles) {
    $factoryPath = Join-Path $resolvedDest $factoryWorkflow
    if (Test-Path -Path $factoryPath -PathType Leaf) {
        if ($DryRun) {
            Write-Info "Would remove factory-only workflow: $factoryWorkflow"
        } else {
            Remove-Item -Path $factoryPath -Force
            Write-Ok "Removed factory-only workflow: $factoryWorkflow"
        }
        $removed++
    }
}

Write-Host ''
Write-Host 'Summary:' -ForegroundColor Cyan
Write-Host "  Copied:  $copied"
Write-Host "  Removed: $removed"
Write-Host "  Skipped: $skipped"
