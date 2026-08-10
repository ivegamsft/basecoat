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

    [string[]]$ProtectedBranchPrefixes = @('preserved/', 'backup/', 'wip/'),

    [string]$LedgerPath = 'test-results/lane-closeout/orphaned-lanes.json',

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

function Test-ProtectedBranchPrefix {
    param(
        [string]$Branch,
        [string[]]$Prefixes
    )

    foreach ($prefix in $Prefixes) {
        if (-not [string]::IsNullOrWhiteSpace($prefix) -and $Branch.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
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
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to refresh origin refs; branch audit stopped without deleting branches.'
}

$worktreeBranches = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$worktreeOutput = git worktree list --porcelain
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to map worktrees; branch audit stopped without deleting branches.'
}
foreach ($line in @($worktreeOutput)) {
    if ($line -match '^branch refs/heads/(.+)$') {
        [void]$worktreeBranches.Add($Matches[1])
    }
}

$openPrHeads = @{}
$openPrJson = gh pr list --state open --limit 10000 --json number,headRefName,assignees,author
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to query open pull requests; branch audit stopped without deleting branches.'
}
$openPrs = $openPrJson | ConvertFrom-Json
foreach ($pr in @($openPrs)) {
    if (-not [string]::IsNullOrWhiteSpace($pr.headRefName)) {
        $owner = if (@($pr.assignees).Count -gt 0) {
            $pr.assignees[0].login
        }
        elseif ($pr.author.login) {
            $pr.author.login
        }
        else {
            'unknown'
        }
        $openPrHeads[$pr.headRefName] = [pscustomobject]@{
            Number = [int]$pr.number
            Owner  = $owner
        }
    }
}

$mergedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$mergedRemoteBranches = git branch -r --merged "origin/$DefaultBranch"
if ($LASTEXITCODE -ne 0) {
    throw "Unable to classify branches merged into origin/$DefaultBranch."
}
foreach ($entry in @($mergedRemoteBranches)) {
    $branchName = ($entry -replace '^\s*origin/', '').Trim()
    if ($branchName -and $branchName -ne 'HEAD') {
        [void]$mergedSet.Add($branchName)
    }
}

$nowUtc = [DateTimeOffset]::UtcNow
$remoteAudit = @()
$remoteRefs = git for-each-ref refs/remotes/origin --format='%(refname:short)|%(committerdate:unix)|%(committerdate:iso8601-strict)|%(objectname)'
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to enumerate remote branches.'
}

foreach ($line in @($remoteRefs)) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }

    $parts = $line.Split('|', 4)
    if ($parts.Count -lt 4) {
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
    $hasProtectedPrefix = Test-ProtectedBranchPrefix -Branch $branch -Prefixes $ProtectedBranchPrefixes
    $safeToDelete = $isStale -and $isMerged -and -not $hasOpenPr -and -not $hasProtectedPrefix

    $state = if (-not $isStale) {
        'recent'
    }
    elseif ($hasProtectedPrefix) {
        'retained-protected-wip'
    }
    elseif ($safeToDelete) {
        'stale-merged'
    }
    elseif ($hasOpenPr) {
        "stale-open-pr-#$($openPrHeads[$branch].Number)"
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
        TerminalState = if ($safeToDelete) { 'MERGED' } elseif ($hasOpenPr) { 'HANDED_OFF' } else { 'PARKED' }
        PrNumber      = if ($hasOpenPr) { $openPrHeads[$branch].Number } else { $null }
        Owner         = if ($hasOpenPr) { $openPrHeads[$branch].Owner } else { 'unknown' }
        RemoteObjectId = $parts[3].Trim()
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
$localRetained = @()
$localRefs = git for-each-ref refs/heads --format='%(refname:short)|%(upstream:track)'
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to enumerate local branches.'
}
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
        if ($worktreeBranches.Contains($branch)) {
            $localRetained += [pscustomobject]@{
                Branch        = $branch
                AgeDays       = '-'
                LastCommitUtc = '-'
                State         = 'orphaned-local-worktree-owned'
                TerminalState = 'PARKED'
                Owner         = 'unknown'
                SafeToDelete  = $false
            }
            continue
        }

        git merge-base --is-ancestor $branch "origin/$DefaultBranch" 2>$null
        $isMergedLocal = $LASTEXITCODE -eq 0
        $hasProtectedPrefix = Test-ProtectedBranchPrefix -Branch $branch -Prefixes $ProtectedBranchPrefixes

        if ($hasProtectedPrefix -or -not $isMergedLocal) {
            $localRetained += [pscustomobject]@{
                Branch        = $branch
                AgeDays       = '-'
                LastCommitUtc = '-'
                State         = if ($hasProtectedPrefix) { 'orphaned-local-retained' } else { 'orphaned-local-unverified' }
                TerminalState = 'PARKED'
                Owner         = 'unknown'
                SafeToDelete  = $false
            }
            continue
        }
        $localOrphaned += [pscustomobject]@{
            Branch        = $branch
            AgeDays       = '-'
            LastCommitUtc = '-'
            State         = 'orphaned-local-merged'
            TerminalState = 'MERGED'
            Owner         = 'unknown'
            SafeToDelete  = $true
        }
    }
}

