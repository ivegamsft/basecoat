[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$detectorScript = Join-Path $repoRoot "scripts\ship-it\build-break-detector.ps1"
$workflowFile = Join-Path $repoRoot ".github\workflows\ship-it-build-guard.yml"

if (-not (Test-Path $detectorScript)) {
  throw "Missing build-break detector script: $detectorScript"
}
if (-not (Test-Path $workflowFile)) {
  throw "Missing build guard workflow: $workflowFile"
}

$outputDirectory = Join-Path $repoRoot "test-results\ship-it-build-break-test"
if (Test-Path $outputDirectory) {
  Remove-Item -Path $outputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

function Invoke-Scenario {
  param(
    [Parameter(Mandatory)]
    [string]$Name,
    [Parameter(Mandatory)]
    [array]$Runs,
    [Parameter(Mandatory)]
    [string]$ExpectedAction,
    [Parameter(Mandatory)]
    [string]$ExpectedReason,
    [string]$ExpectedClassifier = "",
    [int]$CurrentRetryCount = 0,
    [int]$MaxAutoRetries = 2
  )

  $runsPath = Join-Path $outputDirectory "$Name-runs.json"
  $summaryPath = Join-Path $outputDirectory "$Name-summary.json"
  $Runs | ConvertTo-Json -Depth 8 | Set-Content -Path $runsPath -Encoding utf8

  & $detectorScript `
    -TargetRepo "IBuySpy-Shared/basecoat" `
    -TargetBranch "intent/ship-it/demo" `
    -WorkflowName "BaseCoat - PR Validation" `
    -FailureInputPath $runsPath `
    -CurrentRetryCount $CurrentRetryCount `
    -MaxAutoRetries $MaxAutoRetries `
    -DryRun `
    -OutputPath $summaryPath

  if (-not (Test-Path $summaryPath)) {
    throw "Scenario '$Name' did not create summary JSON."
  }

  $summary = Get-Content -Raw -Path $summaryPath | ConvertFrom-Json
  if ($summary.action -ne $ExpectedAction) {
    throw "Scenario '$Name' expected action '$ExpectedAction' but found '$($summary.action)'."
  }
  if ($summary.reason -ne $ExpectedReason) {
    throw "Scenario '$Name' expected reason '$ExpectedReason' but found '$($summary.reason)'."
  }
  if ($ExpectedClassifier -and $summary.classifier.category -ne $ExpectedClassifier) {
    throw "Scenario '$Name' expected classifier '$ExpectedClassifier' but found '$($summary.classifier.category)'."
  }

  $markdownPath = [System.IO.Path]::ChangeExtension($summaryPath, ".md")
  if (-not (Test-Path $markdownPath)) {
    throw "Scenario '$Name' did not create markdown summary."
  }
}

$now = (Get-Date).ToUniversalTime()
function New-Run {
  param(
    [long]$RunId,
    [string]$Conclusion,
    [int]$MinutesAgo,
    [string]$LogExcerpt
  )

  return [ordered]@{
    databaseId = $RunId
    workflowName = "BaseCoat - PR Validation"
    headBranch = "intent/ship-it/demo"
    conclusion = $Conclusion
    createdAt = $now.AddMinutes(-1 * $MinutesAgo).ToString("yyyy-MM-ddTHH:mm:ssZ")
    url = "https://github.com/IBuySpy-Shared/basecoat/actions/runs/$RunId"
    log_excerpt = $LogExcerpt
  }
}

Invoke-Scenario `
  -Name "recoverable-retry" `
  -Runs @(
    (New-Run -RunId 1001 -Conclusion "failure" -MinutesAgo 1 -LogExcerpt "Build timed out with ECONNRESET during dependency download"),
    (New-Run -RunId 1000 -Conclusion "success" -MinutesAgo 10 -LogExcerpt "")
  ) `
  -ExpectedAction "retry" `
  -ExpectedReason "recoverable-transient-infra" `
  -CurrentRetryCount 0 `
  -MaxAutoRetries 2

Invoke-Scenario `
  -Name "nonrecoverable-escalate" `
  -Runs @(
    (New-Run -RunId 1002 -Conclusion "failure" -MinutesAgo 1 -LogExcerpt "Compilation failed: error CS1002 ; expected")
  ) `
  -ExpectedAction "escalate" `
  -ExpectedReason "nonrecoverable-compile-error" `
  -CurrentRetryCount 0 `
  -MaxAutoRetries 2

Invoke-Scenario `
  -Name "retry-exhausted-escalate" `
  -Runs @(
    (New-Run -RunId 1003 -Conclusion "failure" -MinutesAgo 1 -LogExcerpt "Temporary failure: timed out while contacting package feed")
  ) `
  -ExpectedAction "escalate" `
  -ExpectedReason "retry-exhausted-transient-infra" `
  -CurrentRetryCount 2 `
  -MaxAutoRetries 2

Invoke-Scenario `
  -Name "no-failures-clear" `
  -Runs @(
    (New-Run -RunId 1004 -Conclusion "success" -MinutesAgo 1 -LogExcerpt ""),
    (New-Run -RunId 1005 -Conclusion "neutral" -MinutesAgo 2 -LogExcerpt ""),
    (New-Run -RunId 1006 -Conclusion "cancelled" -MinutesAgo 3 -LogExcerpt "")
  ) `
  -ExpectedAction "no_action" `
  -ExpectedReason "no-failures-detected"

Invoke-Scenario `
  -Name "failure-with-missing-log" `
  -Runs @(
    (New-Run -RunId 1007 -Conclusion "failure" -MinutesAgo 1 -LogExcerpt "")
  ) `
  -ExpectedAction "escalate" `
  -ExpectedReason "nonrecoverable-unknown" `
  -ExpectedClassifier "unknown"

function gh {
  if ($args -contains "--json") {
    $global:LASTEXITCODE = 0
    return '{"databaseId":1008,"workflowName":"BaseCoat - PR Validation","headBranch":"intent/ship-it/demo","conclusion":"failure","createdAt":"2026-10-06T12:00:00Z","url":"https://github.com/IBuySpy-Shared/basecoat/actions/runs/1008"}'
  }

  $global:LASTEXITCODE = 1
  return "workflow log service unavailable"
}

$logApiFailureVisible = $false
try {
  & $detectorScript `
    -TargetRepo "IBuySpy-Shared/basecoat" `
    -SourceRunId 1008 `
    -DryRun `
    -OutputPath (Join-Path $outputDirectory "missing-log-api-summary.json")
} catch {
  $logApiFailureVisible = $_.Exception.Message -match "gh command failed: gh run view 1008 .*--log"
} finally {
  Remove-Item Function:\gh -ErrorAction SilentlyContinue
}
if (-not $logApiFailureVisible) {
  throw "A failed log API lookup must fail visibly instead of producing a success-shaped summary."
}

$workflowContent = Get-Content -Raw -Path $workflowFile
if ($workflowContent -notmatch "workflow_run:") {
  throw "Build guard workflow must include workflow_run trigger."
}
if ($workflowContent -notmatch "workflow_dispatch:") {
  throw "Build guard workflow must include workflow_dispatch trigger."
}
if ($workflowContent -notmatch "(?m)^\s+if: github\.event_name == 'workflow_dispatch' \|\| \(github\.event_name == 'workflow_run' && github\.event\.workflow_run\.conclusion == 'failure'\)\s*$") {
  throw "Build guard resolver must filter successful and cancelled completions before runner allocation while preserving manual dispatch and failure recovery."
}
if ($workflowContent -notmatch "ship-it-build-summary.json|build-break-summary.json") {
  throw "Build guard workflow should emit build-break summary artifacts."
}
if ($workflowContent -notmatch '\$\{\{ needs\.resolve-inputs\.outputs\.target_repo == github\.repository && github\.token \|\| secrets\.SHIP_IT_CROSS_REPO_TOKEN \}\}') {
  throw "Build guard workflow must use github.token for same-repository targets and SHIP_IT_CROSS_REPO_TOKEN only for cross-repository targets."
}
if ($workflowContent -notmatch "HAS_CROSS_REPO_TOKEN: \$\{\{ secrets\.SHIP_IT_CROSS_REPO_TOKEN != '' \}\}") {
  throw "Build guard workflow must expose whether SHIP_IT_CROSS_REPO_TOKEN is configured."
}
if ($workflowContent -notmatch '\$targetRepo -ne \$hostRepo -and -not \$hasCrossRepoToken') {
  throw "Build guard workflow must fail fast when a cross-repository target lacks a cross-repo token."
}
if ($workflowContent -notmatch 'github\.token is scoped to \$hostRepo only') {
  throw "Build guard workflow must explain why github.token cannot be used for cross-repository targets."
}

$detectorContent = Get-Content -Raw -Path $detectorScript
if ($detectorContent -notmatch '\[AllowEmptyCollection\(\)\]\s*\r?\n\s*\[array\]\$FailureTrend') {
  throw "Build-break detector escalation must allow empty FailureTrend collections."
}

Write-Host "Ship-it build-break detector tests passed."
