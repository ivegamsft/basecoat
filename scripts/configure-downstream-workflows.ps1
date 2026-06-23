<#
.SYNOPSIS
    Copies and configures downstream-safe BaseCoat workflows into .github/workflows.

.DESCRIPTION
    Installs BaseCoat workflows with explicit provenance naming:
    - basecoat-<capability>.yml         (reusable)
    - basecoat-agent-<capability>.yml   (advanced templates)
    - basecoat-internal-<capability>.yml (internal workflows)

    Default behavior installs only reusable workflows. Template and internal workflows are
    opt-in via parameters.

    Source workflows are expected in .github/base-coat/workflows (as synced by BaseCoat).

.PARAMETER SourceDir
    Directory containing source workflow templates.

.PARAMETER DestinationDir
    Directory where configured workflows are written.

.PARAMETER IncludeUnsupported
    Also install advanced/unsupported workflows (not recommended for consumer repos).

.PARAMETER IncludeTemplates
    Include template workflows (in addition to reusable workflows).

.PARAMETER IncludeInternal
    Include internal workflows (in addition to reusable workflows).

.PARAMETER InstallClass
    Workflow classes to install. Valid values: reusable, templates, internal.
    Defaults to reusable.

.PARAMETER KeepUnknownBc
    Keep unknown managed workflow files already present in destination.
    Managed prefixes are bc-, basecoat-, basecoat-agent-, basecoat-internal-.

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
    [switch]$IncludeTemplates,
    [switch]$IncludeInternal,
    [ValidateSet('reusable', 'templates', 'internal')]
    [string[]]$InstallClass = @('reusable'),
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
        Destination = 'basecoat-upstream-version-drift.yml'
        LegacyDestinations = @('bc-check-health.yml')
        Name = 'BaseCoat Reusable - Upstream Version Drift'
        Class = 'reusable'
        Supported = $true
    }
    [pscustomobject]@{
        Source = 'version-check.yml'
        Destination = 'basecoat-version-check.yml'
        LegacyDestinations = @('bc-version-check.yml')
        Name = 'BaseCoat Reusable - Version Check'
        Supported = $true
        Class = 'reusable'
    }
    [pscustomobject]@{
        Source = 'secret-scan.yml'
        Destination = 'basecoat-secret-scan.yml'
        LegacyDestinations = @('bc-secret-scan.yml')
        Name = 'BaseCoat Reusable - Secret Scan'
        Supported = $true
        Class = 'reusable'
    }
    [pscustomobject]@{
        Source = 'intake-contract-check.yml'
        Destination = 'basecoat-intake-contract-check.yml'
        LegacyDestinations = @()
        Name = 'BaseCoat Reusable - Intake Contract Check'
        Supported = $true
        Class = 'reusable'
    }
    [pscustomobject]@{
        Source = 'dependency-update-advisor.yml'
        Destination = 'basecoat-dependency-update-advisor.yml'
        LegacyDestinations = @('bc-dependency-update-advisor.yml')
        Name = 'BaseCoat Template - Dependency Update Advisor'
        Supported = $true
        Class = 'templates'
    }
    [pscustomobject]@{
        Source = 'issue-approve.yml'
        Destination = 'basecoat-issue-approve.yml'
        LegacyDestinations = @()
        Name = 'BaseCoat Template - Issue Approve'
        Supported = $true
        Class = 'templates'
    }
    [pscustomobject]@{
        Source = 'sprint-closeout-branch-audit.yml'
        Destination = 'basecoat-sprint-closeout-branch-audit.yml'
        LegacyDestinations = @('bc-sprint-closeout-branch-audit.yml')
        Name = 'BaseCoat Template - Sprint Closeout Branch Audit'
        Supported = $true
        Class = 'templates'
    }
    [pscustomobject]@{
        Source = 'token-inventory.yml'
        Destination = 'basecoat-token-inventory.yml'
        LegacyDestinations = @()
        Name = 'BaseCoat Template - Token Inventory'
        Supported = $true
        Class = 'templates'
    }
    [pscustomobject]@{
        Source = 'code-review-agent.lock.yml'
        Destination = 'basecoat-agent-code-review.yml'
        LegacyDestinations = @()
        Name = 'BaseCoat Agent Template - Code Review'
        Supported = $false
        Class = 'templates'
    }
    [pscustomobject]@{
        Source = 'issue-triage.lock.yml'
        Destination = 'basecoat-agent-issue-triage.yml'
        LegacyDestinations = @()
        Name = 'BaseCoat Agent Template - Issue Triage'
        Supported = $false
        Class = 'templates'
    }
    [pscustomobject]@{
        Source = 'release-impact-advisor.lock.yml'
        Destination = 'basecoat-agent-release-impact-advisor.yml'
        LegacyDestinations = @()
        Name = 'BaseCoat Agent Template - Release Impact Advisor'
        Supported = $false
        Class = 'templates'
    }
    [pscustomobject]@{
        Source = 'retro-facilitator.lock.yml'
        Destination = 'basecoat-agent-retro-facilitator.yml'
        LegacyDestinations = @()
        Name = 'BaseCoat Agent Template - Retro Facilitator'
        Supported = $false
        Class = 'templates'
    }
    [pscustomobject]@{
        Source = 'security-analyst.lock.yml'
        Destination = 'basecoat-agent-security-analyst.yml'
        LegacyDestinations = @()
        Name = 'BaseCoat Agent Template - Security Analyst'
        Supported = $false
        Class = 'templates'
    }
    [pscustomobject]@{
        Source = 'self-healing-ci.lock.yml'
        Destination = 'basecoat-agent-self-healing-ci.yml'
        LegacyDestinations = @()
        Name = 'BaseCoat Agent Template - Self-Healing CI'
        Supported = $false
        Class = 'templates'
    }
    [pscustomobject]@{
        Source = 'auto-approve-cloud-agent-workflows.yml'
        Destination = 'basecoat-internal-auto-approve-cloud-agent-workflows.yml'
        LegacyDestinations = @()
        Name = 'BaseCoat Internal - Auto-approve Cloud Agent Workflows'
        Supported = $false
        Class = 'internal'
    }
)

