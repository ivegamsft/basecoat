[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$enforcerScript = Join-Path $repoRoot "scripts\ship-it\release-gate-enforcer.ps1"
$workflowFile = Join-Path $repoRoot ".github\workflows\ship-it-release-gate.yml"

if (-not (Test-Path $enforcerScript)) {
  throw "Missing release-gate enforcer script: $enforcerScript"
}
if (-not (Test-Path $workflowFile)) {
  throw "Missing release-gate workflow: $workflowFile"
}

$outputDirectory = Join-Path $repoRoot "test-results\ship-it-release-gate-test"
if (Test-Path $outputDirectory) {
  Remove-Item -Path $outputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

function Invoke-Scenario {
  param(
    [Parameter(Mandatory)]
    [string]$Name,
    [Parameter(Mandatory)]
    [hashtable]$Params,
    [Parameter(Mandatory)]
    [bool]$ExpectedAllowed,
    [string]$ExpectedBlockerContains = ""
  )

  $outputPath = Join-Path $outputDirectory "$Name-summary.json"
  $invokeParams = @{
    RiskBand = $Params.RiskBand
    PromotionStage = $Params.PromotionStage
    PreviousStageStatus = $Params.PreviousStageStatus
    LintStatus = $Params.LintStatus
    BuildStatus = $Params.BuildStatus
    TypeStatus = $Params.TypeStatus
    E2eStatus = $Params.E2eStatus
    SecurityStatus = $Params.SecurityStatus
    SmokeStatus = $Params.SmokeStatus
    EnvironmentProtectionStatus = $Params.EnvironmentProtectionStatus
    RequireApproval = [bool]$Params.RequireApproval
    ApprovalStatus = $Params.ApprovalStatus
    RollbackRunbookRef = $Params.RollbackRunbookRef
    RollbackValidationStatus = $Params.RollbackValidationStatus
    ChangeType = $Params.ChangeType
    ExecutionLane = if ($Params.ContainsKey("ExecutionLane")) { $Params.ExecutionLane } else { "standard" }
    GoalIds = $Params.GoalIds
    SpecGoalIds = $Params.SpecGoalIds
    SpecStatus = $Params.SpecStatus
    DocsStatus = $Params.DocsStatus
    TestsStatus = $Params.TestsStatus
    RunbookStatus = $Params.RunbookStatus
    ReleaseNotesStatus = $Params.ReleaseNotesStatus
    DocsGoalIds = $Params.DocsGoalIds
    TestsGoalIds = $Params.TestsGoalIds
    RunbookGoalIds = $Params.RunbookGoalIds
    ReleaseNotesGoalIds = $Params.ReleaseNotesGoalIds
    TargetRepo = "IBuySpy-Shared/basecoat"
    SourceBranch = "intent/ship-it/demo"
    SourceSha = "1234567890abcdef1234567890abcdef12345678"
    WorkflowRef = "IBuySpy-Shared/basecoat/.github/workflows/ship-it-release-gate.yml@refs/heads/main"
    WorkflowRunId = "1001"
    OutputPath = $outputPath
    DryRun = $true
  }

  & $enforcerScript @invokeParams
  if (-not (Test-Path $outputPath)) {
    throw "Scenario '$Name' did not create summary JSON."
  }

  $summary = Get-Content -Raw -Path $outputPath | ConvertFrom-Json
  if ([bool]$summary.promotion_allowed -ne $ExpectedAllowed) {
    throw "Scenario '$Name' expected promotion_allowed=$ExpectedAllowed but got '$($summary.promotion_allowed)'."
  }

  if (-not [string]::IsNullOrWhiteSpace($ExpectedBlockerContains)) {
    $joined = ($summary.blockers -join ",")
    if ($joined -notmatch [regex]::Escape($ExpectedBlockerContains)) {
      throw "Scenario '$Name' expected blocker containing '$ExpectedBlockerContains' but blockers were '$joined'."
    }
  }

  if ([string]::IsNullOrWhiteSpace($summary.evidence_bundle.bundle_sha256)) {
    throw "Scenario '$Name' must include evidence bundle digest."
  }
  if ($summary.evidence_bundle.immutable_references.Count -lt 4) {
    throw "Scenario '$Name' must include immutable references."
  }

  $markdownPath = [System.IO.Path]::ChangeExtension($outputPath, ".md")
  if (-not (Test-Path $markdownPath)) {
    throw "Scenario '$Name' did not create markdown summary."
  }
  if ($summary.artifact_completeness.scorecard.Count -lt 5) {
    throw "Scenario '$Name' should include a full artifact scorecard."
  }
  if ($summary.spec_drift.remediation_suggestions.Count -lt 1) {
    throw "Scenario '$Name' should emit spec drift remediation suggestions."
  }
}

Invoke-Scenario -Name "low-risk-canary-pass" -Params @{
  RiskBand = "low"
  PromotionStage = "canary"
  ChangeType = "code"
  PreviousStageStatus = "pass"
  LintStatus = "pass"
  BuildStatus = "pass"
  TypeStatus = "not_run"
  E2eStatus = "not_run"
  SecurityStatus = "not_run"
  SmokeStatus = "pass"
  EnvironmentProtectionStatus = "configured"
  RequireApproval = $false
  ApprovalStatus = "not-required"
  RollbackRunbookRef = ""
  RollbackValidationStatus = "missing"
  GoalIds = "GOAL-1,GOAL-2"
  SpecGoalIds = "GOAL-1,GOAL-2"
  SpecStatus = "present"
  DocsStatus = "present"
  TestsStatus = "present"
  RunbookStatus = "present"
  ReleaseNotesStatus = "present"
  DocsGoalIds = "GOAL-1,GOAL-2"
  TestsGoalIds = "GOAL-1,GOAL-2"
  RunbookGoalIds = "GOAL-1,GOAL-2"
  ReleaseNotesGoalIds = "GOAL-1,GOAL-2"
} -ExpectedAllowed $true

Invoke-Scenario -Name "medium-risk-missing-type-fails" -Params @{
  RiskBand = "medium"
  PromotionStage = "staging"
  ChangeType = "code"
  PreviousStageStatus = "pass"
  LintStatus = "pass"
  BuildStatus = "pass"
  TypeStatus = "fail"
  E2eStatus = "not_run"
  SecurityStatus = "not_run"
  SmokeStatus = "pass"
  EnvironmentProtectionStatus = "configured"
  RequireApproval = $false
  ApprovalStatus = "not-required"
  RollbackRunbookRef = ""
  RollbackValidationStatus = "missing"
  GoalIds = "GOAL-1,GOAL-2"
  SpecGoalIds = "GOAL-1,GOAL-2"
  SpecStatus = "present"
  DocsStatus = "present"
  TestsStatus = "present"
  RunbookStatus = "present"
  ReleaseNotesStatus = "present"
  DocsGoalIds = "GOAL-1,GOAL-2"
  TestsGoalIds = "GOAL-1,GOAL-2"
  RunbookGoalIds = "GOAL-1,GOAL-2"
  ReleaseNotesGoalIds = "GOAL-1,GOAL-2"
} -ExpectedAllowed $false -ExpectedBlockerContains "required-gates-failed:type"

Invoke-Scenario -Name "production-missing-rollback-fails" -Params @{
  RiskBand = "high"
  PromotionStage = "production"
  ChangeType = "release"
  PreviousStageStatus = "pass"
  LintStatus = "pass"
  BuildStatus = "pass"
  TypeStatus = "pass"
  E2eStatus = "pass"
  SecurityStatus = "pass"
  SmokeStatus = "pass"
  EnvironmentProtectionStatus = "configured"
  RequireApproval = $true
  ApprovalStatus = "approved"
  RollbackRunbookRef = ""
  RollbackValidationStatus = "missing"
  GoalIds = "GOAL-1,GOAL-2"
  SpecGoalIds = "GOAL-1,GOAL-2"
  SpecStatus = "present"
  DocsStatus = "present"
  TestsStatus = "present"
  RunbookStatus = "present"
  ReleaseNotesStatus = "present"
  DocsGoalIds = "GOAL-1,GOAL-2"
  TestsGoalIds = "GOAL-1,GOAL-2"
  RunbookGoalIds = "GOAL-1,GOAL-2"
  ReleaseNotesGoalIds = "GOAL-1,GOAL-2"
} -ExpectedAllowed $false -ExpectedBlockerContains "rollback-runbook-missing"

Invoke-Scenario -Name "production-approved-and-validated-pass" -Params @{
  RiskBand = "critical"
  PromotionStage = "production"
  ChangeType = "release"
  PreviousStageStatus = "pass"
  LintStatus = "pass"
  BuildStatus = "pass"
  TypeStatus = "pass"
  E2eStatus = "pass"
  SecurityStatus = "pass"
  SmokeStatus = "pass"
  EnvironmentProtectionStatus = "configured"
  RequireApproval = $true
  ApprovalStatus = "approved"
  RollbackRunbookRef = "https://example.com/runbooks/rollback"
  RollbackValidationStatus = "validated"
  GoalIds = "GOAL-1,GOAL-2"
  SpecGoalIds = "GOAL-1,GOAL-2"
  SpecStatus = "present"
  DocsStatus = "present"
  TestsStatus = "present"
  RunbookStatus = "present"
  ReleaseNotesStatus = "present"
  DocsGoalIds = "GOAL-1,GOAL-2"
  TestsGoalIds = "GOAL-1,GOAL-2"
  RunbookGoalIds = "GOAL-1,GOAL-2"
  ReleaseNotesGoalIds = "GOAL-1,GOAL-2"
} -ExpectedAllowed $true

Invoke-Scenario -Name "missing-required-artifact-blocks" -Params @{
  RiskBand = "medium"
  PromotionStage = "staging"
  ChangeType = "code"
  PreviousStageStatus = "pass"
  LintStatus = "pass"
  BuildStatus = "pass"
  TypeStatus = "pass"
  E2eStatus = "not_run"
  SecurityStatus = "not_run"
  SmokeStatus = "pass"
  EnvironmentProtectionStatus = "configured"
  RequireApproval = $false
  ApprovalStatus = "not-required"
  RollbackRunbookRef = ""
  RollbackValidationStatus = "missing"
  GoalIds = "GOAL-1,GOAL-2"
  SpecGoalIds = "GOAL-1,GOAL-2"
  SpecStatus = "present"
  DocsStatus = "present"
  TestsStatus = "missing"
  RunbookStatus = "present"
  ReleaseNotesStatus = "present"
  DocsGoalIds = "GOAL-1,GOAL-2"
  TestsGoalIds = ""
  RunbookGoalIds = "GOAL-1,GOAL-2"
  ReleaseNotesGoalIds = "GOAL-1,GOAL-2"
} -ExpectedAllowed $false -ExpectedBlockerContains "artifact-missing:tests"

Invoke-Scenario -Name "spec-drift-blocks-promotion" -Params @{
  RiskBand = "medium"
  PromotionStage = "staging"
  ChangeType = "code"
  PreviousStageStatus = "pass"
  LintStatus = "pass"
  BuildStatus = "pass"
  TypeStatus = "pass"
  E2eStatus = "not_run"
  SecurityStatus = "not_run"
  SmokeStatus = "pass"
  EnvironmentProtectionStatus = "configured"
  RequireApproval = $false
  ApprovalStatus = "not-required"
  RollbackRunbookRef = ""
  RollbackValidationStatus = "missing"
  GoalIds = "GOAL-1,GOAL-2"
  SpecGoalIds = "GOAL-1"
  SpecStatus = "present"
  DocsStatus = "present"
  TestsStatus = "present"
  RunbookStatus = "present"
  ReleaseNotesStatus = "present"
  DocsGoalIds = "GOAL-1"
  TestsGoalIds = "GOAL-1"
  RunbookGoalIds = "GOAL-1"
  ReleaseNotesGoalIds = "GOAL-1"
} -ExpectedAllowed $false -ExpectedBlockerContains "spec-drift-detected"

Invoke-Scenario -Name "runbook-goal-link-required-for-production" -Params @{
  RiskBand = "high"
  PromotionStage = "production"
  ChangeType = "release"
  PreviousStageStatus = "pass"
  LintStatus = "pass"
  BuildStatus = "pass"
  TypeStatus = "pass"
  E2eStatus = "pass"
  SecurityStatus = "pass"
  SmokeStatus = "pass"
  EnvironmentProtectionStatus = "configured"
  RequireApproval = $true
  ApprovalStatus = "approved"
  RollbackRunbookRef = "https://example.com/runbooks/rollback"
  RollbackValidationStatus = "validated"
  GoalIds = "GOAL-1,GOAL-2"
  SpecGoalIds = "GOAL-1,GOAL-2"
  SpecStatus = "present"
  DocsStatus = "present"
  TestsStatus = "present"
  RunbookStatus = "present"
  ReleaseNotesStatus = "present"
  DocsGoalIds = "GOAL-1,GOAL-2"
  TestsGoalIds = "GOAL-1,GOAL-2"
  RunbookGoalIds = ""
  ReleaseNotesGoalIds = "GOAL-1,GOAL-2"
} -ExpectedAllowed $false -ExpectedBlockerContains "artifact-goal-link-missing:runbook"

Invoke-Scenario -Name "pilot-luxesite-lane-requires-security-and-e2e" -Params @{
  RiskBand = "medium"
  PromotionStage = "staging"
  ChangeType = "code"
  ExecutionLane = "pilot-luxesite"
  PreviousStageStatus = "pass"
  LintStatus = "pass"
  BuildStatus = "pass"
  TypeStatus = "pass"
  E2eStatus = "not_run"
  SecurityStatus = "not_run"
  SmokeStatus = "pass"
  EnvironmentProtectionStatus = "configured"
  RequireApproval = $false
  ApprovalStatus = "not-required"
  RollbackRunbookRef = ""
  RollbackValidationStatus = "missing"
  GoalIds = "GOAL-1,GOAL-2"
  SpecGoalIds = "GOAL-1,GOAL-2"
  SpecStatus = "present"
  DocsStatus = "present"
  TestsStatus = "present"
  RunbookStatus = "present"
  ReleaseNotesStatus = "present"
  DocsGoalIds = "GOAL-1,GOAL-2"
  TestsGoalIds = "GOAL-1,GOAL-2"
  RunbookGoalIds = "GOAL-1,GOAL-2"
  ReleaseNotesGoalIds = "GOAL-1,GOAL-2"
} -ExpectedAllowed $false -ExpectedBlockerContains "required-gates-failed:e2e,security"

Invoke-Scenario -Name "pilot-luxesite-lane-requires-runbook-and-release-notes" -Params @{
  RiskBand = "medium"
  PromotionStage = "staging"
  ChangeType = "code"
  ExecutionLane = "pilot-luxesite"
  PreviousStageStatus = "pass"
  LintStatus = "pass"
  BuildStatus = "pass"
  TypeStatus = "pass"
  E2eStatus = "pass"
  SecurityStatus = "pass"
  SmokeStatus = "pass"
  EnvironmentProtectionStatus = "configured"
  RequireApproval = $false
  ApprovalStatus = "not-required"
  RollbackRunbookRef = ""
  RollbackValidationStatus = "missing"
  GoalIds = "GOAL-1,GOAL-2"
  SpecGoalIds = "GOAL-1,GOAL-2"
  SpecStatus = "present"
  DocsStatus = "present"
  TestsStatus = "present"
  RunbookStatus = "missing"
  ReleaseNotesStatus = "missing"
  DocsGoalIds = "GOAL-1,GOAL-2"
  TestsGoalIds = "GOAL-1,GOAL-2"
  RunbookGoalIds = ""
  ReleaseNotesGoalIds = ""
} -ExpectedAllowed $false -ExpectedBlockerContains "artifact-missing:runbook"

$workflowContent = Get-Content -Raw -Path $workflowFile
if ($workflowContent -notmatch "workflow_dispatch:") {
  throw "Ship-it release gate workflow must include workflow_dispatch trigger."
}
if ($workflowContent -notmatch "promotion_stage:") {
  throw "Ship-it release gate workflow must include promotion_stage input."
}
if ($workflowContent -notmatch "rollback_validation_status:") {
  throw "Ship-it release gate workflow must include rollback_validation_status input."
}
if ($workflowContent -notmatch "change_type:") {
  throw "Ship-it release gate workflow must include change_type input."
}
if ($workflowContent -notmatch "execution_lane:") {
  throw "Ship-it release gate workflow must include execution_lane input."
}
if ($workflowContent -notmatch "goal_ids:") {
  throw "Ship-it release gate workflow must include goal_ids input."
}
if ($workflowContent -notmatch "promotion-evidence-bundle.json") {
  throw "Ship-it release gate workflow must emit promotion evidence bundle."
}

Write-Host "Ship-it release-gate enforcer tests passed."
