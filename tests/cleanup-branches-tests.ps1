#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$scriptPath = Join-Path $repoRoot 'scripts\cleanup-branches.ps1'
$publisherPath = Join-Path $repoRoot 'scripts\publish-orphaned-lane-ledger.ps1'
$runtimeScriptPath = Join-Path $repoRoot '.github\base-coat\scripts\cleanup-branches.ps1'
$runtimePublisherPath = Join-Path $repoRoot '.github\base-coat\scripts\publish-orphaned-lane-ledger.ps1'
$workflowPath = Join-Path $repoRoot '.github\workflows\sprint-closeout-branch-audit.yml'
$distributedWorkflowPath = Join-Path $repoRoot '.github\base-coat\workflows\sprint-closeout-branch-audit.yml'

if (-not (Test-Path $scriptPath)) {
    throw 'Cleanup script is missing: scripts/cleanup-branches.ps1'
}

if (-not (Test-Path $workflowPath)) {
    throw 'Branch audit workflow is missing: .github/workflows/sprint-closeout-branch-audit.yml'
}
if (-not (Test-Path $distributedWorkflowPath)) {
    throw 'Distributed branch audit workflow is missing'
}
if (-not (Test-Path $publisherPath)) {
    throw 'Orphaned-lane publisher is missing: scripts/publish-orphaned-lane-ledger.ps1'
}
if (-not (Test-Path $runtimeScriptPath) -or -not (Test-Path $runtimePublisherPath)) {
    throw 'Distributed branch-audit runtime scripts are missing'
}

$scriptContent = Get-Content $runtimeScriptPath -Raw
$publisherContent = Get-Content $runtimePublisherPath -Raw
$scriptWrapperContent = Get-Content $scriptPath -Raw
$publisherWrapperContent = Get-Content $publisherPath -Raw
$workflowContent = Get-Content $workflowPath -Raw
$distributedWorkflowContent = Get-Content $distributedWorkflowPath -Raw

foreach ($wrapper in @($scriptWrapperContent, $publisherWrapperContent)) {
    if ($wrapper -notmatch [regex]::Escape('.github\base-coat\scripts')) {
        throw 'Root runtime wrappers must delegate to the distributed implementation'
    }
}

$requiredScriptSnippets = @(
    'param(',
    '[int]$StaleDays = 30',
    '[switch]$ApplyChanges',
    '[string]$LedgerPath',
    'git for-each-ref refs/remotes/origin',
    "throw 'Unable to refresh origin refs; branch audit stopped without deleting branches.'",
    'git worktree list --porcelain',
    "throw 'Unable to map worktrees; branch audit stopped without deleting branches.'",
    'orphaned-local-worktree-owned',
    'retained-worktree-owned',
    '%(objectname)',
    'git branch -r --merged',
    'git merge-base --is-ancestor',
    'gh pr list --state all',
    '--limit 10000',
    'headRefOid',
    'baseRefName',
    'Get-ExactHeadPrEvidence',
    'Get-FreshExactHeadPullRequests',
    "throw 'Unable to query pull request evidence; branch audit stopped without deleting branches.'",
    'pr-evidence-query-failed',
    'stale-squash-merged-pr-#',
    'stale-closed-unmerged-pr-#',
    'stale-merged-pr-non-default-base-#',
    'stale-ambiguous-exact-head-prs',
    'stale-pr-head-moved',
    '--force-with-lease=refs/heads/$($item.Branch):$($item.RemoteObjectId)',
    'TerminalState',
    'Owner',
    'nextAction',
    '$failedRemote',
    '$failedLocal',
    '$LASTEXITCODE -eq 0',
    'ConvertTo-Json',
    'GITHUB_STEP_SUMMARY'
)

foreach ($snippet in $requiredScriptSnippets) {
    if ($scriptContent -notmatch [regex]::Escape($snippet)) {
        throw "Cleanup script is missing required snippet: $snippet"
    }
}

if ($scriptContent -cmatch 'git branch -D') {
    throw 'Cleanup script must not force-delete local branches'
}
if ($scriptContent -notmatch [regex]::Escape('$finalWorktreeBranches = Get-WorktreeBranchMap')) {
    throw 'Apply mode must refresh worktree mappings immediately before remote deletion'
}

