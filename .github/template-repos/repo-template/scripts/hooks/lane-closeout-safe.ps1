$ErrorActionPreference = 'Stop'

$ledger = $null
$branch = $null

function Write-LaneLedger {
    param([hashtable]$Record)

    if (-not $ledger) {
        return
    }

    $Record.updatedAt = (Get-Date).ToUniversalTime().ToString('o')
    $Record | ConvertTo-Json -Depth 6 | Set-Content -Path $ledger -Encoding utf8
}

function Get-StashContentKey {
    param([string]$Ref)

    $parts = @(
        (git rev-parse "$Ref^{tree}" 2>$null),
        (git rev-parse "$Ref^2^{tree}" 2>$null)
    ) | Where-Object { $_ }
    $untracked = (git rev-parse "$Ref^3^{tree}" 2>$null)
    if ($LASTEXITCODE -eq 0 -and $untracked) {
        $parts += $untracked
    }
    return (($parts | ForEach-Object { $_.Trim().Substring(0, 8) }) -join '')
}

function Get-StashSensitivityKey {
    param([string]$Ref)

    $parts = @(
        (git rev-parse "$Ref^{tree}" 2>$null),
        (git rev-parse "$Ref^2^{tree}" 2>$null)
    ) | Where-Object { $_ }
    $untracked = (git rev-parse "$Ref^3^{tree}" 2>$null)
    if ($LASTEXITCODE -eq 0 -and $untracked) {
        $parts += $untracked
    }
    return (($parts | ForEach-Object { $_.Trim().Substring(0, 8) }) -join '')
}

function Test-RetainedStashSnapshot {
    param([string]$Ref)

    if ([string]::IsNullOrWhiteSpace($Ref)) {
        return $false
    }
    $retainedSnapshots = @(git stash list --format='%H' 2>$null)
    return $LASTEXITCODE -eq 0 -and $retainedSnapshots -contains $Ref
}

