param(
    [string]$Repository,
    [int]$LookbackDays = 14,
    [int]$QueueWarnSeconds = 300,
    [ValidateSet('markdown', 'json')]
    [string]$OutputFormat = 'markdown',
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

function Invoke-GhApiJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Endpoint
    )

    $raw = gh api $Endpoint 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "gh api failed for '$Endpoint': $raw"
    }

    return $raw | ConvertFrom-Json
}

function Get-PercentileValue {
    param(
        [double[]]$Values,
        [double]$Percentile
    )

    if (-not $Values -or $Values.Count -eq 0) {
        return $null
    }

    $sorted = @($Values | Sort-Object)
    $index = [math]::Ceiling(($Percentile / 100.0) * $sorted.Count) - 1
    if ($index -lt 0) { $index = 0 }
    if ($index -ge $sorted.Count) { $index = $sorted.Count - 1 }
    return [math]::Round($sorted[$index], 2)
}

function Get-QueueSeconds {
    param(
        [datetime]$CreatedAt,
        [datetime]$StartedAt
    )

    if ($null -eq $CreatedAt -or $null -eq $StartedAt) {
        return $null
    }

    $seconds = ($StartedAt - $CreatedAt).TotalSeconds
    if ($seconds -lt 0) { return 0 }
    return [math]::Round($seconds, 2)
}

if ([string]::IsNullOrWhiteSpace($Repository)) {
    $Repository = gh repo view --json nameWithOwner --jq .nameWithOwner 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Repository)) {
        throw 'Repository was not provided and could not be inferred from gh repo view.'
    }
}

$releaseLaneWorkflows = @(
    'release.yml',
    'publish-to-production.yml',
    'package-basecoat.yml',
    'docs-production.yml',
    'close-production-issues.yml'
)

$deployLaneWorkflows = @(
    'extension-deploy.yml',
    'mcp-deploy.yml',
    'portal-deploy.yml'
)

$workflowLaneMap = @{}
foreach ($w in $releaseLaneWorkflows) { $workflowLaneMap[$w] = 'release-lane' }
foreach ($w in $deployLaneWorkflows) { $workflowLaneMap[$w] = 'deploy-lane' }

$workflowFiles = @($workflowLaneMap.Keys | Sort-Object)
$cutoff = (Get-Date).ToUniversalTime().AddDays(-1 * $LookbackDays)

$queueObservations = New-Object System.Collections.Generic.List[object]
$wrongRunnerPatterns = New-Object System.Collections.Generic.List[object]
$runnerApiWarning = $null

