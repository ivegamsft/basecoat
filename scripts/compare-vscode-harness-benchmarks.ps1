#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BaselineFile,
    [Parameter(Mandatory = $true)][string]$CandidateFile,
    [string]$ThresholdFile = "tests/evals/vscode-harness-regression-thresholds.json",
    [string]$OutputDir = "test-results",
    [string]$SummaryFile = ""
)

$ErrorActionPreference = "Stop"

function Assert-Path {
    param([string]$Path, [string]$Message)
    if (-not (Test-Path $Path)) {
        throw $Message
    }
}

function Get-Numeric {
    param($Obj, [string]$Name)
    $value = $Obj.$Name
    if ($null -eq $value) {
        throw "Missing numeric metric '$Name'"
    }
    return [double]$value
}

function Compare-Metric {
    param(
        [string]$Metric,
        [double]$Baseline,
        [double]$Candidate,
        [double]$Threshold,
        [string]$Mode
    )

    $delta = [Math]::Round(($Candidate - $Baseline), 6)
    $passed = $false
    $limitText = ""

    switch ($Mode) {
        "max_drop" {
            $drop = [Math]::Round(($Baseline - $Candidate), 6)
            $passed = $drop -le $Threshold
            $limitText = "drop <= $Threshold"
        }
        "max_increase_abs" {
            $passed = $delta -le $Threshold
            $limitText = "increase <= $Threshold"
        }
        "max_increase_pct" {
            $pctIncrease = if ($Baseline -eq 0) { if ($Candidate -eq 0) { 0 } else { [double]::PositiveInfinity } } else { (($Candidate - $Baseline) / $Baseline) * 100.0 }
            $pctIncrease = [Math]::Round($pctIncrease, 6)
            $passed = $pctIncrease -le $Threshold
            $delta = $pctIncrease
            $limitText = "increase_pct <= $Threshold"
        }
        default { throw "Unsupported comparison mode: $Mode" }
    }

    return [PSCustomObject]@{
        metric = $Metric
        baseline = $Baseline
        candidate = $Candidate
        delta = $delta
        mode = $Mode
        threshold = $Threshold
        limit = $limitText
        passed = $passed
    }
}

Assert-Path -Path $BaselineFile -Message "Baseline file not found: $BaselineFile"
Assert-Path -Path $CandidateFile -Message "Candidate file not found: $CandidateFile"
Assert-Path -Path $ThresholdFile -Message "Threshold file not found: $ThresholdFile"

$baseline = Get-Content $BaselineFile -Raw | ConvertFrom-Json
$candidate = Get-Content $CandidateFile -Raw | ConvertFrom-Json
$thresholds = Get-Content $ThresholdFile -Raw | ConvertFrom-Json