$installClasses = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($class in $InstallClass) {
    [void]$installClasses.Add($class)
}
if ($IncludeTemplates) {
    [void]$installClasses.Add('templates')
}
if ($IncludeInternal) {
    [void]$installClasses.Add('internal')
}

$knownManagedFiles = @(
    $workflowMap |
        ForEach-Object { @($_.Destination) + @($_.LegacyDestinations) } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
)
$factoryOnlyWorkflowFiles = @(
    'database-ci-cd.yml',
    'bc-database-ci-cd.yml',
    'basecoat-internal-database-ci-cd.yml'
)

$copied = 0
$removed = 0
$skipped = 0

foreach ($workflow in $workflowMap) {
    if (-not $installClasses.Contains($workflow.Class)) {
        Write-Info "Skipping workflow outside selected classes ($($workflow.Class)): $($workflow.Source)"
        $skipped++
        continue
    }

    $sourceFile = Join-Path $resolvedSource $workflow.Source
    $destFile = Join-Path $resolvedDest $workflow.Destination

    if (-not $workflow.Supported -and -not $IncludeUnsupported) {
        if (Test-Path $destFile) {
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

    if (-not (Test-Path -Path $sourceFile -PathType Leaf)) {
        Write-Warn "Source workflow missing in '$SourceDir', skipping: $($workflow.Source)"
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

    if ($DryRun) {
        Write-Info "Would copy $($workflow.Source) -> $($workflow.Destination)"
    } else {
        Set-Content -Path $destFile -Value $content -Encoding UTF8
        Write-Ok "Installed workflow: $($workflow.Destination)"
    }
    $copied++

    foreach ($legacyName in $workflow.LegacyDestinations) {
        if ($legacyName -eq $workflow.Destination) {
            continue
        }
        $legacyPath = Join-Path $resolvedDest $legacyName
        if (Test-Path -Path $legacyPath -PathType Leaf) {
            if ($DryRun) {
                Write-Info "Would remove legacy workflow filename: $legacyName"
            } else {
                Remove-Item -Path $legacyPath -Force
                Write-Ok "Removed legacy workflow filename: $legacyName"
            }
            $removed++
        }
    }
}

if (-not $KeepUnknownBc) {
    $managedPrefixes = @('bc-', 'basecoat-', 'basecoat-agent-', 'basecoat-internal-')
    $unknownManagedFiles = Get-ChildItem -Path $resolvedDest -Filter '*.yml' -File -ErrorAction SilentlyContinue |
        Where-Object {
            $name = $_.Name.ToLowerInvariant()
            @($managedPrefixes | Where-Object { $name.StartsWith($_) }).Count -gt 0 -and
            $_.Name -notin $knownManagedFiles
        }

    foreach ($file in $unknownManagedFiles) {
        if ($DryRun) {
            Write-Info "Would remove unknown managed workflow: $($file.Name)"
        } else {
            Remove-Item -Path $file.FullName -Force
            Write-Ok "Removed unknown managed workflow: $($file.Name)"
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
