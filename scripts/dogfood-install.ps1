[CmdletBinding()]
param(
    [switch]$Check,
    [string]$RootDir = (Join-Path $PSScriptRoot '..')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-NoReparsePoint {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $pathComparison = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') {
        [System.StringComparison]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparison]::Ordinal
    }
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith(
            $fullRoot + [System.IO.Path]::DirectorySeparatorChar,
            $pathComparison
        )) {
        throw "Projection path escapes repository root: '$Path'"
    }

    $relative = $fullPath.Substring($fullRoot.Length).TrimStart(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $current = $fullRoot
    foreach ($segment in ($relative -split '[\\/]')) {
        $current = Join-Path $current $segment
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Projection path contains a symbolic link or reparse point: '$current'"
            }
        }
    }
}

function Read-ProjectionManifest {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    try {
        $manifest = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    }
    catch {
        throw "Dogfood projection manifest is invalid: $($_.Exception.Message)"
    }
    if ($manifest.schemaVersion -ne 1 -or $null -eq $manifest.entries) {
        throw 'Dogfood projection manifest has an unsupported schema.'
    }
    foreach ($entry in $manifest.entries) {
        $segments = ([string]$entry.path -split '/')
        if ($entry.path -cnotmatch '^(?:\.github/(?:skills|agents|prompts)|\.agents/skills)/[A-Za-z0-9._ -]+(?:/[A-Za-z0-9._ -]+)*$' -or
            @($segments | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0 -or
            $entry.sha256 -cnotmatch '^[0-9a-f]{64}$') {
            throw "Dogfood projection manifest contains an invalid entry: '$($entry.path)'"
        }
    }
    $manifest
}

try {
    $resolvedRoot = (Resolve-Path -LiteralPath $RootDir).Path
    $projectionHelper = Join-Path $PSScriptRoot 'dogfood-projection.ps1'
    if (-not (Test-Path -LiteralPath $projectionHelper -PathType Leaf)) {
        throw "Missing shared projection helper: $projectionHelper"
    }
    . $projectionHelper

    $manifestRelativePath = '.github/.basecoat-dogfood-manifest.json'
    $manifestPath = Join-Path $resolvedRoot ($manifestRelativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    $targets = @('.github/skills', '.github/agents', '.github/prompts', '.agents/skills')
    foreach ($target in $targets) {
        Assert-NoReparsePoint -Root $resolvedRoot -Path (Join-Path $resolvedRoot ($target -replace '/', [System.IO.Path]::DirectorySeparatorChar))
    }
    Assert-NoReparsePoint -Root $resolvedRoot -Path $manifestPath

    $plan = @(Get-BaseCoatProjectionPlan -SourceRoot $resolvedRoot -Mode Dogfood)
    $currentEntries = @(
        foreach ($item in $plan) {
            $relativePath = $item.DestinationPath
            $destination = Join-Path $resolvedRoot ($relativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
            Assert-NoReparsePoint -Root $resolvedRoot -Path $destination
            [pscustomobject]@{
                path = $relativePath
                sourcePath = $item.SourcePath
                destinationPath = $destination
                sha256 = Get-Sha256 -Path $item.SourcePath
            }
        }
    )
    $manifest = Read-ProjectionManifest -Path $manifestPath
    $previousEntries = @()
    if ($manifest) {
        $previousEntries = @($manifest.entries)
    }
    $previousByPath = @{}
    foreach ($entry in $previousEntries) {
        $previousByPath[[string]$entry.path] = [string]$entry.sha256
    }
    $currentByPath = @{}
    foreach ($entry in $currentEntries) {
        if ($currentByPath.ContainsKey($entry.path)) {
            throw "Projection plan contains duplicate destination '$($entry.path)'"
        }
        $currentByPath[$entry.path] = $entry
    }

    $missing = [System.Collections.Generic.List[string]]::new()
    $outdated = [System.Collections.Generic.List[string]]::new()
    $orphaned = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $currentEntries) {
        if (-not (Test-Path -LiteralPath $entry.destinationPath -PathType Leaf)) {
            $missing.Add($entry.path)
            continue
        }
        if ((Get-Sha256 -Path $entry.destinationPath) -ne $entry.sha256) {
            $outdated.Add($entry.path)
        }
    }
    foreach ($path in $previousByPath.Keys) {
        if (-not $currentByPath.ContainsKey($path)) {
            $orphaned.Add($path)
        }
    }

    $tracked = @()
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git is required to verify that dogfood projection destinations contain no tracked files.'
    }
    $tracked = @(git -C $resolvedRoot ls-files -- '.github/skills' '.github/agents' '.github/prompts' '.agents/skills' $manifestRelativePath 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to verify tracked projection paths under '$resolvedRoot'."
    }
    if ($tracked.Count -gt 0) {
        throw "Dogfood projection destination contains tracked files and will not be overwritten: $($tracked -join ', ')"
    }

    $staleCount = $missing.Count + $outdated.Count + $orphaned.Count
    if ($Check) {
        if ($staleCount -gt 0 -or $null -eq $manifest) {
            Write-Host "Dogfood self-install is stale: $($missing.Count) missing, $($outdated.Count) outdated, $($orphaned.Count) orphaned. Run 'pwsh scripts/dogfood-install.ps1'."
            exit 1
        }
        Write-Host "Dogfood self-install is current: $($currentEntries.Count) projected file(s)."
        exit 0
    }

    foreach ($entry in $currentEntries) {
        if (Test-Path -LiteralPath $entry.destinationPath -PathType Leaf) {
            if (-not $previousByPath.ContainsKey($entry.path)) {
                throw "Projection destination is not owned by the dogfood installer: '$($entry.path)'"
            }
        }
    }

    foreach ($path in $orphaned) {
        $destination = Join-Path $resolvedRoot ($path -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        Assert-NoReparsePoint -Root $resolvedRoot -Path $destination
        if (Test-Path -LiteralPath $destination -PathType Leaf) {
            $previousHash = $previousByPath[$path]
            if ((Get-Sha256 -Path $destination) -ne $previousHash) {
                throw "Refusing to remove locally modified stale projection '$path'. Restore it or remove it manually."
            }
        }
    }

    foreach ($entry in $currentEntries) {
        $parent = Split-Path -Parent $entry.destinationPath
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        Copy-Item -LiteralPath $entry.sourcePath -Destination $entry.destinationPath -Force
    }
    foreach ($path in $orphaned) {
        $destination = Join-Path $resolvedRoot ($path -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        Assert-NoReparsePoint -Root $resolvedRoot -Path $destination
        if (Test-Path -LiteralPath $destination -PathType Leaf) {
            Remove-Item -LiteralPath $destination -Force
        }
    }

    $manifestDirectory = Split-Path -Parent $manifestPath
    New-Item -ItemType Directory -Path $manifestDirectory -Force | Out-Null
    $manifestTempPath = "$manifestPath.tmp"
    Assert-NoReparsePoint -Root $resolvedRoot -Path $manifestTempPath
    [ordered]@{
        schemaVersion = 1
        entries = @(
            $currentEntries | ForEach-Object {
                [ordered]@{
                    path = $_.path
                    sha256 = $_.sha256
                }
            }
        )
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestTempPath -Encoding UTF8
    Move-Item -LiteralPath $manifestTempPath -Destination $manifestPath -Force

    Write-Host "Dogfood self-install complete: $($currentEntries.Count) projected, $($orphaned.Count) stale file(s) removed."
}
catch {
    Write-Error $_
    exit 1
}
