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
  -Intent "ship-it" `
  -Goal "Validate ship-it dispatch test path" `
  -TargetRepo "IBuySpy-Shared/basecoat" `
  -SpecRef "https://example.com/specs/ship-it-test" `
  -RiskBand "medium" `
  -DryRun `
  -OutputPath $outputJson

if (-not (Test-Path $outputJson)) {
  throw "Dispatch summary JSON was not created: $outputJson"
}

$summary = Get-Content -Raw -Path $outputJson | ConvertFrom-Json
if ($summary.intent -ne "ship-it") {
  throw "Expected intent ship-it but found '$($summary.intent)'"
}
if (-not $summary.dry_run) {
  throw "Dry-run summary should report dry_run=true."
}
if ($summary.child_issues.Count -ne 3) {
  throw "Expected 3 child sprint issues but found $($summary.child_issues.Count)"
}
if ([string]::IsNullOrWhiteSpace($summary.parent_issue_url)) {
  throw "parent_issue_url should not be empty in summary output."
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

Write-Host "Ship-it dispatch tests passed."