foreach ($workflowFile in $workflowFiles) {
    $runsEndpoint = "repos/$Repository/actions/workflows/$workflowFile/runs?per_page=100"
    try {
        $runsResponse = Invoke-GhApiJson -Endpoint $runsEndpoint
    }
    catch {
        $queueObservations.Add([pscustomobject]@{
                workflow              = $workflowFile
                lane                  = $workflowLaneMap[$workflowFile]
                sampled_runs          = 0
                queue_p50_seconds     = $null
                queue_p95_seconds     = $null
                queue_max_seconds     = $null
                queued_over_threshold = 0
                warning               = $_.Exception.Message
            })
        continue
    }

    $eligibleRuns = @(
        $runsResponse.workflow_runs |
            Where-Object {
                $created = [datetime]$_.created_at
                $created.ToUniversalTime() -ge $cutoff
            }
    )

    $queueValues = New-Object System.Collections.Generic.List[double]
    $overThreshold = 0

    foreach ($run in $eligibleRuns) {
        $createdAt = if ($run.created_at) { [datetime]$run.created_at } else { $null }
        $startedAt = if ($run.run_started_at) { [datetime]$run.run_started_at } else { $null }
        $queueSeconds = Get-QueueSeconds -CreatedAt $createdAt -StartedAt $startedAt
        if ($null -ne $queueSeconds) {
            [void]$queueValues.Add([double]$queueSeconds)
            if ($queueSeconds -ge $QueueWarnSeconds) {
                $overThreshold++
            }
        }

        if ($run.conclusion -in @('failure', 'timed_out', 'cancelled')) {
            try {
                $jobsResponse = Invoke-GhApiJson -Endpoint "repos/$Repository/actions/runs/$($run.id)/jobs?per_page=100"
                $failedJobs = @($jobsResponse.jobs | Where-Object { $_.conclusion -in @('failure', 'timed_out', 'cancelled') })

                foreach ($job in $failedJobs) {
                    $labels = @($job.labels)
                    $runnerName = [string]$job.runner_name
                    $isGithubHosted = $false
                    if ($runnerName -match '^GitHub Actions') {
                        $isGithubHosted = $true
                    }
                    if (@('ubuntu-latest', 'windows-latest', 'macos-latest') | Where-Object { $labels -contains $_ }) {
                        $isGithubHosted = $true
                    }

                    $missingRunnerAssignment = [string]::IsNullOrWhiteSpace($runnerName) -or -not $job.started_at
                    $isPotentialWrongRunner = $isGithubHosted -or $missingRunnerAssignment
                    if (-not $isPotentialWrongRunner) {
                        continue
                    }

                    $queueAtFailure = $null
                    if ($createdAt -and $run.updated_at) {
                        $queueAtFailure = Get-QueueSeconds -CreatedAt $createdAt -StartedAt ([datetime]$run.updated_at)
                    }

                    $wrongRunnerPatterns.Add([pscustomobject]@{
                            workflow            = $workflowFile
                            lane                = $workflowLaneMap[$workflowFile]
                            run_id              = $run.id
                            run_url             = $run.html_url
                            run_attempt         = $run.run_attempt
                            run_conclusion      = $run.conclusion
                            job_name            = $job.name
                            job_conclusion      = $job.conclusion
                            runner_name         = $runnerName
                            labels              = ($labels -join ', ')
                            queue_seconds       = $queueAtFailure
                            pattern_description = if ($missingRunnerAssignment) { 'no-runner-assigned-on-failure' } else { 'failed-on-github-hosted-in-lane-workflow' }
                        })
                }
            }
            catch {
                $wrongRunnerPatterns.Add([pscustomobject]@{
                        workflow            = $workflowFile
                        lane                = $workflowLaneMap[$workflowFile]
                        run_id              = $run.id
                        run_url             = $run.html_url
                        run_attempt         = $run.run_attempt
                        run_conclusion      = $run.conclusion
                        job_name            = '(jobs-unavailable)'
                        job_conclusion      = 'unknown'
                        runner_name         = ''
                        labels              = ''
                        queue_seconds       = $null
                        pattern_description = "could-not-read-jobs: $($_.Exception.Message)"
                    })
            }
        }
    }

    $queueArray = @($queueValues.ToArray())
    $queueObservations.Add([pscustomobject]@{
            workflow              = $workflowFile
            lane                  = $workflowLaneMap[$workflowFile]
            sampled_runs          = $eligibleRuns.Count
            queue_p50_seconds     = Get-PercentileValue -Values $queueArray -Percentile 50
            queue_p95_seconds     = Get-PercentileValue -Values $queueArray -Percentile 95
            queue_max_seconds     = if ($queueArray.Count -gt 0) { [math]::Round(($queueArray | Measure-Object -Maximum).Maximum, 2) } else { $null }
            queued_over_threshold = $overThreshold
            warning               = $null
        })
}

$runnerCapacity = [pscustomobject]@{
    total_count   = 0
    online_count  = 0
    offline_count = 0
    busy_count    = 0
    offline_names = @()
}

try {
    $runnersResponse = Invoke-GhApiJson -Endpoint "repos/$Repository/actions/runners?per_page=100"
    $runners = @($runnersResponse.runners)
    $runnerCapacity.total_count = $runners.Count
    $runnerCapacity.online_count = @($runners | Where-Object { $_.status -eq 'online' }).Count
    $runnerCapacity.offline_count = @($runners | Where-Object { $_.status -ne 'online' }).Count
    $runnerCapacity.busy_count = @($runners | Where-Object { $_.busy -eq $true }).Count
    $runnerCapacity.offline_names = @($runners | Where-Object { $_.status -ne 'online' } | Select-Object -ExpandProperty name)
}
catch {
    $runnerApiWarning = $_.Exception.Message
}

$totalQueuedOverThreshold = @($queueObservations | Measure-Object -Property queued_over_threshold -Sum).Sum
$queueObservationArray = @($queueObservations.ToArray())
$wrongRunnerPatternArray = @($wrongRunnerPatterns.ToArray())
$summary = [pscustomobject]@{
    repository                     = $Repository
    generated_at_utc               = (Get-Date).ToUniversalTime().ToString('o')
    lookback_days                  = $LookbackDays
    queue_warn_seconds             = $QueueWarnSeconds
    workflows_scanned              = $workflowFiles.Count
    queue_samples                  = @($queueObservations | Measure-Object -Property sampled_runs -Sum).Sum
    queue_over_threshold_total     = if ($null -eq $totalQueuedOverThreshold) { 0 } else { [int]$totalQueuedOverThreshold }
    potential_wrong_runner_patterns = $wrongRunnerPatternArray.Count
    runner_capacity                = $runnerCapacity
    warning                        = $runnerApiWarning
}