$deletedRemote = @()
$deletedLocal = @()
$failedRemote = @()
$failedLocal = @()
if ($ApplyChanges) {
    $totalDeletes = $deletableRemote.Count + $localOrphaned.Count
    if ($totalDeletes -gt 0) {
        if (-not (Confirm-Continue "Proceed with deleting $totalDeletes branch(es)?")) {
            Write-Host 'Deletion cancelled by user.'
            exit 0
        }
    }

    foreach ($item in $deletableRemote) {
        $exactPrJson = gh pr list --state open --head $item.Branch --limit 1 --json number,headRefName,assignees,author
        if ($LASTEXITCODE -ne 0) {
            $failedRemote += $item.Branch
            Write-Warning "Skipped remote deletion for '$($item.Branch)': exact-head PR verification failed."
            continue
        }

        $exactOpenPr = @($exactPrJson | ConvertFrom-Json) | Select-Object -First 1
        if ($exactOpenPr) {
            $owner = if (@($exactOpenPr.assignees).Count -gt 0) {
                $exactOpenPr.assignees[0].login
            }
            elseif ($exactOpenPr.author.login) {
                $exactOpenPr.author.login
            }
            else {
                'unknown'
            }
            $item.SafeToDelete = $false
            $item.State = "stale-open-pr-#$($exactOpenPr.number)"
            $item.TerminalState = 'HANDED_OFF'
            $item.PrNumber = [int]$exactOpenPr.number
            $item.Owner = $owner
            Write-Warning "Skipped remote deletion for '$($item.Branch)': open PR #$($exactOpenPr.number) was found during final verification."
            continue
        }

        $leaseArgument = "--force-with-lease=refs/heads/$($item.Branch):$($item.RemoteObjectId)"
        git push $leaseArgument origin --delete $item.Branch | Out-Host
        if ($LASTEXITCODE -eq 0) {
            $deletedRemote += $item.Branch
        }
        else {
            $failedRemote += $item.Branch
        }
    }

    foreach ($item in $localOrphaned) {
        git branch -d $item.Branch | Out-Host
        if ($LASTEXITCODE -eq 0) {
            $deletedLocal += $item.Branch
        }
        else {
            $failedLocal += $item.Branch
        }
    }
}