$requiredPublisherSnippets = @(
    'Orphaned lane ledger',
    'basecoat-orphaned-lane-ledger',
    "terminalState -in @('HANDED_OFF', 'PARKED')",
    "gh issue list --state open --search 'basecoat-orphaned-lane-ledger in:body' --limit 1000",
    "throw 'Unable to query the marker-keyed orphaned-lane issue.'",
    '$_.body.Contains($marker',
    "@('issue', 'edit'",
    "@('issue', 'create'",
    "@('issue', 'close'",
    'Invoke-GhIssueMutation',
    '$LASTEXITCODE -ne 0',
    '$lane.owner',
    '$lane.nextAction',
    '[switch]$DryRun'
)
foreach ($snippet in $requiredPublisherSnippets) {
    if ($publisherContent -notmatch [regex]::Escape($snippet)) {
        throw "Orphaned-lane publisher is missing required snippet: $snippet"
    }
}

$requiredWorkflowSnippets = @(
    'schedule:',
    'workflow_dispatch:',
    'apply_changes',
    'publish_issue',
    'stale_days',
    'contents: write',
    'issues: write',
    'timeout-minutes: 20',
    'group: ${{ github.workflow }}-${{ github.ref }}',
    'scripts/cleanup-branches.ps1',
    'scripts/publish-orphaned-lane-ledger.ps1',
    "if: github.event_name != 'workflow_dispatch' || inputs.publish_issue",
    'orphaned-lane-ledger',
    'actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a'
)

foreach ($snippet in $requiredWorkflowSnippets) {
    if ($workflowContent -notmatch [regex]::Escape($snippet)) {
        throw "Branch audit workflow is missing required snippet: $snippet"
    }
}

foreach ($snippet in @(
    'issues: write',
    'publish_issue',
    'LedgerPath',
    '.github/base-coat/scripts/cleanup-branches.ps1',
    '.github/base-coat/scripts/publish-orphaned-lane-ledger.ps1',
    'orphaned-lane-ledger'
)) {
    if ($distributedWorkflowContent -notmatch [regex]::Escape($snippet)) {
        throw "Distributed branch audit workflow is missing required snippet: $snippet"
    }
}

if ($workflowContent -match 'pull_request_target:' -or $distributedWorkflowContent -match 'pull_request_target:') {
    throw 'Branch cleanup must not run destructive apply mode automatically from pull_request_target'
}

if ($workflowContent -notmatch 'name:\s*"?BaseCoat\s*-\s*Sprint Closeout Branch Audit"?' ) {
    throw 'Branch audit workflow is missing required BaseCoat-prefixed workflow name'
}

if ($workflowContent -notmatch 'uses:\s*actions/checkout@[a-f0-9]{40}') {
    throw 'Branch audit workflow must pin actions/checkout to a full commit SHA'
}

