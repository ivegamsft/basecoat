#Requires -Version 7.0
<#
.SYNOPSIS
    Build oldest-first, dependency-ordered backlog waves for the autopilot: intent.

.DESCRIPTION
    Selects open, actionable issues, orders them oldest-first, parses inter-issue
    dependencies ("depends on #N" / "blocked by #N"), performs a topological sort,
    and groups ready issues into waves of at most WaveSize. Items whose
    dependencies are not yet satisfied wait for a later wave. Dependency cycles
    are reported as blocked.

    Dependencies are drawn from body references ("depends on|blocked by|requires
    #N"), GitHub native sub-issues (a parent/epic depends on each open child),
    and body "Parent: [owner/repo]#N" references. An epic therefore always
    lands after its children, or stays blocked while any child is unresolved.

    Reads selection defaults from autopilot.config.json. Pass -InputPath to run
    against a fixed JSON issue list (offline / test mode) instead of calling gh.
    In offline mode each issue may carry an injectable `subIssues` array to
    represent its native child issues.

.NOTES
    Part of the backlog-autopilot agent. See docs/design/backlog-autopilot-intent.md.
#>
[CmdletBinding()]
param(
    [string]$Repo = "ivegamsft/basecoat",
    [int]$WaveSize = 0,
    [string]$InputPath,
    [string]$ConfigPath = (Join-Path $PSScriptRoot "autopilot.config.json"),
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ConfigPath)) {
    throw "Missing autopilot config: $ConfigPath"
}
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

if ($WaveSize -le 0) {
    $WaveSize = [int]$config.selection.default_wave_size
}
if ($WaveSize -le 0) { $WaveSize = 5 }

$excludeLabels = @()
if ($config.selection.exclude_labels) {
    $excludeLabels = @($config.selection.exclude_labels | ForEach-Object { "$_".ToLowerInvariant() })
}

# --- Load issues -----------------------------------------------------------
if ($InputPath) {
    if (-not (Test-Path $InputPath)) {
        throw "Input issue file not found: $InputPath"
    }
    $rawIssues = Get-Content $InputPath -Raw | ConvertFrom-Json
} else {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        throw "gh CLI not found and no -InputPath supplied."
    }
    # sort:created-asc requests oldest-first from the server so the --limit
    # window keeps the OLDEST issues, not the newest. Without it gh defaults to
    # CREATED_AT DESC and the limit would truncate away the true oldest backlog.
    $json = & gh issue list --repo $Repo --state open --limit 500 `
        --search "sort:created-asc" `
        --json number,createdAt,title,labels,body 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "gh issue list failed for $Repo."
    }
    $rawIssues = $json | ConvertFrom-Json
}

$issues = @($rawIssues)

# --- Filter excluded labels -----------------------------------------------
$actionable = @($issues | Where-Object {
    $labelNames = @()
    if ($_.labels) {
        $labelNames = @($_.labels | ForEach-Object { "$($_.name)".ToLowerInvariant() })
    }
    -not ($labelNames | Where-Object { $excludeLabels -contains $_ })
})

# --- Oldest-first ordering -------------------------------------------------
$ordered = @($actionable | Sort-Object `
    @{ Expression = { [datetime]$_.createdAt } }, `
    @{ Expression = { [int]$_.number } })

$openNumbers = @($ordered | ForEach-Object { [int]$_.number })

# Track EVERY open issue (before the actionable-label filter) so a dependency on
# an open-but-non-actionable issue (labelled blocked/needs-info, etc.) still
# constrains its dependents instead of silently disappearing from the graph.
$allOpenSet = @{}
foreach ($i in $issues) { $allOpenSet[[int]$i.number] = $true }

# Resolve whether a referenced dependency is still open. Known open issues come
# from the fetched set; a dependency outside the fetched window is resolved live
# via gh. Offline (-InputPath) mode treats unknown references as satisfied since
# the supplied list is authoritative. Results are cached to avoid repeat calls.
$depOpenCache = @{}
function Test-DependencyOpen {
    param([int]$Dep)
    if ($allOpenSet.ContainsKey($Dep)) { return $true }
    if ($depOpenCache.ContainsKey($Dep)) { return $depOpenCache[$Dep] }
    if ($InputPath) { $depOpenCache[$Dep] = $false; return $false }
    # Fail closed: treat any dependency whose state cannot be positively
    # resolved as CLOSED (i.e. still open/blocking) is wrong; instead treat it
    # as OPEN so a throttled/failed/ambiguous lookup never lets a dependent jump
    # ahead of an unsatisfied prerequisite. Only a definitive non-OPEN state
    # from gh marks the dependency satisfied.
    $isOpen = $true
    try {
        $depJson = & gh issue view $Dep --repo $Repo --json state 2>$null
        if ($LASTEXITCODE -eq 0 -and $depJson) {
            $isOpen = (($depJson | ConvertFrom-Json).state -eq 'OPEN')
        }
    } catch { $isOpen = $true }
    $depOpenCache[$Dep] = $isOpen
    return $isOpen
}

