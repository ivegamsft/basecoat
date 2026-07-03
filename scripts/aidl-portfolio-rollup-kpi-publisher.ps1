#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Cross-repo AIDL portfolio rollup and KPI publisher.

.DESCRIPTION
    Aggregates portfolio metrics across multiple repositories, separates leading
    and lagging indicators, emits JSON + Markdown dashboard artifacts, and can
    publish a control-plane report comment to a target issue.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Repositories,

    [ValidateRange(1, 365)]
    [int]$LookbackDays = 14,

    [string]$OutputDir = "artifacts\aidl-portfolio-rollup",

    [string]$PublishIssueRepo = "",

    [int]$PublishIssueNumber = 0,

    [switch]$DryRun,

    [string]$SnapshotPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host "  -> $Message" -ForegroundColor Cyan
}

function Resolve-RepositoryList([string[]]$InputRepos) {
    $parsed = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in @($InputRepos)) {
        if ([string]::IsNullOrWhiteSpace($entry)) {
            continue
        }

        $tokens = $entry -split "[,\r\n]"
        foreach ($token in $tokens) {
            $trimmed = $token.Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed)) {
                continue
            }
            if ($trimmed -notmatch "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$") {
                throw "Invalid repository format '$trimmed'. Expected owner/repo."
            }
            if (-not $parsed.Contains($trimmed)) {
                $parsed.Add($trimmed)
            }
        }
    }

    if ($parsed.Count -eq 0) {
        throw "At least one repository is required."
    }

    return [string[]]$parsed.ToArray()
}

function Invoke-GhJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & gh @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "gh command failed: gh $($Arguments -join ' ')"
    }

    if ([string]::IsNullOrWhiteSpace($output)) {
        return @()
    }

    $parsed = $output | ConvertFrom-Json -Depth 100
    if ($null -eq $parsed) {
        return @()
    }
    return $parsed
}

function Get-PagedResults {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Endpoint
    )

    $all = [System.Collections.Generic.List[object]]::new()
    $page = 1
    do {
        $connector = if ($Endpoint.Contains("?")) { "&" } else { "?" }
        $paged = "${Endpoint}${connector}per_page=100&page=$page"
        $items = @(Invoke-GhJson -Arguments @("api", $paged))
        foreach ($item in $items) {
            if ($null -eq $item) { continue }
            $all.Add($item)
        }
        $page++
    } while ($items.Count -eq 100)

    return @($all)
}

function Get-ClosedPullsUpdatedSince {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Repository,
        [Parameter(Mandatory = $true)]
        [datetime]$SinceUtc
    )

    $all = [System.Collections.Generic.List[object]]::new()
    $page = 1
    $continuePaging = $true
    do {
        $endpoint = "/repos/$Repository/pulls?state=closed&sort=updated&direction=desc&per_page=100&page=$page"
        $items = @(Invoke-GhJson -Arguments @("api", $endpoint))
        foreach ($item in $items) {
            if ($null -eq $item) { continue }
            $updatedAt = ([datetime]$item.updated_at).ToUniversalTime()
            if ($updatedAt -lt $SinceUtc) {
                $continuePaging = $false
                break
            }
            $all.Add($item)
        }
        $page++
    } while ($continuePaging -and $items.Count -eq 100)

    return @($all)
}

function Get-IssueCommentsPaged {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Repo,
        [Parameter(Mandatory = $true)]
        [int]$IssueNumber
    )

    return @(Get-PagedResults -Endpoint "/repos/$Repo/issues/$IssueNumber/comments")
}

function Get-LabelNames($Item) {
    $labels = [System.Collections.Generic.List[string]]::new()
    foreach ($label in @($Item.labels)) {
        if ($null -eq $label) { continue }
        if ($label.PSObject.Properties.Name -contains "name") {
            $name = [string]$label.name
            if (-not [string]::IsNullOrWhiteSpace($name)) {
                $labels.Add($name.ToLowerInvariant())
            }
        }
    }
    return [string[]]$labels.ToArray()
}

function Test-AnyLabelMatch {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Labels,
        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    foreach ($label in $Labels) {
        foreach ($pattern in $Patterns) {
            if ($label -match $pattern) {
                return $true
            }
        }
    }
    return $false
}

function New-LinkTuple([string]$Title, [string]$Url) {
    return [ordered]@{
        title = $Title
        url = $Url
    }
}

