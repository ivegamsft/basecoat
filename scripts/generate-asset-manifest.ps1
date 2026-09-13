#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [string]$OutputPath = "asset-manifest.json"
)

$ErrorActionPreference = "Stop"

function Get-FrontmatterVersion {
    param([string]$Path)
    $content = Get-Content -Path $Path -Raw
    if ($content -notmatch '^---\r?\n([\s\S]+?)\r?\n---') { return $null }
    $fm = $matches[1]
    if ($fm -match '(?m)^version:\s*["'']?([0-9]+\.[0-9]+\.[0-9]+)["'']?\s*$') {
        return $matches[1]
    }
    return $null
}

function Get-FrontmatterDistribution {
    # Reads the #3374 distribution classification from frontmatter, applying
    # defaults (ships:true, dogfood:false, status:active) for absent fields.
    # Value validation is the job of validate-asset-distribution; here we only
    # read well-formed values and fall back to defaults otherwise.
    param([string]$Path)
    $ships = $true; $dogfood = $false; $status = 'active'
    $content = Get-Content -Path $Path -Raw
    if ($content -match '^---\r?\n([\s\S]+?)\r?\n---') {
        $fm = $matches[1]
        if ($fm -match '(?m)^ships:\s*["'']?(true|false)["'']?\s*$') { $ships = ($matches[1] -eq 'true') }
        if ($fm -match '(?m)^dogfood:\s*["'']?(true|false)["'']?\s*$') { $dogfood = ($matches[1] -eq 'true') }
        if ($fm -match '(?m)^status:\s*["'']?(experimental|active|deprecated)["'']?\s*$') { $status = $matches[1].ToLowerInvariant() }
    }
    return [PSCustomObject]@{ ships = $ships; dogfood = $dogfood; status = $status }
}

function Get-AssetType {
    param([string]$Path)
    if ($Path -like 'agents/*.agent.md') { return 'agent' }
    if ($Path -like 'instructions/*.instructions.md') { return 'instruction' }
    if ($Path -like 'prompts/*.prompt.md') { return 'prompt' }
    if ($Path -like 'skills/*/SKILL.md') { return 'skill' }
    if ($Path -in @(
            'scripts/validate-basecoat.ps1',
            'scripts/validate-basecoat.sh',
            'scripts/validate-skill-visibility.ps1',
            'scripts/validate-asset-distribution.ps1',
            'scripts/validate-workflow-action-pins.ps1',
            'scripts/validate-workflow-action-pins.py',
            'scripts/validate-reusable-workflow-contracts.py'
        )) { return 'script' }
    return $null
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$libraryVersion = (Get-Content version.json -Raw | ConvertFrom-Json).version
if (-not $libraryVersion) {
    throw "Unable to determine library version from version.json"
}

$candidates = @()
$candidates += Get-ChildItem agents -Filter '*.agent.md' -File | ForEach-Object { $_.FullName }
$candidates += Get-ChildItem instructions -Filter '*.instructions.md' -File | ForEach-Object { $_.FullName }
$candidates += Get-ChildItem prompts -Filter '*.prompt.md' -File | ForEach-Object { $_.FullName }
$candidates += Get-ChildItem skills -Recurse -Filter 'SKILL.md' -File | ForEach-Object { $_.FullName }
$candidates += @(
    'scripts/validate-basecoat.ps1',
    'scripts/validate-basecoat.sh',
    'scripts/validate-skill-visibility.ps1',
    'scripts/validate-asset-distribution.ps1',
    'scripts/validate-workflow-action-pins.ps1',
    'scripts/validate-workflow-action-pins.py',
    'scripts/validate-reusable-workflow-contracts.py'
) | ForEach-Object { (Resolve-Path $_).Path }

$assets = foreach ($full in $candidates | Sort-Object) {
    $relative = Resolve-Path -Relative $full
    if ($relative -match '^\.[\\/]') { $relative = $relative.Substring(2) }
    $relative = $relative -replace '\\', '/'
    $type = Get-AssetType $relative
    if (-not $type) { continue }
    $assetVersion = Get-FrontmatterVersion $full
    $sha = (git hash-object -- $full).Trim()
    $obj = [ordered]@{
        path = $relative
        type = $type
        sha = $sha
        version = if ($assetVersion) { $assetVersion } else { $null }
        effectiveVersion = if ($assetVersion) { $assetVersion } else { $libraryVersion }
        versionSource = if ($assetVersion) { "frontmatter" } else { "library" }
    }
    if ($type -in @('skill', 'agent', 'prompt')) {
        $dist = Get-FrontmatterDistribution $full
        # Only emit distribution metadata when it deviates from the defaults
        # (ships:true, dogfood:false, status:active). Absent fields already mean
        # "shipped/active" everywhere that reads the manifest, so emitting them
        # for every default asset is pure churn and needless adoption-SHA noise.
        $isDefault = $dist.ships -and (-not $dist.dogfood) -and ($dist.status -eq 'active')
        if (-not $isDefault) {
            $label = if ($dist.ships -and $dist.dogfood) { 'both' }
            elseif ($dist.ships) { 'shipped' }
            elseif ($dist.dogfood) { 'internal' }
            else { 'none' }
            $obj['ships'] = $dist.ships
            $obj['dogfood'] = $dist.dogfood
            $obj['status'] = $dist.status
            $obj['distribution'] = $label
        }
    }
    [PSCustomObject]$obj
}

$manifest = [PSCustomObject]@{
    schemaVersion = "1.1"
    libraryVersion = $libraryVersion
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    assets = @($assets)
}

$manifest | ConvertTo-Json -Depth 8 | Out-File -FilePath $OutputPath -Encoding utf8
Write-Host "Generated $OutputPath with $($assets.Count) assets"