# Resolve the open GitHub native sub-issues (children) of an issue. An epic must
# be ordered AFTER every one of its children, so each open child becomes a
# dependency of the parent. Offline (-InputPath) mode is authoritative and reads
# an injectable `subIssues` array on the issue object; online mode queries the
# native sub-issues endpoint (already filtered to open children). Cached to
# avoid repeat calls. Returns a wrapper @{ ok = <bool>; status = <string>;
# children = <int[]> }: status is 'ok' (children enumerated), 'error' (the
# online lookup failed after every retry — callers fail closed) or 'unsupported'
# (endpoint 404 — no native sub-issue support, callers skip sentinel-blocking).
# ok mirrors status -eq 'ok'. A wrapper is used rather than $null because
# PowerShell unwraps an empty array return to $null, which would make "no
# children" indistinguishable from "lookup failed".
$subIssueCache = @{}

# Global sub-issue endpoint health counters (issue #3358). Only ONLINE lookups
# are counted (offline/injected results never touch the endpoint). They let the
# script distinguish a per-epic transient failure (some lookups fail) from a
# global outage (every lookup fails) so a globally unavailable or unauthorized
# endpoint fails loud instead of silently blocking every issue and exiting 0.
$script:SubIssueOnlineAttempts = 0
$script:SubIssueOnlineErrors = 0
$script:SubIssueUnsupported = 0

