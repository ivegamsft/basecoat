#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Updates versioned documentation references and version.json for a release.

.DESCRIPTION
    Rewrites semver tag references (vX.Y.Z) in a curated set of user-facing guide
    documents so examples track the latest BaseCoat release tag. Also updates
    version.json with the same version and current UTC release date.

.EXAMPLE
    pwsh scripts/update-versioned-docs.ps1 -Version 3.33.0
    pwsh scripts/update-versioned-docs.ps1 -Version v3.33.0
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = 'Stop'

$normalizedVersion = $Version.Trim()
if ($normalizedVersion.StartsWith('v')) {
    $normalizedVersion = $normalizedVersion.Substring(1)
}

if ($normalizedVersion -notmatch '^\d+\.\d+\.\d+$') {
    throw "Invalid version '$Version'. Expected semver like 3.33.0 or v3.33.0."
}

$tagVersion = "v$normalizedVersion"
$repoRoot = Split-Path -Parent $PSScriptRoot
$utcDate = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')

$trackedDocs = @(
    'docs/guides/agent-examples.md',
    'docs/guides/basecoat-yml.md',
    'docs/guides/consumer-sync.md',
    'docs/guides/customization.md',
    'docs/guides/external-setup.md',
    'docs/guides/integrate-prompt.md',
    'docs/guides/version-drift.md'
)

foreach ($relativePath in $trackedDocs) {
    $fullPath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path $fullPath)) {
        Write-Warning "Skipping missing file: $relativePath"
        continue
    }

    $content = Get-Content -Path $fullPath -Raw -Encoding UTF8
    $updated = [Regex]::Replace($content, 'v\d+\.\d+\.\d+', $tagVersion)

    if ($updated -ne $content) {
        Set-Content -Path $fullPath -Value $updated -Encoding UTF8
        Write-Host "Updated version tags in $relativePath -> $tagVersion"
    }
}

$versionFile = Join-Path $repoRoot 'version.json'
if (-not (Test-Path $versionFile)) {
    throw "Missing required file: version.json"
}

$versionData = Get-Content -Path $versionFile -Raw -Encoding UTF8 | ConvertFrom-Json
$versionData.version = $normalizedVersion
$versionData.releaseDate = $utcDate
$versionData | ConvertTo-Json -Depth 10 | Set-Content -Path $versionFile -Encoding UTF8

Write-Host "Updated version.json -> version=$normalizedVersion releaseDate=$utcDate"