$leaseTestRoot = Join-Path $repoRoot ('test-results\branch-delete-lease-' + [Guid]::NewGuid().ToString('N'))
$leaseRemote = Join-Path $leaseTestRoot 'origin.git'
$leaseFirst = Join-Path $leaseTestRoot 'first'
$leaseSecond = Join-Path $leaseTestRoot 'second'
$leaseLocationPushed = $false
try {
    New-Item -ItemType Directory -Path $leaseTestRoot -Force | Out-Null
    git init --bare $leaseRemote | Out-Null
    git init $leaseFirst | Out-Null
    Push-Location $leaseFirst
    $leaseLocationPushed = $true
    git config user.name 'branch-cleanup-test'
    git config user.email 'branch-cleanup-test@example.com'
    Set-Content tracked.txt 'baseline'
    git add tracked.txt
    git commit -m 'test: establish lease baseline' | Out-Null
    git branch -M feat/lease-test
    git remote add origin $leaseRemote
    git push --set-upstream origin feat/lease-test | Out-Null
    $auditedObjectId = (git rev-parse HEAD).Trim()
    Pop-Location
    $leaseLocationPushed = $false

    git clone --branch feat/lease-test $leaseRemote $leaseSecond | Out-Null
    Push-Location $leaseSecond
    $leaseLocationPushed = $true
    git config user.name 'branch-cleanup-test'
    git config user.email 'branch-cleanup-test@example.com'
    Set-Content tracked.txt 'moved'
    git commit -am 'test: move remote tip' | Out-Null
    git push origin feat/lease-test | Out-Null
    Pop-Location
    $leaseLocationPushed = $false

    Push-Location $leaseFirst
    $leaseLocationPushed = $true
    $leaseArgument = "--force-with-lease=refs/heads/feat/lease-test:$auditedObjectId"
    git push $leaseArgument origin --delete feat/lease-test 2>$null
    if ($LASTEXITCODE -eq 0) {
        throw 'Exact-tip deletion lease must reject a remote branch that moved after audit'
    }
    if (@(git ls-remote --heads origin refs/heads/feat/lease-test).Count -ne 1) {
        throw 'Exact-tip deletion lease must retain the moved remote branch'
    }
}
finally {
    if ($leaseLocationPushed) {
        Pop-Location
    }
    if (Test-Path $leaseTestRoot) {
        Remove-Item $leaseTestRoot -Recurse -Force
    }
}

