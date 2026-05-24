param(
    [string]$TargetDir = ".github/base-coat",
    [string]$StateFileName = ".sync-state.json",
    [switch]$ProtectCustomized = $true,
    [switch]$SetArchiveReadOnly = $true
)

$ErrorActionPreference = "Stop"

function Get-FileSha256 {
    param([string]$Path)
    if (-not (Test-Path $Path -PathType Leaf)) { return $null }
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLower()
}

function Remove-EmptyParents {
    param([string]$Path,[string]$StopAt)
    $dir = Split-Path -Path $Path -Parent
    while ($dir -and (Test-Path $dir) -and ($dir -ne $StopAt)) {
        $hasChildren = (Get-ChildItem -LiteralPath $dir -Force | Measure-Object).Count -gt 0
        if ($hasChildren) { break }
        Remove-Item -LiteralPath $dir -Force
        $dir = Split-Path -Path $dir -Parent
    }
}

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) { throw "Run this inside a git repository." }

$fullTargetDir = Join-Path $repoRoot $TargetDir
if (-not (Test-Path $fullTargetDir)) {
    Write-Host "Target directory not found: $fullTargetDir (nothing to clean)."
    exit 0
}

$manifestPath = Join-Path $fullTargetDir "asset-manifest.json"
if (-not (Test-Path $manifestPath)) {
    Write-Warning "asset-manifest.json not found in $fullTargetDir — skipping cleanup."
    exit 0
}

$statePath = Join-Path $fullTargetDir $StateFileName
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

$currentManaged = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

foreach ($a in @($manifest.assets)) {
    $rel = [string]$a.path
    if (-not $rel) { continue }
    $full = Join-Path $fullTargetDir $rel
    if (Test-Path $full -PathType Leaf) {
        [void]$currentManaged.Add($rel)
    }
}

foreach ($rootFile in @("README.md","CHANGELOG.md","version.json","asset-manifest.json","basecoat-metadata.json","INVENTORY.md")) {
    $full = Join-Path $fullTargetDir $rootFile
    if (Test-Path $full -PathType Leaf) { [void]$currentManaged.Add($rootFile) }
}

$prev = $null
if (Test-Path $statePath) {
    try { $prev = Get-Content $statePath -Raw | ConvertFrom-Json } catch { $prev = $null }
}

$removed = 0
$skippedCustomized = 0

if ($prev -and $prev.managedFiles) {
    $prevMap = @{}
    foreach ($f in @($prev.managedFiles)) {
        $prevMap[[string]$f.path] = [string]$f.sha256
    }

    foreach ($oldRel in $prevMap.Keys) {
        if ($currentManaged.Contains($oldRel)) { continue }

        $oldFull = Join-Path $fullTargetDir $oldRel
        if (-not (Test-Path $oldFull -PathType Leaf)) { continue }

        $currentSha = Get-FileSha256 $oldFull
        $prevSha = $prevMap[$oldRel]
        $isCustomized = $ProtectCustomized -and $prevSha -and $currentSha -and ($currentSha -ne $prevSha)

        if ($isCustomized) {
            Write-Host "SKIP customized stale file: $oldRel" -ForegroundColor Yellow
            $skippedCustomized++
            continue
        }

        Remove-Item -LiteralPath $oldFull -Force
        Remove-EmptyParents -Path $oldFull -StopAt $fullTargetDir
        Write-Host "Removed stale managed file: $oldRel"
        $removed++
    }
}

if ($SetArchiveReadOnly) {
    $archiveDir = Join-Path $fullTargetDir "docs/archive"
    if (Test-Path $archiveDir) {
        Get-ChildItem -Path $archiveDir -File -Recurse | ForEach-Object {
            $_.IsReadOnly = $true
        }
        Write-Host "Set archive files read-only under docs/archive."
    }
}

$newState = [ordered]@{
    schemaVersion = "1"
    generatedAt = (Get-Date).ToString("o")
    targetDir = $TargetDir
    managedFiles = @()
}

foreach ($rel in $currentManaged) {
    $full = Join-Path $fullTargetDir $rel
    $sha = Get-FileSha256 $full
    if ($sha) {
        $newState.managedFiles += [ordered]@{ path = $rel; sha256 = $sha }
    }
}

$newState.managedFiles = @($newState.managedFiles | Sort-Object path)
$newState | ConvertTo-Json -Depth 6 | Set-Content -Path $statePath -Encoding UTF8

Write-Host "Cleanup complete. Removed=$removed, SkippedCustomized=$skippedCustomized, StateFile=$statePath"

