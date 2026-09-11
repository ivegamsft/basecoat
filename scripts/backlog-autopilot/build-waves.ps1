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
# avoid repeat calls. Returns a wrapper @{ ok = <bool>; children = <int[]> }:
# ok=$false means the online lookup failed after every retry (callers fail
# closed). A wrapper is used rather than $null because PowerShell unwraps an
# empty array return to $null, which would make "no children" indistinguishable
# from "lookup failed".
$subIssueCache = @{}
function Get-SubIssueChildren {
    param($Issue)
    $num = [int]$Issue.number
    if ($subIssueCache.ContainsKey($num)) { return $subIssueCache[$num] }

    $prop = $Issue.PSObject.Properties['subIssues']
    if ($prop -and $null -ne $prop.Value) {
        $result = @{ ok = $true; children = @($prop.Value | ForEach-Object { [int]$_ }) }
        $subIssueCache[$num] = $result
        return $result
    }
    if ($InputPath) {
        $result = @{ ok = $true; children = @() }
        $subIssueCache[$num] = $result
        return $result
    }

    # Online lookup. Route through the repository's configured API-burst pacing
    # and exponential backoff (autopilot.config.json -> pacing) so a 500-issue
    # window cannot hammer the sub-issues endpoint past GitHub's secondary
    # rate-limit thresholds. A lookup that never succeeds returns ok=$false so
    # callers fail closed instead of erasing an epic's children on a transient or
    # unauthorized failure. Only a definitive exit-0 response (including a
    # genuinely empty child set) is cached as authoritative.
    $pacing = $config.pacing
    $burst = if ($pacing -and $pacing.min_seconds_between_api_bursts) { [double]$pacing.min_seconds_between_api_bursts } else { 0 }
    $base = if ($pacing -and $pacing.backoff.base_seconds) { [double]$pacing.backoff.base_seconds } else { 5 }
    $factor = if ($pacing -and $pacing.backoff.factor) { [double]$pacing.backoff.factor } else { 2 }
    $maxBackoff = if ($pacing -and $pacing.backoff.max_seconds) { [double]$pacing.backoff.max_seconds } else { 300 }
    $maxRetries = if ($config.loop -and $config.loop.default_max_retries) { [int]$config.loop.default_max_retries } else { 3 }

    $ok = $false
    $children = @()
    for ($attempt = 0; $attempt -le $maxRetries; $attempt++) {
        if ($burst -gt 0) { Start-Sleep -Seconds $burst }
        $cj = & gh api "repos/$Repo/issues/$num/sub_issues" --paginate `
            --jq '.[] | select(.state=="open") | .number' 2>$null
        if ($LASTEXITCODE -eq 0) {
            $ok = $true
            $children = @(@($cj) |
                ForEach-Object { "$_".Trim() } |
                Where-Object { $_ -match '^\d+$' } |
                ForEach-Object { [int]$_ })
            break
        }
        if ($attempt -lt $maxRetries) {
            $wait = [Math]::Min($base * [Math]::Pow($factor, $attempt), $maxBackoff)
            Start-Sleep -Seconds $wait
        }
    }
    $result = @{ ok = $ok; children = $children }
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

    # Native sub-issues: the parent depends on each still-open child. ok=$false
    # means the lookup failed after all retries; fail closed so the epic cannot
    # be scheduled with unfinished children we could not enumerate.
    $subResult = Get-SubIssueChildren $issue
    if (-not $subResult.ok) {
        [void]$deps.Add($SentinelUnplaceable)
    } else {
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
