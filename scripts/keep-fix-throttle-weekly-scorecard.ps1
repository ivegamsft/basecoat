#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates the Keep/Fix/Throttle weekly scorecard and trend readout.

.DESCRIPTION
    Computes weekly operating metrics (throughput, failure rate, MTTR, manual
    intervention rate), classifies trends, and emits JSON + Markdown artifacts.
    Supports live GitHub data collection or deterministic fixture input via
    -SnapshotPath for tests and dry-run scenarios.
#>

[CmdletBinding()]
param(
    [string]$Repository = "",
    [ValidateRange(1, 30)]
    [int]$LookbackDays = 7,
    [ValidateRange(2, 8)]
    [int]$TrendWindowWeeks = 4,
    [string]$OutputDir = "artifacts\keep-fix-throttle-weekly-scorecard",
    [string]$SnapshotPath = "",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\keep-fix-throttle-helpers.ps1"

function Get-LiveSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Repo,
        [Parameter(Mandatory = $true)]
        [datetime]$SinceUtc,
        [Parameter(Mandatory = $true)]
        [datetime]$UntilUtc
    )

    $runs = @(
        Get-PagedResults -Endpoint "/repos/$Repo/actions/runs?status=completed&created=%3E%3D$($SinceUtc.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
    ) | Where-Object {
        $_.PSObject.Properties.Name -contains 'created_at' -and $_.created_at -and ([datetime]$_.created_at).ToUniversalTime() -ge $SinceUtc -and ([datetime]$_.created_at).ToUniversalTime() -le $UntilUtc
    }
    $runCount = @($runs).Count
    $failedRuns = @($runs | Where-Object { $_.conclusion -eq "failure" -or $_.conclusion -eq "timed_out" -or $_.conclusion -eq "cancelled" }).Count
    $failureRate = if ($runCount -gt 0) { [math]::Round($failedRuns / [double]$runCount, 4) } else { 0.0 }

    $pulls = @(
        Get-PagedResults -Endpoint "/repos/$Repo/pulls?state=closed&sort=updated&direction=desc"
    )
    $mergedPulls = @(
        $pulls | Where-Object {
            $null -ne $_.merged_at -and
            ([datetime]$_.merged_at).ToUniversalTime() -ge $SinceUtc -and
            ([datetime]$_.merged_at).ToUniversalTime() -le $UntilUtc
        }
    )

    $mttrDurations = [System.Collections.Generic.List[double]]::new()
    $manualApprovalCount = 0
    foreach ($pr in $mergedPulls) {
        $prNumber = [int]$pr.number
        if ($pr.created_at -and $pr.merged_at) {
            $opened = ([datetime]$pr.created_at).ToUniversalTime()
            $merged = ([datetime]$pr.merged_at).ToUniversalTime()
            $mttrDurations.Add(($merged - $opened).TotalHours)
        }

        $reviews = @(
            Invoke-GhJson -Arguments @("api", "/repos/$Repo/pulls/$prNumber/reviews")
        )
        $approved = @($reviews | Where-Object { $_.state -eq "APPROVED" }).Count -gt 0
        if ($approved) {
            $manualApprovalCount++
        }
    }

    $mttrHours = if ($mttrDurations.Count -gt 0) {
        [math]::Round((@($mttrDurations) | Measure-Object -Average).Average, 2)
    } else {
        0.0
    }
    $manualInterventionRate = if ($mergedPulls.Count -gt 0) {
        [math]::Round($manualApprovalCount / [double]$mergedPulls.Count, 4)
    } else {
        0.0
    }
    $throughput = $mergedPulls.Count

    return [ordered]@{
        week_start = $SinceUtc.ToString("yyyy-MM-dd")
        throughput = $throughput
        failure_rate = $failureRate
        mttr_hours = $mttrHours
        manual_intervention_rate = $manualInterventionRate
    }
}

function Get-StatusForMetric {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Trend
    )
    switch ($Trend) {
        "improving" { return "healthy" }
        "stable" { return "watch" }
        "regressing" { return "action-required" }
        default { return "insufficient-data" }
    }
}

