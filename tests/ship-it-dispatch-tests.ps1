[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$dispatchScript = Join-Path $repoRoot "scripts\ship-it\dispatch-intent.ps1"
$workflowFile = Join-Path $repoRoot ".github\workflows\ship-it-intent-dispatch.yml"
$skillFile = Join-Path $repoRoot "skills\ship-it\SKILL.md"
$skillEvalFile = Join-Path $repoRoot "skills\ship-it\eval.yaml"

if (-not (Test-Path $dispatchScript)) {
  throw "Missing ship-it dispatch script: $dispatchScript"
}
if (-not (Test-Path $workflowFile)) {
  throw "Missing ship-it workflow: $workflowFile"
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

Write-Host "Ship-it dispatch tests passed."
