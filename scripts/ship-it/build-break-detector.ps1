[CmdletBinding()]
param(
  [string]$TargetRepo = $env:GITHUB_REPOSITORY,

  [string]$TargetBranch = "",

  [string]$WorkflowName = "",

  [int]$MaxRuns = 20,

  [int]$MaxAutoRetries = 2,

  [int]$CurrentRetryCount = 0,

  [long]$SourceRunId = 0,

  [string]$FailureInputPath = "",

  [switch]$DryRun,

  [string]$OutputPath = "test-results\ship-it\build-break-summary.json"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($TargetRepo) -or $TargetRepo -notmatch "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$") {
  throw "TargetRepo must be in owner/repo format."
}
if ($MaxRuns -lt 1) {
  throw "MaxRuns must be at least 1."
}
if ($MaxAutoRetries -lt 0) {
  throw "MaxAutoRetries cannot be negative."
}
if ($CurrentRetryCount -lt 0) {
  throw "CurrentRetryCount cannot be negative."
}
if (-not [string]::IsNullOrWhiteSpace($FailureInputPath) -and -not (Test-Path $FailureInputPath)) {
  throw "FailureInputPath was provided but file does not exist: $FailureInputPath"
}

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

function Get-RunLogExcerpt {
  param(
    [Parameter(Mandatory)]
    [long]$RunId
  )

  $logOutput = Invoke-Gh -Arguments @("run", "view", $RunId.ToString(), "--repo", $TargetRepo, "--log")
  if ($null -eq $logOutput) {
    return ""
  }

  $text = [string]::Join("`n", @($logOutput))
  if ($text.Length -le 3500) {
    return $text
  }

  return $text.Substring($text.Length - 3500)
}

function ConvertTo-RunObjects {
  param(
    [Parameter(Mandatory)]
    [array]$Rows
  )

  $runs = @()
  foreach ($row in $Rows) {
    $runId = [long]$row.databaseId
    $createdAt = [string]$row.createdAt
    $workflow = [string]$row.workflowName
    $branch = [string]$row.headBranch
    $conclusion = [string]$row.conclusion
    $url = [string]$row.url
    $logExcerpt = if ($null -ne $row.log_excerpt) { [string]$row.log_excerpt } else { "" }

    $runs += [ordered]@{
      run_id = $runId
      created_at = $createdAt
      workflow_name = $workflow
      branch = $branch
      conclusion = $conclusion
      url = $url
      log_excerpt = $logExcerpt
    }
  }

  return $runs | Sort-Object -Property created_at -Descending
}

function Get-RunsFromInput {
  param(
    [Parameter(Mandatory)]
    [string]$Path
  )

  $parsed = Get-Content -Raw -Path $Path | ConvertFrom-Json
  if ($parsed -is [System.Array]) {
    return ConvertTo-RunObjects -Rows $parsed
  }
  if ($null -ne $parsed) {
    return ConvertTo-RunObjects -Rows @($parsed)
  }
  return @()
}

function Get-RunsFromGitHub {
  $json = Invoke-Gh -Arguments @(
    "run", "list",
    "--repo", $TargetRepo,
    "--limit", $MaxRuns.ToString(),
    "--json", "databaseId,workflowName,headBranch,conclusion,createdAt,url"
  )
  $rows = $json | ConvertFrom-Json
  if ($null -eq $rows) {
    return @()
  }

  $runs = ConvertTo-RunObjects -Rows @($rows)
  foreach ($run in $runs) {
    if ($run.conclusion -eq "failure") {
      $run.log_excerpt = Get-RunLogExcerpt -RunId $run.run_id
    }
  }

  return $runs
}

