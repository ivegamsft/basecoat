#Requires -Version 7.0
<#
.SYNOPSIS
    Pacing and anti-throttle gate for the autopilot: backlog delivery loop.

.DESCRIPTION
    Three modes, all deterministic (no side effects unless -Sleep is passed):

      interval  Given the last merge time, compute how long to wait so the
                configured minimum interval between merges elapses. This keeps
                the merge queue serialized at a steady, conflict-safe pace.

      apiburst  Given the last API-burst time, compute how long to wait so the
                configured minimum interval between API bursts elapses. Wrap
                batches of gh/API calls with this to stay under GitHub
                secondary-rate-limit thresholds.

      backoff   Given a retry attempt (0-based) and optional HTTP status code,
                compute exponential-backoff seconds. Backoff applies to 403 and
                429 responses and GitHub secondary-rate-limit conditions.

    Reads pacing defaults from autopilot.config.json. Emits a JSON decision so
    the caller (backlog-autopilot agent or a wrapping script) can wait
    accordingly.

.NOTES
    Part of the backlog-autopilot agent. See docs/design/backlog-autopilot-intent.md.
#>
[CmdletBinding()]
param(
    [ValidateSet("interval", "apiburst", "backoff")]
    [string]$Mode = "interval",
    [string]$ConfigPath = (Join-Path $PSScriptRoot "autopilot.config.json"),
    [string]$LastMergeUtc,
    [string]$LastBurstUtc,
    [string]$NowUtc,
    [int]$Attempt = 0,
    [int]$StatusCode = 0,
    [switch]$Sleep
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ConfigPath)) {
    throw "Missing autopilot config: $ConfigPath"
}
$pacing = (Get-Content $ConfigPath -Raw | ConvertFrom-Json).pacing

if ($Mode -eq "interval") {
    $minInterval = [double]$pacing.min_seconds_between_merges
    $now = if ($NowUtc) { [datetime]::Parse($NowUtc).ToUniversalTime() } else { (Get-Date).ToUniversalTime() }

    $waitSeconds = $minInterval
    if ($LastMergeUtc) {
        $last = [datetime]::Parse($LastMergeUtc).ToUniversalTime()
        $elapsed = ($now - $last).TotalSeconds
        $waitSeconds = [Math]::Max(0.0, $minInterval - $elapsed)
    }

    $decision = [ordered]@{
        mode                = "interval"
        min_interval_seconds = $minInterval
        wait_seconds        = [Math]::Round($waitSeconds, 2)
        ready               = ($waitSeconds -le 0)
    }
} elseif ($Mode -eq "apiburst") {
    # Deterministic minimum interval between API bursts (batches of gh/API
    # calls) so the loop stays under GitHub secondary-rate-limit thresholds.
    $minInterval = [double]$pacing.min_seconds_between_api_bursts
    $now = if ($NowUtc) { [datetime]::Parse($NowUtc).ToUniversalTime() } else { (Get-Date).ToUniversalTime() }

    $waitSeconds = $minInterval
    if ($LastBurstUtc) {
        $last = [datetime]::Parse($LastBurstUtc).ToUniversalTime()
        $elapsed = ($now - $last).TotalSeconds
        $waitSeconds = [Math]::Max(0.0, $minInterval - $elapsed)
    }

    $decision = [ordered]@{
        mode                = "apiburst"
        min_interval_seconds = $minInterval
        wait_seconds        = [Math]::Round($waitSeconds, 2)
        ready               = ($waitSeconds -le 0)
    }
} else {
    $base = [double]$pacing.backoff.base_seconds
    $factor = [double]$pacing.backoff.factor
    $max = [double]$pacing.backoff.max_seconds
    $retryStatuses = @($pacing.backoff.retry_on_status)

    $shouldRetry = $true
    if ($StatusCode -ne 0) {
        $shouldRetry = ($retryStatuses -contains $StatusCode)
    }

    if ($shouldRetry) {
        $raw = $base * [Math]::Pow($factor, [Math]::Max(0, $Attempt))
        $waitSeconds = [Math]::Min($raw, $max)
    } else {
        $waitSeconds = 0.0
    }

    $decision = [ordered]@{
        mode         = "backoff"
        attempt      = $Attempt
        status_code  = $StatusCode
        should_retry = $shouldRetry
        wait_seconds = [Math]::Round($waitSeconds, 2)
        max_seconds  = $max
    }
}

if ($Sleep -and $decision.wait_seconds -gt 0) {
    Start-Sleep -Seconds ([double]$decision.wait_seconds)
}

[pscustomobject]$decision | ConvertTo-Json -Depth 4
