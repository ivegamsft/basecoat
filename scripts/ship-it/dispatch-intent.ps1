[CmdletBinding()]
param(
  [ValidateSet("ship-it", "spec-2-prod", "onboarding-conductor")]
  [string]$Intent = "ship-it",

  [Parameter(Mandatory)]
  [string]$Goal,

  [string]$TargetRepo = $env:GITHUB_REPOSITORY,

  [string]$SpecRef = "",

  [ValidateSet("low", "medium", "high", "critical")]
  [string]$RiskBand = "medium",

  [ValidateSet("solo-dev", "team-dev", "regulated-team", "pilot-luxesite", "pilot-wawkr", "pilot-work-tracker")]
  [string]$Profile = "team-dev",

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

if ($Intent -eq "onboarding-conductor") {
  $commonLabels += "onboarding-conductor"
}

function Get-IntentPhases {
  param(
    [Parameter(Mandatory)]
    [string]$IntentName
  )

  if ($IntentName -eq "onboarding-conductor") {
    return @(
      @{
        Name = "Discover"
        Goal = "Detect repository onboarding posture and drift against the selected profile."
        ExitCriteria = @(
          "Repository surfaces are inventoried",
          "Drift against desired profile is captured",
          "Any blocking prerequisite is documented"
        )
      },
      @{
        Name = "Plan"
        Goal = "Generate an actionable desired-state diff aligned to the selected onboarding profile."
        ExitCriteria = @(
          "Desired-state diff is attached",
          "Plan is profile-aware and idempotent",
          "Remediation actions are listed for detected drift"
        )
      },
      @{
        Name = "Apply"
        Goal = "Open or update an onboarding PR with generated changes for the selected profile."
        ExitCriteria = @(
          "Single onboarding PR is created or updated",
          "Changes are idempotent on rerun",
          "No duplicate onboarding artifacts are generated"
        )
      },
      @{
        Name = "Validate"
        Goal = "Run BaseCoat validation checks and publish readiness evidence."
        ExitCriteria = @(
          "Required checks have evidence links",
          "Readiness report is published",
          "Failed checks map to remediation tasks or issues"
        )
      }
    )
  }

  return @(
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
}

function Get-DesiredStateDiff {
  param(
    [Parameter(Mandatory)]
    [string]$IntentName,
    [Parameter(Mandatory)]
    [string]$ProfileName
  )

  if ($IntentName -ne "onboarding-conductor") {
    return @(
      [ordered]@{
        surface = "goal-scope"
        current_state = "unknown"
        desired_state = "validated"
        action = "confirm_scope"
      },
      [ordered]@{
        surface = "quality-gates"
        current_state = "unknown"
        desired_state = "required_checks_green"
        action = "run_validation"
      },
      [ordered]@{
        surface = "release-evidence"
        current_state = "unknown"
        desired_state = "documented"
        action = "capture_evidence"
      }
    )
  }

  $profiles = @{
    "solo-dev" = @{
      branch_policy = "minimal"
      workflow_pack = "solo"
      template_pack = "solo"
      telemetry_mode = "local"
      secrets_mode = "local"
      hook_pack = "none"
      execution_lane = "standard"
      release_gate_mode = "risk-band-default"
      artifact_completeness_mode = "risk-band-default"
    }
    "team-dev" = @{
      branch_policy = "shared"
      workflow_pack = "team"
      template_pack = "team"
      telemetry_mode = "shared"
      secrets_mode = "workflow-secrets"
      hook_pack = "standard"
      execution_lane = "standard"
      release_gate_mode = "risk-band-default"
      artifact_completeness_mode = "risk-band-default"
    }
    "regulated-team" = @{
      branch_policy = "locked-down"
      workflow_pack = "regulated"
      template_pack = "regulated"
      telemetry_mode = "org-managed"
      secrets_mode = "org-managed"
      hook_pack = "guardrails"
      execution_lane = "standard"
      release_gate_mode = "risk-band-default"
      artifact_completeness_mode = "risk-band-default"
    }
    "pilot-luxesite" = @{
      branch_policy = "shared-protected"
      workflow_pack = "team-plus-pilot-hardening"
      template_pack = "team-plus-pilot"
      telemetry_mode = "shared"
      secrets_mode = "workflow-secrets"
      hook_pack = "standard"
      execution_lane = "pilot-luxesite"
      release_gate_mode = "lane-strict"
      artifact_completeness_mode = "lane-strict"
    }
    "pilot-wawkr" = @{
      branch_policy = "shared-protected"
      workflow_pack = "team-plus-pilot-canary"
      template_pack = "team-plus-pilot"
      telemetry_mode = "shared"
      secrets_mode = "workflow-secrets"
      hook_pack = "standard"
      execution_lane = "pilot-wawkr"
      release_gate_mode = "lane-strict"
      artifact_completeness_mode = "lane-strict"
    }
    "pilot-work-tracker" = @{
      branch_policy = "shared-protected"
      workflow_pack = "team-plus-pilot-lane-aware"
      template_pack = "team-plus-pilot"
      telemetry_mode = "shared"
      secrets_mode = "workflow-secrets"
      hook_pack = "standard"
      execution_lane = "pilot-work-tracker"
      release_gate_mode = "lane-strict"
      artifact_completeness_mode = "lane-strict"
    }
  }

  if (-not $profiles.ContainsKey($ProfileName)) {
    throw "Unsupported onboarding profile: $ProfileName"
  }

  $selection = $profiles[$ProfileName]
  return @(
    [ordered]@{
      surface = "branch_policy"
      current_state = "detect-at-runtime"
      desired_state = $selection.branch_policy
      action = "create_or_update"
    },
    [ordered]@{
      surface = "workflow_pack"
      current_state = "detect-at-runtime"
      desired_state = $selection.workflow_pack
      action = "create_or_update"
    },
    [ordered]@{
      surface = "template_pack"
      current_state = "detect-at-runtime"
      desired_state = $selection.template_pack
      action = "create_or_update"
    },
    [ordered]@{
      surface = "telemetry_mode"
      current_state = "detect-at-runtime"
      desired_state = $selection.telemetry_mode
      action = "create_or_update"
    },
    [ordered]@{
      surface = "secrets_mode"
      current_state = "detect-at-runtime"
      desired_state = $selection.secrets_mode
      action = "create_or_update"
    },
    [ordered]@{
      surface = "hook_pack"
      current_state = "detect-at-runtime"
      desired_state = $selection.hook_pack
      action = "create_or_update"
    },
    [ordered]@{
      surface = "execution_lane"
      current_state = "detect-at-runtime"
      desired_state = $selection.execution_lane
      action = "create_or_update"
    },
    [ordered]@{
      surface = "release_gate_mode"
      current_state = "detect-at-runtime"
      desired_state = $selection.release_gate_mode
      action = "create_or_update"
    },
    [ordered]@{
      surface = "artifact_completeness_mode"
      current_state = "detect-at-runtime"
      desired_state = $selection.artifact_completeness_mode
      action = "create_or_update"
    }
  )
}

function Get-ExecutionLane {
  param(
    [Parameter(Mandatory)]
    [string]$IntentName,
    [Parameter(Mandatory)]
    [string]$ProfileName,
    [Parameter(Mandatory)]
    [string]$StageSlug
  )

  if ($IntentName -eq "onboarding-conductor" -and $ProfileName -eq "pilot-luxesite") {
    switch ($StageSlug) {
      "discover" { return "pilot-luxesite-baseline-remediation" }
      "plan" { return "pilot-luxesite-artifact-contract" }
      "apply" { return "pilot-luxesite-stabilization" }
      "validate" { return "pilot-luxesite-release-readiness" }
      default { return "pilot-luxesite" }
    }
  }

  if ($IntentName -eq "onboarding-conductor" -and $ProfileName -eq "pilot-wawkr") {
    switch ($StageSlug) {
      "discover" { return "pilot-wawkr-canary-baseline" }
      "plan" { return "pilot-wawkr-canary-contract" }
      "apply" { return "pilot-wawkr-canary-deployment" }
      "validate" { return "pilot-wawkr-canary-validation" }
      default { return "pilot-wawkr" }
    }
  }

  if ($IntentName -eq "onboarding-conductor" -and $ProfileName -eq "pilot-work-tracker") {
    switch ($StageSlug) {
      "discover" { return "pilot-work-tracker-baseline" }
      "plan" { return "pilot-work-tracker-contract" }
      "apply" { return "pilot-work-tracker-deployment" }
      "validate" { return "pilot-work-tracker-validation" }
      default { return "pilot-work-tracker" }
    }
  }

  return "standard"
}

function Get-StageArtifact {
  param(
    [Parameter(Mandatory)]
    [string]$IntentName,
    [Parameter(Mandatory)]
    [string]$RepoShortName,
    [Parameter(Mandatory)]
    [string]$GoalText,
    [Parameter(Mandatory)]
    [int]$StageIndex,
    [Parameter(Mandatory)]
    [string]$StageSlug,
    [Parameter(Mandatory)]
    [string]$RunHash,
    [Parameter(Mandatory)]
    [string]$ExecutionLane
  )

  $safeGoalSlug = ($GoalText.ToLowerInvariant() -replace "[^a-z0-9]+", "-").Trim("-")
  if ($safeGoalSlug.Length -gt 24) {
    $safeGoalSlug = $safeGoalSlug.Substring(0, 24).Trim("-")
  }
  if ([string]::IsNullOrWhiteSpace($safeGoalSlug)) {
    $safeGoalSlug = "goal"
  }

  $hashSegment = $RunHash.Substring(0, [Math]::Min(8, $RunHash.Length))
  $branchName = "intent/$IntentName/$hashSegment/s$StageIndex-$StageSlug-$safeGoalSlug"
  $prTitlePrefix = if ($IntentName -eq "onboarding-conductor") { "Phase" } else { "Sprint" }

  $requiredChecks = @(
    "BaseCoat - PR Flow Hygiene / PR readiness routing and weekly hygiene report",
    "BaseCoat - Sprint Closeout Branch Audit / branch-audit"
  )
  if ($StageIndex -eq 3) {
    $requiredChecks += "Ship-it Release Gate / enforce-release-gate"
  }

  return [ordered]@{
    stage = $StageIndex
    execution_lane = $ExecutionLane
    branch_name = $branchName
    pr_title = "[Intent][$IntentName][$prTitlePrefix $StageIndex][$RepoShortName] $GoalText"
    pr_search_query = "is:pr is:open head:$branchName"
    merge_policy = [ordered]@{
      sequencing = "serial"
      required_checks = $requiredChecks
      merge_ready_condition = "all_required_checks_green"
    }
  cleanup_policy = [ordered]@{
    workflow = ".github/workflows/sprint-closeout-branch-audit.yml"
    script = "scripts/cleanup-branches.ps1"
    audit_log = "GITHUB_STEP_SUMMARY"
  }
}
}

function Get-ReleaseGateContract {
  return [ordered]@{
    workflow = ".github/workflows/ship-it-release-gate.yml"
    promotion_order = @("validate", "canary", "staging", "production")
    required_gates_by_risk_band = [ordered]@{
      low = @("lint", "build", "smoke")
      medium = @("lint", "build", "type", "smoke")
      high = @("lint", "build", "type", "e2e", "security", "smoke")
      critical = @("lint", "build", "type", "e2e", "security", "smoke")
    }
    production_cutover_requirements = @(
      "environment_protection_configured",
      "required_approvals_recorded",
      "rollback_runbook_reference_present",
      "rollback_validation_passed"
    )
    artifact_matrix = [ordered]@{
      low = @("spec", "docs", "tests")
      medium = @("spec", "docs", "tests")
      high = @("spec", "docs", "tests", "runbook", "release_notes")
      critical = @("spec", "docs", "tests", "runbook", "release_notes")
      production_override = @("runbook", "release_notes")
    }
    drift_detection = @(
      "compare_contract_goal_ids_to_spec_goal_ids",
      "compare_contract_goal_ids_to_implementation_goal_ids",
      "emit_remediation_suggestions"
    )
    goal_id_linkage_requirements = @(
      "runbook_delta_mapped_to_goal_ids",
      "release_notes_delta_mapped_to_goal_ids"
    )
    evidence_bundle_output = "test-results/ship-it/promotion-evidence-bundle.json"
    lane_profiles = [ordered]@{
      standard = [ordered]@{
        required_gates = @()
        required_artifacts = @()
        notes = @("Uses risk-band defaults.")
      }
      "pilot-luxesite" = [ordered]@{
        required_gates = @("lint", "build", "type", "e2e", "security", "smoke")
        required_artifacts = @("spec", "docs", "tests", "runbook", "release_notes")
        notes = @(
          "Forces security and e2e gates for stabilization validation.",
          "Requires runbook and release-note artifacts for all promotion stages."
        )
      }
      "pilot-wawkr" = [ordered]@{
        required_gates = @("lint", "build", "type", "e2e", "security", "smoke")
        required_artifacts = @("spec", "docs", "tests", "runbook", "release_notes")
        notes = @(
          "Forces all gates for canary validation and evidence collection.",
          "Requires spec, docs, tests, runbook, and release-notes for canary contractual completeness."
        )
      }
      "pilot-work-tracker" = [ordered]@{
        required_gates = @("lint", "build", "type", "e2e", "security", "smoke")
        required_artifacts = @("spec", "docs", "tests", "runbook", "release_notes")
        notes = @(
          "Forces all gates for lane-aware execution and evidence collection.",
          "Requires spec, docs, tests, runbook, and release-notes for work-tracker lane contractual completeness.",
          "Work-tracker deployment model emphasizes lane-aware orchestration and merge sequencing."
        )
      }
    }
  }
}

function Get-ContentHash {
  param(
    [Parameter(Mandatory)]
    [string]$InputText
  )

  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputText.ToLowerInvariant())
    $hash = $sha.ComputeHash($bytes)
    return ([BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Get-OpenIntentIssues {
  param(
    [Parameter(Mandatory)]
    [string]$Repo,
    [string[]]$Labels = @()
  )

  $issues = @()
  $page = 1
  do {
    $query = "/repos/$Repo/issues?state=open&per_page=100&page=$page"
    if ($Labels.Count -gt 0) {
      $query += "&labels=$([uri]::EscapeDataString(($Labels -join ',')))"
    }

    $response = Invoke-Gh -Arguments @("api", $query)
    $parsed = @($response | ConvertFrom-Json)
    foreach ($issue in $parsed) {
      if ($null -eq $issue.pull_request) {
        $issues += [pscustomobject]@{
          number = $issue.number
          url = $issue.html_url
          title = $issue.title
          body = $issue.body
        }
      }
    }

    $page++
  } while ($parsed.Count -eq 100)

  return $issues
}

function Find-ExistingIssueByMarker {
  param(
    [Parameter(Mandatory)]
    [array]$Issues,
    [Parameter(Mandatory)]
    [string]$Marker
  )

  foreach ($issue in $Issues) {
    if (-not [string]::IsNullOrWhiteSpace($issue.body) -and $issue.body.Contains($Marker)) {
      return $issue
    }
  }

  return $null
}

$sprints = Get-IntentPhases -IntentName $Intent
$desiredStateDiff = Get-DesiredStateDiff -IntentName $Intent -ProfileName $Profile
$releaseGateContract = Get-ReleaseGateContract
$runKey = "$Intent|$TargetRepo|$trimmedGoal|$Profile"
$runKeyHash = Get-ContentHash -InputText $runKey
$parentMarker = "<!-- basecoat-intent-parent:$runKeyHash -->"

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
- Profile: `$Profile`
- Spec reference: $specLine
- Started: $timestamp

## Governance Checklist

- [ ] Scope and acceptance criteria confirmed
- [ ] Required validation gates identified
- [ ] Required release gates satisfy the risk-band policy
- [ ] Rollout strategy documented
- [ ] Rollback strategy documented
- [ ] Documentation updates identified

## Execution Model

This issue is the control-plane parent for a governed multi-sprint execution loop.
Child sprint issues are generated automatically and must remain linked.

## Desired-State Diff

The flow below emits actionable desired-state changes.
"@

foreach ($diff in $desiredStateDiff) {
  $parentBody += "`n- `$($diff.surface)`: current=`$($diff.current_state)` -> desired=`$($diff.desired_state)` (`$($diff.action)`)"
}

$parentBody += @"

## Staged Promotion Contract

- Release gate workflow: `$($releaseGateContract.workflow)`
- Promotion order: `$($releaseGateContract.promotion_order -join " -> ")`
- Evidence bundle output: `$($releaseGateContract.evidence_bundle_output)`
- [ ] Production cutover uses validated rollback evidence

$parentMarker
"@

$summary = [ordered]@{
  intent = $Intent
  goal = $trimmedGoal
  target_repo = $TargetRepo
  risk_band = $RiskBand
  profile = $Profile
  spec_ref = $SpecRef
  started_at = $timestamp
  dry_run = [bool]$DryRun
  run_key = $runKey
  run_key_hash = $runKeyHash
  desired_state_diff = $desiredStateDiff
  release_gate_contract = $releaseGateContract
  remediation_tasks = @(
    [ordered]@{
      name = "Open remediation issue on failed apply or validate phases"
      owner = $Intent
      status = "pending"
    }
  )
  parent_issue_url = ""
  parent_issue_number = ""
  parent_issue_reused = $false
  child_issues = @()
}

if ($DryRun) {
  $summary.parent_issue_url = "https://github.com/$TargetRepo/issues/0000"
  $summary.parent_issue_number = "0000"
  for ($i = 0; $i -lt $sprints.Count; $i++) {
    $phaseName = [string]$sprints[$i].Name
    $phaseSlug = ($phaseName.ToLowerInvariant() -replace "[^a-z0-9]+", "-").Trim("-")
    $executionLane = Get-ExecutionLane -IntentName $Intent -ProfileName $Profile -StageSlug $phaseSlug
    $stageArtifact = Get-StageArtifact `
      -IntentName $Intent `
      -RepoShortName $repoName `
      -GoalText $trimmedGoal `
      -StageIndex ($i + 1) `
      -StageSlug $phaseSlug `
      -RunHash $runKeyHash `
      -ExecutionLane $executionLane
    $summary.child_issues += [ordered]@{
      sprint = $phaseName
      phase = $phaseName
      url = "https://github.com/$TargetRepo/issues/000$($i + 1)"
      number = "000$($i + 1)"
      reused = $false
      stage_artifact = $stageArtifact
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
  Ensure-Label -Repo $TargetRepo -Name "onboarding-conductor" -Color "1d76db" -Description "Tracks onboarding-conductor intent runs."

  $existingIssues = Get-OpenIntentIssues -Repo $TargetRepo -Labels @("intent-control-plane", $Intent)
  $existingParent = Find-ExistingIssueByMarker -Issues $existingIssues -Marker $parentMarker

  $bodyPath = Join-Path $tempRoot "ship-it-parent-$([Guid]::NewGuid().ToString()).md"
  Set-Content -Path $bodyPath -Value $parentBody -Encoding UTF8

  if ($null -ne $existingParent) {
    $summary.parent_issue_reused = $true
    $parentUrl = [string]$existingParent.url
    Invoke-Gh -Arguments @(
      "issue", "edit", [string]$existingParent.number,
      "--repo", $TargetRepo,
      "--title", $parentTitle,
      "--body-file", $bodyPath,
      "--add-label", ($commonLabels -join ",")
    ) | Out-Null
  } else {
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
  }

  $summary.parent_issue_url = $parentUrl
  if ($parentUrl -notmatch "/issues/(\d+)$") {
    throw "Unable to parse parent issue number from: $parentUrl"
  }
  $summary.parent_issue_number = $Matches[1]

  for ($i = 0; $i -lt $sprints.Count; $i++) {
    $sprint = $sprints[$i]
    $index = $i + 1
    $phaseName = [string]$sprint.Name
    $phaseSlug = ($phaseName.ToLowerInvariant() -replace "[^a-z0-9]+", "-").Trim("-")
    $phaseMarker = "<!-- basecoat-intent-child:${runKeyHash}:${phaseSlug} -->"
    $executionLane = Get-ExecutionLane -IntentName $Intent -ProfileName $Profile -StageSlug $phaseSlug
    $stageArtifact = Get-StageArtifact `
      -IntentName $Intent `
      -RepoShortName $repoName `
      -GoalText $trimmedGoal `
      -StageIndex $index `
      -StageSlug $phaseSlug `
      -RunHash $runKeyHash `
      -ExecutionLane $executionLane
    $sprintTitlePrefix = if ($Intent -eq "onboarding-conductor") { "Phase" } else { "Sprint" }
    $sprintTitle = "[Intent][$Intent][$sprintTitlePrefix $index][$repoName] $trimmedGoal"
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

## PR Artifacts

- Planned branch: `$($stageArtifact.branch_name)`
- Planned PR title: $($stageArtifact.pr_title)
- Planned PR search: `$($stageArtifact.pr_search_query)`
- Execution lane: `$($stageArtifact.execution_lane)`
- [ ] Linked PR created or updated for this stage

## Merge Sequencing Guardrail

- Policy: `$($stageArtifact.merge_policy.sequencing)`
- Required checks before merge:
  - `$($stageArtifact.merge_policy.required_checks[0])`
  - `$($stageArtifact.merge_policy.required_checks[1])`
- [ ] Merge this stage only after prior stage closure and all required checks are green

## Release Gate Enforcement

- Release gate workflow: `$($releaseGateContract.workflow)`
- Promotion order: `$($releaseGateContract.promotion_order -join " -> ")`
- Release gate lane input: `$($stageArtifact.execution_lane)`
- Lane strict profile for pilot-luxesite:
  - Required gates: `lint, build, type, e2e, security, smoke`
  - Required artifacts: `spec, docs, tests, runbook, release_notes`
- [ ] Evidence bundle attached for this stage (`promotion-evidence-bundle.json`)
- [ ] Promotion blocked when any required gate fails for `risk-$RiskBand`
- [ ] Rollback validation evidence captured before production cutover
- [ ] Runbook delta mapped to goal IDs
- [ ] Release-note delta mapped to goal IDs
- [ ] Spec drift report reviewed with remediation actions

## Branch Cleanup and Audit

- Cleanup workflow: `$($stageArtifact.cleanup_policy.workflow)`
- Cleanup script: `$($stageArtifact.cleanup_policy.script)`
- Audit output: `$($stageArtifact.cleanup_policy.audit_log)`
- [ ] Post-merge cleanup audit reviewed

$phaseMarker
"@

    $sprintBodyPath = Join-Path $tempRoot "ship-it-sprint-$index-$([Guid]::NewGuid().ToString()).md"
    Set-Content -Path $sprintBodyPath -Value $sprintBody -Encoding UTF8

    $existingChild = Find-ExistingIssueByMarker -Issues $existingIssues -Marker $phaseMarker
    if ($null -ne $existingChild) {
      $sprintUrl = [string]$existingChild.url
      Invoke-Gh -Arguments @(
        "issue", "edit", [string]$existingChild.number,
        "--repo", $TargetRepo,
        "--title", $sprintTitle,
        "--body-file", $sprintBodyPath,
        "--add-label", (($commonLabels + "sprint") -join ",")
      ) | Out-Null
    } else {
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
    }
    if ($sprintUrl -notmatch "/issues/(\d+)$") {
      throw "Unable to parse child issue number from: $sprintUrl"
    }
    $childIssueNumber = $Matches[1]

    $summary.child_issues += [ordered]@{
      sprint = $phaseName
      phase = $phaseName
      url = $sprintUrl
      number = $childIssueNumber
      reused = ($null -ne $existingChild)
      stage_artifact = $stageArtifact
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
- Profile: `$($summary.profile)`
- Dry run: `$($summary.dry_run)`
- Parent issue: $($summary.parent_issue_url)
- Parent issue reused: `$($summary.parent_issue_reused)`

## Desired-State Diff
"@

foreach ($diff in $summary.desired_state_diff) {
  $markdown += "`n- $($diff.surface): $($diff.current_state) -> $($diff.desired_state) ($($diff.action))"
}

$markdown += @"

## Child Issues
"@

foreach ($child in $summary.child_issues) {
  $markdown += "`n- $($child.sprint): $($child.url) (reused=$($child.reused))"
}

Set-Content -Path $markdownPath -Value $markdown -Encoding UTF8

Write-Host "Ship-it intent dispatched."
Write-Host "Summary: $OutputPath"
Write-Output ($summary | ConvertTo-Json -Depth 6)