$report = New-Object psobject
$report | Add-Member -NotePropertyName summary -NotePropertyValue $summary
$report | Add-Member -NotePropertyName queue_observations -NotePropertyValue $queueObservationArray
$report | Add-Member -NotePropertyName wrong_runner_patterns -NotePropertyValue $wrongRunnerPatternArray

if ($OutputFormat -eq 'json') {
    $rendered = $report | ConvertTo-Json -Depth 8
}
else {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Runner Health Observability Report')
    $lines.Add('')
    $lines.Add("| Metric | Value |")
    $lines.Add("|---|---|")
    $lines.Add("| Repository | $($summary.repository) |")
    $lines.Add("| Generated (UTC) | $($summary.generated_at_utc) |")
    $lines.Add("| Lookback days | $($summary.lookback_days) |")
    $lines.Add("| Queue warning threshold (s) | $($summary.queue_warn_seconds) |")
    $lines.Add("| Workflows scanned | $($summary.workflows_scanned) |")
    $lines.Add("| Queue samples | $($summary.queue_samples) |")
    $lines.Add("| Queue over threshold | $($summary.queue_over_threshold_total) |")
    $lines.Add("| Potential wrong-runner patterns | $($summary.potential_wrong_runner_patterns) |")
    $lines.Add("| Runner capacity (online/offline/busy/total) | $($runnerCapacity.online_count)/$($runnerCapacity.offline_count)/$($runnerCapacity.busy_count)/$($runnerCapacity.total_count) |")
    $lines.Add('')

    if ($summary.warning) {
        $lines.Add("> Warning: $($summary.warning)")
        $lines.Add('')
    }

    $lines.Add('## Queue wait by workflow')
    $lines.Add('')
    $lines.Add('| Lane | Workflow | Runs sampled | P50 queue (s) | P95 queue (s) | Max queue (s) | Over threshold | Warning |')
    $lines.Add('|---|---|---:|---:|---:|---:|---:|---|')
    foreach ($row in $queueObservationArray | Sort-Object lane, workflow) {
        $lines.Add("| $($row.lane) | $($row.workflow) | $($row.sampled_runs) | $($row.queue_p50_seconds) | $($row.queue_p95_seconds) | $($row.queue_max_seconds) | $($row.queued_over_threshold) | $($row.warning) |")
    }
    $lines.Add('')

    $lines.Add('## Offline runner capacity')
    $lines.Add('')
    if ($runnerCapacity.offline_count -gt 0) {
        $lines.Add('- Offline runners:')
        foreach ($runnerName in $runnerCapacity.offline_names) {
            $lines.Add("  - $runnerName")
        }
    }
    else {
        $lines.Add('- No offline runners reported for repository scope.')
    }
    $lines.Add('')

    $lines.Add('## Potential wrong-runner failure patterns')
    $lines.Add('')
    if ($wrongRunnerPatternArray.Count -eq 0) {
        $lines.Add('No potential wrong-runner patterns were detected in the lookback window.')
    }
    else {
        $lines.Add('| Lane | Workflow | Run ID | Job | Conclusion | Runner | Pattern |')
        $lines.Add('|---|---|---:|---|---|---|---|')
        foreach ($item in ($wrongRunnerPatternArray | Sort-Object workflow, run_id, job_name | Select-Object -First 50)) {
            $runnerDisplay = if ([string]::IsNullOrWhiteSpace($item.runner_name)) { '(none)' } else { $item.runner_name }
            $jobDisplay = if ([string]::IsNullOrWhiteSpace($item.job_name)) { '(unknown)' } else { $item.job_name }
            $runRef = "[#$($item.run_id)]($($item.run_url))"
            $lines.Add("| $($item.lane) | $($item.workflow) | $runRef | $jobDisplay | $($item.job_conclusion) | $runnerDisplay | $($item.pattern_description) |")
        }
    }

    $rendered = $lines -join "`n"
}

if ($OutputPath) {
    Set-Content -Path $OutputPath -Value $rendered -Encoding utf8
}
else {
    Write-Host $rendered
}

exit 0
