#!/usr/bin/env pwsh
# Asset-manifest drift check (#3374, spec step 3). Regenerates asset-manifest.json
# in a temporary path from the current repository tree and compares it, field by
# field, against the committed manifest -- ignoring only the volatile
# generatedAt timestamp. This closes the gap that let a change to an asset (or to
# version.json) land without a corresponding manifest regeneration: the classic
# failure mode is bumping version.json without running the generator, or adding
# ships/dogfood/status frontmatter without regenerating the distribution rollup.
#
# The comparison is semantic (parsed objects re-serialized), so pure formatting
# differences (e.g. a jq-rewritten manifest) do not trip the check; only a real
# content divergence does. The check is a no-op when the generator is absent
# (installed/consumer copies ship the manifest but not the build script), so it
# is safe to invoke unconditionally from validate-basecoat.ps1.
[CmdletBinding()]
param(
    [string]$RootDir = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $RootDir).Path
$generator = Join-Path $PSScriptRoot 'generate-asset-manifest.ps1'
$committedPath = Join-Path $root 'asset-manifest.json'

if (-not (Test-Path $generator)) {
    Write-Host 'Asset manifest drift check skipped (generator not present in this copy).'
    return
}
if (-not (Test-Path $committedPath)) {
    throw "asset-manifest.json not found at $committedPath"
}

function Get-AssetMap {
    param($Manifest)
    $map = @{}
    foreach ($asset in $Manifest.assets) {
        $map[$asset.path] = ($asset | ConvertTo-Json -Depth 8 -Compress)
    }
    return $map
}

$tempManifest = [System.IO.Path]::Combine(
    [System.IO.Path]::GetTempPath(),
    "asset-manifest-drift-$([guid]::NewGuid().ToString('N')).json")

Push-Location
try {
    & $generator -OutputPath $tempManifest *> $null
}
finally {
    Pop-Location
}

try {
    $committed = Get-Content -LiteralPath $committedPath -Raw | ConvertFrom-Json
    $regen = Get-Content -LiteralPath $tempManifest -Raw | ConvertFrom-Json

    $errors = @()
    if ($committed.schemaVersion -ne $regen.schemaVersion) {
        $errors += "schemaVersion: committed '$($committed.schemaVersion)' != regenerated '$($regen.schemaVersion)'"
    }
    if ($committed.libraryVersion -ne $regen.libraryVersion) {
        $errors += "libraryVersion: committed '$($committed.libraryVersion)' != regenerated '$($regen.libraryVersion)'"
    }

    $committedMap = Get-AssetMap $committed
    $regenMap = Get-AssetMap $regen

    foreach ($path in $regenMap.Keys) {
        if (-not $committedMap.ContainsKey($path)) {
            $errors += "asset missing from committed manifest: $path"
        }
        elseif ($committedMap[$path] -ne $regenMap[$path]) {
            $errors += "asset entry differs from regenerated manifest: $path"
        }
    }
    foreach ($path in $committedMap.Keys) {
        if (-not $regenMap.ContainsKey($path)) {
            $errors += "stale asset in committed manifest (no longer in tree): $path"
        }
    }

    if ($errors.Count -gt 0) {
        foreach ($e in $errors) { Write-Host "ERROR: $e" -ForegroundColor Red }
        throw "Asset manifest drift detected ($($errors.Count) difference(s)); run 'pwsh scripts/generate-asset-manifest.ps1' and commit the result."
    }

    Write-Host "Asset manifest is in sync with the tree ($($regen.assets.Count) assets)."
}
finally {
    Remove-Item -LiteralPath $tempManifest -Force -ErrorAction SilentlyContinue
}