$ledgerRows = @()
foreach ($item in $staleRemote) {
    $ledgerRows += [pscustomobject]@{
        lane          = $item.Branch
        source        = 'remote'
        state         = $item.State
        terminalState = $item.TerminalState
        prNumber      = $item.PrNumber
        owner         = $item.Owner
        ageDays       = $item.AgeDays
        safeToDelete  = $item.SafeToDelete
        action        = if ($deletedRemote -contains $item.Branch) { 'deleted' } elseif ($failedRemote -contains $item.Branch) { 'delete-failed' } elseif ($item.SafeToDelete) { 'prune-candidate' } else { 'retained' }
        nextAction    = if ($failedRemote -contains $item.Branch) {
            'Resolve remote protection or permissions, then retry verified branch deletion.'
        }
        elseif ($item.TerminalState -eq 'HANDED_OFF') {
            "Resolve PR #$($item.PrNumber) gates, then rerun lane-closeout."
        }
        elseif ($item.TerminalState -eq 'PARKED') {
            if ($item.State -eq 'orphaned-local-worktree-owned') {
                'Verify the mapped worktree is inactive and clean before retrying branch cleanup.'
            }
            else {
                'Assign an owner, preserve WIP, and record the next recovery action.'
            }
        }
        else {
            'Prune only after exact branch/worktree safety verification.'
        }
    }
}
foreach ($item in @($localOrphaned) + @($localRetained)) {
    $ledgerRows += [pscustomobject]@{
        lane          = $item.Branch
        source        = 'local'
        state         = $item.State
        terminalState = $item.TerminalState
        prNumber      = $null
        owner         = $item.Owner
        ageDays       = $null
        safeToDelete  = $item.SafeToDelete
        action        = if ($deletedLocal -contains $item.Branch) { 'deleted' } elseif ($failedLocal -contains $item.Branch) { 'delete-failed' } elseif ($item.SafeToDelete) { 'prune-candidate' } else { 'retained' }
        nextAction    = if ($failedLocal -contains $item.Branch) {
            'Verify worktree ownership and retry non-force local branch deletion.'
        }
        elseif ($item.TerminalState -eq 'PARKED') {
            'Assign an owner, preserve WIP, and record the next recovery action.'
        }
        else {
            'Prune only after exact branch/worktree safety verification.'
        }
    }
}

if ($LedgerPath) {
    $ledgerParent = Split-Path $LedgerPath -Parent
    if ($ledgerParent -and -not (Test-Path $ledgerParent)) {
        New-Item -ItemType Directory -Path $ledgerParent -Force | Out-Null
    }

    [pscustomobject]@{
        schemaVersion = 1
        generatedAt   = (Get-Date).ToUniversalTime().ToString('o')
        repository    = (git config --get remote.origin.url)
        defaultBranch = $DefaultBranch
        staleDays     = $StaleDays
        applyChanges  = [bool]$ApplyChanges
        lanes         = $ledgerRows
    } | ConvertTo-Json -Depth 6 | Set-Content -Path $LedgerPath -Encoding utf8
}

Write-Host "Branch audit summary:"
Write-Host "  stale threshold days: $StaleDays"
Write-Host "  stale remote branches: $($staleRemote.Count)"
Write-Host "  safe remote deletions: $($deletableRemote.Count)"
Write-Host "  retained stale branches: $($retainedStale.Count)"
Write-Host "  orphaned local branches: $($localOrphaned.Count)"
Write-Host "  retained local branches: $($localRetained.Count)"
if ($ApplyChanges) {
    Write-Host "  deleted remote branches: $($deletedRemote.Count)"
    Write-Host "  deleted local branches: $($deletedLocal.Count)"
    Write-Host "  failed remote deletions: $($failedRemote.Count)"
    Write-Host "  failed local deletions: $($failedLocal.Count)"
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

if ($localRetained.Count -gt 0) {
    Write-Host ''
    Write-Host 'Retained local branches (manual follow-up required):'
    $localRetained | Format-Table Branch, State -AutoSize
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
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value "| Retained local branches | $($localRetained.Count) |"
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value "| Failed deletions | $($failedRemote.Count + $failedLocal.Count) |"
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value "| Ledger records | $($ledgerRows.Count) |"
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value ""

    Write-MarkdownTable -Path $env:GITHUB_STEP_SUMMARY -Title 'Safe Remote Deletion Candidates' -Rows $deletableRemote
    Write-MarkdownTable -Path $env:GITHUB_STEP_SUMMARY -Title 'Retained Stale Branches' -Rows $retainedStale
    Write-MarkdownTable -Path $env:GITHUB_STEP_SUMMARY -Title 'Retained Local Branches' -Rows $localRetained
}
