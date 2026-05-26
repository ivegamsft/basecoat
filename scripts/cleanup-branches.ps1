#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Audit and optionally clean stale remote branches plus orphaned local branches.

.DESCRIPTION
  By default this script runs in audit mode and reports:
  - stale remote branches (age >= StaleDays)
  - stale+merged remote branches safe to delete
  - local orphaned branches (tracking upstream gone)

  Use -ApplyChanges to delete safe remote branches and local orphaned branches.
#>
param(
    [ValidateRange(1, 365)]
    [int]$StaleDays = 30,

    [string]$DefaultBranch = 'main',

    [string[]]$ProtectedBranches = @('main', 'master', 'develop'),

    [switch]$ApplyChanges,

    [switch]$AssumeYes
)

$ErrorActionPreference = 'Stop'

function Write-MarkdownTable {
    param(
        [string]$Path,
        [string]$Title,
        [object[]]$Rows
    )

    if (-not $Path) {
        return
    }

    Add-Content -Path $Path -Value "## $Title"
    Add-Content -Path $Path -Value ""

    if (-not $Rows -or $Rows.Count -eq 0) {
        Add-Content -Path $Path -Value "_None_"
        Add-Content -Path $Path -Value ""
        return
    }

    Add-Content -Path $Path -Value "| Branch | Age (days) | Last commit UTC | State |"
    Add-Content -Path $Path -Value "|---|---:|---|---|"
    foreach ($row in $Rows) {
        Add-Content -Path $Path -Value "| $($row.Branch) | $($row.AgeDays) | $($row.LastCommitUtc) | $($row.State) |"
    }
    Add-Content -Path $Path -Value ""
}

function Confirm-Continue {
    param([string]$Message)

    if ($AssumeYes) {
        return $true
    }

    $response = Read-Host "$Message (y/N)"
    return $response -match '^(y|yes)$'
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git is required but was not found in PATH.'
}

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    throw 'Run this script inside a git repository.'
}

Set-Location $repoRoot

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'gh CLI is required but was not found in PATH.'
}

git fetch origin --prune | Out-Null

$openPrHeads = @{}
$openPrs = gh pr list --state open --limit 200 --json number,headRefName | ConvertFrom-Json
foreach ($pr in @($openPrs)) {
    if (-not [string]::IsNullOrWhiteSpace($pr.headRefName)) {
        $openPrHeads[$pr.headRefName] = [int]$pr.number
    }
}

$mergedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$mergedRemoteBranches = git branch -r --merged "origin/$DefaultBranch"
foreach ($entry in @($mergedRemoteBranches)) {
    $branchName = ($entry -replace '^\s*origin/', '').Trim()
    if ($branchName -and $branchName -ne 'HEAD') {
        [void]$mergedSet.Add($branchName)
    }
}

$nowUtc = [DateTimeOffset]::UtcNow
$remoteAudit = @()
$remoteRefs = git for-each-ref refs/remotes/origin --format='%(refname:short)|%(committerdate:unix)|%(committerdate:iso8601-strict)'

foreach ($line in @($remoteRefs)) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }

    $parts = $line.Split('|', 3)
    if ($parts.Count -lt 3) {
        continue
    }

    $fullRef = $parts[0].Trim()
    if ($fullRef -eq 'origin/HEAD') {
        continue
    }

    $branch = $fullRef -replace '^origin/', ''
    if ($ProtectedBranches -contains $branch) {
        continue
    }

    $epoch = 0L
    if (-not [long]::TryParse($parts[1], [ref]$epoch)) {
        continue
    }

    $lastCommit = [DateTimeOffset]::FromUnixTimeSeconds($epoch).UtcDateTime
    $ageDays = [int][Math]::Floor(($nowUtc - [DateTimeOffset]::FromUnixTimeSeconds($epoch)).TotalDays)
    $isStale = $ageDays -ge $StaleDays
    $isMerged = $mergedSet.Contains($branch)
    $hasOpenPr = $openPrHeads.ContainsKey($branch)
    $safeToDelete = $isStale -and $isMerged -and -not $hasOpenPr

    $state = if (-not $isStale) {
        'recent'
    }
    elseif ($safeToDelete) {
        'stale-merged'
    }
    elseif ($hasOpenPr) {
        "stale-open-pr-#$($openPrHeads[$branch])"
    }
    elseif (-not $isMerged) {
        'stale-unmerged'
    }
    else {
        'stale'
    }

    $remoteAudit += [pscustomobject]@{
        Branch        = $branch
        AgeDays       = $ageDays
        LastCommitUtc = $lastCommit.ToString('yyyy-MM-dd HH:mm:ss')
        State         = $state
        SafeToDelete  = $safeToDelete
    }
}

