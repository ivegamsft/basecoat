[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$dispatchScript = Join-Path $repoRoot "scripts\ship-it\dispatch-intent.ps1"
$workflowFile = Join-Path $repoRoot ".github\workflows\ship-it-intent-dispatch.yml"
$packageDispatchScript = Join-Path $repoRoot ".github\base-coat\scripts\ship-it\dispatch-intent.ps1"
$packageTargetRepositoryValidator = Join-Path $repoRoot ".github\base-coat\scripts\ship-it\validate-target-repository.ps1"
$packageWorkflowFile = Join-Path $repoRoot ".github\base-coat\workflows\ship-it-intent-dispatch.yml"
$skillFile = Join-Path $repoRoot "skills\ship-it\SKILL.md"
$skillEvalFile = Join-Path $repoRoot "skills\ship-it\eval.yaml"

if (-not (Test-Path $dispatchScript)) {
  throw "Missing ship-it dispatch script: $dispatchScript"
}
if (-not (Test-Path $workflowFile)) {
  throw "Missing ship-it workflow: $workflowFile"
}
if (-not (Test-Path $packageDispatchScript)) {
  throw "Missing packaged ship-it dispatch script: $packageDispatchScript"
}
if (-not (Test-Path $packageTargetRepositoryValidator)) {
  throw "Missing packaged target repository validator: $packageTargetRepositoryValidator"
}
if (-not (Test-Path $packageWorkflowFile)) {
  throw "Missing packaged ship-it workflow: $packageWorkflowFile"
}
if (-not (Test-Path $skillFile)) {
  throw "Missing ship-it skill file: $skillFile"
}
if (-not (Test-Path $skillEvalFile)) {
  throw "Missing ship-it skill eval file: $skillEvalFile"
}

$outputDirectory = Join-Path $repoRoot "test-results\ship-it-test"
$outputJson = Join-Path $outputDirectory "summary.json"
if (Test-Path $outputDirectory) {
  Remove-Item -Path $outputDirectory -Recurse -Force
}

& $dispatchScript `
  -Intent "onboarding-conductor" `
  -Goal "Validate onboarding conductor dispatch test path" `
  -TargetRepo "IBuySpy-Shared/basecoat" `
  -SpecRef "https://example.com/specs/ship-it-test" `
  -RiskBand "medium" `
  -Profile "team-dev" `
  -DryRun `
  -OutputPath $outputJson

if (-not (Test-Path $outputJson)) {
  throw "Dispatch summary JSON was not created: $outputJson"
}

$outputMarkdown = [System.IO.Path]::ChangeExtension($outputJson, ".md")
if (-not (Test-Path $outputMarkdown)) {
  throw "Dispatch summary Markdown was not created: $outputMarkdown"
}
$summaryMarkdown = Get-Content -Raw -Path $outputMarkdown
if ($summaryMarkdown -notmatch [regex]::Escape('- Intent: `onboarding-conductor`')) {
  throw "Summary Markdown should render the intent as a backtick code span with the expanded value."
}
if ($summaryMarkdown -match '\$\(') {
  throw "Summary Markdown must not contain literal PowerShell subexpressions (broken backtick escaping)."
}

$summary = Get-Content -Raw -Path $outputJson | ConvertFrom-Json
if ($summary.intent -ne "onboarding-conductor") {
  throw "Expected intent onboarding-conductor but found '$($summary.intent)'"
}
if (-not $summary.dry_run) {
  throw "Dry-run summary should report dry_run=true."
}
if ($summary.child_issues.Count -ne 4) {
  throw "Expected 4 child phase issues but found $($summary.child_issues.Count)"
}
if ([string]::IsNullOrWhiteSpace($summary.parent_issue_url)) {
  throw "parent_issue_url should not be empty in summary output."
}
if ($summary.profile -ne "team-dev") {
  throw "Expected profile team-dev but found '$($summary.profile)'"
}
if ($summary.desired_state_diff.Count -lt 5) {
  throw "Expected actionable desired_state_diff entries but found $($summary.desired_state_diff.Count)"
}
if ($summary.remediation_tasks.Count -lt 1) {
  throw "Expected at least one remediation task in summary output."
}
if ([string]::IsNullOrWhiteSpace($summary.release_gate_contract.workflow)) {
  throw "Expected release_gate_contract workflow to be present."
}
if ($summary.release_gate_contract.promotion_order.Count -ne 4) {
  throw "Expected staged promotion order with 4 phases."
}
if (-not $summary.release_gate_contract.required_gates_by_risk_band.high.Contains("security")) {
  throw "Expected high-risk required gates to include security."
}
if (-not $summary.release_gate_contract.artifact_matrix.high.Contains("runbook")) {
  throw "Expected high-risk artifact matrix to include runbook."
}
if (-not $summary.release_gate_contract.goal_id_linkage_requirements.Contains("release_notes_delta_mapped_to_goal_ids")) {
  throw "Expected release gate contract to require goal-ID linkage for release notes."
}
if ($summary.child_issues[0].stage_artifact.branch_name -notmatch '^intent/') {
  throw "Expected stage artifact branch_name to use intent/* naming."
}
if ([string]::IsNullOrWhiteSpace($summary.child_issues[0].stage_artifact.pr_title)) {
  throw "Expected stage artifact pr_title to be present."
}
if ($summary.child_issues[0].stage_artifact.merge_policy.sequencing -ne "serial") {
  throw "Expected merge_policy.sequencing=serial in stage artifact."
}
if ([string]::IsNullOrWhiteSpace($summary.child_issues[0].stage_artifact.cleanup_policy.workflow)) {
  throw "Expected cleanup workflow path in stage artifact."
}

$pilotOutputJson = Join-Path $outputDirectory "summary-pilot-luxesite.json"
& $dispatchScript `
  -Intent "onboarding-conductor" `
  -Goal "Validate luxesite pilot lane onboarding path" `
  -TargetRepo "IBuySpy-Shared/basecoat" `
  -SpecRef "https://example.com/specs/luxesite-pilot" `
  -RiskBand "medium" `
  -Profile "pilot-luxesite" `
  -DryRun `
  -OutputPath $pilotOutputJson

if (-not (Test-Path $pilotOutputJson)) {
  throw "Pilot dispatch summary JSON was not created: $pilotOutputJson"
}

$pilotSummary = Get-Content -Raw -Path $pilotOutputJson | ConvertFrom-Json
if ($pilotSummary.profile -ne "pilot-luxesite") {
  throw "Expected pilot profile pilot-luxesite but found '$($pilotSummary.profile)'"
}
if ($pilotSummary.child_issues.Count -ne 4) {
  throw "Expected 4 pilot child phase issues but found $($pilotSummary.child_issues.Count)"
}
if ($pilotSummary.child_issues[0].stage_artifact.execution_lane -ne "pilot-luxesite-baseline-remediation") {
  throw "Expected Discover phase lane to be pilot-luxesite-baseline-remediation but found '$($pilotSummary.child_issues[0].stage_artifact.execution_lane)'."
}
if ($pilotSummary.child_issues[3].stage_artifact.execution_lane -ne "pilot-luxesite-release-readiness") {
  throw "Expected Validate phase lane to be pilot-luxesite-release-readiness but found '$($pilotSummary.child_issues[3].stage_artifact.execution_lane)'."
}
if ($pilotSummary.release_gate_contract.lane_profiles.'pilot-luxesite'.required_artifacts.Count -lt 5) {
  throw "Expected pilot lane profile to include strict required artifact policy."
}

$workflowContent = Get-Content -Raw -Path $workflowFile
$packageWorkflowContent = Get-Content -Raw -Path $packageWorkflowFile
$skillContent = Get-Content -Raw -Path $skillFile
$outputContractPath = Join-Path $repoRoot "skills\ship-it\references\output-contract.md"
if (-not (Test-Path $outputContractPath)) {
  throw "Missing ship-it output contract reference: $outputContractPath"
}
$outputContractContent = Get-Content -Raw -Path $outputContractPath
foreach ($requiredText in @(
  'ship-it-intent-dispatch.yml',
  'stop and report',
  'never substitute'
)) {
  if ($skillContent -notmatch [regex]::Escape($requiredText)) {
    throw "Ship-it skill must fail closed and require observable execution evidence: $requiredText"
  }
}
foreach ($requiredText in @(
  'do not substitute `/approve`',
  'do not report success',
  'observable workflow run IDs'
)) {
  if ($outputContractContent -notmatch [regex]::Escape($requiredText)) {
    throw "Ship-it output contract reference must document fail-closed evidence requirements: $requiredText"
  }
}
if ($workflowContent -notmatch "workflow_dispatch:") {
  throw "Ship-it workflow must include workflow_dispatch trigger."
}
if ($workflowContent -notmatch "issue_comment:") {
  throw "Ship-it workflow must include issue_comment trigger."
}
if ($workflowContent -notmatch "/ship-it") {
  throw "Ship-it workflow must detect /ship-it comment command."
}
if ($workflowContent -notmatch "/onboarding") {
  throw "Ship-it workflow must detect /onboarding comment command."
}
if ($workflowContent -notmatch "onboarding-conductor") {
  throw "Ship-it workflow must expose onboarding-conductor intent option."
}
if ($workflowContent -notmatch "profile:") {
  throw "Ship-it workflow must include profile input for onboarding-conductor intent."
}
if ($workflowContent -notmatch "pilot-luxesite") {
  throw "Ship-it workflow must expose pilot-luxesite profile option."
}
if ($workflowContent -notmatch "pilot-wawkr") {
  throw "Ship-it workflow must expose pilot-wawkr profile option."
}
if ($workflowContent -notmatch "pilot-work-tracker") {
  throw "Ship-it workflow must expose pilot-work-tracker profile option."
}
if ($workflowContent -notmatch "/spec-2-prod") {
  throw "Ship-it workflow must detect /spec-2-prod comment command."
}
if ($workflowContent -notmatch '"spec-2-prod":\s*"spec-2-prod"' -or
  $workflowContent -notmatch 'deliveryDirective\.intent') {
  throw "Ship-it workflow must map spec-2-prod to its canonical intent in the resolver."
}
foreach ($workflow in @($workflowContent, $packageWorkflowContent)) {
  foreach ($requiredText in @(
    'source_issue_number:',
    'approval_comment_id:',
    'approval_receipt_base64:',
    'preapproval.resolvePreApproval',
    'workflowRun.created_at',
    'if (approvalCommentId !== "")',
    'Pre-approval mode requires both source_issue_number and approval_comment_id.',
    'APPROVAL_RECEIPT_BASE64',
    "needs.resolve-intent.outputs.approval_comment_id == ''"
  )) {
    if ($workflow -notmatch [regex]::Escape($requiredText)) {
      throw "Both ship-it workflow surfaces must enforce the explicit pre-approval contract: $requiredText"
    }
  }
  if ($workflow -match 'if \(sourceIssueNumber !== "" \|\| approvalCommentId !== ""\)') {
    throw "A delivery source issue without an approval comment must not activate pre-approval mode."
  }
  if ($workflow -notmatch 'result\.should_run = "true";\s*result\.dry_run = "false";\s*result\.intent = deliveryDirective\.kind === "delivery"') {
    throw "Accepted issue_comment intent directives must override the resolver default and run live."
  }
}

$wawkrOutputJson = Join-Path $outputDirectory "summary-pilot-wawkr.json"
& $dispatchScript `
  -Intent "onboarding-conductor" `
  -Goal "Validate wawkr canary lane onboarding path" `
  -TargetRepo "IBuySpy-Shared/basecoat" `
  -SpecRef "https://example.com/specs/wawkr-canary" `
  -RiskBand "medium" `
  -Profile "pilot-wawkr" `
  -DryRun `
  -OutputPath $wawkrOutputJson

if (-not (Test-Path $wawkrOutputJson)) {
  throw "Wawkr dispatch summary JSON was not created: $wawkrOutputJson"
}

$wawkrSummary = Get-Content -Raw -Path $wawkrOutputJson | ConvertFrom-Json
if ($wawkrSummary.profile -ne "pilot-wawkr") {
  throw "Expected wawkr profile pilot-wawkr but found '$($wawkrSummary.profile)'"
}
if ($wawkrSummary.child_issues.Count -ne 4) {
  throw "Expected 4 wawkr child phase issues but found $($wawkrSummary.child_issues.Count)"
}
if ($wawkrSummary.child_issues[0].stage_artifact.execution_lane -ne "pilot-wawkr-canary-baseline") {
  throw "Expected Discover phase lane to be pilot-wawkr-canary-baseline but found '$($wawkrSummary.child_issues[0].stage_artifact.execution_lane)'."
}
if ($wawkrSummary.child_issues[3].stage_artifact.execution_lane -ne "pilot-wawkr-canary-validation") {
  throw "Expected Validate phase lane to be pilot-wawkr-canary-validation but found '$($wawkrSummary.child_issues[3].stage_artifact.execution_lane)'."
}
if ($wawkrSummary.release_gate_contract.lane_profiles.'pilot-wawkr'.required_artifacts.Count -lt 5) {
  throw "Expected wawkr lane profile to include strict required artifact policy."
}

$workTrackerOutputJson = Join-Path $outputDirectory "summary-pilot-work-tracker.json"
& $dispatchScript `
  -Intent "onboarding-conductor" `
  -Goal "Validate work-tracker lane-aware onboarding path" `
  -TargetRepo "IBuySpy-Shared/basecoat" `
  -SpecRef "https://example.com/specs/work-tracker-lane-aware" `
  -RiskBand "medium" `
  -Profile "pilot-work-tracker" `
  -DryRun `
  -OutputPath $workTrackerOutputJson

if (-not (Test-Path $workTrackerOutputJson)) {
  throw "Work-tracker dispatch summary JSON was not created: $workTrackerOutputJson"
}

$workTrackerSummary = Get-Content -Raw -Path $workTrackerOutputJson | ConvertFrom-Json
if ($workTrackerSummary.profile -ne "pilot-work-tracker") {
  throw "Expected work-tracker profile pilot-work-tracker but found '$($workTrackerSummary.profile)'"
}
if ($workTrackerSummary.child_issues.Count -ne 4) {
  throw "Expected 4 work-tracker child phase issues but found $($workTrackerSummary.child_issues.Count)"
}
if ($workTrackerSummary.child_issues[0].stage_artifact.execution_lane -ne "pilot-work-tracker-baseline") {
  throw "Expected Discover phase lane to be pilot-work-tracker-baseline but found '$($workTrackerSummary.child_issues[0].stage_artifact.execution_lane)'."
}
if ($workTrackerSummary.child_issues[3].stage_artifact.execution_lane -ne "pilot-work-tracker-validation") {
  throw "Expected Validate phase lane to be pilot-work-tracker-validation but found '$($workTrackerSummary.child_issues[3].stage_artifact.execution_lane)'."
}
if ($workTrackerSummary.release_gate_contract.lane_profiles.'pilot-work-tracker'.required_artifacts.Count -lt 5) {
  throw "Expected work-tracker lane profile to include strict required artifact policy."
}

$dispatchScriptContent = Get-Content -Raw -Path $dispatchScript
$packageDispatchScriptContent = Get-Content -Raw -Path $packageDispatchScript
if ($dispatchScriptContent -notmatch 'return\s+,\$issues') {
  throw "Get-OpenIntentIssues must return a wrapped array so empty issue sets do not collapse to null."
}
if ($dispatchScriptContent -notmatch '\[array\]\$Issues\s*=\s*@\(\)') {
  throw "Find-ExistingIssueByMarker must accept empty issue collections without mandatory-array binding failures."
}
foreach ($scriptContent in @($dispatchScriptContent, $packageDispatchScriptContent)) {
  foreach ($requiredText in @(
    'Assert-PreApprovalCurrent',
    'source_approval_receipt',
    'source_approval_receipt_base64',
    'basecoat-preapproval-receipt:v1',
    'ProjectOwner and ProjectNumber',
    'runKey += "|preapproval:'
  )) {
    if ($scriptContent -notmatch [regex]::Escape($requiredText)) {
      throw "Both ship-it dispatch scripts must preserve and revalidate pre-approval evidence: $requiredText"
    }
  }
  if ($scriptContent -match 'commonLabels\s*=\s*@\([^)]*"approved"') {
    throw "Dispatch scripts must never copy the approved label onto generated issues."
  }
}

$shipItOutputJson = Join-Path $outputDirectory "summary-ship-it.json"
& $dispatchScript `
  -Intent "ship-it" `
  -Goal "Validate ship-it dispatch path" `
  -TargetRepo "IBuySpy-Shared/basecoat" `
  -SpecRef "https://example.com/specs/ship-it" `
  -RiskBand "medium" `
  -DryRun `
  -OutputPath $shipItOutputJson

if (-not (Test-Path $shipItOutputJson)) {
  throw "Ship-it dispatch summary JSON was not created: $shipItOutputJson"
}

$shipItSummary = Get-Content -Raw -Path $shipItOutputJson | ConvertFrom-Json
if ($shipItSummary.intent -ne "ship-it") {
  throw "Expected intent ship-it but found '$($shipItSummary.intent)'"
}
if (-not $shipItSummary.dry_run) {
  throw "Dry-run summary should report dry_run=true."
}
if ($shipItSummary.child_issues.Count -ne 3) {
  throw "Expected 3 child sprint issues for ship-it but found $($shipItSummary.child_issues.Count)"
}
if (-not $shipItSummary.child_issues[0].stage_artifact.merge_policy.sync_with_latest_main) {
  throw "Expected Sprint 1 merge policy to require latest-main sync."
}
if ($shipItSummary.child_issues[0].stage_artifact.merge_policy.wait_for_previous_stage) {
  throw "Sprint 1 should not wait for a previous stage."
}
if (-not $shipItSummary.child_issues[1].stage_artifact.merge_policy.wait_for_previous_stage) {
  throw "Sprint 2 should wait for the previous stage to close."
}
if ($shipItSummary.child_issues[1].stage_artifact.previous_stage_issue_url -ne $shipItSummary.child_issues[0].url) {
  throw "Sprint 2 should reference Sprint 1 as its previous stage issue."
}
if ($shipItSummary.child_issues[2].stage_artifact.previous_stage_issue_url -ne $shipItSummary.child_issues[1].url) {
  throw "Sprint 3 should reference Sprint 2 as its previous stage issue."
}
if ($shipItSummary.child_issues[2].stage_artifact.merge_policy.required_checks -notcontains "BaseCoat - Ship-it Release Gate / Evaluate Ship-it Release Gate") {
  throw "Expected Sprint 3 merge policy to require the BaseCoat Ship-it Release Gate."
}
if ($shipItSummary.child_issues[0].stage_artifact.branch_name -notmatch '^intent/ship-it/') {
  throw "Expected stage artifact branch to use intent/ship-it/* naming."
}
if ([string]::IsNullOrWhiteSpace($shipItSummary.release_gate_contract.workflow)) {
  throw "Expected release_gate_contract workflow to be present for ship-it."
}

$provenanceOutputJson = Join-Path $outputDirectory "summary-feature-provenance.json"
& $dispatchScript `
  -Intent "ship-it" `
  -Goal "Deliver approved feature scope" `
  -TargetRepo "IBuySpy-Shared/basecoat" `
  -SpecRef "https://example.com/specs/feature" `
  -RiskBand "medium" `
  -SourceIssueNumber "3477" `
  -SourceIssueUrl "https://github.com/IBuySpy-Shared/basecoat/issues/3477" `
  -SourceScope "Implement approved feature scope only" `
  -FeatureOrigin $true `
  -RawDirective "SHIP-IT: Deliver approved feature scope" `
  -DirectiveSource "issue_comment:colon-alias" `
  -DirectiveActor "maintainer" `
  -DirectiveEvidenceUrl "https://github.com/IBuySpy-Shared/basecoat/issues/3477#issuecomment-1" `
  -DirectiveTimestamp "2026-10-04T00:00:00Z" `
  -DryRun `
  -OutputPath $provenanceOutputJson

$provenanceSummary = Get-Content -Raw -Path $provenanceOutputJson | ConvertFrom-Json
if ($provenanceSummary.source_issue_number -ne "3477" -or
  $provenanceSummary.source_issue_url -notmatch '/issues/3477$' -or
  -not $provenanceSummary.feature_origin -or
  $provenanceSummary.source_scope -ne "Implement approved feature scope only" -or
  $provenanceSummary.directive_provenance.raw_directive -ne "SHIP-IT: Deliver approved feature scope" -or
  $provenanceSummary.directive_provenance.normalized_intent -ne "ship-it" -or
  $provenanceSummary.directive_provenance.original_actor -ne "maintainer" -or
  $provenanceSummary.directive_provenance.evidence_url -notmatch 'issuecomment-1') {
  throw "Dispatch summary did not preserve source issue, approved scope, and directive provenance."
}

$packagedWorkflow = Join-Path $repoRoot ".github\base-coat\workflows\ship-it-intent-dispatch.yml"
$packagedDispatchScript = Join-Path $repoRoot ".github\base-coat\scripts\ship-it\dispatch-intent.ps1"
$packagedIssueApproval = Join-Path $repoRoot ".github\base-coat\workflows\issue-approve.yml"
$directiveContracts = @()
foreach ($path in @($workflowFile, $packagedWorkflow)) {
  $content = Get-Content -Raw -Path $path
  $contractMatch = [regex]::Match(
    $content,
    '(?s)// BEGIN SHIP-IT DIRECTIVE CONTRACT\r?\n(?<contract>.*?)\r?\n\s*// END SHIP-IT DIRECTIVE CONTRACT'
  )
  if (-not $contractMatch.Success) {
    throw "$path is missing the tested ship-it directive contract."
  }
  $directiveContracts += $contractMatch.Groups["contract"].Value
  foreach ($required in @(
    'source_issue_number',
    'approved',
    'qualified exact /approve evidence',
    'isCanonicalWorkflowIntent',
    'workflow_dispatch'
  )) {
    if ($content -notmatch [regex]::Escape($required)) {
      throw "$path is missing delivery gate contract text: $required"
    }
  }
}
if ($directiveContracts[0] -ne $directiveContracts[1]) {
  throw "Canonical and packaged dispatch workflows must share the same tested directive normalizer."
}
$packagedDispatchContent = Get-Content -Raw -Path $packagedDispatchScript
if ($packagedDispatchContent -notmatch 'directive_provenance' -or
  $packagedDispatchContent -notmatch 'SourceScope' -or
  $packagedDispatchContent -notmatch '\[switch\]\$AllowCrossRepository' -or
  $packagedDispatchContent -notmatch 'validate-target-repository\.ps1') {
  throw "Packaged dispatch script must preserve provenance, source scope, and cross-repository authorization."
}

$rejectedCrossRepoOutput = Join-Path $outputDirectory "summary-cross-repository-rejected.json"
$crossRepoRejected = $false
try {
  & $packagedDispatchScript `
    -Intent "onboarding-conductor" `
    -Goal "Validate packaged cross-repository authorization" `
    -TargetRepo "IBuySpy-Shared/dispatch-test-target" `
    -DryRun `
    -OutputPath $rejectedCrossRepoOutput | Out-Null
} catch {
  $crossRepoRejected = $_.Exception.Message -match "Cross-repository dispatch requires explicit"
}
if (-not $crossRepoRejected) {
  throw "Packaged dispatch must reject cross-repository targets without explicit authorization."
}
if (Test-Path $rejectedCrossRepoOutput) {
  throw "Rejected packaged cross-repository dispatch must not create a summary."
}