function Classify-Trend {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Current,
        [Parameter(Mandatory = $true)]
        [double]$Baseline,
        [Parameter(Mandatory = $true)]
        [bool]$HigherIsBetter,
        [Parameter(Mandatory = $true)]
        [double]$Threshold
    )

    $delta = [math]::Round(($Current - $Baseline), 4)
    if ($HigherIsBetter) {
        if ($delta -ge $Threshold) { return @{ trend = "improving"; delta = $delta } }
        if ($delta -le (-1 * $Threshold)) { return @{ trend = "regressing"; delta = $delta } }
        return @{ trend = "stable"; delta = $delta }
    }

    if ($delta -le (-1 * $Threshold)) { return @{ trend = "improving"; delta = $delta } }
    if ($delta -ge $Threshold) { return @{ trend = "regressing"; delta = $delta } }
    return @{ trend = "stable"; delta = $delta }
}

function Build-Scorecard {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Snapshots,
        [Parameter(Mandatory = $true)]
        [int]$WindowWeeks
    )

    $orderedSnapshots = @($Snapshots | Sort-Object { [datetime]::Parse($_.week_start) } -Descending)
    if ($orderedSnapshots.Count -eq 0) {
        throw "At least one snapshot is required."
    }

    $recent = @($orderedSnapshots | Select-Object -First $WindowWeeks)
    $current = $recent[0]
    $history = if ($recent.Count -gt 1) { @($recent | Select-Object -Skip 1) } else { @() }

    $defs = @(
        @{
            name = "throughput"
            label = "Throughput"
            unit = "merged_prs_per_week"
            higherIsBetter = $true
            threshold = 1.0
            remediation = "https://github.com/IBuySpy-Shared/basecoat/issues/2046"
        },
        @{
            name = "failure_rate"
            label = "Workflow failure rate"
            unit = "ratio"
            higherIsBetter = $false
            threshold = 0.02
            remediation = "https://github.com/IBuySpy-Shared/basecoat/issues/2047"
        },
        @{
            name = "mttr_hours"
            label = "MTTR"
            unit = "hours"
            higherIsBetter = $false
            threshold = 4.0
            remediation = "https://github.com/IBuySpy-Shared/basecoat/issues/2047"
        },
        @{
            name = "manual_intervention_rate"
            label = "Manual intervention rate"
            unit = "ratio"
            higherIsBetter = $false
            threshold = 0.05
            remediation = "https://github.com/IBuySpy-Shared/basecoat/issues/2049"
        }
    )

    $metrics = [ordered]@{}
    $regressing = [System.Collections.Generic.List[object]]::new()
    $improving = [System.Collections.Generic.List[object]]::new()

    foreach ($def in $defs) {
        $name = [string]$def.name
        $currentValue = [double]$current.$name
        $baselineValue = if (@($history).Count -gt 0) {
            [math]::Round((@($history | Measure-Object -Property $name -Average).Average), 4)
        } else {
            $currentValue
        }

        $trendInfo = if (@($history).Count -gt 0) {
            Classify-Trend -Current $currentValue -Baseline $baselineValue -HigherIsBetter ([bool]$def.higherIsBetter) -Threshold ([double]$def.threshold)
        } else {
            @{ trend = "insufficient-data"; delta = 0.0 }
        }

        $trend = [string]$trendInfo.trend
        $delta = [double]$trendInfo.delta
        if ($trend -eq "regressing") {
            $regressing.Add([ordered]@{
                key = $name
                label = $def.label
                remediation_link = $def.remediation
            })
        } elseif ($trend -eq "improving") {
            $improving.Add([ordered]@{
                key = $name
                label = $def.label
            })
        }

        $metrics[$name] = [ordered]@{
            label = $def.label
            current = [math]::Round($currentValue, 4)
            baseline = [math]::Round($baselineValue, 4)
            delta = [math]::Round($delta, 4)
            trend = $trend
            status = Get-StatusForMetric -Trend $trend
            unit = $def.unit
            higher_is_better = [bool]$def.higherIsBetter
            remediation_link = $def.remediation
        }
    }

    $overall = if ($regressing.Count -gt 0) {
        "regressing"
    } elseif ($improving.Count -gt 0) {
        "improving"
    } else {
        "stable"
    }

    return [ordered]@{
        samples_analyzed = $recent.Count
        current_week = [string]$current.week_start
        overall_trend = $overall
        metrics = $metrics
        improving_metrics = @($improving)
        regressing_metrics = @($regressing)
    }
}

