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

function Get-AssetType {
    param([string]$Path)
    if ($Path -like 'agents/*.agent.md') { return 'agent' }
    if ($Path -like 'instructions/*.instructions.md') { return 'instruction' }
    if ($Path -like 'prompts/*.prompt.md') { return 'prompt' }
    if ($Path -like 'skills/*/SKILL.md') { return 'skill' }
    if ($Path -in @(
            'scripts/validate-basecoat.ps1',
            'scripts/validate-basecoat.sh',
            'scripts/validate-workflow-action-pins.ps1',
            'scripts/validate-workflow-action-pins.py'
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
    'scripts/validate-workflow-action-pins.ps1',
    'scripts/validate-workflow-action-pins.py'
) | ForEach-Object { (Resolve-Path $_).Path }

$assets = foreach ($full in $candidates | Sort-Object) {
    $relative = Resolve-Path -Relative $full
    if ($relative.StartsWith('.\')) { $relative = $relative.Substring(2) }
    $relative = $relative -replace '\\', '/'
    $type = Get-AssetType $relative
    if (-not $type) { continue }
    $assetVersion = Get-FrontmatterVersion $full
    $sha = (git hash-object -- $full).Trim()
    [PSCustomObject]@{
        path = $relative
        type = $type
        sha = $sha
        version = if ($assetVersion) { $assetVersion } else { $null }
        effectiveVersion = if ($assetVersion) { $assetVersion } else { $libraryVersion }
        versionSource = if ($assetVersion) { "frontmatter" } else { "library" }
    }
}

$manifest = [PSCustomObject]@{
    schemaVersion = "1.0"
    libraryVersion = $libraryVersion
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    assets = @($assets)
}

$manifest | ConvertTo-Json -Depth 8 | Out-File -FilePath $OutputPath -Encoding utf8
Write-Host "Generated $OutputPath with $($assets.Count) assets"
