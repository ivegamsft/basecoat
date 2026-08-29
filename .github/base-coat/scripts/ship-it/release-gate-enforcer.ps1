[CmdletBinding()]
param(
  [ValidateSet("low", "medium", "high", "critical")]
  [string]$RiskBand = "medium",

  [ValidateSet("validate", "canary", "staging", "production")]
  [string]$PromotionStage = "validate",

  [ValidateSet("pass", "fail", "not_run")]
  [string]$LintStatus = "not_run",

  [ValidateSet("pass", "fail", "not_run")]
  [string]$BuildStatus = "not_run",

  [ValidateSet("pass", "fail", "not_run")]
  [string]$TypeStatus = "not_run",

  [ValidateSet("pass", "fail", "not_run")]
  [string]$E2eStatus = "not_run",

  [ValidateSet("pass", "fail", "not_run")]
  [string]$SecurityStatus = "not_run",

  [ValidateSet("pass", "fail", "not_run")]
  [string]$SmokeStatus = "not_run",

  [ValidateSet("code", "docs-only", "config", "release")]
  [string]$ChangeType = "code",

  [ValidateSet("standard", "pilot-luxesite", "pilot-wawkr", "pilot-work-tracker")]
  [string]$ExecutionLane = "standard",

  [ValidateSet("present", "missing", "not_applicable")]
  [string]$SpecStatus = "missing",

  [ValidateSet("present", "missing", "not_applicable")]
  [string]$DocsStatus = "missing",

  [ValidateSet("present", "missing", "not_applicable")]
  [string]$TestsStatus = "missing",

  [ValidateSet("present", "missing", "not_applicable")]
  [string]$RunbookStatus = "missing",

  [ValidateSet("present", "missing", "not_applicable")]
  [string]$ReleaseNotesStatus = "missing",

  [string]$GoalIds = "",

  [string]$SpecGoalIds = "",

  [string]$DocsGoalIds = "",

  [string]$TestsGoalIds = "",

  [string]$RunbookGoalIds = "",

  [string]$ReleaseNotesGoalIds = "",

  [ValidateSet("pass", "fail", "not_run")]
  [string]$PreviousStageStatus = "pass",

  [ValidateSet("configured", "missing")]
  [string]$EnvironmentProtectionStatus = "configured",

  [bool]$RequireApproval = $false,

  [ValidateSet("approved", "not-required", "missing")]
  [string]$ApprovalStatus = "not-required",

  [string]$RollbackRunbookRef = "",

  [ValidateSet("validated", "missing", "failed")]
  [string]$RollbackValidationStatus = "missing",

  [string]$TargetEnvironment = "",

  [string]$TargetRepo = "",

  [string]$SourceBranch = "",

  [string]$SourceSha = "",

  [string]$WorkflowRef = "",

  [string]$WorkflowRunId = "",

  [string]$OutputPath = "test-results\ship-it\promotion-evidence-bundle.json",

  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function ConvertTo-CanonicalJson {
  param([Parameter(Mandatory)][object]$InputObject)
  return ($InputObject | ConvertTo-Json -Depth 12 -Compress)
}

function Get-Sha256Hex {
  param([Parameter(Mandatory)][string]$InputText)

  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputText)
    $hash = $sha.ComputeHash($bytes)
    return ([BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Get-DefaultEnvironmentForStage {
  param([Parameter(Mandatory)][string]$Stage)

  switch ($Stage) {
    "validate" { return "validation" }
    "canary" { return "canary" }
    "staging" { return "staging" }
    "production" { return "production" }
    default { return $Stage }
  }
}

function Get-RequiredGates {
  param([Parameter(Mandatory)][string]$Risk)

  switch ($Risk) {
    "low" { return @("lint", "build", "smoke") }
    "medium" { return @("lint", "build", "type", "smoke") }
    "high" { return @("lint", "build", "type", "e2e", "security", "smoke") }
    "critical" { return @("lint", "build", "type", "e2e", "security", "smoke") }
    default { throw "Unsupported risk band: $Risk" }
  }
}

function Get-StageOrder {
  return @("validate", "canary", "staging", "production")
}

function ConvertTo-NormalizedList {
  param([string]$Value)

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return @()
  }

  $tokens = $Value -split '[,\s;|]+' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $normalized = @()
  foreach ($token in $tokens) {
    if ($seen.Add($token)) {
      $normalized += $token
    }
  }
  return $normalized
}

function Get-RequiredArtifacts {
  param(
    [Parameter(Mandatory)][string]$Risk,
    [Parameter(Mandatory)][string]$Stage,
    [Parameter(Mandatory)][string]$Delta
  )

  $required = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($name in @("spec", "docs")) {
    [void]$required.Add($name)
  }

  if ($Delta -ne "docs-only") {
    [void]$required.Add("tests")
  }

  if ($Risk -in @("high", "critical") -or $Delta -in @("config", "release") -or $Stage -eq "production") {
    [void]$required.Add("runbook")
  }

  if ($Risk -in @("high", "critical") -or $Delta -eq "release" -or $Stage -eq "production") {
    [void]$required.Add("release_notes")
  }

  return @($required)
}

function Get-LanePolicy {
  param([Parameter(Mandatory)][string]$Lane)

  switch ($Lane) {
    "standard" {
      return [ordered]@{
        lane = "standard"
        description = "Risk-band defaults."
        required_gates = @()
        required_artifacts = @()
      }
    }
    "pilot-luxesite" {
      return [ordered]@{
        lane = "pilot-luxesite"
        description = "Pilot stabilization lane with strict promotion checks and artifacts."
        required_gates = @("lint", "build", "type", "e2e", "security", "smoke")
        required_artifacts = @("spec", "docs", "tests", "runbook", "release_notes")
      }
    }
    "pilot-wawkr" {
      return [ordered]@{
        lane = "pilot-wawkr"
        description = "Pilot canary lane for wawkr downstream repo with strict promotion checks and evidence."
        required_gates = @("lint", "build", "type", "e2e", "security", "smoke")
        required_artifacts = @("spec", "docs", "tests", "runbook", "release_notes")
      }
    }
    "pilot-work-tracker" {
      return [ordered]@{
        lane = "pilot-work-tracker"
        description = "Pilot lane-aware execution lane for work-tracker with strict promotion checks and lane-aware orchestration."
        required_gates = @("lint", "build", "type", "e2e", "security", "smoke")
        required_artifacts = @("spec", "docs", "tests", "runbook", "release_notes")
      }
    }
    default {
      throw "Unsupported execution lane: $Lane"
    }
  }
}

function Get-ArtifactCoverage {
  param(
    [string[]]$ContractGoalIds,
    [string[]]$ArtifactGoalIds
  )

  $missing = @()
  $extra = @()
  $coveragePercent = 100.0

  if ($ContractGoalIds.Count -gt 0) {
    foreach ($goal in $ContractGoalIds) {
      if ($ArtifactGoalIds -notcontains $goal) {
        $missing += $goal
      }
    }
    $coveragePercent = [math]::Round((($ContractGoalIds.Count - $missing.Count) / [double]$ContractGoalIds.Count) * 100.0, 2)
  }

  foreach ($goal in $ArtifactGoalIds) {
    if ($ContractGoalIds.Count -gt 0 -and $ContractGoalIds -notcontains $goal) {
      $extra += $goal
    }
  }

  return [ordered]@{
    missing = $missing
    extra = $extra
    coverage_percent = $coveragePercent
  }
}

$stageOrder = Get-StageOrder
$stageIndex = [Array]::IndexOf($stageOrder, $PromotionStage)
if ($stageIndex -lt 0) {
  throw "Unsupported promotion stage: $PromotionStage"
}

if ([string]::IsNullOrWhiteSpace($TargetEnvironment)) {
  $TargetEnvironment = Get-DefaultEnvironmentForStage -Stage $PromotionStage
}

$effectiveSourceSha = if ([string]::IsNullOrWhiteSpace($SourceSha)) { $env:GITHUB_SHA } else { $SourceSha }
$effectiveWorkflowRef = if ([string]::IsNullOrWhiteSpace($WorkflowRef)) { $env:GITHUB_WORKFLOW_REF } else { $WorkflowRef }
$effectiveWorkflowRunId = if ([string]::IsNullOrWhiteSpace($WorkflowRunId)) { $env:GITHUB_RUN_ID } else { $WorkflowRunId }
$effectiveTargetRepo = if ([string]::IsNullOrWhiteSpace($TargetRepo)) { $env:GITHUB_REPOSITORY } else { $TargetRepo }
$effectiveSourceBranch = if ([string]::IsNullOrWhiteSpace($SourceBranch)) { $env:GITHUB_REF_NAME } else { $SourceBranch }

$gateStatuses = [ordered]@{
  lint = $LintStatus
  build = $BuildStatus
  type = $TypeStatus
  e2e = $E2eStatus
  security = $SecurityStatus
  smoke = $SmokeStatus
}

$contractGoalIds = ConvertTo-NormalizedList -Value $GoalIds
$specContractGoalIds = ConvertTo-NormalizedList -Value $SpecGoalIds
if ($specContractGoalIds.Count -eq 0) {
  $specContractGoalIds = $contractGoalIds
}
$docsGoalIdList = ConvertTo-NormalizedList -Value $DocsGoalIds
$testsGoalIdList = ConvertTo-NormalizedList -Value $TestsGoalIds
$runbookGoalIdList = ConvertTo-NormalizedList -Value $RunbookGoalIds
$releaseNotesGoalIdList = ConvertTo-NormalizedList -Value $ReleaseNotesGoalIds

$artifactStatuses = [ordered]@{
  spec = [ordered]@{ status = $SpecStatus; goal_ids = $specContractGoalIds }
  docs = [ordered]@{ status = $DocsStatus; goal_ids = $docsGoalIdList }
  tests = [ordered]@{ status = $TestsStatus; goal_ids = $testsGoalIdList }
  runbook = [ordered]@{ status = $RunbookStatus; goal_ids = $runbookGoalIdList }
  release_notes = [ordered]@{ status = $ReleaseNotesStatus; goal_ids = $releaseNotesGoalIdList }
}
$lanePolicy = Get-LanePolicy -Lane $ExecutionLane

$requiredArtifacts = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($artifactName in (Get-RequiredArtifacts -Risk $RiskBand -Stage $PromotionStage -Delta $ChangeType)) {
  [void]$requiredArtifacts.Add($artifactName)
}
foreach ($artifactName in @($lanePolicy.required_artifacts)) {
  [void]$requiredArtifacts.Add([string]$artifactName)
}
$requiredArtifacts = @($requiredArtifacts)

$requiredGates = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($gateName in (Get-RequiredGates -Risk $RiskBand)) {
  [void]$requiredGates.Add($gateName)
}
foreach ($gateName in @($lanePolicy.required_gates)) {
  [void]$requiredGates.Add([string]$gateName)
}
$requiredGates = @($requiredGates)
$failedRequiredGates = @()

$gateChecks = [ordered]@{}
foreach ($gateName in $gateStatuses.Keys) {
  $isRequired = $requiredGates -contains $gateName
  $status = [string]$gateStatuses[$gateName]
  $isPassing = $status -eq "pass"
  if ($isRequired -and -not $isPassing) {
    $failedRequiredGates += $gateName
  }
  $gateChecks[$gateName] = [ordered]@{
    required = $isRequired
    status = $status
    passing = $isPassing
  }
}

$blockers = @()
if ($failedRequiredGates.Count -gt 0) {
  $blockers += "required-gates-failed:$($failedRequiredGates -join ',')"
}

$artifactScorecard = @()
$artifactPresentCount = 0
$artifactRequiredCount = 0
$runbookDelta = [ordered]@{
  goal_ids = @()
  missing_goal_ids = @()
  extra_goal_ids = @()
}
$releaseNotesDelta = [ordered]@{
  goal_ids = @()
  missing_goal_ids = @()
  extra_goal_ids = @()
}

foreach ($artifactName in $artifactStatuses.Keys) {
  $artifact = $artifactStatuses[$artifactName]
  $isRequired = $requiredArtifacts -contains $artifactName
  $isPresent = $artifact.status -eq "present"
  if ($isRequired) {
    $artifactRequiredCount++
    if ($isPresent) {
      $artifactPresentCount++
    } else {
      $blockers += "artifact-missing:$artifactName"
    }
  }

  $coverage = Get-ArtifactCoverage -ContractGoalIds $contractGoalIds -ArtifactGoalIds @($artifact.goal_ids)
  $drifted = ($coverage.missing.Count -gt 0) -or ($coverage.extra.Count -gt 0)

  if ($artifactName -eq "runbook") {
    $runbookDelta.goal_ids = @($artifact.goal_ids)
    $runbookDelta.missing_goal_ids = @($coverage.missing)
    $runbookDelta.extra_goal_ids = @($coverage.extra)
  }
  if ($artifactName -eq "release_notes") {
    $releaseNotesDelta.goal_ids = @($artifact.goal_ids)
    $releaseNotesDelta.missing_goal_ids = @($coverage.missing)
    $releaseNotesDelta.extra_goal_ids = @($coverage.extra)
  }

  if ($isRequired -and $artifactName -in @("runbook", "release_notes") -and $isPresent -and @($artifact.goal_ids).Count -eq 0) {
    $blockers += "artifact-goal-link-missing:$artifactName"
  }

  $remediation = if (-not $isRequired) {
    "Optional for current risk/change profile."
  } elseif (-not $isPresent) {
    "Add or attach the required artifact before promotion."
  } elseif ($drifted) {
    "Align artifact goal mapping with intent contract goal IDs."
  } else {
    "No remediation required."
  }

  $artifactScorecard += [ordered]@{
    artifact = $artifactName
    required = $isRequired
    status = $artifact.status
    present = $isPresent
    goal_ids = @($artifact.goal_ids)
    missing_goal_ids = @($coverage.missing)
    extra_goal_ids = @($coverage.extra)
    coverage_percent = $coverage.coverage_percent
    drifted = $drifted
    remediation = $remediation
  }
}

$implementationGoalIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($artifactName in $artifactStatuses.Keys) {
  $artifact = $artifactStatuses[$artifactName]
  if ($artifact.status -eq "present") {
    foreach ($goal in @($artifact.goal_ids)) {
      [void]$implementationGoalIds.Add($goal)
    }
  }
}
$implementationGoalIdList = @($implementationGoalIds)

$missingFromSpec = @()
$missingFromImplementation = @()
$undocumentedImplementationGoals = @()

foreach ($goal in $contractGoalIds) {
  if ($specContractGoalIds -notcontains $goal) {
    $missingFromSpec += $goal
  }
  if ($implementationGoalIdList -notcontains $goal) {
    $missingFromImplementation += $goal
  }
}
foreach ($goal in $implementationGoalIdList) {
  if ($contractGoalIds.Count -gt 0 -and $contractGoalIds -notcontains $goal) {
    $undocumentedImplementationGoals += $goal
  }
}

$driftRemediations = @()
if ($missingFromSpec.Count -gt 0) {
  $driftRemediations += "Update intent/spec contract to include missing goal IDs: $($missingFromSpec -join ', ')."
}
if ($missingFromImplementation.Count -gt 0) {
  $driftRemediations += "Add implementation artifacts for missing goals: $($missingFromImplementation -join ', ')."
}
if ($undocumentedImplementationGoals.Count -gt 0) {
  $driftRemediations += "Reconcile undocumented implementation goals with intent contract: $($undocumentedImplementationGoals -join ', ')."
}
if ($driftRemediations.Count -eq 0) {
  $driftRemediations += "No spec drift detected."
}

$specDrift = [ordered]@{
  has_drift = ($missingFromSpec.Count -gt 0) -or ($missingFromImplementation.Count -gt 0) -or ($undocumentedImplementationGoals.Count -gt 0)
  contract_goal_ids = $contractGoalIds
  spec_goal_ids = $specContractGoalIds
  implementation_goal_ids = $implementationGoalIdList
  missing_from_spec = $missingFromSpec
  missing_from_implementation = $missingFromImplementation
  undocumented_implementation_goals = $undocumentedImplementationGoals
  remediation_suggestions = $driftRemediations
}

if ($specDrift.has_drift) {
  $blockers += "spec-drift-detected"
}

$artifactCompleteness = [ordered]@{
  change_type = $ChangeType
  required_artifacts = $requiredArtifacts
  required_count = $artifactRequiredCount
  present_required_count = $artifactPresentCount
  score_percent = if ($artifactRequiredCount -eq 0) { 100.0 } else { [math]::Round(($artifactPresentCount / [double]$artifactRequiredCount) * 100.0, 2) }
  scorecard = $artifactScorecard
  runbook_delta = $runbookDelta
  release_notes_delta = $releaseNotesDelta
}

$previousStageRequirement = [ordered]@{
  required = $stageIndex -gt 0
  status = $PreviousStageStatus
  passing = $true
}
if ($stageIndex -gt 0 -and $PreviousStageStatus -ne "pass") {
  $previousStageRequirement.passing = $false
  $blockers += "previous-stage-not-passed"
}

$isProductionCutover = $PromotionStage -eq "production"
$effectiveRequireApproval = $RequireApproval -or $isProductionCutover -or $RiskBand -in @("high", "critical")
$approvalPassing = -not $effectiveRequireApproval -or $ApprovalStatus -eq "approved"
if (-not $approvalPassing) {
  $blockers += "approval-missing"
}

$environmentProtectionPassing = $EnvironmentProtectionStatus -eq "configured"
if (-not $environmentProtectionPassing) {
  $blockers += "environment-protection-missing"
}

$rollbackValidationRequired = $isProductionCutover
$rollbackRunbookPresent = -not [string]::IsNullOrWhiteSpace($RollbackRunbookRef)
$rollbackValidationPassing = $RollbackValidationStatus -eq "validated"
if ($rollbackValidationRequired -and -not $rollbackRunbookPresent) {
  $blockers += "rollback-runbook-missing"
}
if ($rollbackValidationRequired -and -not $rollbackValidationPassing) {
  $blockers += "rollback-validation-failed"
}

$promotionAllowed = $blockers.Count -eq 0

$immutableReferences = @()
if (-not [string]::IsNullOrWhiteSpace($effectiveTargetRepo)) {
  $immutableReferences += "repo:$effectiveTargetRepo"
}
if (-not [string]::IsNullOrWhiteSpace($effectiveSourceBranch)) {
  $immutableReferences += "branch:$effectiveSourceBranch"
}
if (-not [string]::IsNullOrWhiteSpace($effectiveSourceSha)) {
  $immutableReferences += "sha:$effectiveSourceSha"
}
if (-not [string]::IsNullOrWhiteSpace($effectiveWorkflowRef)) {
  $immutableReferences += "workflow_ref:$effectiveWorkflowRef"
}
if (-not [string]::IsNullOrWhiteSpace($effectiveWorkflowRunId)) {
  $immutableReferences += "run_id:$effectiveWorkflowRunId"
}
$immutableReferences += "promotion_stage:$PromotionStage"
$immutableReferences += "risk_band:$RiskBand"
$immutableReferences += "execution_lane:$ExecutionLane"

$summary = [ordered]@{
  risk_band = $RiskBand
  promotion_stage = $PromotionStage
  execution_lane = $ExecutionLane
  target_environment = $TargetEnvironment
  promotion_allowed = $promotionAllowed
  blockers = $blockers
  progressive_promotion = [ordered]@{
    order = $stageOrder
    previous_stage = if ($stageIndex -gt 0) { $stageOrder[$stageIndex - 1] } else { "" }
    previous_stage_requirement = $previousStageRequirement
  }
  required_gates = $gateChecks
  failed_required_gates = $failedRequiredGates
  lane_policy = $lanePolicy
  artifact_completeness = $artifactCompleteness
  spec_drift = $specDrift
  environment_protection = [ordered]@{
    status = $EnvironmentProtectionStatus
    require_approval = $effectiveRequireApproval
    approval_status = $ApprovalStatus
    passing = $environmentProtectionPassing -and $approvalPassing
  }
  rollback_contract = [ordered]@{
    required_for_stage = $rollbackValidationRequired
    runbook_ref = $RollbackRunbookRef
    runbook_present = $rollbackRunbookPresent
    validation_status = $RollbackValidationStatus
    validation_passing = $rollbackValidationPassing
  }
  evidence_bundle = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    immutable_references = $immutableReferences
    output_path = $OutputPath
  }
  dry_run = [bool]$DryRun
}

$canonicalWithoutDigest = ConvertTo-CanonicalJson -InputObject $summary
$summary.evidence_bundle.bundle_sha256 = Get-Sha256Hex -InputText $canonicalWithoutDigest

$outputDirectory = Split-Path -Path $OutputPath -Parent
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
  New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$summary | ConvertTo-Json -Depth 12 | Set-Content -Path $OutputPath -Encoding UTF8

$markdownPath = [System.IO.Path]::ChangeExtension($OutputPath, ".md")
$blockersText = if ($summary.blockers.Count -gt 0) { $summary.blockers -join ", " } else { "none" }
$md = @"
# Ship-it Release Gate Summary

- Risk band: `$($summary.risk_band)`
- Promotion stage: `$($summary.promotion_stage)`
- Execution lane: `$($summary.execution_lane)`
- Target environment: `$($summary.target_environment)`
- Promotion allowed: `$($summary.promotion_allowed)`
- Blockers: $blockersText

## Required Gates
"@

foreach ($gateName in $summary.required_gates.Keys) {
  $gate = $summary.required_gates[$gateName]
  $md += "`n- ${gateName}: status=$($gate.status) required=$($gate.required) passing=$($gate.passing)"
}

$md += "`n`n## Progressive Promotion"
$md += "`n`n- Order: $($summary.progressive_promotion.order -join ' -> ')"
$md += "`n- Previous stage: $($summary.progressive_promotion.previous_stage)"
$md += "`n- Previous stage passing: $($summary.progressive_promotion.previous_stage_requirement.passing)"
$md += "`n`n## Environment Protection"
$md += "`n`n- Protection status: $($summary.environment_protection.status)"
$md += "`n- Approval required: $($summary.environment_protection.require_approval)"
$md += "`n- Approval status: $($summary.environment_protection.approval_status)"
$md += "`n`n## Lane Policy"
$md += "`n`n- Description: $($summary.lane_policy.description)"
$md += "`n- Added required gates: $($(if ($summary.lane_policy.required_gates.Count -gt 0) { $summary.lane_policy.required_gates -join ', ' } else { 'none' }))"
$md += "`n- Added required artifacts: $($(if ($summary.lane_policy.required_artifacts.Count -gt 0) { $summary.lane_policy.required_artifacts -join ', ' } else { 'none' }))"

$md += "`n`n## Rollback Contract"
$md += "`n`n- Required for stage: $($summary.rollback_contract.required_for_stage)"
$md += "`n- Runbook present: $($summary.rollback_contract.runbook_present)"
$md += "`n- Validation status: $($summary.rollback_contract.validation_status)"
$md += "`n`n## Evidence Bundle"
$md += "`n`n- SHA-256: $($summary.evidence_bundle.bundle_sha256)"
$md += "`n- Immutable refs: $($summary.evidence_bundle.immutable_references -join ' | ')"
$md += "`n`n## Artifact Completeness Scorecard"
$md += "`n`n- Change type: $($summary.artifact_completeness.change_type)"
$md += "`n- Required artifacts: $($summary.artifact_completeness.required_artifacts -join ', ')"
$md += "`n- Completeness score: $($summary.artifact_completeness.score_percent)%"
$md += "`n`n| Artifact | Required | Status | Goal IDs | Missing Goals | Extra Goals | Coverage % | Remediation |"
$md += "`n|---|---|---|---|---|---|---|---|"
foreach ($entry in $summary.artifact_completeness.scorecard) {
  $goalIdsText = if ($entry.goal_ids.Count -gt 0) { $entry.goal_ids -join ", " } else { "-" }
  $missingGoalsText = if ($entry.missing_goal_ids.Count -gt 0) { $entry.missing_goal_ids -join ", " } else { "-" }
  $extraGoalsText = if ($entry.extra_goal_ids.Count -gt 0) { $entry.extra_goal_ids -join ", " } else { "-" }
  $md += "`n| $($entry.artifact) | $($entry.required) | $($entry.status) | $goalIdsText | $missingGoalsText | $extraGoalsText | $($entry.coverage_percent) | $($entry.remediation) |"
}
$md += "`n`n### Runbook Delta (Goal IDs)"
$md += "`n- Goal IDs: $($(if ($summary.artifact_completeness.runbook_delta.goal_ids.Count -gt 0) { $summary.artifact_completeness.runbook_delta.goal_ids -join ', ' } else { '-' }))"
$md += "`n- Missing contract goals: $($(if ($summary.artifact_completeness.runbook_delta.missing_goal_ids.Count -gt 0) { $summary.artifact_completeness.runbook_delta.missing_goal_ids -join ', ' } else { '-' }))"
$md += "`n- Extra goals: $($(if ($summary.artifact_completeness.runbook_delta.extra_goal_ids.Count -gt 0) { $summary.artifact_completeness.runbook_delta.extra_goal_ids -join ', ' } else { '-' }))"
$md += "`n`n### Release-Notes Delta (Goal IDs)"
$md += "`n- Goal IDs: $($(if ($summary.artifact_completeness.release_notes_delta.goal_ids.Count -gt 0) { $summary.artifact_completeness.release_notes_delta.goal_ids -join ', ' } else { '-' }))"
$md += "`n- Missing contract goals: $($(if ($summary.artifact_completeness.release_notes_delta.missing_goal_ids.Count -gt 0) { $summary.artifact_completeness.release_notes_delta.missing_goal_ids -join ', ' } else { '-' }))"
$md += "`n- Extra goals: $($(if ($summary.artifact_completeness.release_notes_delta.extra_goal_ids.Count -gt 0) { $summary.artifact_completeness.release_notes_delta.extra_goal_ids -join ', ' } else { '-' }))"
$md += "`n`n## Spec Drift"
$md += "`n`n- Drift detected: $($summary.spec_drift.has_drift)"
$md += "`n- Contract goal IDs: $($(if ($summary.spec_drift.contract_goal_ids.Count -gt 0) { $summary.spec_drift.contract_goal_ids -join ', ' } else { '-' }))"
$md += "`n- Spec goal IDs: $($(if ($summary.spec_drift.spec_goal_ids.Count -gt 0) { $summary.spec_drift.spec_goal_ids -join ', ' } else { '-' }))"
$md += "`n- Implementation goal IDs: $($(if ($summary.spec_drift.implementation_goal_ids.Count -gt 0) { $summary.spec_drift.implementation_goal_ids -join ', ' } else { '-' }))"
$md += "`n- Missing from spec: $($(if ($summary.spec_drift.missing_from_spec.Count -gt 0) { $summary.spec_drift.missing_from_spec -join ', ' } else { '-' }))"
$md += "`n- Missing from implementation: $($(if ($summary.spec_drift.missing_from_implementation.Count -gt 0) { $summary.spec_drift.missing_from_implementation -join ', ' } else { '-' }))"
$md += "`n- Undocumented implementation goals: $($(if ($summary.spec_drift.undocumented_implementation_goals.Count -gt 0) { $summary.spec_drift.undocumented_implementation_goals -join ', ' } else { '-' }))"
$md += "`n`n### Spec Drift Remediation Suggestions"
foreach ($suggestion in $summary.spec_drift.remediation_suggestions) {
  $md += "`n- $suggestion"
}

Set-Content -Path $markdownPath -Value $md -Encoding UTF8

Write-Output ($summary | ConvertTo-Json -Depth 12)

if (-not $DryRun -and -not $promotionAllowed) {
  Write-Error "Promotion blocked by release gate contract."
  exit 1
}
