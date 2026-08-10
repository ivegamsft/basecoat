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

function Get-WorktreeBranchMap {
    $branches = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $worktreeOutput = git worktree list --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to map worktrees; branch audit stopped without deleting branches.'
    }
    foreach ($line in @($worktreeOutput)) {
        if ($line -match '^branch refs/heads/(.+)$') {
            [void]$branches.Add($Matches[1])
        }
    }
    return ,$branches
}

function Get-PullRequestOwner {
    param([object]$PullRequest)

    if (@($PullRequest.assignees).Count -gt 0) {
        return $PullRequest.assignees[0].login
    }
    if ($PullRequest.author -and $PullRequest.author.login) {
        return $PullRequest.author.login
    }
    return 'unknown'
}

function Get-ExactHeadPrEvidence {
    param(
        [object[]]$PullRequests,
        [string]$Branch,
        [string]$AuditedObjectId,
        [string]$DefaultBranch
    )

    $candidates = @($PullRequests | Where-Object { $_.headRefName -ceq $Branch })
    $exactTip = @($candidates | Where-Object { $_.headRefOid -eq $AuditedObjectId })

    if ($exactTip.Count -gt 1) {
        return [pscustomobject]@{
            Kind = 'ambiguous'
            PullRequest = $null
            Owner = 'unknown'
        }
    }

    if ($exactTip.Count -eq 1) {
        $pr = $exactTip[0]
        $kind = if ($pr.mergedAt -or $pr.state -eq 'MERGED') {
            if ($pr.baseRefName -ceq $DefaultBranch) {
                'merged'
            }
            else {
                'merged-non-default-base'
            }
        }
        elseif ($pr.state -eq 'OPEN') {
            'open'
        }
        else {
            'closed-unmerged'
        }
        return [pscustomobject]@{
            Kind = $kind
            PullRequest = $pr
            Owner = Get-PullRequestOwner -PullRequest $pr
        }
    }

    if ($candidates.Count -gt 0) {
        return [pscustomobject]@{
            Kind = 'moved'
            PullRequest = $candidates[0]
            Owner = Get-PullRequestOwner -PullRequest $candidates[0]
        }
    }

    return [pscustomobject]@{
        Kind = 'none'
        PullRequest = $null
        Owner = 'unknown'
    }
}

function Get-FreshExactHeadPullRequests {
    param([string]$Branch)

    $json = gh pr list --state all --head $Branch --limit 100 --json number,state,headRefName,headRefOid,baseRefName,mergedAt,closedAt,assignees,author,url
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to refresh exact-head PR evidence for '$Branch'."
    }
    $pullRequests = @($json | ConvertFrom-Json)
    if ($pullRequests.Count -ge 100) {
        throw "Exact-head PR evidence for '$Branch' reached the query limit and is ambiguous."
    }
    return $pullRequests
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

$worktreeBranches = Get-WorktreeBranchMap

