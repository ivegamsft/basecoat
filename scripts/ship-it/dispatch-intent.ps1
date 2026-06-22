[CmdletBinding()]
param(
  [ValidateSet("ship-it", "spec-2-prod")]
  [string]$Intent = "ship-it",

  [Parameter(Mandatory)]
  [string]$Goal,

  [string]$TargetRepo = $env:GITHUB_REPOSITORY,

  [string]$SpecRef = "",

  [ValidateSet("low", "medium", "high", "critical")]
  [string]$RiskBand = "medium",

  [int]$ProjectNumber = 0,

  [string]$ProjectOwner = "",

  [switch]$DryRun,

  [string]$OutputPath = "test-results\ship-it\summary.json"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($TargetRepo) -or $TargetRepo -notmatch "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$") {
  throw "TargetRepo must be in owner/repo format."
}

$trimmedGoal = $Goal.Trim()
if ([string]::IsNullOrWhiteSpace($trimmedGoal)) {
  throw "Goal cannot be empty."
}

if ($ProjectNumber -gt 0 -and [string]::IsNullOrWhiteSpace($ProjectOwner)) {
  throw "ProjectOwner is required when ProjectNumber is provided."
}

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$repoName = $TargetRepo.Split("/")[1]
$commonLabels = @("intent-control-plane", $Intent, "risk-$RiskBand")

$sprints = @(
  @{
    Name = "Sprint 1 - Plan and Scope"
    Goal = "Finalize implementation scope, architecture, and acceptance criteria."
    ExitCriteria = @(
      "Spec and dependencies are validated",
      "Delivery plan and owners are defined",
      "Risk controls are acknowledged"
    )
  },
  @{
    Name = "Sprint 2 - Build and Verify"
    Goal = "Implement changes and pass required quality gates."
    ExitCriteria = @(
      "Code changes merged to feature branch",
      "Required lint/build/test checks pass",
      "Rollback strategy is documented"
    )
  },
  @{
    Name = "Sprint 3 - Release and Learn"
    Goal = "Release safely and capture post-release learnings."
    ExitCriteria = @(
      "Release checklist and evidence links are complete",
      "Post-release verification completed",
      "Learning log updated with outcomes and follow-ups"
    )
  }
)

function Invoke-Gh {
  param(
    [Parameter(Mandatory)]
    [string[]]$Arguments
  )

  $output = & gh @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "gh command failed: gh $($Arguments -join ' ')"
  }
  return $output
}

function Ensure-Label {
  param(
    [Parameter(Mandatory)]
    [string]$Repo,
    [Parameter(Mandatory)]
    [string]$Name,
    [Parameter(Mandatory)]
    [string]$Color,
    [Parameter(Mandatory)]
    [string]$Description
  )

  Invoke-Gh -Arguments @(
    "label", "create",
    "--repo", $Repo,
    $Name,
    "--color", $Color,
    "--description", $Description,
    "--force"
  ) | Out-Null
}

if (-not $DryRun) {
  $ghCommand = Get-Command gh -ErrorAction SilentlyContinue
  if (-not $ghCommand) {
    throw "gh CLI is required for live side effects."
  }
  Invoke-Gh -Arguments @("auth", "status") | Out-Null
}

$parentTitle = "[Intent][$Intent][$repoName] $trimmedGoal"
$specLine = if ([string]::IsNullOrWhiteSpace($SpecRef)) { "_Not provided_" } else { $SpecRef.Trim() }

$parentBody = @"
## Intent Contract

- Intent: `$Intent`
- Goal: $trimmedGoal
- Repository: $TargetRepo
- Risk band: `$RiskBand`
- Spec reference: $specLine
- Started: $timestamp

## Governance Checklist

- [ ] Scope and acceptance criteria confirmed
- [ ] Required validation gates identified
- [ ] Rollout strategy documented
- [ ] Rollback strategy documented
- [ ] Documentation updates identified

## Execution Model

This issue is the control-plane parent for a governed multi-sprint execution loop.
Child sprint issues are generated automatically and must remain linked.
"@

$summary = [ordered]@{
  intent = $Intent
  goal = $trimmedGoal
  target_repo = $TargetRepo
  risk_band = $RiskBand
  spec_ref = $SpecRef
  started_at = $timestamp
  dry_run = [bool]$DryRun
  parent_issue_url = ""
  parent_issue_number = ""
  child_issues = @()
}