function Get-PorcelainStatusPaths {
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = 'git'
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    foreach ($argument in @('status', '--porcelain=v1', '-z', '--untracked-files=all')) {
        [void]$startInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $rawStatus = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        throw 'Unable to inspect lane status.'
    }

    $records = $rawStatus.Split([char]0, [StringSplitOptions]::RemoveEmptyEntries)
    $paths = [Collections.Generic.List[string]]::new()
    for ($index = 0; $index -lt $records.Count; $index++) {
        $record = $records[$index]
        if ($record.Length -lt 4) {
            continue
        }

        $statusCode = $record.Substring(0, 2)
        $paths.Add($record.Substring(3))
        if ($statusCode -match '[RC]' -and $index + 1 -lt $records.Count) {
            $index++
            $paths.Add($records[$index])
        }
    }
    return $paths
}

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        exit 0
    }

    $repoRoot = (git rev-parse --show-toplevel 2>$null)
    if (-not $repoRoot) {
        exit 0
    }

    Set-Location $repoRoot
    $branch = (git symbolic-ref --quiet --short HEAD 2>$null)
    if (-not $branch -or $branch -in @('main', 'master')) {
        exit 0
    }

    $gitDir = (git rev-parse --absolute-git-dir).Trim()
    $ledgerDir = Join-Path $gitDir 'basecoat\lane-closeout'
    New-Item -ItemType Directory -Path $ledgerDir -Force | Out-Null
    $ledgerPrefix = ($branch -replace '[^A-Za-z0-9._-]+', '-').Trim('-')
    if (-not $ledgerPrefix) {
        $ledgerPrefix = 'lane'
    }
    if ($ledgerPrefix.Length -gt 60) {
        $ledgerPrefix = $ledgerPrefix.Substring(0, 60).TrimEnd('-')
    }
    if (-not $ledgerPrefix) {
        $ledgerPrefix = 'lane'
    }
    $branchBytes = [Text.Encoding]::UTF8.GetBytes($branch)
    $branchHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($branchBytes)).ToLowerInvariant().Substring(0, 12)
    $ledgerName = "$ledgerPrefix-$branchHash.json"
    $ledger = Join-Path $ledgerDir $ledgerName

    $head = (git rev-parse HEAD).Trim()
    $statusPaths = @(Get-PorcelainStatusPaths)
    $record = @{
        mode = 'safe'
        lane = $branch
        head = $head
        dirty = ($statusPaths.Count -gt 0)
        terminalState = 'PARKED'
        wipRef = $null
        snapshot = $null
        snapshotContentKey = $null
        pushSucceeded = $false
        restoreSucceeded = $true
        nextAction = 'Run lane-closeout in full mode to resolve PR and gate state.'
    }

    if ($statusPaths.Count -eq 0) {
        $upstream = (git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>$null)
        if ($LASTEXITCODE -eq 0 -and $upstream) {
            git push origin $branch | Out-Null
        }
        else {
            git push --set-upstream origin $branch | Out-Null
        }
        $record.pushSucceeded = ($LASTEXITCODE -eq 0)
        if (-not $record.pushSucceeded) {
            $record.nextAction = 'Repair authentication or remote configuration, then rerun lane-closeout.'
        }
        Write-LaneLedger $record
        exit 0
    }

    $sensitivePath = $statusPaths | ForEach-Object {
        $path = $_
        $sensitiveDirectory = $path -match '(?i)(^|[\\/])(credentials?|secrets?)([\\/]|$)'
        $sensitiveFile = $path -match '(?i)(^|[\\/])(\.env(?:\..*)?|id_rsa|id_ed25519|[^\\/]+\.(pem|key|pfx|p12))$'
        if ($sensitiveDirectory -or $sensitiveFile) {
            $path
        }
    } | Select-Object -First 1

    $previousLedger = $null
    if (Test-Path $ledger) {
        try {
            $previousLedger = Get-Content $ledger -Raw | ConvertFrom-Json
        }
        catch {
            $previousLedger = $null
        }
    }
    $previousLedgerSnapshot = if ($previousLedger) { [string]$previousLedger.snapshot } else { '' }
    $previousLedgerContentKey = if ($previousLedger -and $previousLedger.PSObject.Properties['snapshotContentKey']) {
        [string]$previousLedger.snapshotContentKey
    }
    else { '' }
    $previousLedgerSnapshotWasRetained = Test-RetainedStashSnapshot $previousLedgerSnapshot

    $stashBefore = (git rev-parse --verify refs/stash 2>$null)
    if ($LASTEXITCODE -eq 0 -and $stashBefore) {
        $stashBefore = $stashBefore.Trim()
    }
    else {
        $stashBefore = $null
    }

    git stash push --include-untracked --message "basecoat safe lane capture: $branch" --quiet
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to create a safe WIP snapshot.'
    }

    $stashAfter = (git rev-parse --verify refs/stash 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $stashAfter -or $stashAfter.Trim() -eq $stashBefore) {
        if ($stashBefore -and
            $previousLedger -and
            $previousLedger.nextAction -match 'sensitive-path' -and
            $previousLedgerSnapshot -eq $stashBefore -and
            $previousLedgerSnapshotWasRetained) {
            $worktreeStillDirty = @(git status --porcelain=v1 --untracked-files=all).Count -gt 0
            if (-not $worktreeStillDirty) {
                git stash apply --index $previousLedgerSnapshot --quiet
                $worktreeStillDirty = $LASTEXITCODE -eq 0
            }
            $record.snapshot = $previousLedgerSnapshot
            $record.snapshotContentKey = if ($previousLedgerContentKey) {
                $previousLedgerContentKey
            }
            else {
                Get-StashSensitivityKey $previousLedgerSnapshot
            }
            $record.restoreSucceeded = $worktreeStillDirty
            $record.nextAction = if ($worktreeStillDirty) {
                'Review sensitive-path candidate before publishing WIP: retained sensitive-path candidate'
            }
            else {
                'Restore the retained stash manually before continuing.'
            }
            Write-LaneLedger $record
            exit 0
        }
        $record.error = 'git stash did not create a new WIP snapshot.'
        $record.nextAction = 'Capture submodule or unsupported WIP manually, then rerun lane-closeout.'
        Write-LaneLedger $record
        exit 0
    }

    $snapshot = $stashAfter.Trim()
    $tree = Get-StashContentKey $snapshot
    $sensitivityKey = Get-StashSensitivityKey $snapshot
    $previousSnapshot = (git rev-parse 'stash@{1}' 2>$null)
    $duplicateSensitiveSnapshot = $false
    if (-not $sensitivePath -and
        $previousLedger -and
        $previousLedger.nextAction -match 'sensitive-path' -and
        $previousLedger.snapshot -and
        $previousLedgerContentKey -eq $sensitivityKey) {
        $sensitivePath = 'retained sensitive-path candidate'
        if ($previousLedgerSnapshotWasRetained -and
            (Get-StashContentKey $previousLedgerSnapshot) -eq $tree) {
            $previousSnapshot = $previousLedgerSnapshot
            $duplicateSensitiveSnapshot = $true
        }
        else {
            $previousSnapshot = $null
        }
    }
    if ($sensitivePath -and $LASTEXITCODE -eq 0 -and $previousSnapshot) {
        $previousSnapshot = $previousSnapshot.Trim()
        $duplicateSensitiveSnapshot = (Get-StashContentKey $previousSnapshot) -eq $tree
    }
    $safeBranch = ($branch -replace '[^A-Za-z0-9._/-]', '-').Trim('/')
    if ($safeBranch.Length -gt 80) {
        $safeBranch = $safeBranch.Substring(0, 80).TrimEnd('-', '/')
    }
    $wipRef = "wip/$safeBranch-$tree"
    $record.snapshot = $snapshot
    $record.snapshotContentKey = $sensitivityKey
    $record.wipRef = $wipRef
    $record.terminalState = 'PARKED'

    if (-not $sensitivePath) {
        $remoteRef = @(git ls-remote --heads origin "refs/heads/$wipRef" 2>$null)
        if ($remoteRef.Count -gt 0) {
            $record.pushSucceeded = $true
        }
        else {
            git push origin "${snapshot}:refs/heads/$wipRef" | Out-Null
            $record.pushSucceeded = ($LASTEXITCODE -eq 0)
        }
    }
    else {
        $record.nextAction = "Review sensitive-path candidate before publishing WIP: $sensitivePath"
    }

    git stash apply --index $snapshot --quiet
    $record.restoreSucceeded = ($LASTEXITCODE -eq 0)
    if ($record.restoreSucceeded) {
        if ($duplicateSensitiveSnapshot -or -not $sensitivePath) {
            $currentStash = (git rev-parse 'stash@{0}' 2>$null)
            if ($currentStash -and $currentStash.Trim() -eq $snapshot) {
                git stash drop --quiet 'stash@{0}'
                if ($duplicateSensitiveSnapshot) {
                    $record.snapshot = $previousSnapshot
                    $record.snapshotContentKey = if ($previousLedgerContentKey) {
                        $previousLedgerContentKey
                    }
                    else {
                        Get-StashSensitivityKey $previousSnapshot
                    }
                }
            }
        }
    }
    else {
        $record.nextAction = 'Restore the retained stash manually before continuing.'
    }

    if (-not $record.pushSucceeded -and -not $sensitivePath) {
        $record.nextAction = 'Repair remote publishing, then push the recorded WIP snapshot.'
    }

    Write-LaneLedger $record
}
catch {
    Write-LaneLedger @{
        mode = 'safe'
        lane = $branch
        terminalState = 'PARKED'
        error = $_.Exception.Message
        nextAction = 'Inspect the lane and rerun lane-closeout; no cleanup was attempted.'
    }
    Write-Warning "BaseCoat safe lane closeout parked: $($_.Exception.Message)"
}

exit 0