$allPrJson = gh pr list --state all --limit 10000 --json number,state,headRefName,headRefOid,baseRefName,mergedAt,closedAt,assignees,author,url
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to query pull request evidence; branch audit stopped without deleting branches.'
}
$allPrs = @($allPrJson | ConvertFrom-Json)
if ($allPrs.Count -ge 10000) {
    throw 'Pull request evidence reached the query limit; branch audit stopped without deleting branches.'
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
    $remoteObjectId = $parts[3].Trim()
    $isMergedByTopology = $mergedSet.Contains($branch)
    $prEvidence = Get-ExactHeadPrEvidence -PullRequests $allPrs -Branch $branch -AuditedObjectId $remoteObjectId -DefaultBranch $DefaultBranch
    $isMergedByPr = $prEvidence.Kind -eq 'merged'
    $hasOpenPr = $prEvidence.Kind -eq 'open'
    $isMappedWorktree = $worktreeBranches.Contains($branch)
    $hasProtectedPrefix = Test-ProtectedBranchPrefix -Branch $branch -Prefixes $ProtectedBranchPrefixes
    $hasBlockingPrEvidence = $prEvidence.Kind -in @('ambiguous', 'closed-unmerged', 'merged-non-default-base', 'moved')
    $isMerged = $isMergedByTopology -or $isMergedByPr
    $safeToDelete = $isStale -and $isMerged -and -not $hasOpenPr -and -not $hasBlockingPrEvidence -and -not $hasProtectedPrefix -and -not $isMappedWorktree

    $state = if (-not $isStale) {
        'recent'
    }
    elseif ($hasProtectedPrefix) {
        'retained-protected-wip'
    }
    elseif ($isMappedWorktree) {
        'retained-worktree-owned'
    }
    elseif ($prEvidence.Kind -eq 'ambiguous') {
        'stale-ambiguous-exact-head-prs'
    }
    elseif ($prEvidence.Kind -eq 'closed-unmerged') {
        "stale-closed-unmerged-pr-#$($prEvidence.PullRequest.number)"
    }
    elseif ($prEvidence.Kind -eq 'merged-non-default-base') {
        "stale-merged-pr-non-default-base-#$($prEvidence.PullRequest.number)"
    }
    elseif ($prEvidence.Kind -eq 'moved') {
        'stale-pr-head-moved'
    }
    elseif ($hasOpenPr) {
        "stale-open-pr-#$($prEvidence.PullRequest.number)"
    }
    elseif ($safeToDelete) {
        if ($isMergedByPr -and -not $isMergedByTopology) {
            "stale-squash-merged-pr-#$($prEvidence.PullRequest.number)"
        }
        else {
            'stale-merged'
        }
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
        PrNumber      = if ($prEvidence.PullRequest) { [int]$prEvidence.PullRequest.number } else { $null }
        Owner         = $prEvidence.Owner
        RemoteObjectId = $remoteObjectId
        SafeToDelete  = $safeToDelete
        MergedByTopology = $isMergedByTopology
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
                PrNumber      = $null
                SafeToDelete  = $false
            }
            continue
        }

        git merge-base --is-ancestor $branch "origin/$DefaultBranch" 2>$null
        $isMergedLocalByTopology = $LASTEXITCODE -eq 0
        $localObjectId = (git rev-parse $branch).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to inspect local branch tip '$branch'."
        }
        $localPrEvidence = Get-ExactHeadPrEvidence -PullRequests $allPrs -Branch $branch -AuditedObjectId $localObjectId -DefaultBranch $DefaultBranch
        $isMergedLocal = $isMergedLocalByTopology -or $localPrEvidence.Kind -eq 'merged'
        $hasBlockingLocalPrEvidence = $localPrEvidence.Kind -in @('ambiguous', 'closed-unmerged', 'merged-non-default-base', 'moved', 'open')
        $hasProtectedPrefix = Test-ProtectedBranchPrefix -Branch $branch -Prefixes $ProtectedBranchPrefixes

        if ($hasProtectedPrefix -or $hasBlockingLocalPrEvidence -or -not $isMergedLocal) {
            $localState = if ($hasProtectedPrefix) {
                'orphaned-local-retained'
            }
            elseif ($localPrEvidence.Kind -eq 'ambiguous') {
                'orphaned-local-ambiguous-exact-head-prs'
            }
            elseif ($localPrEvidence.Kind -eq 'closed-unmerged') {
                "orphaned-local-closed-unmerged-pr-#$($localPrEvidence.PullRequest.number)"
            }
            elseif ($localPrEvidence.Kind -eq 'merged-non-default-base') {
                "orphaned-local-merged-pr-non-default-base-#$($localPrEvidence.PullRequest.number)"
            }
            elseif ($localPrEvidence.Kind -eq 'moved') {
                'orphaned-local-pr-head-moved'
            }
            elseif ($localPrEvidence.Kind -eq 'open') {
                "orphaned-local-open-pr-#$($localPrEvidence.PullRequest.number)"
            }
            else {
                'orphaned-local-unverified'
            }
            $localRetained += [pscustomobject]@{
                Branch        = $branch
                AgeDays       = '-'
                LastCommitUtc = '-'
                State         = $localState
                TerminalState = if ($localPrEvidence.Kind -eq 'open') { 'HANDED_OFF' } else { 'PARKED' }
                Owner         = $localPrEvidence.Owner
                PrNumber      = if ($localPrEvidence.PullRequest) { [int]$localPrEvidence.PullRequest.number } else { $null }
                SafeToDelete  = $false
            }
            continue
        }
        if (-not $isMergedLocalByTopology -and $localPrEvidence.Kind -eq 'merged') {
            $localRetained += [pscustomobject]@{
                Branch        = $branch
                AgeDays       = '-'
                LastCommitUtc = '-'
                State         = "orphaned-local-squash-merged-retained-pr-#$($localPrEvidence.PullRequest.number)"
                TerminalState = 'PARKED'
                Owner         = $localPrEvidence.Owner
                PrNumber      = [int]$localPrEvidence.PullRequest.number
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
            Owner         = $localPrEvidence.Owner
            PrNumber      = if ($localPrEvidence.PullRequest) { [int]$localPrEvidence.PullRequest.number } else { $null }
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
        $freshWorktreeBranches = Get-WorktreeBranchMap
        if ($freshWorktreeBranches.Contains($item.Branch)) {
            $item.SafeToDelete = $false
            $item.State = 'retained-worktree-owned'
            $item.TerminalState = 'PARKED'
            Write-Warning "Skipped remote deletion for '$($item.Branch)': the branch is mapped to a worktree."
            continue
        }

        $freshRemoteLine = @(git ls-remote --heads origin "refs/heads/$($item.Branch)")
        if ($LASTEXITCODE -ne 0 -or $freshRemoteLine.Count -ne 1) {
            $failedRemote += $item.Branch
            $item.SafeToDelete = $false
            $item.State = 'remote-tip-query-failed'
            $item.TerminalState = 'PARKED'
            Write-Warning "Skipped remote deletion for '$($item.Branch)': the exact remote tip could not be refreshed."
            continue
        }

        $freshRemoteObjectId = ($freshRemoteLine[0] -split '\s+')[0]
        if ($freshRemoteObjectId -ne $item.RemoteObjectId) {
            $item.SafeToDelete = $false
            $item.State = 'remote-tip-moved'
            $item.TerminalState = 'PARKED'
            Write-Warning "Skipped remote deletion for '$($item.Branch)': the remote tip moved after audit."
            continue
        }

        try {
            $freshPrs = Get-FreshExactHeadPullRequests -Branch $item.Branch
        }
        catch {
            $failedRemote += $item.Branch
            $item.SafeToDelete = $false
            $item.State = 'pr-evidence-query-failed'
            $item.TerminalState = 'PARKED'
            Write-Warning "Skipped remote deletion for '$($item.Branch)': $($_.Exception.Message)"
            continue
        }

        $freshPrEvidence = Get-ExactHeadPrEvidence -PullRequests $freshPrs -Branch $item.Branch -AuditedObjectId $item.RemoteObjectId -DefaultBranch $DefaultBranch
        if ($freshPrEvidence.Kind -eq 'open') {
            $item.SafeToDelete = $false
            $item.State = "stale-open-pr-#$($freshPrEvidence.PullRequest.number)"
            $item.TerminalState = 'HANDED_OFF'
            $item.PrNumber = [int]$freshPrEvidence.PullRequest.number
            $item.Owner = $freshPrEvidence.Owner
            Write-Warning "Skipped remote deletion for '$($item.Branch)': open PR #$($freshPrEvidence.PullRequest.number) was found during final verification."
            continue
        }

        if ($freshPrEvidence.Kind -in @('ambiguous', 'closed-unmerged', 'merged-non-default-base', 'moved')) {
            $item.SafeToDelete = $false
            $item.TerminalState = 'PARKED'
            $item.State = switch ($freshPrEvidence.Kind) {
                'ambiguous' { 'stale-ambiguous-exact-head-prs' }
                'closed-unmerged' { "stale-closed-unmerged-pr-#$($freshPrEvidence.PullRequest.number)" }
                'merged-non-default-base' { "stale-merged-pr-non-default-base-#$($freshPrEvidence.PullRequest.number)" }
                'moved' { 'stale-pr-head-moved' }
            }
            Write-Warning "Skipped remote deletion for '$($item.Branch)': exact-head PR evidence is '$($freshPrEvidence.Kind)'."
            continue
        }

        if ($freshPrEvidence.Kind -eq 'none') {
            git merge-base --is-ancestor "origin/$($item.Branch)" "origin/$DefaultBranch" 2>$null
            if ($LASTEXITCODE -ne 0) {
                $item.SafeToDelete = $false
                $item.State = 'stale-unmerged'
                $item.TerminalState = 'PARKED'
                Write-Warning "Skipped remote deletion for '$($item.Branch)': neither topology nor exact-head PR evidence proves it merged."
                continue
            }
        }

        $finalWorktreeBranches = Get-WorktreeBranchMap
        if ($finalWorktreeBranches.Contains($item.Branch)) {
            $item.SafeToDelete = $false
            $item.State = 'retained-worktree-owned'
            $item.TerminalState = 'PARKED'
            Write-Warning "Skipped remote deletion for '$($item.Branch)': a worktree mapping appeared during final verification."
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
            if ($item.State -eq 'pr-evidence-query-failed') {
                'Restore GitHub PR query access, verify exact-head evidence, then rerun branch cleanup.'
            }
            elseif ($item.State -eq 'remote-tip-query-failed') {
                'Restore remote ref access, verify the exact branch tip, then rerun branch cleanup.'
            }
            else {
                'Resolve remote protection or permissions, then retry verified branch deletion.'
            }
        }
        elseif ($item.TerminalState -eq 'HANDED_OFF') {
            "Resolve PR #$($item.PrNumber) gates, then rerun lane-closeout."
        }
        elseif ($item.State -eq 'retained-worktree-owned') {
            'Verify the mapped worktree is inactive and clean, recover any WIP, then rerun branch cleanup.'
        }
        elseif ($item.TerminalState -eq 'PARKED') {
            'Assign an owner, preserve WIP, and record the next recovery action.'
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
        prNumber      = $item.PrNumber
        owner         = $item.Owner
        ageDays       = $null
        safeToDelete  = $item.SafeToDelete
        action        = if ($deletedLocal -contains $item.Branch) { 'deleted' } elseif ($failedLocal -contains $item.Branch) { 'delete-failed' } elseif ($item.SafeToDelete) { 'prune-candidate' } else { 'retained' }
        nextAction    = if ($failedLocal -contains $item.Branch) {
            'Verify worktree ownership and retry non-force local branch deletion.'
        }
        elseif ($item.TerminalState -eq 'PARKED') {
            if ($item.State -eq 'orphaned-local-worktree-owned') {
                'Verify the mapped worktree is inactive and clean, recover any WIP, then rerun branch cleanup.'
            }
            elseif ($item.State -like 'orphaned-local-squash-merged-retained-pr-*') {
                'Retain the branch until an explicit reviewed cleanup verifies the squash-merged PR; non-force branch deletion cannot prove squash topology.'
            }
            else {
                'Assign an owner, preserve WIP, and record the next recovery action.'
            }
        }
        elseif ($item.TerminalState -eq 'HANDED_OFF') {
            "Resolve PR #$($item.PrNumber) gates, then rerun lane-closeout."
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