function Format-Hours([double]$Value) {
    if ($Value -le 0) {
        return "n/a"
    }
    return [math]::Round($Value, 1)
}

function Get-RepoMetricsFromLiveData {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Repository,
        [Parameter(Mandatory = $true)]
        [datetime]$SinceUtc
    )

    $openIssuesEndpoint = "/repos/$Repository/issues?state=open"
    $closedIssuesEndpoint = "/repos/$Repository/issues?state=closed&since=$($SinceUtc.ToString('o'))"
    $openPullsEndpoint = "/repos/$Repository/pulls?state=open&sort=updated&direction=desc"

    $openIssues = @(
        @(Get-PagedResults -Endpoint $openIssuesEndpoint) |
            Where-Object { $null -eq $_.pull_request }
    )
    $closedIssuesInWindow = @(
        @(Get-PagedResults -Endpoint $closedIssuesEndpoint) |
            Where-Object {
                $null -eq $_.pull_request -and
                $null -ne $_.closed_at -and
                ([datetime]$_.closed_at).ToUniversalTime() -ge $SinceUtc
            }
    )
    $issues = @($openIssues + $closedIssuesInWindow)

    $openPulls = @(Get-PagedResults -Endpoint $openPullsEndpoint)
    $closedPullsUpdatedInWindow = @(Get-ClosedPullsUpdatedSince -Repository $Repository -SinceUtc $SinceUtc)
    $mergedPullsInWindow = @(
        $closedPullsUpdatedInWindow | Where-Object {
            $null -ne $_.merged_at -and
            ([datetime]$_.merged_at).ToUniversalTime() -ge $SinceUtc
        }
    )

    $blockedIssues = [System.Collections.Generic.List[object]]::new()
    $riskHighIssues = [System.Collections.Generic.List[object]]::new()
    $incidentOpenIssues = [System.Collections.Generic.List[object]]::new()
    $roadmapOpenIssues = [System.Collections.Generic.List[object]]::new()
    $sprintOpenIssues = [System.Collections.Generic.List[object]]::new()
    $closedSprintIssues = [System.Collections.Generic.List[object]]::new()
    $closedIncidentDurations = [System.Collections.Generic.List[double]]::new()
    $closedIncidentCount = 0

    foreach ($issue in $issues) {
        $labels = Get-LabelNames -Item $issue
        $isBlocked = Test-AnyLabelMatch -Labels $labels -Patterns @("^blocked$", "^status:block(ed)?$", "^needs-unblock$")
        $isRiskHigh = Test-AnyLabelMatch -Labels $labels -Patterns @("^risk:high$", "^risk-high$", "^priority:high$", "^priority:critical$")
        $isIncident = Test-AnyLabelMatch -Labels $labels -Patterns @("^incident$", "^type:incident$")
        $isRoadmap = Test-AnyLabelMatch -Labels $labels -Patterns @("^roadmap$", "^status:roadmap$", "^plan:roadmap$")
        $isSprint = Test-AnyLabelMatch -Labels $labels -Patterns @("^sprint:\d+$")

        if ($issue.state -eq "open") {
            if ($isBlocked) { $blockedIssues.Add($issue) }
            if ($isRiskHigh) { $riskHighIssues.Add($issue) }
            if ($isIncident) { $incidentOpenIssues.Add($issue) }
            if ($isRoadmap) { $roadmapOpenIssues.Add($issue) }
            if ($isSprint) { $sprintOpenIssues.Add($issue) }
        } elseif ($issue.state -eq "closed") {
            $closedAt = ([datetime]$issue.closed_at).ToUniversalTime()
            if ($isSprint -and $closedAt -ge $SinceUtc) {
                $closedSprintIssues.Add($issue)
            }
            if ($isIncident -and $closedAt -ge $SinceUtc) {
                $closedIncidentCount++
                if ($null -ne $issue.created_at -and $null -ne $issue.closed_at) {
                    $openedAt = ([datetime]$issue.created_at).ToUniversalTime()
                    $closedIncidentDurations.Add(($closedAt - $openedAt).TotalHours)
                }
            }
        }
    }

    $leadTimes = [System.Collections.Generic.List[double]]::new()
    foreach ($pr in $mergedPullsInWindow) {
        if ($null -ne $pr.created_at -and $null -ne $pr.merged_at) {
            $openedAt = ([datetime]$pr.created_at).ToUniversalTime()
            $mergedAt = ([datetime]$pr.merged_at).ToUniversalTime()
            $leadTimes.Add(($mergedAt - $openedAt).TotalHours)
        }
    }

    $medianIncidentHours = 0.0
    if ($closedIncidentDurations.Count -gt 0) {
        $sorted = @($closedIncidentDurations | Sort-Object)
        $middle = [int][math]::Floor($sorted.Count / 2)
        if ($sorted.Count % 2 -eq 0) {
            $medianIncidentHours = ($sorted[$middle - 1] + $sorted[$middle]) / 2.0
        } else {
            $medianIncidentHours = $sorted[$middle]
        }
    }

    $avgPrLeadHours = if ($leadTimes.Count -gt 0) {
        ($leadTimes | Measure-Object -Average).Average
    } else {
        0.0
    }

    $recentClosedIssues = @(
        $closedIssuesInWindow |
            Sort-Object { [datetime]$_.closed_at } -Descending |
            Select-Object -First 5
    )
    $recentMergedPrs = @(
        $mergedPullsInWindow |
            Sort-Object { [datetime]$_.merged_at } -Descending |
            Select-Object -First 5
    )

    $caveats = [System.Collections.Generic.List[string]]::new()
    if (@($issues | Where-Object { Test-AnyLabelMatch -Labels (Get-LabelNames $_) -Patterns @("^sprint:\d+$") }).Count -eq 0) {
        $caveats.Add("No sprint:* labels detected; sprint status metrics may be incomplete.")
    }
    if (@($issues | Where-Object { Test-AnyLabelMatch -Labels (Get-LabelNames $_) -Patterns @("^roadmap$", "^status:roadmap$", "^plan:roadmap$") }).Count -eq 0) {
        $caveats.Add("No roadmap labels detected; roadmap backlog metrics may be incomplete.")
    }

    $throughput = $closedIssuesInWindow.Count + $mergedPullsInWindow.Count
    $sprintDoneTotal = $closedSprintIssues.Count + $sprintOpenIssues.Count
    $sprintCompletionPct = if ($sprintDoneTotal -gt 0) {
        [math]::Round(($closedSprintIssues.Count * 100.0) / $sprintDoneTotal, 1)
    } else {
        0.0
    }

    return [ordered]@{
        repository = $Repository
        generated_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        lookback_days = $LookbackDays
        leading_indicators = [ordered]@{
            blocked_open_issues = $blockedIssues.Count
            open_review_queue = @($openPulls | Where-Object { -not $_.draft }).Count
            open_risk_high_issues = $riskHighIssues.Count
            open_incidents = $incidentOpenIssues.Count
        }
        lagging_indicators = [ordered]@{
            throughput_items_closed_or_merged = $throughput
            merged_prs = $mergedPullsInWindow.Count
            closed_issues = $closedIssuesInWindow.Count
            closed_incidents = $closedIncidentCount
            incident_median_resolution_hours = [math]::Round($medianIncidentHours, 2)
            average_pr_lead_time_hours = [math]::Round($avgPrLeadHours, 2)
        }
        roadmap_vs_sprint = [ordered]@{
            roadmap_open_items = $roadmapOpenIssues.Count
            sprint_open_items = $sprintOpenIssues.Count
            sprint_closed_items = $closedSprintIssues.Count
            sprint_completion_pct = $sprintCompletionPct
        }
        drill_down_links = [ordered]@{
            blocked = @($blockedIssues | Select-Object -First 5 | ForEach-Object { New-LinkTuple -Title $_.title -Url $_.html_url })
            risk_high = @($riskHighIssues | Select-Object -First 5 | ForEach-Object { New-LinkTuple -Title $_.title -Url $_.html_url })
            incidents_open = @($incidentOpenIssues | Select-Object -First 5 | ForEach-Object { New-LinkTuple -Title $_.title -Url $_.html_url })
            review_queue = @($openPulls | Where-Object { -not $_.draft } | Select-Object -First 5 | ForEach-Object { New-LinkTuple -Title $_.title -Url $_.html_url })
            merged_prs = @($recentMergedPrs | ForEach-Object { New-LinkTuple -Title $_.title -Url $_.html_url })
            recently_closed_issues = @($recentClosedIssues | ForEach-Object { New-LinkTuple -Title $_.title -Url $_.html_url })
        }
        data_quality_caveats = @($caveats)
    }
}