function Get-FailureClassification {
  param(
    [Parameter(Mandatory)]
    [string]$LogText
  )

  $lower = $LogText.ToLowerInvariant()
  $rules = @(
    [ordered]@{
      category = "transient-infra"
      recoverable = $true
      confidence = "high"
      patterns = @("timed out", "econnreset", "503 service unavailable", "temporary failure", "connection reset", "rate limit", "429")
      recommendation = "Retry failed jobs and re-check runner/network health."
    },
    [ordered]@{
      category = "dependency-resolution"
      recoverable = $true
      confidence = "medium"
      patterns = @("unable to resolve package", "could not resolve", "restore failed", "npm err!", "nuget restore")
      recommendation = "Retry once and validate package feed availability."
    },
    [ordered]@{
      category = "test-flake"
      recoverable = $true
      confidence = "medium"
      patterns = @("flaky", "intermittent", "stale element", "retryable test failure")
      recommendation = "Retry failed tests and quarantine flaky cases if repeated."
    },
    [ordered]@{
      category = "compile-error"
      recoverable = $false
      confidence = "high"
      patterns = @("compilation failed", "error cs", "ts\d+:", "syntax error", "build failed")
      recommendation = "Escalate with fix-forward commit; retries will not unblock."
    },
    [ordered]@{
      category = "config-or-permission"
      recoverable = $false
      confidence = "high"
      patterns = @("permission denied", "not authorized", "missing secret", "invalid configuration", "access denied")
      recommendation = "Escalate to owners of configuration/secrets and gate promotion."
    },
    [ordered]@{
      category = "policy-gate"
      recoverable = $false
      confidence = "high"
      patterns = @("required status check", "branch protection", "policy violation", "security gate failed")
      recommendation = "Escalate and resolve policy failure explicitly before rerun."
    }
  )

  foreach ($rule in $rules) {
    foreach ($pattern in $rule.patterns) {
      if ($pattern -match "\\d\+\:|\(|\)|\|" -or $pattern.Contains("+")) {
        if ($lower -match $pattern) {
          return [ordered]@{
            category = $rule.category
            recoverable = [bool]$rule.recoverable
            confidence = $rule.confidence
            evidence = $pattern
            recommendation = $rule.recommendation
          }
        }
      } elseif ($lower.Contains($pattern)) {
        return [ordered]@{
          category = $rule.category
          recoverable = [bool]$rule.recoverable
          confidence = $rule.confidence
          evidence = $pattern
          recommendation = $rule.recommendation
        }
      }
    }
  }

  return [ordered]@{
    category = "unknown"
    recoverable = $false
    confidence = "low"
    evidence = "no-rule-match"
    recommendation = "Escalate for manual triage; classifier could not determine safe auto-retry."
  }
}

function Find-ExistingIssueByMarker {
  param(
    [Parameter(Mandatory)]
    [string]$Repo,
    [Parameter(Mandatory)]
    [string]$Marker
  )

  $search = Invoke-Gh -Arguments @(
    "search", "issues",
    "--repo", $Repo,
    "--state", "open",
    "--label", "build-break",
    "--json", "number,title,body,url"
  ) | ConvertFrom-Json

  foreach ($item in @($search)) {
    if (-not [string]::IsNullOrWhiteSpace($item.body) -and $item.body.Contains($Marker)) {
      return $item
    }
  }

  return $null
}

function Open-OrUpdateEscalationIssue {
  param(
    [Parameter(Mandatory)]
    [hashtable]$Summary,
    [Parameter(Mandatory)]
    [hashtable]$Classification,
    [Parameter(Mandatory)]
    [array]$FailureTrend,
    [Parameter(Mandatory)]
    [string]$Reason
  )

  $markerInput = "$($Summary.target_repo)|$($Summary.target_branch)|$($Summary.workflow_name)|$($Classification.category)"
  $markerHash = Get-ContentHash -InputText $markerInput
  $marker = "<!-- basecoat-build-break:$markerHash -->"
  $title = "[Intent][build-break][$($Summary.target_branch)] $($Summary.workflow_name)"

  $timeline = ""
  foreach ($entry in $FailureTrend) {
    $timeline += "`n| $($entry.run_id) | $($entry.created_at) | $($entry.conclusion) | $($entry.url) |"
  }

  $body = @"
## Build-Break Escalation

- Repository: $($Summary.target_repo)
- Branch: $($Summary.target_branch)
- Workflow: $($Summary.workflow_name)
- Consecutive failures: $($Summary.consecutive_failures)
- Classification: $($Classification.category) (recoverable=$($Classification.recoverable))
- Escalation reason: $Reason

## Failure Trend

| Run ID | Created At | Conclusion | URL |
|---|---|---|---|$timeline

## Recommendation

$($Classification.recommendation)

## Recovery Attempts

- Max auto retries: $($Summary.max_auto_retries)
- Retry count consumed: $($Summary.current_retry_count)
- Next retry count: $($Summary.next_retry_count)

## Required Actions

- [ ] Root cause identified and documented
- [ ] Fix-forward change merged
- [ ] Follow-up run green
- [ ] This escalation issue closed

$marker
"@

  $tempBody = Join-Path ([System.IO.Path]::GetTempPath()) "build-break-escalation-$([Guid]::NewGuid().ToString()).md"
  Set-Content -Path $tempBody -Value $body -Encoding UTF8

  try {
    $existing = Find-ExistingIssueByMarker -Repo $Summary.target_repo -Marker $marker
    if ($null -ne $existing) {
      Invoke-Gh -Arguments @(
        "issue", "edit", [string]$existing.number,
        "--repo", $Summary.target_repo,
        "--title", $title,
        "--body-file", $tempBody,
        "--add-label", "intent-control-plane,build-break,remediation,escalated"
      ) | Out-Null
      return [string]$existing.url
    }

    return (Invoke-Gh -Arguments @(
      "issue", "create",
      "--repo", $Summary.target_repo,
      "--title", $title,
      "--body-file", $tempBody,
      "--label", "intent-control-plane",
      "--label", "build-break",
      "--label", "remediation",
      "--label", "escalated"
    ) | Select-Object -Last 1).Trim()
  } finally {
    if (Test-Path $tempBody) {
      Remove-Item -Path $tempBody -Force
    }
  }
}

