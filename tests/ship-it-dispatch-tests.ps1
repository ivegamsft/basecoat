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

Write-Host "Ship-it dispatch tests passed."
