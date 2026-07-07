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
    url = "https://github.com/ivegamsft/basecoat/actions/runs/$RunId"
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
    (New-Run -RunId 1005 -Conclusion "neutral" -MinutesAgo 2 -LogExcerpt "")
  ) `
  -ExpectedAction "no_action" `
  -ExpectedReason "no-failures-detected"

$workflowContent = Get-Content -Raw -Path $workflowFile
if ($workflowContent -notmatch "workflow_run:") {
  throw "Build guard workflow must include workflow_run trigger."
}
if ($workflowContent -notmatch "workflow_dispatch:") {
  throw "Build guard workflow must include workflow_dispatch trigger."
}
if ($workflowContent -notmatch "ship-it-build-summary.json|build-break-summary.json") {
  throw "Build guard workflow should emit build-break summary artifacts."
}

Write-Host "Ship-it build-break detector tests passed."