$allowedCrossRepoOutput = Join-Path $outputDirectory "summary-cross-repository-allowed.json"
& $packagedDispatchScript `
  -Intent "onboarding-conductor" `
  -Goal "Validate packaged cross-repository authorization" `
  -TargetRepo "IBuySpy-Shared/dispatch-test-target" `
  -AllowCrossRepository `
  -DryRun `
  -OutputPath $allowedCrossRepoOutput | Out-Null
$allowedCrossRepoSummary = Get-Content -Raw -Path $allowedCrossRepoOutput | ConvertFrom-Json
if (-not $allowedCrossRepoSummary.dry_run -or
  $allowedCrossRepoSummary.target_repo -ne "IBuySpy-Shared/dispatch-test-target") {
  throw "Explicitly authorized packaged cross-repository dry-run did not complete successfully."
}

$remoteNormalizationDirectory = Join-Path $outputDirectory "remote-normalization-test"
New-Item -ItemType Directory -Force -Path $remoteNormalizationDirectory | Out-Null
try {
  & git -C $remoteNormalizationDirectory init --quiet
  if ($LASTEXITCODE -ne 0) { throw "Unable to initialize repository URL normalization fixture." }
  Push-Location $remoteNormalizationDirectory
  try {
    & git remote add origin "ssh://git@github.com/IBuySpy-Shared/basecoat.git"
    if ($LASTEXITCODE -ne 0) { throw "Unable to configure repository URL normalization fixture." }
    $remoteUrls = @(
      "ssh://git@github.com/IBuySpy-Shared/basecoat.git",
      "git@github.com:IBuySpy-Shared/basecoat.git"
    )
    $validators = @(
      (Join-Path $repoRoot "scripts\ship-it\validate-target-repository.ps1"),
      $packageTargetRepositoryValidator
    )
    foreach ($validator in $validators) {
      foreach ($remoteUrl in $remoteUrls) {
        & git remote set-url origin $remoteUrl
        if ($LASTEXITCODE -ne 0) { throw "Unable to configure repository URL normalization fixture." }
        & $validator -TargetRepo "IBuySpy-Shared/basecoat" | Out-Null
      }
    }
  } finally {
    Pop-Location
  }
} finally {
  Remove-Item -LiteralPath $remoteNormalizationDirectory -Recurse -Force
}

