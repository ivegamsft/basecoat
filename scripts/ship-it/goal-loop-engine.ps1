<#
.SYNOPSIS
  Tracks and validates sprint state transitions for an Intent2Prod execution run.

.DESCRIPTION
  The goal-loop engine enforces the Intent2Prod lifecycle state machine.
  It reads the current state of a control-plane run from the sprint issue
  states and emits the next required action or detects completion.

  Lifecycle: CREATED -> SCOPING -> IMPLEMENTING -> VALIDATING -> PROMOTING -> SHIPPED -> CLOSED

.PARAMETER Repo
  Target repository in owner/repo format.

.PARAMETER ParentIssueNumber
  The control-plane parent issue number.

.PARAMETER SprintIssueNumbers
  Array of sprint child issue numbers (Sprint 1, Sprint 2, Sprint 3).

.PARAMETER DryRun
  When set, emits the state assessment without making changes.

.EXAMPLE
  .\goal-loop-engine.ps1 -Repo IBuySpy-Shared/basecoat -ParentIssueNumber 1874 -SprintIssueNumbers 1875,1876,1877
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidatePattern("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")]
  [string]$Repo,

  [Parameter(Mandatory)]
  [int]$ParentIssueNumber,

  [Parameter(Mandatory)]
  [int[]]$SprintIssueNumbers,

  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ($SprintIssueNumbers.Count -ne 3) {
  throw "SprintIssueNumbers must have exactly 3 elements (Sprint 1, Sprint 2, Sprint 3)."
}

function Get-IssueState {
  param([int]$IssueNumber)

  $result = & gh issue view $IssueNumber --repo $Repo --json state,title,body 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to query issue #$IssueNumber: $result"
  }
  return $result | ConvertFrom-Json
}

function Test-ExitCriteriaComplete {
  param([string]$Body)

  if ([string]::IsNullOrWhiteSpace($Body)) {
    return $false
  }
  $unchecked = [regex]::Matches($Body, "- \[ \]").Count
  $checked = [regex]::Matches($Body, "- \[x\]").Count
  return $unchecked -eq 0 -and $checked -gt 0
}

# Lifecycle state table maps (sprint index, sprint state, exit criteria) -> control-plane state
$lifecycleStates = @(
  [pscustomobject]@{
    State = "CREATED"
    Description = "Control-plane issued; Sprint 1 not yet started."
  },
  [pscustomobject]@{
    State = "SCOPING"
    Description = "Sprint 1 open; architecture and scope in progress."
  },
  [pscustomobject]@{
    State = "IMPLEMENTING"
    Description = "Sprint 2 open; implementation in progress."
  },
  [pscustomobject]@{
    State = "VALIDATING"
    Description = "Sprint 2 closed; validation evidence being collected."
  },
  [pscustomobject]@{
    State = "PROMOTING"
    Description = "Sprint 3 open; release promotion in progress."
  },
  [pscustomobject]@{
    State = "SHIPPED"
    Description = "Sprint 3 closed; post-release verification pending."
  },
  [pscustomobject]@{
    State = "CLOSED"
    Description = "All sprints closed; parent issue closed."
  }
)

Write-Host "Querying control-plane state for parent #$ParentIssueNumber in $Repo..."

$parentIssue = Get-IssueState -IssueNumber $ParentIssueNumber
$sprint1 = Get-IssueState -IssueNumber $SprintIssueNumbers[0]
$sprint2 = Get-IssueState -IssueNumber $SprintIssueNumbers[1]
$sprint3 = Get-IssueState -IssueNumber $SprintIssueNumbers[2]

$sprint1Open = $sprint1.state -eq "OPEN"
$sprint1Closed = $sprint1.state -eq "CLOSED"
$sprint2Open = $sprint2.state -eq "OPEN"
$sprint2Closed = $sprint2.state -eq "CLOSED"
$sprint3Open = $sprint3.state -eq "OPEN"
$sprint3Closed = $sprint3.state -eq "CLOSED"
$parentOpen = $parentIssue.state -eq "OPEN"
$parentClosed = $parentIssue.state -eq "CLOSED"

$sprint1Done = $sprint1Closed
$sprint2Done = $sprint2Closed
$sprint3Done = $sprint3Closed

# Determine current lifecycle state
$currentState = if ($parentClosed -and $sprint3Closed) {
  "CLOSED"
} elseif ($sprint3Closed -and $parentOpen) {
  "SHIPPED"
} elseif ($sprint3Open) {
  "PROMOTING"
} elseif ($sprint2Closed -and -not $sprint3Open -and -not $sprint3Closed) {
  "VALIDATING"
} elseif ($sprint2Open) {
  "IMPLEMENTING"
} elseif ($sprint1Closed -and -not $sprint2Open -and -not $sprint2Closed) {
  "SCOPING"  # sprint 2 not yet started after sprint 1 closed
} elseif ($sprint1Open) {
  "SCOPING"
} else {
  "CREATED"
}

$stateInfo = $lifecycleStates | Where-Object { $_.State -eq $currentState }

# Determine next action
$nextAction = switch ($currentState) {
  "CREATED" {
    "Sprint 1 has not been started. Open Sprint 1 issue #$($SprintIssueNumbers[0]) to begin scoping."
  }
  "SCOPING" {
    if (Test-ExitCriteriaComplete -Body $sprint1.body) {
      "Sprint 1 exit criteria are complete. Close Sprint 1 issue #$($SprintIssueNumbers[0]) and open Sprint 2."
    } else {
      "Sprint 1 is in progress. Complete exit criteria in issue #$($SprintIssueNumbers[0]) before advancing."
    }
  }
  "IMPLEMENTING" {
    if (Test-ExitCriteriaComplete -Body $sprint2.body) {
      "Sprint 2 exit criteria are complete. Close Sprint 2 issue #$($SprintIssueNumbers[1]) and proceed to validation."
    } else {
      "Sprint 2 is in progress. Implement changes, pass required CI gates, and document rollback strategy."
    }
  }
  "VALIDATING" {
    "Sprint 2 is closed. Open Sprint 3 issue #$($SprintIssueNumbers[2]) to begin release promotion."
  }
  "PROMOTING" {
    if (Test-ExitCriteriaComplete -Body $sprint3.body) {
      "Sprint 3 exit criteria are complete. Close Sprint 3 issue #$($SprintIssueNumbers[2]) and complete post-release verification."
    } else {
      "Sprint 3 is in progress. Complete release checklist and post-release verification."
    }
  }
  "SHIPPED" {
    "All sprints complete. Update learning log and close parent issue #$ParentIssueNumber."
  }
  "CLOSED" {
    "Control-plane run is fully complete."
  }
  default {
    "Unknown state. Inspect sprint issues manually."
  }
}

$result = [ordered]@{
  parent_issue   = $ParentIssueNumber
  repo           = $Repo
  lifecycle_state = $currentState
  description    = $stateInfo.Description
  next_action    = $nextAction
  sprints        = @(
    [ordered]@{ number = $SprintIssueNumbers[0]; state = $sprint1.state; title = $sprint1.title }
    [ordered]@{ number = $SprintIssueNumbers[1]; state = $sprint2.state; title = $sprint2.title }
    [ordered]@{ number = $SprintIssueNumbers[2]; state = $sprint3.state; title = $sprint3.title }
  )
}

$result | ConvertTo-Json -Depth 4 | Write-Output