function Get-PortfolioAggregate {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$RepositoryMetrics
    )

    $repos = @($RepositoryMetrics)
    $portfolio = [ordered]@{
        generated_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        repository_count = $repos.Count
        leading_indicators = [ordered]@{
            blocked_open_issues = 0
            open_review_queue = 0
            open_risk_high_issues = 0
            open_incidents = 0
        }
        lagging_indicators = [ordered]@{
            throughput_items_closed_or_merged = 0
            merged_prs = 0
            closed_issues = 0
            closed_incidents = 0
            incident_median_resolution_hours = 0
            average_pr_lead_time_hours = 0
        }
        roadmap_vs_sprint = [ordered]@{
            roadmap_open_items = 0
            sprint_open_items = 0
            sprint_closed_items = 0
            sprint_completion_pct = 0
        }
        data_quality_caveats = @()
    }

    $incidentMedians = [System.Collections.Generic.List[double]]::new()
    $leadAverages = [System.Collections.Generic.List[double]]::new()
    $caveats = [System.Collections.Generic.List[string]]::new()

    foreach ($repo in $repos) {
        $portfolio.leading_indicators.blocked_open_issues += [int]$repo.leading_indicators.blocked_open_issues
        $portfolio.leading_indicators.open_review_queue += [int]$repo.leading_indicators.open_review_queue
        $portfolio.leading_indicators.open_risk_high_issues += [int]$repo.leading_indicators.open_risk_high_issues
        $portfolio.leading_indicators.open_incidents += [int]$repo.leading_indicators.open_incidents

        $portfolio.lagging_indicators.throughput_items_closed_or_merged += [int]$repo.lagging_indicators.throughput_items_closed_or_merged
        $portfolio.lagging_indicators.merged_prs += [int]$repo.lagging_indicators.merged_prs
        $portfolio.lagging_indicators.closed_issues += [int]$repo.lagging_indicators.closed_issues
        $portfolio.lagging_indicators.closed_incidents += [int]$repo.lagging_indicators.closed_incidents

        $portfolio.roadmap_vs_sprint.roadmap_open_items += [int]$repo.roadmap_vs_sprint.roadmap_open_items
        $portfolio.roadmap_vs_sprint.sprint_open_items += [int]$repo.roadmap_vs_sprint.sprint_open_items
        $portfolio.roadmap_vs_sprint.sprint_closed_items += [int]$repo.roadmap_vs_sprint.sprint_closed_items

        $incidentMetric = [double]$repo.lagging_indicators.incident_median_resolution_hours
        if ($incidentMetric -gt 0) {
            $incidentMedians.Add($incidentMetric)
        }
        $leadMetric = [double]$repo.lagging_indicators.average_pr_lead_time_hours
        if ($leadMetric -gt 0) {
            $leadAverages.Add($leadMetric)
        }

        foreach ($caveat in @($repo.data_quality_caveats)) {
            $caveats.Add("$($repo.repository): $caveat")
        }
    }

    if ($incidentMedians.Count -gt 0) {
        $portfolio.lagging_indicators.incident_median_resolution_hours = [math]::Round((@($incidentMedians) | Measure-Object -Average).Average, 2)
    }
    if ($leadAverages.Count -gt 0) {
        $portfolio.lagging_indicators.average_pr_lead_time_hours = [math]::Round((@($leadAverages) | Measure-Object -Average).Average, 2)
    }

    $sprintTotal = $portfolio.roadmap_vs_sprint.sprint_open_items + $portfolio.roadmap_vs_sprint.sprint_closed_items
    if ($sprintTotal -gt 0) {
        $portfolio.roadmap_vs_sprint.sprint_completion_pct = [math]::Round(($portfolio.roadmap_vs_sprint.sprint_closed_items * 100.0) / $sprintTotal, 1)
    }

    $portfolio.data_quality_caveats = @($caveats)
    return $portfolio
}

