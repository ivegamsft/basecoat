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

    Reads selection defaults from autopilot.config.json. Pass -InputPath to run
    against a fixed JSON issue list (offline / test mode) instead of calling gh.

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

# --- Parse dependencies ----------------------------------------------------
$depsByIssue = @{}
$depPattern = '(?i)(?:depends on|blocked by|requires)\s*#(\d+)'
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
    $depsByIssue[$num] = $deps
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