function Convert-ScorecardToMarkdown {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Scorecard
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# Keep/Fix/Throttle Weekly Scorecard")
    $lines.Add("")
    $lines.Add("- Repository: $($Scorecard.repository)")
    $lines.Add("- Generated (UTC): $($Scorecard.generated_at_utc)")
    $lines.Add("- Weekly window: last $($Scorecard.lookback_days) day(s)")
    $lines.Add("- Trend window: $($Scorecard.trend_window_weeks) week(s)")
    $lines.Add("- Current week start: $($Scorecard.current_week)")
    $lines.Add("- Overall trend: **$($Scorecard.overall_trend)**")
    $lines.Add("")
    $lines.Add("## Metric Readout")
    $lines.Add("")
    $lines.Add("| Metric | Current | Baseline avg | Delta | Trend | Status |")
    $lines.Add("|---|---:|---:|---:|---|---|")
    foreach ($metricName in @("throughput", "failure_rate", "mttr_hours", "manual_intervention_rate")) {
        $metric = $Scorecard.metrics.$metricName
        $lines.Add("| $($metric.label) | $($metric.current) | $($metric.baseline) | $($metric.delta) | $($metric.trend) | $($metric.status) |")
    }
    $lines.Add("")
    $lines.Add("## Trend Classification")
    $lines.Add("")
    if (@($Scorecard.regressing_metrics).Count -gt 0) {
        $lines.Add("### Regressing")
        foreach ($item in @($Scorecard.regressing_metrics)) {
            $lines.Add("- **$($item.label)** -> remediation: $($item.remediation_link)")
        }
        $lines.Add("")
    } else {
        $lines.Add("- No regressing metrics this week.")
        $lines.Add("")
    }

    if (@($Scorecard.improving_metrics).Count -gt 0) {
        $lines.Add("### Improving")
        foreach ($item in @($Scorecard.improving_metrics)) {
            $lines.Add("- **$($item.label)**")
        }
        $lines.Add("")
    }

    $lines.Add("## Review Workflow")
    $lines.Add("")
    $lines.Add("1. Review this report against issue #2050 acceptance criteria.")
    $lines.Add("2. If any metric is regressing, update linked remediation issue(s).")
    $lines.Add("3. Post this readout in the weekly governance review thread.")
    $lines.Add("")

    return ($lines -join "`n")
}

if ([string]::IsNullOrWhiteSpace($Repository)) {
    $Repository = if ([string]::IsNullOrWhiteSpace($env:GITHUB_REPOSITORY)) {
        "IBuySpy-Shared/basecoat"
    } else {
        $env:GITHUB_REPOSITORY
    }
}

if ($Repository -notmatch "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$") {
    throw "Repository must be in owner/repo format."
}

$snapshots = @()
if (-not [string]::IsNullOrWhiteSpace($SnapshotPath)) {
    if (-not (Test-Path -Path $SnapshotPath)) {
        throw "SnapshotPath not found: $SnapshotPath"
    }
    $snapshots = @((Get-Content -Raw -Path $SnapshotPath | ConvertFrom-Json))
    if ($snapshots.Count -eq 0) {
        throw "SnapshotPath must contain at least one snapshot object."
    }
} else {
    if ($DryRun) {
        throw "DryRun requires -SnapshotPath."
    }
    $untilUtc = (Get-Date).ToUniversalTime()
    $sinceUtc = $untilUtc.AddDays(-1 * $LookbackDays)
    $snapshots = @(
        Get-LiveSnapshot -Repo $Repository -SinceUtc $sinceUtc -UntilUtc $untilUtc
    )
}

$scorecardSummary = Build-Scorecard -Snapshots $snapshots -WindowWeeks $TrendWindowWeeks
$scorecard = [ordered]@{
    schema_version = "1.0.0"
    repository = $Repository
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    lookback_days = $LookbackDays
    trend_window_weeks = $TrendWindowWeeks
    samples_analyzed = $scorecardSummary.samples_analyzed
    current_week = $scorecardSummary.current_week
    overall_trend = $scorecardSummary.overall_trend
    metrics = $scorecardSummary.metrics
    improving_metrics = $scorecardSummary.improving_metrics
    regressing_metrics = $scorecardSummary.regressing_metrics
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$jsonPath = Join-Path $OutputDir "keep-fix-throttle-weekly-scorecard.json"
$markdownPath = Join-Path $OutputDir "keep-fix-throttle-weekly-scorecard.md"

$scorecard | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
Convert-ScorecardToMarkdown -Scorecard $scorecard | Set-Content -Path $markdownPath -Encoding UTF8

Write-Host "Wrote scorecard JSON: $jsonPath"
Write-Host "Wrote scorecard Markdown: $markdownPath"