function Get-SubIssueChildren {
    param($Issue)
    $num = [int]$Issue.number
    if ($subIssueCache.ContainsKey($num)) { return $subIssueCache[$num] }

    $prop = $Issue.PSObject.Properties['subIssues']
    if ($prop -and $null -ne $prop.Value) {
        $result = @{ ok = $true; status = 'ok'; children = @($prop.Value | ForEach-Object { [int]$_ }) }
        $subIssueCache[$num] = $result
        return $result
    }
    # Offline simulation hook (mirrors the injectable `subIssues` array): a
    # fixture may carry `subIssuesStatus` = 'error' or 'unsupported' to model a
    # failed or 404 online lookup deterministically, so the global-failure gate
    # (issue #3358) is testable without network access. Counted as an online
    # attempt because the gate keys off online lookup outcomes; real offline runs
    # never set this property, so the counters stay zero and the gate never fires.
    $statusProp = $Issue.PSObject.Properties['subIssuesStatus']
    if ($statusProp -and $statusProp.Value) {
        $simStatus = "$($statusProp.Value)".ToLowerInvariant()
        if ($simStatus -eq 'error' -or $simStatus -eq 'unsupported') {
            $script:SubIssueOnlineAttempts++
            if ($simStatus -eq 'error') { $script:SubIssueOnlineErrors++ } else { $script:SubIssueUnsupported++ }
            $result = @{ ok = $false; status = $simStatus; children = @() }
            $subIssueCache[$num] = $result
            return $result
        }
    }
    if ($InputPath) {
        $result = @{ ok = $true; status = 'ok'; children = @() }
        $subIssueCache[$num] = $result
        return $result
    }

    # Online lookup. Route through the repository's configured API-burst pacing
    # and exponential backoff (autopilot.config.json -> pacing) so a 500-issue
    # window cannot hammer the sub-issues endpoint past GitHub's secondary
    # rate-limit thresholds. Classify the outcome so callers can distinguish a
    # successful lookup, a definitive "endpoint unsupported" (HTTP 404 — treat as
    # "no native sub-issues" and do NOT sentinel-block), and a transient/auth
    # failure (fail closed per epic). Only a definitive exit-0 response
    # (including a genuinely empty child set) is cached as authoritative.
    $pacing = $config.pacing
    $burst = if ($pacing -and $pacing.min_seconds_between_api_bursts) { [double]$pacing.min_seconds_between_api_bursts } else { 0 }
    $base = if ($pacing -and $pacing.backoff.base_seconds) { [double]$pacing.backoff.base_seconds } else { 5 }
    $factor = if ($pacing -and $pacing.backoff.factor) { [double]$pacing.backoff.factor } else { 2 }
    $maxBackoff = if ($pacing -and $pacing.backoff.max_seconds) { [double]$pacing.backoff.max_seconds } else { 300 }
    $maxRetries = if ($config.loop -and $config.loop.default_max_retries) { [int]$config.loop.default_max_retries } else { 3 }

    $status = 'error'
    $children = @()
    for ($attempt = 0; $attempt -le $maxRetries; $attempt++) {
        if ($burst -gt 0) { Start-Sleep -Seconds $burst }
        $errFile = [System.IO.Path]::GetTempFileName()
        try {
            $cj = & gh api "repos/$Repo/issues/$num/sub_issues" --paginate `
                --jq '.[] | select(.state=="open") | .number' 2>$errFile
            $exitCode = $LASTEXITCODE
            $stderr = (Get-Content -Path $errFile -Raw -ErrorAction SilentlyContinue)
        } finally {
            Remove-Item -Path $errFile -Force -ErrorAction SilentlyContinue
        }
        if ($exitCode -eq 0) {
            $status = 'ok'
            $children = @(@($cj) |
                ForEach-Object { "$_".Trim() } |
                Where-Object { $_ -match '^\d+$' } |
                ForEach-Object { [int]$_ })
            break
        }
        # A 404 means the sub-issues endpoint/feature is unavailable for this
        # repo or token. Retrying cannot help, and sentinel-blocking every issue
        # on a repo that simply lacks native sub-issues would erase all waves.
        # Treat it as "no native sub-issues support" and stop retrying.
        if ($stderr -match '(?i)(?:HTTP\s*)?404|not found') {
            $status = 'unsupported'
            break
        }
        if ($attempt -lt $maxRetries) {
            $wait = [Math]::Min($base * [Math]::Pow($factor, $attempt), $maxBackoff)
            Start-Sleep -Seconds $wait
        }
    }

    $script:SubIssueOnlineAttempts++
    if ($status -eq 'error') { $script:SubIssueOnlineErrors++ }
    elseif ($status -eq 'unsupported') { $script:SubIssueUnsupported++ }

    $result = @{ ok = ($status -eq 'ok'); status = $status; children = $children }
    $subIssueCache[$num] = $result
    return $result
}

# --- Parse dependencies ----------------------------------------------------
# Dependencies come from three sources, all unioned:
#   1. Body references: "depends on|blocked by|requires #N".
#   2. GitHub native sub-issues: a parent depends on each open child.
#   3. Body "Parent: [owner/repo]#N" references (the child side of the same
#      epic->child relationship), so ordering is correct even when the native
#      sub-issue link is absent or the endpoint is unavailable.
$depsByIssue = @{}
$parentLinks = @{}
$depPattern = '(?i)(?:depends on|blocked by|requires)\s*#(\d+)'
$parentPattern = '(?im)^\s*Parent:\s*(?:([A-Za-z0-9_.\-]+/[A-Za-z0-9_.\-]+))?#(\d+)'

# A native-only epic whose sub-issue lookup fails must never share a wave with
# its (unknown) children. Give it an unplaceable dependency: [int]::MaxValue is
# not a real issue number and is never placed, so the epic stays in $blocked.
$SentinelUnplaceable = [int]::MaxValue

# "Parent:" links are parsed from the FULL fetched set ($issues), not just
# $ordered. An excluded child (blocked/needs-info label) is absent from $ordered
# but must still pin its parent: if its native sub-issue link is missing or the
# endpoint was unavailable, the "Parent: #N" body reference is the only signal
# that keeps the parent from scheduling ahead of unfinished work.
foreach ($issue in $issues) {
    $num = [int]$issue.number
    $pm = [regex]::Match("$($issue.body)", $parentPattern)
    if (-not $pm.Success) { continue }
    $pRepo = $pm.Groups[1].Value
    $pNum = [int]$pm.Groups[2].Value
    if (($pRepo -eq '' -or $pRepo -ieq $Repo) -and $pNum -ne $num) {
        if (-not $parentLinks.ContainsKey($pNum)) {
            $parentLinks[$pNum] = New-Object System.Collections.Generic.HashSet[int]
        }
        [void]$parentLinks[$pNum].Add($num)
    }
}

foreach ($issue in $ordered) {
    $num = [int]$issue.number
    $deps = New-Object System.Collections.Generic.HashSet[int]
    $body = "$($issue.body)"
    foreach ($m in [regex]::Matches($body, $depPattern)) {
        $dep = [int]$m.Groups[1].Value
        # A dependency constrains the wave whenever it is still open, regardless
        # of whether it passed the actionable-label filter or fell outside the
        # fetched window. An open dependency that never becomes actionable can
        # never be "placed", so its dependents correctly stay in the blocked set.
        if ($dep -ne $num -and (Test-DependencyOpen -Dep $dep)) {
            [void]$deps.Add($dep)
        }
    }

    # Native sub-issues: the parent depends on each still-open child.
    #   status 'error'       -> the lookup failed after all retries for a
    #                           transient/auth reason; fail closed so the epic
    #                           cannot be scheduled with unfinished children we
    #                           could not enumerate.
    #   status 'unsupported' -> the endpoint returned 404 (no native sub-issue
    #                           support); do NOT sentinel-block. Ordering falls
    #                           back to body "depends on"/"Parent:" references.
    #   status 'ok'          -> use the enumerated open children.
    $subResult = Get-SubIssueChildren $issue
    if ($subResult.status -eq 'error') {
        [void]$deps.Add($SentinelUnplaceable)
    } elseif ($subResult.status -eq 'ok') {
        foreach ($child in $subResult.children) {
            if ($child -ne $num -and (Test-DependencyOpen -Dep $child)) {
                [void]$deps.Add($child)
            }
        }
    }

    $depsByIssue[$num] = $deps
}

# Apply parent -> child links: a parent depends on each of its open children.
# A parent that is not itself actionable (excluded label / outside the window)
# has no depsByIssue entry and is skipped; it is simply never scheduled.
foreach ($parent in @($parentLinks.Keys)) {
    if (-not $depsByIssue.ContainsKey($parent)) { continue }
    foreach ($child in $parentLinks[$parent]) {
        if ($child -ne $parent -and (Test-DependencyOpen -Dep $child)) {
            [void]$depsByIssue[$parent].Add($child)
        }
    }
}

# --- Global sub-issue endpoint failure detection (issue #3358) -------------
# Get-SubIssueChildren runs for every issue. If the sub-issues endpoint is
# globally unavailable or the token lacks access, EVERY online lookup fails and
# every issue receives the unplaceable sentinel -> every issue lands in
# $blocked, yet the script would still exit 0: a silent, empty-wave result
# indistinguishable from "nothing is ready". Fail loud instead when online
# lookups were attempted and all of them failed for a transient/auth reason.
if ($script:SubIssueOnlineAttempts -gt 0 -and
    $script:SubIssueOnlineErrors -eq $script:SubIssueOnlineAttempts) {
    [Console]::Error.WriteLine("build-waves: every sub-issue lookup failed ($($script:SubIssueOnlineErrors)/$($script:SubIssueOnlineAttempts)). The GitHub sub-issues endpoint appears globally unavailable or the token lacks access; refusing to emit a wave plan that blocks every issue. Verify authentication and API availability, then re-run.")
    exit 3
}
# A globally 404 endpoint (no native sub-issue support) is a benign degraded
# mode: sentinel-blocking was skipped and ordering relies on body references.
# Warn once so the reduced fidelity is visible without failing the run.
if ($script:SubIssueUnsupported -gt 0 -and
    $script:SubIssueUnsupported -eq $script:SubIssueOnlineAttempts) {
    [Console]::Error.WriteLine("build-waves: the GitHub sub-issues endpoint returned 404 for every lookup; native sub-issue dependencies are unavailable. Falling back to body 'depends on' / 'Parent:' references only.")
}

# --- Topological wave assignment (oldest-first, ready-only) -----------------
$placed = @{}
$waves = @()
$remaining = @($openNumbers)

while ($remaining.Count -gt 0) {
    $ready = @($remaining | Where-Object {
        $unmet = @($depsByIssue[$_] | Where-Object { -not $placed.ContainsKey($_) })
        $unmet.Count -eq 0
    })

    if ($ready.Count -eq 0) {
        break  # remaining items form a dependency cycle or depend on blocked work
    }

    $waveItems = @($ready | Select-Object -First $WaveSize | ForEach-Object { [int]$_ })
    $waves += [pscustomobject]@{
        wave   = $waves.Count + 1
        issues = @($waveItems)
    }

    foreach ($i in $waveItems) { $placed[$i] = $true }
    $remaining = @($remaining | Where-Object { -not $placed.ContainsKey($_) })
}

$blocked = @($remaining | ForEach-Object { [int]$_ })

$result = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo         = $Repo
    wave_size    = $WaveSize
    order        = "oldest-first"
    total_issues = $openNumbers.Count
    waves        = @($waves)
    blocked      = $blocked
}

$out = [pscustomobject]$result | ConvertTo-Json -Depth 6

if ($OutputPath) {
    $out | Set-Content -Path $OutputPath -Encoding utf8
    Write-Host "Wrote $($waves.Count) wave(s) to $OutputPath"
} else {
    Write-Output $out
}

exit 0
