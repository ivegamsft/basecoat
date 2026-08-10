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
    '%(objectname)',
    'git branch -r --merged',
    'git merge-base --is-ancestor',
    'gh pr list --state open',
    '--limit 10000',
    'gh pr list --state open --head $item.Branch --limit 1',
    "throw 'Unable to query open pull requests; branch audit stopped without deleting branches.'",
    'exact-head PR verification failed',
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

$requiredPublisherSnippets = @(
    'Orphaned lane ledger',
    'basecoat-orphaned-lane-ledger',
    "terminalState -in @('HANDED_OFF', 'PARKED')",
    "gh issue list --state open --search 'basecoat-orphaned-lane-ledger in:body' --limit 1000",
    "throw 'Unable to query the marker-keyed orphaned-lane issue.'",
    '$_.body.Contains($marker',
    'gh issue edit',
    'gh issue create',
    'gh issue close',
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
$fakeBin = Join-Path $worktreeTestRoot 'bin'
$worktreeLocationPushed = $false
$originalPath = $env:PATH
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

    git init --bare $worktreeRemote | Out-Null
    git init $worktreeRepo | Out-Null
    Push-Location $worktreeRepo
    $worktreeLocationPushed = $true
    git config user.name 'branch-worktree-test'
    git config user.email 'branch-worktree-test@example.com'
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

    $env:PATH = "$fakeBin$([IO.Path]::PathSeparator)$originalPath"
    $ledgerPath = Join-Path $worktreeTestRoot 'ledger.json'
    & pwsh -NoProfile -File $runtimeScriptPath -StaleDays 1 -LedgerPath $ledgerPath -AssumeYes
    if ($LASTEXITCODE -ne 0) {
        throw 'Branch cleanup audit failed for the worktree-ownership fixture'
    }

    $worktreeLane = @((Get-Content $ledgerPath -Raw | ConvertFrom-Json).lanes) |
        Where-Object { $_.lane -eq 'feat/worktree-owned' } |
        Select-Object -First 1
    if (-not $worktreeLane -or $worktreeLane.state -ne 'orphaned-local-worktree-owned' -or $worktreeLane.safeToDelete) {
        throw 'Branch cleanup must retain a local branch mapped to another worktree'
    }
}
finally {
    $env:PATH = $originalPath
    if ($worktreeLocationPushed) {
        Pop-Location
    }
    if (Test-Path $worktreeRepo) {
        git -C $worktreeRepo worktree remove $linkedWorktree 2>$null
    }
    if (Test-Path $worktreeTestRoot) {
        Remove-Item $worktreeTestRoot -Recurse -Force
    }
}

Write-Host 'cleanup-branches tests passed' -ForegroundColor Green