$staleRemote = @(
    $remoteAudit |
    Where-Object { $_.AgeDays -ge $StaleDays } |
    Sort-Object -Property @{ Expression = 'AgeDays'; Descending = $true }, Branch
)
$deletableRemote = @($staleRemote | Where-Object { $_.SafeToDelete })
$retainedStale = @($staleRemote | Where-Object { -not $_.SafeToDelete })

$currentBranch = (git branch --show-current).Trim()
$localOrphaned = @()
$localRefs = git for-each-ref refs/heads --format='%(refname:short)|%(upstream:track)'
foreach ($line in @($localRefs)) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }
    $parts = $line.Split('|', 2)
    if ($parts.Count -lt 2) {
        continue
    }
    $branch = $parts[0].Trim()
    $track = $parts[1].Trim()
    if ($branch -eq $currentBranch) {
        continue
    }
    if ($ProtectedBranches -contains $branch) {
        continue
    }
    if ($track -match '\[gone\]') {
        $localOrphaned += [pscustomobject]@{
            Branch        = $branch
            AgeDays       = '-'
            LastCommitUtc = '-'
            State         = 'orphaned-local'
        }
    }
}

$deletedRemote = @()
$deletedLocal = @()
if ($ApplyChanges) {
    $totalDeletes = $deletableRemote.Count + $localOrphaned.Count
    if ($totalDeletes -gt 0) {
        if (-not (Confirm-Continue "Proceed with deleting $totalDeletes branch(es)?")) {
            Write-Host 'Deletion cancelled by user.'
            exit 0
        }
    }

    foreach ($item in $deletableRemote) {
        git push origin --delete $item.Branch | Out-Host
        $deletedRemote += $item.Branch
    }

    foreach ($item in $localOrphaned) {
        git branch -D $item.Branch | Out-Host
        $deletedLocal += $item.Branch
    }
}

Write-Host "Branch audit summary:"
Write-Host "  stale threshold days: $StaleDays"
Write-Host "  stale remote branches: $($staleRemote.Count)"
Write-Host "  safe remote deletions: $($deletableRemote.Count)"
Write-Host "  retained stale branches: $($retainedStale.Count)"
Write-Host "  orphaned local branches: $($localOrphaned.Count)"
if ($ApplyChanges) {
    Write-Host "  deleted remote branches: $($deletedRemote.Count)"
    Write-Host "  deleted local branches: $($deletedLocal.Count)"
}
else {
    Write-Host '  mode: audit only (no deletions applied)'
}

if ($deletableRemote.Count -gt 0) {
    Write-Host ''
    Write-Host 'Safe remote deletion candidates:'
    $deletableRemote | Format-Table Branch, AgeDays, LastCommitUtc, State -AutoSize
}

if ($retainedStale.Count -gt 0) {
    Write-Host ''
    Write-Host 'Retained stale branches (require owner and expiry tracking):'
    $retainedStale | Format-Table Branch, AgeDays, LastCommitUtc, State -AutoSize
}

if ($localOrphaned.Count -gt 0) {
    Write-Host ''
    Write-Host 'Orphaned local branches:'
    $localOrphaned | Format-Table Branch, State -AutoSize
}

if ($env:GITHUB_STEP_SUMMARY) {
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value "# Branch Audit"
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value ""
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value "| Metric | Value |"
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value "|---|---:|"
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value "| Stale remote branches | $($staleRemote.Count) |"
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value "| Safe remote deletions | $($deletableRemote.Count) |"
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value "| Retained stale branches | $($retainedStale.Count) |"
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value "| Orphaned local branches | $($localOrphaned.Count) |"
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value ""

    Write-MarkdownTable -Path $env:GITHUB_STEP_SUMMARY -Title 'Safe Remote Deletion Candidates' -Rows $deletableRemote
    Write-MarkdownTable -Path $env:GITHUB_STEP_SUMMARY -Title 'Retained Stale Branches' -Rows $retainedStale
}