function Convert-MetricsToMarkdown {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Result
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# AIDL Portfolio Rollup and KPI Report")
    $lines.Add("")
    $lines.Add("- Generated at (UTC): $($Result.generated_at_utc)")
    $lines.Add("- Lookback window (days): $($Result.lookback_days)")
    $lines.Add("- Repositories: $($Result.portfolio.repository_count)")
    $lines.Add("")
    $lines.Add("## KPI Definitions")
    $lines.Add("")
    $lines.Add("| KPI | Type | Calculation |")
    $lines.Add("|---|---|---|")
    $lines.Add("| Blocked Open Issues | Leading | Count of open issues with blocked/status:block labels |")
    $lines.Add("| Open Review Queue | Leading | Count of open non-draft PRs |")
    $lines.Add("| Open Risk High Issues | Leading | Count of open issues labeled risk high or priority high/critical |")
    $lines.Add("| Open Incidents | Leading | Count of open issues labeled incident/type:incident |")
    $lines.Add("| Throughput | Lagging | Closed issues + merged PRs in lookback window |")
    $lines.Add("| Incident Median Resolution Hours | Lagging | Median(created_at -> closed_at) for closed incident issues in lookback window |")
    $lines.Add("| Average PR Lead Time Hours | Lagging | Average(created_at -> merged_at) for merged PRs in lookback window |")
    $lines.Add("| Sprint Completion % | Lagging | sprint_closed_items / (sprint_open_items + sprint_closed_items) * 100 |")
    $lines.Add("")
    $lines.Add("## Portfolio Summary")
    $lines.Add("")
    $lines.Add("### Leading indicators")
    $lines.Add("")
    $lines.Add("| KPI | Value |")
    $lines.Add("|---|---:|")
    $lines.Add("| Blocked open issues | $($Result.portfolio.leading_indicators.blocked_open_issues) |")
    $lines.Add("| Open review queue | $($Result.portfolio.leading_indicators.open_review_queue) |")
    $lines.Add("| Open risk high issues | $($Result.portfolio.leading_indicators.open_risk_high_issues) |")
    $lines.Add("| Open incidents | $($Result.portfolio.leading_indicators.open_incidents) |")
    $lines.Add("")
    $lines.Add("### Lagging indicators")
    $lines.Add("")
    $lines.Add("| KPI | Value |")
    $lines.Add("|---|---:|")
    $lines.Add("| Throughput (closed issues + merged PRs) | $($Result.portfolio.lagging_indicators.throughput_items_closed_or_merged) |")
    $lines.Add("| Merged PRs | $($Result.portfolio.lagging_indicators.merged_prs) |")
    $lines.Add("| Closed issues | $($Result.portfolio.lagging_indicators.closed_issues) |")
    $lines.Add("| Closed incidents | $($Result.portfolio.lagging_indicators.closed_incidents) |")
    $lines.Add("| Incident median resolution hours | $(Format-Hours -Value ([double]$Result.portfolio.lagging_indicators.incident_median_resolution_hours)) |")
    $lines.Add("| Average PR lead time hours | $(Format-Hours -Value ([double]$Result.portfolio.lagging_indicators.average_pr_lead_time_hours)) |")
    $lines.Add("")
    $lines.Add("### Roadmap vs sprint status")
    $lines.Add("")
    $lines.Add("| KPI | Value |")
    $lines.Add("|---|---:|")
    $lines.Add("| Roadmap open items | $($Result.portfolio.roadmap_vs_sprint.roadmap_open_items) |")
    $lines.Add("| Sprint open items | $($Result.portfolio.roadmap_vs_sprint.sprint_open_items) |")
    $lines.Add("| Sprint closed items | $($Result.portfolio.roadmap_vs_sprint.sprint_closed_items) |")
    $lines.Add("| Sprint completion % | $($Result.portfolio.roadmap_vs_sprint.sprint_completion_pct) |")
    $lines.Add("")
    $lines.Add("## Repository Breakdown")
    $lines.Add("")
    $lines.Add("| Repository | Throughput | Blocked | Risk High | Open Incidents | Review Queue | Sprint Completion % |")
    $lines.Add("|---|---:|---:|---:|---:|---:|---:|")
    foreach ($repo in @($Result.repositories)) {
        $lines.Add("| $($repo.repository) | $($repo.lagging_indicators.throughput_items_closed_or_merged) | $($repo.leading_indicators.blocked_open_issues) | $($repo.leading_indicators.open_risk_high_issues) | $($repo.leading_indicators.open_incidents) | $($repo.leading_indicators.open_review_queue) | $($repo.roadmap_vs_sprint.sprint_completion_pct) |")
    }
    $lines.Add("")
    $lines.Add("## Drill-down Links")
    $lines.Add("")
    foreach ($repo in @($Result.repositories)) {
        $lines.Add("### $($repo.repository)")
        $lines.Add("")
        foreach ($groupName in @("blocked", "risk_high", "incidents_open", "review_queue", "merged_prs", "recently_closed_issues")) {
            $entries = @($repo.drill_down_links.$groupName)
            $displayName = $groupName.Replace("_", " ")
            if ($entries.Count -eq 0) {
                $lines.Add("- **$displayName**: _no records_")
                continue
            }
            $lines.Add("- **$displayName**:")
            foreach ($entry in $entries) {
                $lines.Add("  - [$($entry.title)]($($entry.url))")
            }
        }
        $lines.Add("")
    }
    $lines.Add("## Data Quality Caveats")
    $lines.Add("")
    if (@($Result.portfolio.data_quality_caveats).Count -eq 0) {
        $lines.Add("- None detected.")
    } else {
        foreach ($caveat in @($Result.portfolio.data_quality_caveats)) {
            $lines.Add("- $caveat")
        }
    }

    return ($lines -join "`n")
}