if ($baseline.suite -ne $candidate.suite -or $baseline.suite -ne $thresholds.suite) {
    throw "Suite mismatch between baseline, candidate, and thresholds."
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$globalChecks = @()
$globalChecks += Compare-Metric -Metric "resolution_rate" `
    -Baseline (Get-Numeric -Obj $baseline.metrics -Name "resolution_rate") `
    -Candidate (Get-Numeric -Obj $candidate.metrics -Name "resolution_rate") `
    -Threshold ([double]$thresholds.global_thresholds.max_resolution_rate_drop) `
    -Mode "max_drop"
$globalChecks += Compare-Metric -Metric "prompt_tokens_avg" `
    -Baseline (Get-Numeric -Obj $baseline.metrics -Name "prompt_tokens_avg") `
    -Candidate (Get-Numeric -Obj $candidate.metrics -Name "prompt_tokens_avg") `
    -Threshold ([double]$thresholds.global_thresholds.max_prompt_tokens_increase_pct) `
    -Mode "max_increase_pct"
$globalChecks += Compare-Metric -Metric "completion_tokens_avg" `
    -Baseline (Get-Numeric -Obj $baseline.metrics -Name "completion_tokens_avg") `
    -Candidate (Get-Numeric -Obj $candidate.metrics -Name "completion_tokens_avg") `
    -Threshold ([double]$thresholds.global_thresholds.max_completion_tokens_increase_pct) `
    -Mode "max_increase_pct"
$globalChecks += Compare-Metric -Metric "p95_latency_ms" `
    -Baseline (Get-Numeric -Obj $baseline.metrics -Name "p95_latency_ms") `
    -Candidate (Get-Numeric -Obj $candidate.metrics -Name "p95_latency_ms") `
    -Threshold ([double]$thresholds.global_thresholds.max_p95_latency_ms_increase) `
    -Mode "max_increase_abs"
$globalChecks += Compare-Metric -Metric "tool_calls_per_resolved_run" `
    -Baseline (Get-Numeric -Obj $baseline.metrics -Name "tool_calls_per_resolved_run") `
    -Candidate (Get-Numeric -Obj $candidate.metrics -Name "tool_calls_per_resolved_run") `
    -Threshold ([double]$thresholds.global_thresholds.max_tool_calls_per_resolved_run_increase) `
    -Mode "max_increase_abs"

$categoryChecks = @()
foreach ($prop in $thresholds.category_thresholds.PSObject.Properties) {
    $category = $prop.Name
    $catThreshold = $prop.Value

    $baseCat = $baseline.categories.$category
    $candCat = $candidate.categories.$category
    if ($null -eq $baseCat -or $null -eq $candCat) {
        throw "Missing category '$category' in baseline or candidate metrics"
    }

    if ($null -ne $catThreshold.max_resolution_rate_drop) {
        $categoryChecks += Compare-Metric -Metric "$category.resolution_rate" `
            -Baseline (Get-Numeric -Obj $baseCat -Name "resolution_rate") `
            -Candidate (Get-Numeric -Obj $candCat -Name "resolution_rate") `
            -Threshold ([double]$catThreshold.max_resolution_rate_drop) `
            -Mode "max_drop"
    }

    if ($null -ne $catThreshold.max_p95_latency_ms_increase) {
        $categoryChecks += Compare-Metric -Metric "$category.p95_latency_ms" `
            -Baseline (Get-Numeric -Obj $baseCat -Name "p95_latency_ms") `
            -Candidate (Get-Numeric -Obj $candCat -Name "p95_latency_ms") `
            -Threshold ([double]$catThreshold.max_p95_latency_ms_increase) `
            -Mode "max_increase_abs"
    }
}

$allChecks = @($globalChecks + $categoryChecks)
$failedChecks = @($allChecks | Where-Object { -not $_.passed })
$passed = $failedChecks.Count -eq 0

$report = [PSCustomObject]@{
    collected_at = (Get-Date).ToUniversalTime().ToString("o")
    suite = $baseline.suite
    baseline_file = $BaselineFile
    candidate_file = $CandidateFile
    threshold_file = $ThresholdFile
    passed = $passed
    global_checks = $globalChecks
    category_checks = $categoryChecks
    failed_count = $failedChecks.Count
}

$jsonOut = Join-Path $OutputDir "vscode-harness-regression.json"
$report | ConvertTo-Json -Depth 8 | Out-File -FilePath $jsonOut -Encoding utf8

if (-not $SummaryFile) {
    $SummaryFile = Join-Path $OutputDir "vscode-harness-regression-summary.md"
}

$summary = @()
$summary += "# VS Code Harness Regression Summary"
$summary += ""
$summary += "- Suite: ``$($baseline.suite)``"
$summary += "- Overall: **$(if ($passed) { 'PASS' } else { 'FAIL' })**"
$summary += "- Failed checks: **$($failedChecks.Count)**"
$summary += ""
$summary += "| Metric | Baseline | Candidate | Delta | Rule | Result |"
$summary += "|---|---:|---:|---:|---|---|"
foreach ($check in $allChecks) {
    $summary += "| $($check.metric) | $($check.baseline) | $($check.candidate) | $($check.delta) | $($check.limit) | $(if ($check.passed) { 'PASS' } else { 'FAIL' }) |"
}

$summary -join "`n" | Out-File -FilePath $SummaryFile -Encoding utf8

if (-not $passed) {
    Write-Error "Regression thresholds failed. See $SummaryFile"
}
