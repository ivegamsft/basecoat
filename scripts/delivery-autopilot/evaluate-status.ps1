[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidatePattern("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")]
  [string]$Repo,

  [int]$IssueNumber = 0,
  [int]$PullRequestNumber = 0,
  [string[]]$RequiredChecks = @(),
  [switch]$DryRun,
  [string]$OutputPath = "test-results\delivery-autopilot\status-summary.json"
)

$ErrorActionPreference = "Stop"

if ($IssueNumber -le 0 -and $PullRequestNumber -le 0) {
  throw "Provide IssueNumber and/or PullRequestNumber."
}

function Write-JsonOutput {
  param([object]$Data, [string]$Path)
  $fullPath = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path (Get-Location) $Path }
  $directory = Split-Path -Path $fullPath -Parent
  if (-not [string]::IsNullOrWhiteSpace($directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $fullPath -Encoding utf8
}

$base = [ordered]@{
  repo = $Repo
  issue_number = $IssueNumber
  pr_number = $PullRequestNumber
  required_checks = @($RequiredChecks)
}

if ($DryRun) {
  $result = [ordered]@{
    mode = "dry-run"
    generated_at = "dry-run-static"
    stage = if ($PullRequestNumber -gt 0) { "ready_to_merge" } else { "issue_to_pr" }
    is_merge_ready = ($PullRequestNumber -gt 0)
    blockers = if ($PullRequestNumber -gt 0) { @() } else { @("missing-pr-link") }
    next_action = if ($PullRequestNumber -gt 0) { "execute-merge" } else { "open-or-link-pr" }
    source = "deterministic-fixture"
  } + $base
  Write-JsonOutput -Data $result -Path $OutputPath
  $result | ConvertTo-Json -Depth 10 | Write-Output
  exit 0
}

$result = [ordered]@{
  mode = "live"
  generated_at = (Get-Date).ToUniversalTime().ToString("o")
  stage = "unknown"
  is_merge_ready = $false
  blockers = @()
  next_action = "inspect-state"
  source = "github-api"
} + $base

if ($PullRequestNumber -gt 0) {
  $prJson = & gh pr view $PullRequestNumber --repo $Repo --json state,isDraft,mergeStateStatus,statusCheckRollup,url 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to query pull request #${PullRequestNumber}: $prJson"
  }
  $pr = $prJson | ConvertFrom-Json
  $result.stage = "ready_to_merge"
  $isOpen = $pr.state -eq "OPEN"
  $isDraft = [bool]$pr.isDraft
  $mergeState = [string]$pr.mergeStateStatus
  $checkStates = @()
  foreach ($check in @($pr.statusCheckRollup)) {
    if ($null -eq $check) { continue }
    $name = [string]$check.name
    $status = [string]$check.status
    $conclusion = [string]$check.conclusion
    $checkStates += [ordered]@{
      name = $name
      status = $status
      conclusion = $conclusion
    }
  }

  $requiredFailures = @()
  foreach ($required in @($RequiredChecks)) {
    $match = $checkStates | Where-Object { $_.name -eq $required }
    if ($match.Count -eq 0) {
      $requiredFailures += "missing:$required"
      continue
    }
    if ($match[0].conclusion -ne "SUCCESS" -and $match[0].conclusion -ne "success") {
      $requiredFailures += "not-success:$required"
    }
  }

  if (-not $isOpen) { $result.blockers += "pr-not-open" }
  if ($isDraft) { $result.blockers += "pr-draft" }
  if ($mergeState -notin @("CLEAN", "clean", "HAS_HOOKS", "has_hooks")) { $result.blockers += "merge-state:$mergeState" }
  $result.blockers += $requiredFailures
  $result.is_merge_ready = ($result.blockers.Count -eq 0)
  $result.next_action = if ($result.is_merge_ready) { "execute-merge" } else { "build-escalation-payload" }
  $result.pr_url = $pr.url
  $result.check_states = $checkStates
} else {
  $result.stage = "issue_to_pr"
  $issueJson = & gh issue view $IssueNumber --repo $Repo --json state,url,labels,assignees 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to query issue #${IssueNumber}: $issueJson"
  }
  $issue = $issueJson | ConvertFrom-Json
  $labels = @($issue.labels | ForEach-Object { [string]$_.name })
  if ($issue.state -ne "OPEN") { $result.blockers += "issue-not-open" }
  if ($labels -notcontains "approved") { $result.blockers += "issue-not-approved" }
  if ($labels -notcontains "copilot-agent") { $result.blockers += "issue-not-routed" }
  if (@($issue.assignees).Count -eq 0) { $result.blockers += "issue-unassigned" }
  $result.is_merge_ready = $false
  $result.next_action = if ($result.blockers.Count -eq 0) { "open-or-link-pr" } else { "build-escalation-payload" }
  $result.issue_url = $issue.url
}

Write-JsonOutput -Data $result -Path $OutputPath
$result | ConvertTo-Json -Depth 10 | Write-Output