function Publish-ReportComment {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Repo,
        [Parameter(Mandatory = $true)]
        [int]$IssueNumber,
        [Parameter(Mandatory = $true)]
        [string]$Body
    )

    $marker = "<!-- aidl-portfolio-rollup-report -->"
    $publishedBody = "$marker`n$Body"
    $comments = @(Get-IssueCommentsPaged -Repo $Repo -IssueNumber $IssueNumber)
    $existing = $null
    foreach ($comment in $comments) {
        if ($null -eq $comment) { continue }
        if ($null -ne $comment.body -and [string]$comment.body -like "*$marker*") {
            $existing = $comment
            break
        }
    }

    if ($null -ne $existing) {
        Invoke-GhJson -Arguments @(
            "api",
            "--method", "PATCH",
            "/repos/$Repo/issues/comments/$($existing.id)",
            "-f", "body=$publishedBody"
        ) | Out-Null
        return "updated"
    }

    $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ("aidl-portfolio-rollup-comment-" + [Guid]::NewGuid().ToString("N") + ".md")
    Set-Content -Path $tempFile -Value $publishedBody -Encoding UTF8
    try {
        & gh issue comment $IssueNumber --repo $Repo --body-file $tempFile | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "gh issue comment failed for $Repo#$IssueNumber"
        }
    } finally {
        if (Test-Path $tempFile) {
            Remove-Item -Path $tempFile -Force
        }
    }
    return "created"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$resolvedOutputDir = [System.IO.Path]::GetFullPath($OutputDir)
