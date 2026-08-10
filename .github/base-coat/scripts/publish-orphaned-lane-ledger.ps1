[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$LedgerPath,

    [string]$IssueTitle = 'Orphaned lane ledger',

    [string]$BodyPath = 'test-results/lane-closeout/orphaned-lane-issue.md',

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-GhIssueMutation {
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    gh @Arguments | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to $Action (gh exit code $LASTEXITCODE). Verify GH_TOKEN permissions and retry the orphaned-lane publisher."
    }
}

if (-not (Test-Path $LedgerPath)) {
    throw "Lane ledger not found: $LedgerPath"
}

$ledger = Get-Content -Path $LedgerPath -Raw | ConvertFrom-Json
$marker = '<!-- basecoat-orphaned-lane-ledger -->'
$orphaned = @(
    @($ledger.lanes) |
    Where-Object {
        $_ -and (
            ($_.action -eq 'retained' -and $_.terminalState -in @('HANDED_OFF', 'PARKED')) -or
            $_.action -eq 'delete-failed'
        )
    } |
    Sort-Object source, lane
)

if (-not $DryRun -and -not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'gh CLI is required to publish the orphaned-lane issue.'
}

$existing = @()
if (-not $DryRun) {
    $existingJson = gh issue list --state open --search 'basecoat-orphaned-lane-ledger in:body' --limit 1000 --json number,title,body
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to query the marker-keyed orphaned-lane issue.'
    }
    $existing = @(
        @($existingJson | ConvertFrom-Json) |
        Where-Object {
            $_ -and $_.body -and $_.body.Contains($marker, [System.StringComparison]::Ordinal)
        }
    )
}

if ($orphaned.Count -eq 0) {
    foreach ($issue in $existing) {
        Invoke-GhIssueMutation `
            -Action "close resolved orphaned-lane issue #$($issue.number)" `
            -Arguments @('issue', 'close', "$($issue.number)", '--comment', 'Resolved by the latest lane cleanup audit; no retained orphaned lanes remain.')
    }
    Write-Host 'No retained orphaned lanes require an issue.'
    exit 0
}

$bodyParent = Split-Path $BodyPath -Parent
if ($bodyParent -and -not (Test-Path $bodyParent)) {
    New-Item -ItemType Directory -Path $bodyParent -Force | Out-Null
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add($marker)
$lines.Add('# Orphaned Lane Ledger')
$lines.Add('')
$lines.Add("Generated from the branch cleanup audit at $($ledger.generatedAt).")
$lines.Add('')
$lines.Add('| Lane | Source | Owner | Terminal state | Audit state | PR | Next action |')
$lines.Add('|---|---|---|---|---|---:|---|')
foreach ($lane in $orphaned) {
    $pr = if ($lane.prNumber) { "#$($lane.prNumber)" } else { '—' }
    $owner = if ($lane.owner) { $lane.owner } else { 'unknown' }
    $nextAction = if ($lane.nextAction) { $lane.nextAction } else { 'Assign an owner and record the next action.' }
    $lines.Add("| ``$($lane.lane)`` | $($lane.source) | $owner | $($lane.terminalState) | $($lane.state) | $pr | $nextAction |")
}
$lines.Add('')
$lines.Add('This issue is an idempotent remote reaper backstop. It does not authorize')
$lines.Add('branch deletion or worktree removal; use `lane-closeout`,')
$lines.Add('`@branch-hygiene-sweeper`, and `git-worktrees` safety checks.')

$lines | Set-Content -Path $BodyPath -Encoding utf8

if ($DryRun) {
    Write-Host "Dry run wrote orphaned-lane issue body: $BodyPath"
    exit 0
}

if ($existing.Count -gt 0) {
    Invoke-GhIssueMutation `
        -Action "update orphaned-lane issue #$($existing[0].number)" `
        -Arguments @('issue', 'edit', "$($existing[0].number)", '--body-file', $BodyPath)
    Write-Host "Updated orphaned-lane issue #$($existing[0].number)."
    foreach ($duplicate in @($existing | Select-Object -Skip 1)) {
        Invoke-GhIssueMutation `
            -Action "close duplicate orphaned-lane issue #$($duplicate.number)" `
            -Arguments @('issue', 'close', "$($duplicate.number)", '--comment', "Superseded by orphaned-lane ledger issue #$($existing[0].number).")
    }
}
else {
    Invoke-GhIssueMutation `
        -Action "create orphaned-lane issue '$IssueTitle'" `
        -Arguments @('issue', 'create', '--title', $IssueTitle, '--body-file', $BodyPath)
}