$worktreeTestRoot = Join-Path $repoRoot ('test-results\branch-worktree-guard-' + [Guid]::NewGuid().ToString('N'))
$worktreeRemote = Join-Path $worktreeTestRoot 'origin.git'
$worktreeRepo = Join-Path $worktreeTestRoot 'work'
$linkedWorktree = Join-Path $worktreeTestRoot 'linked'
$remoteLinkedWorktree = Join-Path $worktreeTestRoot 'remote-linked'
$fakeBin = Join-Path $worktreeTestRoot 'bin'
$worktreeLocationPushed = $false
$originalPath = $env:PATH
$originalAuthorDate = $env:GIT_AUTHOR_DATE
$originalCommitterDate = $env:GIT_COMMITTER_DATE
$originalRealGit = $env:BASECOAT_REAL_GIT
$originalWorktreeCounter = $env:BASECOAT_WORKTREE_COUNTER
try {
    New-Item -ItemType Directory -Path $worktreeTestRoot, $fakeBin -Force | Out-Null
    Set-Content -Path (Join-Path $fakeBin 'gh.cmd') -Value '@echo []'
    @'
#!/usr/bin/env bash
printf '%s\n' '[]'
'@ | Set-Content -Path (Join-Path $fakeBin 'gh') -NoNewline
    if (-not $IsWindows) {
        chmod +x (Join-Path $fakeBin 'gh')
    }
    $realGit = (Get-Command git).Source
    @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
if ($Arguments.Count -ge 3 -and $Arguments[0] -eq 'worktree' -and $Arguments[1] -eq 'list' -and $Arguments[2] -eq '--porcelain') {
    $count = if (Test-Path $env:BASECOAT_WORKTREE_COUNTER) {
        [int](Get-Content $env:BASECOAT_WORKTREE_COUNTER -Raw)
    }
    else {
        0
    }
    $count++
    Set-Content -Path $env:BASECOAT_WORKTREE_COUNTER -Value $count
    & $env:BASECOAT_REAL_GIT @Arguments
    if ($count -ge 3) {
        Write-Output ''
        Write-Output 'worktree simulated-apply-remap'
        Write-Output 'HEAD 0000000000000000000000000000000000000000'
        Write-Output 'branch refs/heads/feat/apply-remap'
    }
    exit $LASTEXITCODE
}
& $env:BASECOAT_REAL_GIT @Arguments
exit $LASTEXITCODE
'@ | Set-Content -Path (Join-Path $fakeBin 'fake-git.ps1')
    Copy-Item (Join-Path $fakeBin 'fake-git.ps1') (Join-Path $fakeBin 'git.ps1')

    git init --bare $worktreeRemote | Out-Null
    git init $worktreeRepo | Out-Null
    Push-Location $worktreeRepo
    $worktreeLocationPushed = $true
    git config user.name 'branch-worktree-test'
    git config user.email 'branch-worktree-test@example.com'
    $oldCommitDate = (Get-Date).ToUniversalTime().AddDays(-3).ToString('o')
    $env:GIT_AUTHOR_DATE = $oldCommitDate
    $env:GIT_COMMITTER_DATE = $oldCommitDate
    Set-Content tracked.txt 'baseline'
    git add tracked.txt
    git commit -m 'test: establish main' | Out-Null
    git branch -M main
    git remote add origin $worktreeRemote
    git push --set-upstream origin main | Out-Null
    git checkout -b feat/worktree-owned | Out-Null
    Set-Content tracked.txt 'feature'
    git commit -am 'test: add worktree-owned branch' | Out-Null
    git push --set-upstream origin feat/worktree-owned | Out-Null
    git checkout main | Out-Null
    git merge --no-ff feat/worktree-owned -m 'test: merge worktree-owned branch' | Out-Null
    git push origin main | Out-Null
    git worktree add $linkedWorktree feat/worktree-owned | Out-Null
    git push origin --delete feat/worktree-owned | Out-Null
    git checkout -b feat/remote-worktree-owned main | Out-Null
    Set-Content remote-worktree.txt 'feature'
    git add remote-worktree.txt
    git commit -m 'test: add remote worktree-owned branch' | Out-Null
    git push --set-upstream origin feat/remote-worktree-owned | Out-Null
    git checkout main | Out-Null
    git merge --no-ff feat/remote-worktree-owned -m 'test: merge remote worktree-owned branch' | Out-Null
    git push origin main | Out-Null
    git worktree add $remoteLinkedWorktree feat/remote-worktree-owned | Out-Null
    git checkout -b feat/apply-remap main | Out-Null
    Set-Content apply-remap.txt 'feature'
    git add apply-remap.txt
    git commit -m 'test: add apply-time remap branch' | Out-Null
    git push --set-upstream origin feat/apply-remap | Out-Null
    git checkout main | Out-Null
    git merge --no-ff feat/apply-remap -m 'test: merge apply-time remap branch' | Out-Null
    git push origin main | Out-Null

    $env:BASECOAT_REAL_GIT = $realGit
    $env:BASECOAT_WORKTREE_COUNTER = Join-Path $worktreeTestRoot 'worktree-counter.txt'
    $env:PATH = "$fakeBin$([IO.Path]::PathSeparator)$originalPath"
    $ledgerPath = Join-Path $worktreeTestRoot 'ledger.json'
    & pwsh -NoProfile -File $runtimeScriptPath -StaleDays 1 -LedgerPath $ledgerPath -AssumeYes -ApplyChanges
    if ($LASTEXITCODE -ne 0) {
        throw 'Branch cleanup audit failed for the worktree-ownership fixture'
    }

    $worktreeLane = @((Get-Content $ledgerPath -Raw | ConvertFrom-Json).lanes) |
        Where-Object { $_.lane -eq 'feat/worktree-owned' } |
        Select-Object -First 1
    if (-not $worktreeLane -or $worktreeLane.state -ne 'orphaned-local-worktree-owned' -or $worktreeLane.safeToDelete) {
        throw 'Branch cleanup must retain a local branch mapped to another worktree'
    }
    if ($worktreeLane.nextAction -notmatch 'mapped worktree.*recover any WIP') {
        throw 'Local worktree-owned ledger rows must use the verify/recover mapped-worktree action'
    }

    $remoteWorktreeLane = @((Get-Content $ledgerPath -Raw | ConvertFrom-Json).lanes) |
        Where-Object { $_.lane -eq 'feat/remote-worktree-owned' -and $_.source -eq 'remote' } |
        Select-Object -First 1
    if (-not $remoteWorktreeLane -or $remoteWorktreeLane.state -ne 'retained-worktree-owned' -or $remoteWorktreeLane.safeToDelete) {
        throw 'Branch cleanup must retain a remote branch mapped to any worktree'
    }
    if ($remoteWorktreeLane.nextAction -notmatch 'mapped worktree.*recover any WIP') {
        throw 'Remote worktree-owned ledger rows must use the verify/recover mapped-worktree action'
    }
    if (@(git ls-remote --heads origin refs/heads/feat/remote-worktree-owned).Count -ne 1) {
        throw 'Apply mode must not delete a remote branch mapped to a worktree'
    }
    $applyRemapLane = @((Get-Content $ledgerPath -Raw | ConvertFrom-Json).lanes) |
        Where-Object { $_.lane -eq 'feat/apply-remap' -and $_.source -eq 'remote' } |
        Select-Object -First 1
    if (-not $applyRemapLane -or $applyRemapLane.state -ne 'retained-worktree-owned' -or $applyRemapLane.safeToDelete) {
        throw 'Apply mode must retain a branch whose worktree mapping appears immediately before deletion'
    }
    if (@(git ls-remote --heads origin refs/heads/feat/apply-remap).Count -ne 1) {
        throw 'Apply-time worktree remapping must retain the remote branch'
    }
}
finally {
    $env:PATH = $originalPath
    $env:GIT_AUTHOR_DATE = $originalAuthorDate
    $env:GIT_COMMITTER_DATE = $originalCommitterDate
    $env:BASECOAT_REAL_GIT = $originalRealGit
    $env:BASECOAT_WORKTREE_COUNTER = $originalWorktreeCounter
    if ($worktreeLocationPushed) {
        Pop-Location
    }
    if (Test-Path $worktreeRepo) {
        git -C $worktreeRepo worktree remove $linkedWorktree 2>$null
        git -C $worktreeRepo worktree remove $remoteLinkedWorktree 2>$null
    }
    if (Test-Path $worktreeTestRoot) {
        Remove-Item $worktreeTestRoot -Recurse -Force
    }
}