if (-not ($resolvedOutputDir.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase))) {
    throw "OutputDir must resolve inside repository root. Resolved path: $resolvedOutputDir"
}

$repoList = @(Resolve-RepositoryList -InputRepos $Repositories)
$sinceUtc = (Get-Date).ToUniversalTime().AddDays(-$LookbackDays)

if ($PublishIssueNumber -gt 0 -and [string]::IsNullOrWhiteSpace($PublishIssueRepo)) {
    throw "PublishIssueRepo is required when PublishIssueNumber is provided."
}
if ($PublishIssueNumber -lt 0) {
    throw "PublishIssueNumber must be 0 or greater."
}

if (-not $DryRun) {
    $ghCommand = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $ghCommand) {
        throw "gh CLI is required unless -DryRun is used."
    }
}

Write-Step "Preparing repository metrics for $($repoList.Count) repositories."
$repoMetrics = [System.Collections.Generic.List[object]]::new()

if (-not [string]::IsNullOrWhiteSpace($SnapshotPath)) {
    if (-not (Test-Path $SnapshotPath)) {
        throw "SnapshotPath not found: $SnapshotPath"
    }
    Write-Step "Loading metrics from snapshot: $SnapshotPath"
    $snapshot = @(Get-Content -Path $SnapshotPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100)
    foreach ($repo in $repoList) {
        $match = $snapshot | Where-Object { $_.repository -eq $repo } | Select-Object -First 1
        if ($null -eq $match) {
            throw "Snapshot does not include repository: $repo"
        }
        $repoMetrics.Add($match)
    }
} elseif ($DryRun) {
    Write-Step "Dry-run enabled without snapshot; generating deterministic placeholder data."
    foreach ($repo in $repoList) {
        $repoMetrics.Add([pscustomobject]([ordered]@{
                repository = $repo
                generated_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
                lookback_days = $LookbackDays
                leading_indicators = [ordered]@{
                    blocked_open_issues = 2
                    open_review_queue = 3
                    open_risk_high_issues = 1
                    open_incidents = 1
                }
                lagging_indicators = [ordered]@{
                    throughput_items_closed_or_merged = 9
                    merged_prs = 4
                    closed_issues = 5
                    closed_incidents = 1
                    incident_median_resolution_hours = 18.5
                    average_pr_lead_time_hours = 27.25
                }
                roadmap_vs_sprint = [ordered]@{
                    roadmap_open_items = 6
                    sprint_open_items = 7
                    sprint_closed_items = 8
                    sprint_completion_pct = 53.3
                }
                drill_down_links = [ordered]@{
                    blocked = @(
                        (New-LinkTuple -Title "Blocked item sample ($repo)" -Url "https://github.com/$repo/issues/100")
                    )
                    risk_high = @(
                        (New-LinkTuple -Title "Risk high sample ($repo)" -Url "https://github.com/$repo/issues/101")
                    )
                    incidents_open = @(
                        (New-LinkTuple -Title "Incident sample ($repo)" -Url "https://github.com/$repo/issues/102")
                    )
                    review_queue = @(
                        (New-LinkTuple -Title "Open PR sample ($repo)" -Url "https://github.com/$repo/pull/103")
                    )
                    merged_prs = @(
                        (New-LinkTuple -Title "Merged PR sample ($repo)" -Url "https://github.com/$repo/pull/104")
                    )
                    recently_closed_issues = @(
                        (New-LinkTuple -Title "Closed issue sample ($repo)" -Url "https://github.com/$repo/issues/105")
                    )
                }
                data_quality_caveats = @(
                    "Dry-run placeholder metrics. Replace with live run for production decisions."
                )
            }))
    }
} else {
    foreach ($repo in $repoList) {
        Write-Step "Collecting live metrics for $repo"
        $repoMetrics.Add((Get-RepoMetricsFromLiveData -Repository $repo -SinceUtc $sinceUtc))
    }
}