if ($DryRun) {
  $summary.parent_issue_url = "https://github.com/$TargetRepo/issues/0000"
  $summary.parent_issue_number = "0000"
  for ($i = 0; $i -lt $sprints.Count; $i++) {
    $summary.child_issues += [ordered]@{
      sprint = $sprints[$i].Name
      url = "https://github.com/$TargetRepo/issues/000$($i + 1)"
      number = "000$($i + 1)"
    }
  }
} else {
  $tempRoot = [System.IO.Path]::GetTempPath()
  if ([string]::IsNullOrWhiteSpace($tempRoot)) {
    throw "Unable to resolve a writable temporary directory."
  }

  Ensure-Label -Repo $TargetRepo -Name "intent-control-plane" -Color "4c1d95" -Description "Tracks intent-driven SDLC execution."
  Ensure-Label -Repo $TargetRepo -Name "ship-it" -Color "0e8a16" -Description "Tracks ship-it intent workflows."
  Ensure-Label -Repo $TargetRepo -Name "spec-2-prod" -Color "1d76db" -Description "Tracks spec-to-production delivery workflows."
  Ensure-Label -Repo $TargetRepo -Name "risk-low" -Color "bfe5bf" -Description "Low-risk intent run."
  Ensure-Label -Repo $TargetRepo -Name "risk-medium" -Color "fbca04" -Description "Medium-risk intent run."
  Ensure-Label -Repo $TargetRepo -Name "risk-high" -Color "f9d0c4" -Description "High-risk intent run."
  Ensure-Label -Repo $TargetRepo -Name "risk-critical" -Color "b60205" -Description "Critical-risk intent run."
  Ensure-Label -Repo $TargetRepo -Name "sprint" -Color "5319e7" -Description "Sprint tracking issue."

  $bodyPath = Join-Path $tempRoot "ship-it-parent-$([Guid]::NewGuid().ToString()).md"
  Set-Content -Path $bodyPath -Value $parentBody -Encoding UTF8

  $createParentArgs = @(
    "issue", "create",
    "--repo", $TargetRepo,
    "--title", $parentTitle,
    "--body-file", $bodyPath
  )
  foreach ($label in $commonLabels) {
    $createParentArgs += @("--label", $label)
  }

  $parentUrl = (Invoke-Gh -Arguments $createParentArgs | Select-Object -Last 1).Trim()
  if ($parentUrl -notmatch "/issues/(\d+)$") {
    throw "Unable to parse parent issue number from: $parentUrl"
  }

  $summary.parent_issue_url = $parentUrl
  $summary.parent_issue_number = $Matches[1]

  for ($i = 0; $i -lt $sprints.Count; $i++) {
    $sprint = $sprints[$i]
    $index = $i + 1
    $sprintTitle = "[Intent][$Intent][Sprint $index][$repoName] $trimmedGoal"
    $exitCriteria = $sprint.ExitCriteria | ForEach-Object { "- [ ] $_" } | Out-String

    $sprintBody = @"
## Sprint Objective

$($sprint.Goal)

## Parent Control-Plane Issue

$($summary.parent_issue_url)

## Exit Criteria

$exitCriteria

## Evidence

- [ ] PR links
- [ ] Validation run links
- [ ] Release notes (if applicable)
- [ ] Learning log update
"@

    $sprintBodyPath = Join-Path $tempRoot "ship-it-sprint-$index-$([Guid]::NewGuid().ToString()).md"
    Set-Content -Path $sprintBodyPath -Value $sprintBody -Encoding UTF8

    $createSprintArgs = @(
      "issue", "create",
      "--repo", $TargetRepo,
      "--title", $sprintTitle,
      "--body-file", $sprintBodyPath
    )
    foreach ($label in $commonLabels) {
      $createSprintArgs += @("--label", $label)
    }
    $createSprintArgs += @("--label", "sprint")

    $sprintUrl = (Invoke-Gh -Arguments $createSprintArgs | Select-Object -Last 1).Trim()
    if ($sprintUrl -notmatch "/issues/(\d+)$") {
      throw "Unable to parse child issue number from: $sprintUrl"
    }

    $summary.child_issues += [ordered]@{
      sprint = $sprint.Name
      url = $sprintUrl
      number = $Matches[1]
    }

    Remove-Item -Path $sprintBodyPath -Force
  }

  Remove-Item -Path $bodyPath -Force

  if ($ProjectNumber -gt 0) {
    Invoke-Gh -Arguments @(
      "project", "item-add", $ProjectNumber.ToString(),
      "--owner", $ProjectOwner,
      "--url", $summary.parent_issue_url
    ) | Out-Null

    foreach ($child in $summary.child_issues) {
      Invoke-Gh -Arguments @(
        "project", "item-add", $ProjectNumber.ToString(),
        "--owner", $ProjectOwner,
        "--url", [string]$child.url
      ) | Out-Null
    }
  }
}

$outputDirectory = Split-Path -Path $OutputPath -Parent
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
  New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputPath -Encoding UTF8

$markdownPath = [System.IO.Path]::ChangeExtension($OutputPath, ".md")
$markdown = @"
# Ship-it Intent Dispatch Summary

- Intent: `$($summary.intent)`
- Goal: $($summary.goal)
- Repository: $($summary.target_repo)
- Risk band: `$($summary.risk_band)`
- Dry run: `$($summary.dry_run)`
- Parent issue: $($summary.parent_issue_url)

## Child Sprint Issues
"@

foreach ($child in $summary.child_issues) {
  $markdown += "`n- $($child.sprint): $($child.url)"
}

Set-Content -Path $markdownPath -Value $markdown -Encoding UTF8

Write-Host "Ship-it intent dispatched."
Write-Host "Summary: $OutputPath"
Write-Output ($summary | ConvertTo-Json -Depth 6)