$prEvidenceTestRoot = Join-Path $repoRoot ('test-results\branch-pr-evidence-' + [Guid]::NewGuid().ToString('N'))
$prEvidenceRemote = Join-Path $prEvidenceTestRoot 'origin.git'
$prEvidenceRepo = Join-Path $prEvidenceTestRoot 'work'
$prEvidenceFakeBin = Join-Path $prEvidenceTestRoot 'bin'
$prEvidenceLocationPushed = $false
$originalPath = $env:PATH
$originalAuthorDate = $env:GIT_AUTHOR_DATE
$originalCommitterDate = $env:GIT_COMMITTER_DATE
$originalFakeGhJson = $env:FAKE_GH_PR_JSON
$originalFakeGhFailure = $env:FAKE_GH_QUERY_FAIL
$originalFakeGhHeadFailure = $env:FAKE_GH_HEAD_QUERY_FAIL
try {
    New-Item -ItemType Directory -Path $prEvidenceTestRoot, $prEvidenceFakeBin -Force | Out-Null
    @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
if ($env:FAKE_GH_QUERY_FAIL -eq '1') {
    [Console]::Error.WriteLine('simulated PR query failure')
    exit 41
}
if ($env:FAKE_GH_HEAD_QUERY_FAIL -eq '1' -and $Arguments -contains '--head') {
    [Console]::Error.WriteLine('simulated exact-head PR query failure')
    exit 42
}
[Console]::Out.WriteLine($env:FAKE_GH_PR_JSON)
'@ | Set-Content -Path (Join-Path $prEvidenceFakeBin 'fake-gh.ps1')
    Set-Content -Path (Join-Path $prEvidenceFakeBin 'gh.cmd') -Value '@pwsh -NoProfile -File "%~dp0fake-gh.ps1" %*'
    @'
#!/usr/bin/env bash
exec pwsh -NoProfile -File "$(dirname "$0")/fake-gh.ps1" "$@"
'@ | Set-Content -Path (Join-Path $prEvidenceFakeBin 'gh') -NoNewline
    if (-not $IsWindows) {
        chmod +x (Join-Path $prEvidenceFakeBin 'gh')
    }

    git init --bare $prEvidenceRemote | Out-Null
    git init $prEvidenceRepo | Out-Null
    Push-Location $prEvidenceRepo
    $prEvidenceLocationPushed = $true
    git config user.name 'branch-pr-evidence-test'
    git config user.email 'branch-pr-evidence-test@example.com'
    $oldCommitDate = (Get-Date).ToUniversalTime().AddDays(-3).ToString('o')
    $env:GIT_AUTHOR_DATE = $oldCommitDate
    $env:GIT_COMMITTER_DATE = $oldCommitDate

    Set-Content baseline.txt 'baseline'
    git add baseline.txt
    git commit -m 'test: establish main' | Out-Null
    git branch -M main
    git remote add origin $prEvidenceRemote
    git push --set-upstream origin main | Out-Null

    git checkout -b feat/squash-merged | Out-Null
    Set-Content squash.txt 'squash'
    git add squash.txt
    git commit -m 'test: create squash branch' | Out-Null
    $squashOid = (git rev-parse HEAD).Trim()
    git push --set-upstream origin feat/squash-merged | Out-Null
    git checkout main | Out-Null
    git merge --squash feat/squash-merged | Out-Null
    git commit -m 'test: squash merge feature' | Out-Null
    git push origin main | Out-Null

    git checkout -b feat/closed-unmerged main | Out-Null
    Set-Content closed.txt 'closed'
    git add closed.txt
    git commit -m 'test: create closed branch' | Out-Null
    $closedOid = (git rev-parse HEAD).Trim()
    git push --set-upstream origin feat/closed-unmerged | Out-Null

    git checkout -b feat/ambiguous main | Out-Null
    Set-Content ambiguous.txt 'ambiguous'
    git add ambiguous.txt
    git commit -m 'test: create ambiguous branch' | Out-Null
    $ambiguousOid = (git rev-parse HEAD).Trim()
    git push --set-upstream origin feat/ambiguous | Out-Null

    git checkout -b feat/moved-tip main | Out-Null
    Set-Content moved.txt 'old'
    git add moved.txt
    git commit -m 'test: create original moved branch tip' | Out-Null
    $movedOldOid = (git rev-parse HEAD).Trim()
    Set-Content moved.txt 'new'
    git commit -am 'test: move branch tip' | Out-Null
    git push --set-upstream origin feat/moved-tip | Out-Null
    git checkout main | Out-Null

    git checkout -b feat/non-default-base main | Out-Null
    Set-Content non-default.txt 'non-default'
    git add non-default.txt
    git commit -m 'test: create non-default-base branch' | Out-Null
    $nonDefaultOid = (git rev-parse HEAD).Trim()
    git push --set-upstream origin feat/non-default-base | Out-Null
    git checkout main | Out-Null

    git checkout -b feat/local-squash main | Out-Null
    Set-Content local-squash.txt 'local squash'
    git add local-squash.txt
    git commit -m 'test: create local squash branch' | Out-Null
    $localSquashOid = (git rev-parse HEAD).Trim()
    git push --set-upstream origin feat/local-squash | Out-Null
    git checkout main | Out-Null
    git merge --squash feat/local-squash | Out-Null
    git commit -m 'test: squash merge local-only feature' | Out-Null
    git push origin main | Out-Null
    git push origin --delete feat/local-squash | Out-Null

    $env:FAKE_GH_PR_JSON = @(
        [pscustomobject]@{ number = 101; state = 'MERGED'; headRefName = 'feat/squash-merged'; headRefOid = $squashOid; baseRefName = 'main'; mergedAt = '2026-01-01T00:00:00Z'; closedAt = '2026-01-01T00:00:00Z'; assignees = @(); author = @{ login = 'squash-owner' }; url = 'https://example.test/101' }
        [pscustomobject]@{ number = 102; state = 'CLOSED'; headRefName = 'feat/closed-unmerged'; headRefOid = $closedOid; baseRefName = 'main'; mergedAt = $null; closedAt = '2026-01-01T00:00:00Z'; assignees = @(); author = @{ login = 'closed-owner' }; url = 'https://example.test/102' }
        [pscustomobject]@{ number = 103; state = 'MERGED'; headRefName = 'feat/ambiguous'; headRefOid = $ambiguousOid; baseRefName = 'main'; mergedAt = '2026-01-01T00:00:00Z'; closedAt = '2026-01-01T00:00:00Z'; assignees = @(); author = @{ login = 'ambiguous-owner' }; url = 'https://example.test/103' }
        [pscustomobject]@{ number = 104; state = 'MERGED'; headRefName = 'feat/ambiguous'; headRefOid = $ambiguousOid; baseRefName = 'main'; mergedAt = '2026-01-01T00:00:00Z'; closedAt = '2026-01-01T00:00:00Z'; assignees = @(); author = @{ login = 'ambiguous-owner' }; url = 'https://example.test/104' }
        [pscustomobject]@{ number = 105; state = 'MERGED'; headRefName = 'feat/moved-tip'; headRefOid = $movedOldOid; baseRefName = 'main'; mergedAt = '2026-01-01T00:00:00Z'; closedAt = '2026-01-01T00:00:00Z'; assignees = @(); author = @{ login = 'moved-owner' }; url = 'https://example.test/105' }
        [pscustomobject]@{ number = 106; state = 'MERGED'; headRefName = 'feat/non-default-base'; headRefOid = $nonDefaultOid; baseRefName = 'develop'; mergedAt = '2026-01-01T00:00:00Z'; closedAt = '2026-01-01T00:00:00Z'; assignees = @(); author = @{ login = 'other-base-owner' }; url = 'https://example.test/106' }
        [pscustomobject]@{ number = 107; state = 'MERGED'; headRefName = 'feat/local-squash'; headRefOid = $localSquashOid; baseRefName = 'main'; mergedAt = '2026-01-01T00:00:00Z'; closedAt = '2026-01-01T00:00:00Z'; assignees = @(); author = @{ login = 'local-squash-owner' }; url = 'https://example.test/107' }
    ) | ConvertTo-Json -Depth 5 -Compress
    $env:FAKE_GH_QUERY_FAIL = '0'
    $env:FAKE_GH_HEAD_QUERY_FAIL = '0'
    $env:PATH = "$prEvidenceFakeBin$([IO.Path]::PathSeparator)$originalPath"

    $ledgerPath = Join-Path $prEvidenceTestRoot 'ledger.json'
    & pwsh -NoProfile -File $runtimeScriptPath -StaleDays 1 -LedgerPath $ledgerPath -AssumeYes
    if ($LASTEXITCODE -ne 0) {
        throw 'Branch cleanup audit failed for exact-head PR evidence fixture'
    }
    $lanes = @((Get-Content $ledgerPath -Raw | ConvertFrom-Json).lanes)
    $squashLane = $lanes | Where-Object lane -eq 'feat/squash-merged' | Select-Object -First 1
    $closedLane = $lanes | Where-Object lane -eq 'feat/closed-unmerged' | Select-Object -First 1
    $ambiguousLane = $lanes | Where-Object lane -eq 'feat/ambiguous' | Select-Object -First 1
    $movedLane = $lanes | Where-Object lane -eq 'feat/moved-tip' | Select-Object -First 1
    $nonDefaultLane = $lanes | Where-Object lane -eq 'feat/non-default-base' | Select-Object -First 1
    $localSquashLane = $lanes | Where-Object lane -eq 'feat/local-squash' | Select-Object -First 1
    if (-not $squashLane.safeToDelete -or $squashLane.terminalState -ne 'MERGED' -or $squashLane.state -ne 'stale-squash-merged-pr-#101') {
        throw 'Exact audited PR head evidence must classify squash-merged branches as MERGED'
    }
    if ($closedLane.safeToDelete -or $closedLane.state -ne 'stale-closed-unmerged-pr-#102') {
        throw 'Closed-unmerged exact-head PR evidence must fail closed'
    }
    if ($ambiguousLane.safeToDelete -or $ambiguousLane.state -ne 'stale-ambiguous-exact-head-prs') {
        throw 'Ambiguous exact-head PR evidence must fail closed'
    }
    if ($movedLane.safeToDelete -or $movedLane.state -ne 'stale-pr-head-moved') {
        throw 'Moved PR head evidence must fail closed'
    }
    if ($nonDefaultLane.safeToDelete -or $nonDefaultLane.state -ne 'stale-merged-pr-non-default-base-#106') {
        throw 'Merged PR evidence targeting a non-default base must fail closed'
    }
    if ($localSquashLane.safeToDelete -or $localSquashLane.state -ne 'orphaned-local-squash-merged-retained-pr-#107' -or
        $localSquashLane.nextAction -notmatch 'non-force branch deletion cannot prove squash topology') {
        throw 'Local squash-merged branches must use the explicit retained cleanup path'
    }

    $env:FAKE_GH_QUERY_FAIL = '1'
    $queryFailureOutput = & pwsh -NoProfile -File $runtimeScriptPath -StaleDays 1 -LedgerPath (Join-Path $prEvidenceTestRoot 'query-failure.json') -AssumeYes 2>&1
    if ($LASTEXITCODE -eq 0 -or ($queryFailureOutput -join "`n") -notmatch 'Unable to query pull request evidence') {
        throw 'PR query failures must stop cleanup without deleting branches'
    }

    $env:FAKE_GH_QUERY_FAIL = '0'
    $env:FAKE_GH_HEAD_QUERY_FAIL = '1'
    $headQueryFailureLedgerPath = Join-Path $prEvidenceTestRoot 'head-query-failure.json'
    & pwsh -NoProfile -File $runtimeScriptPath -StaleDays 1 -LedgerPath $headQueryFailureLedgerPath -AssumeYes -ApplyChanges
    if ($LASTEXITCODE -ne 0) {
        throw 'Apply mode must fail closed without crashing when exact-head PR refresh fails'
    }
    $headQueryFailureLane = @((Get-Content $headQueryFailureLedgerPath -Raw | ConvertFrom-Json).lanes) |
        Where-Object lane -eq 'feat/squash-merged' |
        Select-Object -First 1
    if (-not $headQueryFailureLane -or $headQueryFailureLane.state -ne 'pr-evidence-query-failed' -or
        $headQueryFailureLane.action -ne 'delete-failed' -or $headQueryFailureLane.safeToDelete) {
        throw 'Per-branch PR refresh failures must retain the branch and record fail-closed ledger evidence'
    }
    if (@(git ls-remote --heads origin refs/heads/feat/squash-merged).Count -ne 1) {
        throw 'Per-branch PR refresh failure must retain the remote branch'
    }

    $env:FAKE_GH_HEAD_QUERY_FAIL = '0'
    $applyLedgerPath = Join-Path $prEvidenceTestRoot 'apply-ledger.json'
    & pwsh -NoProfile -File $runtimeScriptPath -StaleDays 1 -LedgerPath $applyLedgerPath -AssumeYes -ApplyChanges
    if ($LASTEXITCODE -ne 0) {
        throw 'Branch cleanup apply failed for exact-head PR evidence fixture'
    }
    if (@(git ls-remote --heads origin refs/heads/feat/squash-merged).Count -ne 0) {
        throw 'Apply mode must delete a squash-merged branch only after fresh exact-head verification'
    }
    foreach ($retainedBranch in @('feat/closed-unmerged', 'feat/ambiguous', 'feat/moved-tip', 'feat/non-default-base')) {
        if (@(git ls-remote --heads origin "refs/heads/$retainedBranch").Count -ne 1) {
            throw "Apply mode must retain fail-closed branch '$retainedBranch'"
        }
        git show-ref --verify --quiet refs/heads/feat/local-squash
        if ($LASTEXITCODE -ne 0) {
            throw 'Apply mode must retain a local squash-merged branch that non-force deletion cannot prove'
        }
    }
}
finally {
    $env:PATH = $originalPath
    $env:GIT_AUTHOR_DATE = $originalAuthorDate
    $env:GIT_COMMITTER_DATE = $originalCommitterDate
    $env:FAKE_GH_PR_JSON = $originalFakeGhJson
    $env:FAKE_GH_QUERY_FAIL = $originalFakeGhFailure
    $env:FAKE_GH_HEAD_QUERY_FAIL = $originalFakeGhHeadFailure
    if ($prEvidenceLocationPushed) {
        Pop-Location
    }
    if (Test-Path $prEvidenceTestRoot) {
        Remove-Item $prEvidenceTestRoot -Recurse -Force
    }
}

Write-Host 'cleanup-branches tests passed' -ForegroundColor Green