$portfolio = Get-PortfolioAggregate -RepositoryMetrics @($repoMetrics.ToArray())
$result = [ordered]@{
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    lookback_days = $LookbackDays
    repositories = @($repoMetrics.ToArray())
    portfolio = $portfolio
}

New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null
$jsonPath = Join-Path $resolvedOutputDir "portfolio-kpi-rollup.json"
$markdownPath = Join-Path $resolvedOutputDir "portfolio-kpi-rollup.md"
$dashboardPath = Join-Path $resolvedOutputDir "portfolio-dashboard.md"

$result | ConvertTo-Json -Depth 100 | Set-Content -Path $jsonPath -Encoding UTF8
$reportMarkdown = Convert-MetricsToMarkdown -Result $result
Set-Content -Path $markdownPath -Value $reportMarkdown -Encoding UTF8
Set-Content -Path $dashboardPath -Value $reportMarkdown -Encoding UTF8

$publishState = "skipped"
if ($PublishIssueNumber -gt 0) {
    if ($DryRun) {
        $publishState = "dry-run-skipped"
    } else {
        Write-Step "Publishing report comment to $PublishIssueRepo#$PublishIssueNumber"
        $publishState = Publish-ReportComment -Repo $PublishIssueRepo -IssueNumber $PublishIssueNumber -Body $reportMarkdown
    }
}

$summary = [ordered]@{
    generated_at_utc = $result.generated_at_utc
    lookback_days = $LookbackDays
    repositories = @($repoList)
    artifact_json = $jsonPath
    artifact_markdown = $markdownPath
    artifact_dashboard = $dashboardPath
    publish_state = $publishState
    published_issue_repo = $PublishIssueRepo
    published_issue_number = $PublishIssueNumber
}

Write-Host "AIDL portfolio rollup complete."
Write-Host "JSON: $jsonPath"
Write-Host "Markdown: $markdownPath"
Write-Output ($summary | ConvertTo-Json -Depth 10)
