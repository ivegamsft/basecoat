#!/usr/bin/env pwsh
# Validates the asset distribution classification (#3374) in skill, agent, and
# prompt frontmatter. The classification is four orthogonal axes:
#   ships   : boolean  (default true)  -- distributed to consumer repositories
#   dogfood : boolean  (default false) -- projected into BaseCoat's own session
#   status  : enum     (default active) -- experimental | active | deprecated
#   version : SemVer (validated separately by validate-basecoat)
# Only the ships/dogfood/status axes are checked here. Absent fields are valid
# (permissive migration default); when present they must be well-formed, and an
# asset that ships nowhere (ships:false AND dogfood:false) must be explicitly
# staged (status experimental|deprecated). Extracted as a standalone validator
# so validate-basecoat.ps1 and the test suite exercise identical production
# logic; kept in sync with the parity block in scripts/validate-basecoat.sh.
[CmdletBinding()]
param(
    [string]$RootDir = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $RootDir).Path
$allowedStatus = @('experimental', 'active', 'deprecated')

function Get-Frontmatter {
    param([string]$Path)
    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -match '(?s)^---\r?\n(.*?)\r?\n---') { return $matches[1] }
    return ''
}

function Get-FrontmatterField {
    param([string]$Frontmatter, [string]$Name)
    foreach ($line in ($Frontmatter -split "`n")) {
        if ($line -match "^$([regex]::Escape($Name)):\s*(.+?)\s*$") {
            return $matches[1].Trim().Trim('"', "'").Trim().ToLowerInvariant()
        }
    }
    return $null
}

$assetFiles = @()
foreach ($spec in @(
        @{ Dir = 'skills'; Filter = 'SKILL.md'; Recurse = $true },
        @{ Dir = 'agents'; Filter = '*.agent.md'; Recurse = $false },
        @{ Dir = 'prompts'; Filter = '*.prompt.md'; Recurse = $false }
    )) {
    $dir = Join-Path $root $spec.Dir
    if (Test-Path $dir) {
        $assetFiles += Get-ChildItem -Path $dir -Filter $spec.Filter -File -Recurse:$spec.Recurse
    }
}

$errors = @()
foreach ($file in $assetFiles) {
    $fm = Get-Frontmatter $file.FullName
    if (-not $fm) { continue }

    $ships = Get-FrontmatterField $fm 'ships'
    $dogfood = Get-FrontmatterField $fm 'dogfood'
    $status = Get-FrontmatterField $fm 'status'

    if ($null -ne $ships -and $ships -notin @('true', 'false')) {
        $errors += "$($file.FullName): invalid ships '$ships' (expected true or false)"
    }
    if ($null -ne $dogfood -and $dogfood -notin @('true', 'false')) {
        $errors += "$($file.FullName): invalid dogfood '$dogfood' (expected true or false)"
    }
    if ($null -ne $status -and $status -notin $allowedStatus) {
        $errors += "$($file.FullName): invalid status '$status' (expected experimental, active, or deprecated)"
    }

    $effectiveShips = if ($null -eq $ships) { 'true' } else { $ships }
    $effectiveDogfood = if ($null -eq $dogfood) { 'false' } else { $dogfood }
    $effectiveStatus = if ($null -eq $status) { 'active' } else { $status }
    if ($effectiveShips -eq 'false' -and $effectiveDogfood -eq 'false' -and $effectiveStatus -notin @('experimental', 'deprecated')) {
        $errors += "$($file.FullName): ships:false and dogfood:false requires status experimental or deprecated"
    }
}

if ($errors.Count -gt 0) {
    foreach ($e in $errors) { Write-Host "ERROR: $e" -ForegroundColor Red }
    throw "Asset distribution validation failed with $($errors.Count) error(s)"
}

Write-Host "Asset distribution validation passed ($($assetFiles.Count) assets)."
