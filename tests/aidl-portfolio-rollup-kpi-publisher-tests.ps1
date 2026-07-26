$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running AIDL portfolio rollup and KPI publisher tests...'

$scriptPath = Join-Path $repoRoot 'scripts\aidl-portfolio-rollup-kpi-publisher.ps1'
$helpersPath = Join-Path $repoRoot 'scripts\aidl-portfolio-rollup-kpi-helpers.ps1'
$workflowPath = Join-Path $repoRoot '.github\workflows\aidl-portfolio-rollup-kpi-publisher.yml'
$guidePath = Join-Path $repoRoot 'docs\guides\aidl-portfolio-rollup-kpi-publisher.md'

foreach ($requiredPath in @($scriptPath, $helpersPath, $workflowPath, $guidePath)) {
    if (-not (Test-Path $requiredPath)) {
        throw "Missing required artifact: $requiredPath"
    }
}

$tempDir = Join-Path $repoRoot ("test-results\aidl-rollup-tests-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    $snapshotPath = Join-Path $tempDir 'snapshot.json'
    $outputDir = Join-Path $tempDir 'artifacts'
    $singleOutputDir = Join-Path $tempDir 'single-artifacts'

    @'
[
  {
    "repository": "IBuySpy-Shared/basecoat",
    "generated_at_utc": "2026-06-24T00:00:00Z",
    "lookback_days": 14,
    "leading_indicators": {
      "blocked_open_issues": 3,
      "open_review_queue": 4,
      "open_risk_high_issues": 2,
      "open_incidents": 1
    },
    "lagging_indicators": {
      "throughput_items_closed_or_merged": 12,
      "merged_prs": 5,
      "closed_issues": 7,
      "closed_incidents": 2,
      "incident_median_resolution_hours": 14.5,
      "average_pr_lead_time_hours": 21.3
    },
    "roadmap_vs_sprint": {
      "roadmap_open_items": 6,
      "sprint_open_items": 8,
      "sprint_closed_items": 10,
      "sprint_completion_pct": 55.6
    },
    "drill_down_links": {
      "blocked": [
        {
          "title": "Blocked issue A",
          "url": "https://github.com/ivegamsft/basecoat/issues/1001"
        }
      ],
      "risk_high": [
        {
          "title": "Risk issue A",
          "url": "https://github.com/ivegamsft/basecoat/issues/1002"
        }
      ],
      "incidents_open": [
        {
          "title": "Incident issue A",
          "url": "https://github.com/ivegamsft/basecoat/issues/1003"
        }
      ],
      "review_queue": [
        {
          "title": "PR A",
          "url": "https://github.com/ivegamsft/basecoat/pull/2001"
        }
      ],
      "merged_prs": [
        {
          "title": "Merged PR A",
          "url": "https://github.com/ivegamsft/basecoat/pull/2002"
        }
      ],
      "recently_closed_issues": [
        {
          "title": "Closed issue A",
          "url": "https://github.com/ivegamsft/basecoat/issues/1004"
        }
      ]
    },
    "data_quality_caveats": [
      "No roadmap labels detected; roadmap backlog metrics may be incomplete."
    ]
  },
  {
    "repository": "IBuySpy-Shared/consumer-a",
    "generated_at_utc": "2026-06-24T00:00:00Z",
    "lookback_days": 14,
    "leading_indicators": {
      "blocked_open_issues": 1,
      "open_review_queue": 2,
      "open_risk_high_issues": 1,
      "open_incidents": 0
    },
    "lagging_indicators": {
      "throughput_items_closed_or_merged": 8,
      "merged_prs": 3,
      "closed_issues": 5,
      "closed_incidents": 1,
      "incident_median_resolution_hours": 10.0,
      "average_pr_lead_time_hours": 18.0
    },
    "roadmap_vs_sprint": {
      "roadmap_open_items": 4,
      "sprint_open_items": 5,
      "sprint_closed_items": 9,
      "sprint_completion_pct": 64.3
    },
    "drill_down_links": {
      "blocked": [
        {
          "title": "Blocked issue B",
          "url": "https://github.com/IBuySpy-Shared/consumer-a/issues/3001"
        }
      ],
      "risk_high": [
        {
          "title": "Risk issue B",
          "url": "https://github.com/IBuySpy-Shared/consumer-a/issues/3002"
        }
      ],
      "incidents_open": [],
      "review_queue": [
        {
          "title": "PR B",
          "url": "https://github.com/IBuySpy-Shared/consumer-a/pull/4001"
        }
      ],
      "merged_prs": [
        {
          "title": "Merged PR B",
          "url": "https://github.com/IBuySpy-Shared/consumer-a/pull/4002"
        }
      ],
      "recently_closed_issues": [
        {
          "title": "Closed issue B",
          "url": "https://github.com/IBuySpy-Shared/consumer-a/issues/3003"
        }
      ]
    },
    "data_quality_caveats": []
  }
]
'@ | Set-Content -Path $snapshotPath -Encoding UTF8

    & $scriptPath `
        -Repositories @('IBuySpy-Shared/basecoat', 'IBuySpy-Shared/consumer-a') `
        -LookbackDays 14 `
        -SnapshotPath $snapshotPath `
        -DryRun `
        -OutputDir $outputDir

    if (-not $?) {
        throw 'Rollup script execution failed.'
    }

    $jsonPath = Join-Path $outputDir 'portfolio-kpi-rollup.json'
    $markdownPath = Join-Path $outputDir 'portfolio-kpi-rollup.md'
    $dashboardPath = Join-Path $outputDir 'portfolio-dashboard.md'

    foreach ($artifact in @($jsonPath, $markdownPath, $dashboardPath)) {
        if (-not (Test-Path $artifact)) {
            throw "Expected artifact missing: $artifact"
        }
    }

    $result = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json -Depth 100
    if (@($result.repositories).Count -ne 2) {
        throw "Expected multi-repo aggregation across 2 repositories, got $(@($result.repositories).Count)."
    }

    if ($result.portfolio.leading_indicators.blocked_open_issues -ne 4) {
        throw "Expected blocked_open_issues aggregate of 4, got $($result.portfolio.leading_indicators.blocked_open_issues)."
    }
    if ($result.portfolio.lagging_indicators.throughput_items_closed_or_merged -ne 20) {
        throw "Expected throughput aggregate of 20, got $($result.portfolio.lagging_indicators.throughput_items_closed_or_merged)."
    }

    $hasDrillDown = @($result.repositories[0].drill_down_links.blocked).Count -ge 1
    if (-not $hasDrillDown) {
        throw 'Expected drill-down links to source records.'
    }

    $hasCaveat = @($result.portfolio.data_quality_caveats).Count -ge 1
    if (-not $hasCaveat) {
        throw 'Expected data quality caveats in aggregated output.'
    }

    $markdown = Get-Content -Path $markdownPath -Raw
    if ($markdown -notmatch '## KPI Definitions') {
        throw 'Markdown report missing KPI definitions section.'
    }
    if ($markdown -notmatch '### Leading indicators') {
        throw 'Markdown report missing leading indicators section.'
    }
    if ($markdown -notmatch '### Lagging indicators') {
        throw 'Markdown report missing lagging indicators section.'
    }
    if ($markdown -notmatch '## Drill-down Links') {
        throw 'Markdown report missing drill-down links section.'
    }
    if ($markdown -notmatch '## Data Quality Caveats') {
        throw 'Markdown report missing data quality caveats section.'
    }

    $workflowContent = Get-Content -Path $workflowPath -Raw
    if ($workflowContent -notmatch 'schedule:') {
        throw 'Workflow must include scheduled execution.'
    }
    if ($workflowContent -notmatch 'workflow_dispatch:') {
        throw 'Workflow must include workflow_dispatch trigger.'
    }
    if ($workflowContent -notmatch 'Upload rollup artifacts') {
        throw 'Workflow must upload rollup artifacts.'
    }

    & $scriptPath `
        -Repositories @('IBuySpy-Shared/basecoat') `
        -LookbackDays 14 `
        -SnapshotPath $snapshotPath `
        -DryRun `
        -OutputDir $singleOutputDir

    if (-not $?) {
        throw 'Single-repository rollup script execution failed.'
    }

    # Strict-mode regression test: PSObject.Properties guard for PR filtering
    # Validates that the filter predicate used in the script does not throw
    # under Set-StrictMode -Version Latest when objects lack the pull_request key
    Write-Host 'Strict-mode PR filter regression test...'
    & {
        Set-StrictMode -Version Latest
        . $helpersPath
        $mixedItems = @(
            [PSCustomObject]@{ number = 1; title = 'issue A'; state = 'open' },
            [PSCustomObject]@{ number = 2; title = 'pr B'; state = 'open'; pull_request = @{ url = 'https://api.github.com/repos/owner/repo/pulls/2' } }
        )
        $issuesOnly = @($mixedItems | Where-Object { -not (Test-IsPullRequestItem -Item $_) })
        if ($issuesOnly.Count -ne 1) {
            throw "Strict-mode PR filter (open issues): expected 1 issue, got $($issuesOnly.Count)"
        }
        if ($issuesOnly[0].number -ne 1) {
            throw "Strict-mode PR filter (open issues): expected issue #1, got #$($issuesOnly[0].number)"
        }

        $closedAt = (Get-Date).ToUniversalTime().AddDays(-1).ToString('o')
        $sinceUtc = (Get-Date).ToUniversalTime().AddDays(-7)
        $closedMixed = @(
            [PSCustomObject]@{ number = 3; title = 'closed issue'; state = 'closed'; closed_at = $closedAt },
            [PSCustomObject]@{ number = 4; title = 'closed pr'; state = 'closed'; closed_at = $closedAt; pull_request = @{ url = 'https://api.github.com/repos/owner/repo/pulls/4' } }
        )
        $closedIssuesOnly = @($closedMixed | Where-Object {
            -not (Test-IsPullRequestItem -Item $_) -and
            $null -ne $_.closed_at -and
            ([datetime]$_.closed_at).ToUniversalTime() -ge $sinceUtc
        })
        if ($closedIssuesOnly.Count -ne 1) {
            throw "Strict-mode PR filter (closed issues): expected 1 issue, got $($closedIssuesOnly.Count)"
        }
        if ($closedIssuesOnly[0].number -ne 3) {
            throw "Strict-mode PR filter (closed issues): expected issue #3, got #$($closedIssuesOnly[0].number)"
        }
    }
    Write-Host '  Strict-mode PR filter regression tests passed.' -ForegroundColor Green

    $singleResultPath = Join-Path $singleOutputDir 'portfolio-kpi-rollup.json'
    if (-not (Test-Path $singleResultPath)) {
        throw "Expected single-repository artifact missing: $singleResultPath"
    }

    $singleResult = Get-Content -Path $singleResultPath -Raw | ConvertFrom-Json -Depth 100
    if (@($singleResult.repositories).Count -ne 1) {
        throw "Expected single-repository aggregation across 1 repository, got $(@($singleResult.repositories).Count)."
    }
    if ($singleResult.portfolio.repository_count -ne 1) {
        throw "Expected portfolio.repository_count of 1, got $($singleResult.portfolio.repository_count)."
    }
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
}

Write-Host 'AIDL portfolio rollup and KPI publisher tests passed' -ForegroundColor Green
exit 0