if ([string]::IsNullOrWhiteSpace($FailureInputPath) -and -not $DryRun) {
  $ghCommand = Get-Command gh -ErrorAction SilentlyContinue
  if (-not $ghCommand) {
    throw "gh CLI is required for live mode."
  }
  Invoke-Gh -Arguments @("auth", "status") | Out-Null
}

$allRuns = if (-not [string]::IsNullOrWhiteSpace($FailureInputPath)) {
  Get-RunsFromInput -Path $FailureInputPath
} else {
  Get-RunsFromGitHub
}

$filteredRuns = $allRuns | Where-Object {
  $branchMatch = if ([string]::IsNullOrWhiteSpace($TargetBranch)) { $true } else { $_.branch -eq $TargetBranch }
  $workflowMatch = if ([string]::IsNullOrWhiteSpace($WorkflowName)) { $true } else { $_.workflow_name -eq $WorkflowName }
  $sourceMatch = if ($SourceRunId -gt 0) { $_.run_id -eq $SourceRunId -or $branchMatch } else { $true }
  $branchMatch -and $workflowMatch -and $sourceMatch
}

$targetBranchResolved = if ([string]::IsNullOrWhiteSpace($TargetBranch)) {
  if ($filteredRuns.Count -gt 0) { [string]$filteredRuns[0].branch } else { "" }
} else {
  $TargetBranch
}
$workflowNameResolved = if ([string]::IsNullOrWhiteSpace($WorkflowName)) {
  if ($filteredRuns.Count -gt 0) { [string]$filteredRuns[0].workflow_name } else { "" }
} else {
  $WorkflowName
}

$summary = [ordered]@{
  observed_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  target_repo = $TargetRepo
  target_branch = $targetBranchResolved
  workflow_name = $workflowNameResolved
  source_run_id = if ($SourceRunId -gt 0) { [string]$SourceRunId } else { "" }
  max_auto_retries = $MaxAutoRetries
  current_retry_count = $CurrentRetryCount
  next_retry_count = $CurrentRetryCount
  consecutive_failures = 0
  status = "CLEAR"
  action = "no_action"
  reason = "no-failures-detected"
  latest_failure = $null
  failure_trend = @()
  classifier = $null
  retry_command = ""
  escalation_issue_url = ""
  dry_run = [bool]$DryRun
}

