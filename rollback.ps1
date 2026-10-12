#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Rolls a consumer repo back to a specific BaseCoat release tag.

.DESCRIPTION
    Re-runs the sibling sync.ps1 for a release tag so the staged payload, projections,
    and guidance-lock/v1 match a fresh sync of that tag. Any failure restores the prior install
    and pin, except GUIDANCE_LOCK_BUSY (lease reclaimed as stale), which keeps the backup instead.
    Run from the root of a consumer repository.

.PARAMETER Tag
    The BaseCoat release tag to roll back to (e.g. v3.25.0).
    If omitted, shows the current version and the 5 most-recent release tags.

.PARAMETER Repo
    The BaseCoat GitHub repository (HTTPS clone URL).
    Defaults to the BASECOAT_REPO env var, then the 'source:' key in .basecoat.yml.

.PARAMETER TargetDir
    Directory in the consumer repo where BaseCoat assets live.
    Defaults to '.github/base-coat'.

.EXAMPLE
    pwsh rollback.ps1 -Tag v3.25.0
    pwsh rollback.ps1 -Tag v3.24.1 -Repo https://github.com/my-org/basecoat.git
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Tag = '',
    [string]$Repo = '',
    [string]$TargetDir = ''
)

$ErrorActionPreference = 'Stop'

$sourceRepo = if ($Repo)      { $Repo }      `
  elseif ($env:BASECOAT_REPO) { $env:BASECOAT_REPO } `
  else                        { $null }

$targetDir = if ($TargetDir)        { $TargetDir }        `
  elseif ($env:BASECOAT_TARGET_DIR) { $env:BASECOAT_TARGET_DIR } `
  else                              { '.github/base-coat' }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git is required'
}

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    throw 'Run this inside a git repository'
}

$fullTargetDir = Join-Path $repoRoot $targetDir

# ── Show current version and available tags if no tag given ──────────────────

if (-not $Tag) {
    $versionFile = Join-Path $fullTargetDir 'version.json'
    $currentVersion = if (Test-Path $versionFile) {
        (Get-Content $versionFile -Raw | ConvertFrom-Json).version
    } else {
        'unknown'
    }
    Write-Host "Current BaseCoat version : v$currentVersion"
    Write-Host ""
    Write-Host "Recent release tags:"
    $listRepo = if ($sourceRepo) { $sourceRepo } else {
        Select-String -LiteralPath (Join-Path $repoRoot '.basecoat.yml') -Pattern '^source:\s*["'']?([^"''#\s]+)' -ErrorAction SilentlyContinue |
            Select-Object -First 1 | ForEach-Object { $_.Matches[0].Groups[1].Value }
    }
    if (-not $listRepo) { Write-Host "  (no source configured - set BASECOAT_REPO or 'source:' in .basecoat.yml)" }
    else { git ls-remote --tags --sort='-version:refname' $listRepo 'v*' 2>$null | Select-String 'refs/tags/(v[\d\.]+)$' | ForEach-Object { "  " + $_.Matches[0].Groups[1].Value } | Select-Object -First 10 }
    Write-Host ""
    Write-Host "Usage: pwsh rollback.ps1 -Tag <tag>"
    exit 0
}

# ── Normalise tag ─────────────────────────────────────────────────────────────

if (-not $Tag.StartsWith('v')) { $Tag = "v$Tag" }

# ── Confirm rollback ──────────────────────────────────────────────────────────

$versionFile = Join-Path $fullTargetDir 'version.json'
$priorVersion = if (Test-Path $versionFile) {
    (Get-Content $versionFile -Raw | ConvertFrom-Json).version
} else {
    'unknown'
}

Write-Host "Rolling back BaseCoat: v$priorVersion -> $Tag"
Write-Host "Source : $(if ($sourceRepo) { $sourceRepo } else { '.basecoat.yml source' })"
Write-Host "Target : $fullTargetDir"
Write-Host ""

if (-not $PSCmdlet.ShouldProcess($fullTargetDir, "rollback to $Tag")) {
    exit 0
}

# ── Re-sync the target tag through sync.ps1 ───────────────────────────────────

$syncScript = Join-Path $PSScriptRoot 'sync.ps1'
if (-not (Test-Path -LiteralPath $syncScript -PathType Leaf)) {
    throw "rollback.ps1 requires sync.ps1 beside it ('$syncScript') to replay projections and guidance-lock/v1."
}

$lockHelper = @((Join-Path $PSScriptRoot 'scripts/guidance-lock.ps1'), (Join-Path $repoRoot '.github/base-coat/scripts/guidance-lock.ps1')) |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $lockHelper) { throw "rollback.ps1 requires scripts/guidance-lock.ps1 beside it or in .github/base-coat/scripts." }
. $lockHelper

$backupRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("basecoat-rollback-" + [System.Guid]::NewGuid().ToString('N'))
# Snapshot every tree sync may write. The guidance-lock lease is held from snapshot through the
# .basecoat.yml pin and inherited by sync, so no concurrent writer can commit in between.
$snapshotPaths = @(
    '.github/base-coat', '.github/agents', '.github/agent-references', '.github/instructions',
    '.github/prompts', '.github/skills', '.agents/skills'
) | ForEach-Object { [System.IO.Path]::GetFullPath((Join-Path $repoRoot $_)) }
$envNames = @('BASECOAT_REPO', 'BASECOAT_REF', 'BASECOAT_TARGET_DIR', 'BASECOAT_GUIDANCE_LEASE')
$savedEnv = @{}; $keepBackup = $false
foreach ($name in $envNames) { $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name) }
$configPath = Join-Path $repoRoot '.basecoat.yml'
$originalConfig = if (Test-Path -LiteralPath $configPath -PathType Leaf) { [System.IO.File]::ReadAllBytes($configPath) }
$leasePath = Enter-GuidanceLockLease -RepoRoot $repoRoot
$leaseDir = [System.IO.Path]::GetFullPath(($leasePath -split '\|', 2)[0])

try {
    $index = 0
    $snapshots = foreach ($path in @([System.IO.Path]::GetFullPath($fullTargetDir)) + $snapshotPaths | Select-Object -Unique) {
        $index++
        $snapshot = [pscustomobject]@{ Path = $path; Backup = (Join-Path $backupRoot "$index"); Existed = (Test-Path -LiteralPath $path) }
        New-Item -ItemType Directory -Path $snapshot.Backup -Force | Out-Null
        if ($snapshot.Existed) {
            Get-ChildItem -LiteralPath $path -Force | Where-Object { $_.FullName -ne $leaseDir } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $snapshot.Backup -Recurse -Force }
        }
        $snapshot
    }
    if ($sourceRepo) { $env:BASECOAT_REPO = $sourceRepo }
    $env:BASECOAT_REF = $Tag
    $env:BASECOAT_TARGET_DIR = $targetDir
    $env:BASECOAT_GUIDANCE_LEASE = $leasePath

    # A child process of the current host keeps sync's exit/throw from ending this script.
    & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $syncScript
    $syncExitCode = $LASTEXITCODE
    if (-not (Select-String -LiteralPath (Join-Path $leaseDir 'owner') -Pattern "^token=$([regex]::Escape(($leasePath -split '\|', 2)[1]))$" -Quiet -ErrorAction SilentlyContinue)) {
        $keepBackup = $true
        throw "GUIDANCE_LOCK_BUSY lease='$leaseDir' reason='lease reclaimed as stale during sync' syncExitCode='$syncExitCode'; rollback to $Tag was NOT restored or pinned to avoid overwriting a concurrent writer. Backup kept at '$backupRoot'."
    }
    try {
        if ($syncExitCode -ne 0) { throw "sync exit code $syncExitCode" }
        # sync may redirect a known-bad tag; pin the ref it actually installed.
        $provenancePath = Join-Path $fullTargetDir '.source-provenance.json'
        $installedRef = if (Test-Path -LiteralPath $provenancePath -PathType Leaf) { (Get-Content -LiteralPath $provenancePath -Raw | ConvertFrom-Json).requestedRef }
        if ($installedRef) { $Tag = [string]$installedRef }
        if ($null -ne $originalConfig) {
            $config = [System.IO.File]::ReadAllText($configPath)
            if ($config -match '(?m)^ref:') { $config = [regex]::Replace($config, '(?m)^ref:[^\r\n]*', "ref: $($Tag.Replace('$', '$$'))") }
            else {
                $newline = if ($config -match "`r`n") { "`r`n" } else { "`n" }
                if ($config.Length -gt 0 -and -not $config.EndsWith("`n")) { $config += $newline }
                $config += "ref: $Tag$newline"
            }
            [System.IO.File]::WriteAllText($configPath, $config, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "Updated .basecoat.yml ref pin to $Tag"
        }
    }
    catch {
        foreach ($snapshot in $snapshots) {
            if (Test-Path -LiteralPath $snapshot.Path) {
                Get-ChildItem -LiteralPath $snapshot.Path -Force | Where-Object { $_.FullName -ne $leaseDir } | Remove-Item -Recurse -Force
                if (-not $snapshot.Existed -and -not (Get-ChildItem -LiteralPath $snapshot.Path -Force)) { Remove-Item -LiteralPath $snapshot.Path -Force }
            }
            if ($snapshot.Existed) {
                New-Item -ItemType Directory -Path $snapshot.Path -Force | Out-Null
                Get-ChildItem -LiteralPath $snapshot.Backup -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $snapshot.Path -Recurse -Force }
            }
        }
        if ($null -ne $originalConfig -and [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($configPath)) -ne [Convert]::ToBase64String($originalConfig)) { [System.IO.File]::WriteAllBytes($configPath, $originalConfig) }
        throw "Rollback to $Tag failed ($($_.Exception.Message)); restored the previous payload, projections, guidance lock, and .basecoat.yml pin."
    }
}
finally {
    Exit-GuidanceLockLease -LeasePath $leasePath
    foreach ($name in $envNames) { [Environment]::SetEnvironmentVariable($name, $savedEnv[$name]) }
    if (-not $keepBackup -and (Test-Path -LiteralPath $backupRoot)) {
        Remove-Item -LiteralPath $backupRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "Rolled back to $Tag successfully."
Write-Host "  Run 'git diff --stat' to review changes before committing."
