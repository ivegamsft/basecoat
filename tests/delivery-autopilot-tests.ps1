[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$agentPath = Join-Path $repoRoot "agents\basecoat-60-workflow-delivery-autopilot.agent.md"
$agentEvalPath = Join-Path $repoRoot "agents\basecoat-60-workflow-delivery-autopilot.agent.eval.yaml"
$skillPath = Join-Path $repoRoot "skills\delivery-autopilot\SKILL.md"
$skillEvalPath = Join-Path $repoRoot "skills\delivery-autopilot\eval.yaml"
$statusScript = Join-Path $repoRoot "scripts\delivery-autopilot\evaluate-status.ps1"
$mergeScript = Join-Path $repoRoot "scripts\delivery-autopilot\execute-merge.ps1"
$escalationScript = Join-Path $repoRoot "scripts\delivery-autopilot\build-escalation-payload.ps1"
$docPath = Join-Path $repoRoot "docs\guides\delivery-autopilot-integration.md"
$workflowsGuidePath = Join-Path $repoRoot "docs\guides\workflows-getting-started.md"

foreach ($path in @($agentPath, $agentEvalPath, $skillPath, $skillEvalPath, $statusScript, $mergeScript, $escalationScript, $docPath, $workflowsGuidePath)) {
  if (-not (Test-Path $path)) {
    throw "Missing required delivery-autopilot asset: $path"
  }
}

$temp = Join-Path $repoRoot "test-results\delivery-autopilot-test"
if (Test-Path $temp) {
  Remove-Item -Path $temp -Recurse -Force
}
New-Item -ItemType Directory -Path $temp -Force | Out-Null

$statusOut = Join-Path $temp "status.json"
$mergeOut = Join-Path $temp "merge.json"
$escalationOut = Join-Path $temp "escalation.json"

& $statusScript -Repo "IBuySpy-Shared/basecoat" -IssueNumber 2294 -DryRun -OutputPath $statusOut
if ($LASTEXITCODE -ne 0) {
  throw "evaluate-status.ps1 dry-run failed."
}

& $mergeScript -Repo "IBuySpy-Shared/basecoat" -PullRequestNumber 2299 -DryRun -OutputPath $mergeOut
if ($LASTEXITCODE -ne 0) {
  throw "execute-merge.ps1 dry-run failed."
}

& $escalationScript `
  -Repo "IBuySpy-Shared/basecoat" `
  -Stage "ready_to_merge" `
  -EntityType "pr" `
  -EntityNumber 2299 `
  -Owner "ibuyspy" `
  -EvidenceUrl "https://github.com/IBuySpy-Shared/basecoat/pull/2299" `
  -NextAction "Merge after required checks complete." `
  -DryRun `
  -OutputPath $escalationOut
if ($LASTEXITCODE -ne 0) {
  throw "build-escalation-payload.ps1 dry-run failed."
}

$status = Get-Content -Raw -Path $statusOut | ConvertFrom-Json
$merge = Get-Content -Raw -Path $mergeOut | ConvertFrom-Json
$escalation = Get-Content -Raw -Path $escalationOut | ConvertFrom-Json

if ($status.mode -ne "dry-run" -or $status.generated_at -ne "dry-run-static") {
  throw "evaluate-status.ps1 must emit deterministic dry-run metadata."
}
if ($merge.mode -ne "dry-run" -or $merge.generated_at -ne "dry-run-static") {
  throw "execute-merge.ps1 must emit deterministic dry-run metadata."
}
if ($escalation.mode -ne "dry-run" -or $escalation.generated_at -ne "dry-run-static") {
  throw "build-escalation-payload.ps1 must emit deterministic dry-run metadata."
}
if (-not $escalation.fingerprint -or $escalation.fingerprint -notmatch '^ready_to_merge:pr:2299$') {
  throw "Escalation payload fingerprint is missing or invalid."
}
if (-not ($escalation.labels -contains "remediation") -or -not ($escalation.labels -contains "escalated")) {
  throw "Escalation payload must include remediation/escalated labels."
}

$doc = Get-Content -Raw -Path $docPath
if ($doc -notmatch 'pr-auto-merge-executor\.yml') {
  throw "Integration guide must reference pr-auto-merge-executor.yml."
}
if ($doc -notmatch 'post-merge-release-chain\.yml') {
  throw "Integration guide must reference post-merge-release-chain.yml."
}
if ($doc -notmatch 'automation-stuck-state-watchdog\.yml') {
  throw "Integration guide must reference automation-stuck-state-watchdog.yml."
}

$workflowsGuide = Get-Content -Raw -Path $workflowsGuidePath
if ($workflowsGuide -notmatch 'basecoat-pr-auto-merge-executor\.yml') {
  throw "Workflow getting-started guide must list basecoat-pr-auto-merge-executor.yml."
}
if ($workflowsGuide -notmatch 'policy-packs\.json') {
  throw "Workflow getting-started guide must mention policy-packs.json for template installs."
}
if ($workflowsGuide -notmatch 'human-approval-boundaries\.json') {
  throw "Workflow getting-started guide must mention human-approval-boundaries.json for template installs."
}

$installer = Get-Content -Raw -Path (Join-Path $repoRoot 'scripts\configure-downstream-workflows.ps1')
if ($installer -notmatch 'pr-auto-merge-executor\.yml') {
  throw "Downstream workflow installer must register pr-auto-merge-executor.yml."
}
if ($installer -notmatch 'basecoat-pr-auto-merge-executor\.yml') {
  throw "Downstream workflow installer must map pr-auto-merge-executor.yml to basecoat-pr-auto-merge-executor.yml."
}
if ($installer -notmatch 'policy-packs\.json') {
  throw "Downstream workflow installer must copy policy-packs.json when template workflows are included."
}
if ($installer -notmatch 'human-approval-boundaries\.json') {
  throw "Downstream workflow installer must copy human-approval-boundaries.json when template workflows are included."
}

Write-Host "Delivery-autopilot tests passed."