if ($filteredRuns.Count -gt 0) {
  $consecutiveFailures = 0
  $failureTrend = @()
  foreach ($run in $filteredRuns) {
    if ($run.conclusion -eq "failure") {
      $consecutiveFailures++
      if ($failureTrend.Count -lt 5) {
        $failureTrend += [ordered]@{
          run_id = [string]$run.run_id
          created_at = $run.created_at
          conclusion = $run.conclusion
          url = $run.url
        }
      }
    } else {
      break
    }
  }

  $summary.consecutive_failures = $consecutiveFailures
  $summary.failure_trend = $failureTrend

  $latestFailure = $filteredRuns | Where-Object { $_.conclusion -eq "failure" } | Select-Object -First 1
  if ($null -ne $latestFailure) {
    $summary.latest_failure = [ordered]@{
      run_id = [string]$latestFailure.run_id
      created_at = $latestFailure.created_at
      conclusion = $latestFailure.conclusion
      url = $latestFailure.url
    }
    $classification = Get-FailureClassification -LogText ([string]$latestFailure.log_excerpt)
    $summary.classifier = $classification

    if ($classification.recoverable -and $CurrentRetryCount -lt $MaxAutoRetries) {
      $summary.status = "RETRYING"
      $summary.action = "retry"
      $summary.reason = "recoverable-$($classification.category)"
      $summary.next_retry_count = $CurrentRetryCount + 1
      $summary.retry_command = "gh run rerun $($latestFailure.run_id) --repo $TargetRepo --failed"

      if (-not $DryRun) {
        Invoke-Gh -Arguments @("run", "rerun", $latestFailure.run_id.ToString(), "--repo", $TargetRepo, "--failed") | Out-Null
      }
    } else {
      $summary.status = "ESCALATED"
      $summary.action = "escalate"
      if (-not $classification.recoverable) {
        $summary.reason = "nonrecoverable-$($classification.category)"
      } else {
        $summary.reason = "retry-exhausted-$($classification.category)"
      }

      if (-not $DryRun) {
        Ensure-Label -Repo $TargetRepo -Name "intent-control-plane" -Color "4c1d95" -Description "Tracks intent-driven SDLC execution."
        Ensure-Label -Repo $TargetRepo -Name "build-break" -Color "d93f0b" -Description "Tracks build-break detection and recovery incidents."
        Ensure-Label -Repo $TargetRepo -Name "remediation" -Color "b60205" -Description "Follow-up remediation work item."
        Ensure-Label -Repo $TargetRepo -Name "escalated" -Color "5319e7" -Description "Escalated after retry exhaustion or non-recoverable class."

        $summary.escalation_issue_url = Open-OrUpdateEscalationIssue `
          -Summary $summary `
          -Classification $classification `
          -FailureTrend $failureTrend `
          -Reason $summary.reason
      }
    }
  }
}

$outputDirectory = Split-Path -Path $OutputPath -Parent
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
  New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath -Encoding UTF8

$markdownPath = [System.IO.Path]::ChangeExtension($OutputPath, ".md")
$markdown = @"
# Build-Break Detection Summary

- Repository: $($summary.target_repo)
- Branch: $($summary.target_branch)
- Workflow: $($summary.workflow_name)
- Status: $($summary.status)
- Action: $($summary.action)
- Reason: $($summary.reason)
- Consecutive failures: $($summary.consecutive_failures)
- Retry budget: $($summary.current_retry_count) / $($summary.max_auto_retries)
"@

if ($null -ne $summary.classifier) {
  $markdown += @"

## Classification

- Category: $($summary.classifier.category)
- Recoverable: $($summary.classifier.recoverable)
- Confidence: $($summary.classifier.confidence)
- Evidence: $($summary.classifier.evidence)
- Recommendation: $($summary.classifier.recommendation)
"@
}

if ($summary.failure_trend.Count -gt 0) {
  $markdown += "`n`n## Failure Trend"
  foreach ($entry in $summary.failure_trend) {
    $markdown += "`n- Run $($entry.run_id) ($($entry.conclusion)) - $($entry.url)"
  }
}

if (-not [string]::IsNullOrWhiteSpace($summary.escalation_issue_url)) {
  $markdown += "`n`n## Escalation`n- Issue: $($summary.escalation_issue_url)"
}

if (-not [string]::IsNullOrWhiteSpace($summary.retry_command)) {
  $markdown += "`n`n## Retry Command`n- $($summary.retry_command)"
}

Set-Content -Path $markdownPath -Value $markdown -Encoding UTF8

Write-Host "Build-break detector completed."
Write-Host "Summary: $OutputPath"
Write-Output ($summary | ConvertTo-Json -Depth 8)