if ((Get-Content -Raw -Path $packagedIssueApproval) -match "contains\(github\.event\.comment\.body,\s*'/spec-2-prod'\)") {
  throw "Packaged issue-approve workflow must not own /spec-2-prod dispatch."
}

$directiveContract = $directiveContracts[0]
$parserHarness = @"
const assert = require('node:assert/strict');
const approval = require('../../.github/base-coat/scripts/approval-contract.cjs');
$directiveContract
const cases = [
  { raw: 'ship-it: Release X', kind: 'delivery', intent: 'ship-it', goal: 'Release X' },
  { raw: ' \n SHIP-IT:  Keep   this goal  \n', kind: 'delivery', intent: 'ship-it', goal: 'Keep   this goal' },
  { raw: 'spec-2-prod: Ship spec Y', kind: 'delivery', intent: 'spec-2-prod', goal: 'Ship spec Y' },
  { raw: '/ship-it', kind: 'delivery', intent: 'ship-it', goal: '' },
  { raw: '/spec-2-prod Release Y', kind: 'delivery', intent: 'spec-2-prod', goal: 'Release Y' },
  { raw: 'ship-it:', kind: 'invalid' },
  { raw: 'ship-it-extra: Release X', kind: 'none' },
  { raw: '- ship-it: Release X', kind: 'none' },
  { raw: '> ship-it: Release X', kind: 'none' },
  { raw: '```text\nship-it: Release X\n```', kind: 'invalid' },
  { raw: 'We discussed ship-it: Release X', kind: 'none' },
  { raw: 'feature: ship-it: Release X', kind: 'none' },
  { raw: 'ship-it: Release X\nspec-2-prod: Release Y', kind: 'invalid' },
  { raw: 'ship-it: Release X\nship-it: Release Y', kind: 'invalid' },
  { raw: 'ship-it: Release X\nlater and now', kind: 'invalid' },
  { raw: 'ship-it: Review release X read-only', kind: 'suppressed' },
  { raw: 'spec-2-prod: Release X later', kind: 'suppressed' }
];
for (const test of cases) {
  const actual = parseDeliveryDirective(test.raw);
  assert.equal(actual.kind, test.kind, JSON.stringify(test));
  if (test.intent) {
    assert.equal(actual.intent, test.intent, JSON.stringify(test));
    assert.equal(actual.goal, test.goal, JSON.stringify(test));
  }
  if (test.kind === 'delivery') assert.equal(actual.rawDirective, test.raw);
}
assert.equal(isCanonicalWorkflowIntent('ship-it'), true);
assert.equal(isCanonicalWorkflowIntent('spec-2-prod'), true);
assert.equal(isCanonicalWorkflowIntent('onboarding-conductor'), true);
assert.equal(isCanonicalWorkflowIntent('SHIP-IT'), false);
assert.equal(isCanonicalWorkflowIntent('ship-it: Release X'), false);
assert.equal(classifyDeliveryGoal('Release X read-only'), 'suppressed');
assert.equal(classifyDeliveryGoal('Release X later and now'), 'invalid');
assert.equal(classifyDeliveryGoal('Release X now'), 'delivery');
assert.equal(isPlaceholderSpecUrl('https://example.com/specs/feature'), true);
assert.equal(isPlaceholderSpecUrl('https://github.com/IBuySpy-Shared/basecoat/blob/main/docs/spec/approved.md'), false);
"@
$parserHarnessPath = Join-Path $outputDirectory "directive-contract.cjs"
Set-Content -Path $parserHarnessPath -Value $parserHarness -Encoding UTF8
& node $parserHarnessPath
if ($LASTEXITCODE -ne 0) {
  throw "Ship-it directive parser behavior tests failed."
}

Write-Host "Ship-it dispatch tests passed."
