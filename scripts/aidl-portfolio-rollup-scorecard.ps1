#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates a deterministic delivery-flow scorecard from an AIDL portfolio KPI rollup.

.DESCRIPTION
    Reads the portfolio KPI rollup produced by scripts/aidl-portfolio-rollup-kpi-publisher.ps1
    (portfolio-kpi-rollup.json) and grades the portfolio-level delivery-flow indicators against
    configurable targets, emitting pass/warn/fail per metric and a worst-wins overall outcome.
    The scorecard is a reusable machine-readable artifact (scorecard JSON + markdown) that
    attaches evidence links back to the source rollup and the required producing run.
    Grading is deterministic and offline; the script performs no network calls.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RollupPath,

    [string]$OutputDir = [System.IO.Path]::Combine("artifacts", "aidl-portfolio-rollup-scorecard"),

    [string]$ThresholdsPath = "",

    [Parameter(Mandatory = $true)]
    [string]$RunUrl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RunUrl)) {
    throw "RunUrl is required and must be non-blank so every scorecard carries producing-run evidence."
}

function ConvertTo-IsoUtc([datetime]$Value) {
    return $Value.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

function ConvertTo-SafeUtcDateTime {
    param([object]$Value)

    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime]) { return ([datetime]$Value).ToUniversalTime() }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    try {
        $parsed = [datetimeoffset]::Parse(
            $text,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
        return $parsed.UtcDateTime
    } catch {
        return $null
    }
}

function Get-Prop {
    param([object]$Object, [string]$Name)

    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

# Metric definitions: source path within the portfolio aggregate, direction, and default
# targets. "higher-is-better" passes when value >= pass and warns when value >= warn; otherwise
# "lower-is-better" passes when value <= pass and warns when value <= warn. All targets are
# overridable via -ThresholdsPath (a JSON object keyed by metric with pass/warn numbers).
$MetricDefinitions = @(
    [ordered]@{ key = "sprint_completion_pct"; group = "roadmap_vs_sprint"; direction = "higher-is-better"; pass = 80; warn = 60; label = "Sprint completion (%)"; sample_group = "roadmap_vs_sprint"; sample_keys = @("sprint_open_items", "sprint_closed_items") }
    [ordered]@{ key = "blocked_open_issues"; group = "leading_indicators"; direction = "lower-is-better"; pass = 0; warn = 3; label = "Blocked open issues" }
    [ordered]@{ key = "open_incidents"; group = "leading_indicators"; direction = "lower-is-better"; pass = 0; warn = 2; label = "Open incidents" }
    [ordered]@{ key = "open_risk_high_issues"; group = "leading_indicators"; direction = "lower-is-better"; pass = 0; warn = 2; label = "Open risk-high issues" }
    [ordered]@{ key = "incident_median_resolution_hours"; group = "lagging_indicators"; direction = "lower-is-better"; pass = 24; warn = 72; label = "Incident median resolution (hours)"; sample_group = "lagging_indicators"; sample_keys = @("closed_incidents") }
    [ordered]@{ key = "average_pr_lead_time_hours"; group = "lagging_indicators"; direction = "lower-is-better"; pass = 48; warn = 96; label = "Average PR lead time (hours)"; sample_group = "lagging_indicators"; sample_keys = @("merged_prs") }
)

function Get-MetricStatus {
    param(
        [double]$Value,
        [string]$Direction,
        [double]$Pass,
        [double]$Warn
    )

    if ($Direction -eq "higher-is-better") {
        if ($Value -ge $Pass) { return "pass" }
        if ($Value -ge $Warn) { return "warn" }
        return "fail"
    }
    # lower-is-better
    if ($Value -le $Pass) { return "pass" }
    if ($Value -le $Warn) { return "warn" }
    return "fail"
}

function Get-MetricScore {
    # Deterministic per-metric maturity score aligned with the audit-framework.md bands
    # (pass 85-100, warn 60-84, fail 0-59): pass=100, warn=70, no-data=60 (incomplete evidence),
    # fail=30. Averaged across metrics to yield the 0-100 delivery-flow maturity_score.
    param([string]$Status)

    switch ($Status) {
        "pass" { return 100 }
        "warn" { return 70 }
        "no-data" { return 60 }
        "fail" { return 30 }
        default { return 0 }
    }
}

function Get-CanonicalRealPath {
    param([string]$Path)

    $full = [System.IO.Path]::GetFullPath($Path)
    $root = [System.IO.Path]::GetPathRoot($full)
    if ([string]::IsNullOrEmpty($root)) {
        $root = [string]([System.IO.Path]::DirectorySeparatorChar)
    }
    $remainder = $full.Substring($root.Length)
    $separators = [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $segments = $remainder.Split($separators, [System.StringSplitOptions]::RemoveEmptyEntries)
    $accumulated = $root
    foreach ($segment in $segments) {
        $accumulated = Join-Path $accumulated $segment
        if (Test-Path -LiteralPath $accumulated) {
            $item = Get-Item -LiteralPath $accumulated -Force
            $linkTarget = $item.ResolveLinkTarget($true)
            if ($null -ne $linkTarget) {
                $accumulated = $linkTarget.FullName
            }
        }
    }
    return [System.IO.Path]::GetFullPath($accumulated)
}

if (-not (Test-Path -LiteralPath $RollupPath)) {
    throw "Rollup file not found: $RollupPath"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$repoRootTrimmed = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    $requestedOutputDir = [System.IO.Path]::GetFullPath($OutputDir)
} else {
    $requestedOutputDir = [System.IO.Path]::GetFullPath((Join-Path $repoRootTrimmed $OutputDir))
}
$resolvedOutputDir = Get-CanonicalRealPath -Path $requestedOutputDir
$resolvedRepoRoot = Get-CanonicalRealPath -Path $repoRootTrimmed
$resolvedOutputDirTrimmed = $resolvedOutputDir.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
$repoRootBoundary = $resolvedRepoRoot + [System.IO.Path]::DirectorySeparatorChar
$pathComparison = if ($IsWindows) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }
$isInsideRepoRoot = $resolvedOutputDirTrimmed.Equals($resolvedRepoRoot, $pathComparison) -or
    $resolvedOutputDirTrimmed.StartsWith($repoRootBoundary, $pathComparison)
if (-not $isInsideRepoRoot) {
    throw "OutputDir must resolve inside repository root. Resolved path: $resolvedOutputDir"
}

$rollup = Get-Content -LiteralPath $RollupPath -Raw -Encoding UTF8 | ConvertFrom-Json
$portfolio = Get-Prop -Object $rollup -Name "portfolio"
if ($null -eq $portfolio) {
    throw "Rollup does not contain a 'portfolio' aggregate: $RollupPath"
}

# Load optional threshold overrides.
$overrides = @{}
if (-not [string]::IsNullOrWhiteSpace($ThresholdsPath)) {
    if (-not (Test-Path -LiteralPath $ThresholdsPath)) {
        throw "Thresholds file not found: $ThresholdsPath"
    }
    $overrideJson = Get-Content -LiteralPath $ThresholdsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $knownMetricKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($def in $MetricDefinitions) { [void]$knownMetricKeys.Add([string]$def.key) }
    foreach ($prop in $overrideJson.PSObject.Properties) {
        if (-not $knownMetricKeys.Contains($prop.Name)) {
            throw "Unknown threshold key '$($prop.Name)'. Valid metric keys: $(($MetricDefinitions | ForEach-Object { $_.key }) -join ', ')."
        }
        $ov = $prop.Value
        if ($ov -isnot [System.Management.Automation.PSCustomObject]) {
            throw "Threshold override for '$($prop.Name)' must be an object with numeric 'pass' and/or 'warn'."
        }
        $ovPass = Get-Prop -Object $ov -Name "pass"
        $ovWarn = Get-Prop -Object $ov -Name "warn"
        if ($null -eq $ovPass -and $null -eq $ovWarn) {
            throw "Threshold override for '$($prop.Name)' must specify at least one of 'pass' or 'warn'."
        }
        foreach ($pair in @(@{ n = "pass"; v = $ovPass }, @{ n = "warn"; v = $ovWarn })) {
            if ($null -ne $pair.v -and ($pair.v -isnot [int] -and $pair.v -isnot [long] -and $pair.v -isnot [double] -and $pair.v -isnot [decimal])) {
                throw "Threshold override '$($prop.Name).$($pair.n)' must be numeric."
            }
        }
        $overrides[$prop.Name] = $ov
    }
}

$metricResults = [System.Collections.Generic.List[object]]::new()
$statuses = [System.Collections.Generic.List[string]]::new()

foreach ($def in $MetricDefinitions) {
    $group = Get-Prop -Object $portfolio -Name $def.group
    $rawValue = if ($null -ne $group) { Get-Prop -Object $group -Name $def.key } else { $null }
    if ($null -eq $rawValue) {
        throw "Rollup portfolio aggregate is missing '$($def.group).$($def.key)'."
    }
    $value = [double]$rawValue

    $pass = [double]$def.pass
    $warn = [double]$def.warn
    if ($overrides.ContainsKey($def.key)) {
        $ov = $overrides[$def.key]
        $ovPass = Get-Prop -Object $ov -Name "pass"
        $ovWarn = Get-Prop -Object $ov -Name "warn"
        if ($null -ne $ovPass) { $pass = [double]$ovPass }
        if ($null -ne $ovWarn) { $warn = [double]$ovWarn }
    }

    # Reject inverted threshold pairs so a configuration typo cannot silently make the warn band
    # unreachable: lower-is-better requires pass <= warn; higher-is-better requires pass >= warn.
    if ($def.direction -eq "lower-is-better" -and $pass -gt $warn) {
        throw "Incoherent thresholds for '$($def.key)': pass ($pass) must be <= warn ($warn) for a lower-is-better metric."
    }
    if ($def.direction -eq "higher-is-better" -and $pass -lt $warn) {
        throw "Incoherent thresholds for '$($def.key)': pass ($pass) must be >= warn ($warn) for a higher-is-better metric."
    }

    # No-data policy: some metrics use a sentinel 0 when there are no samples (duration averages
    # when their count is zero; sprint completion when there are no sprint items). When the sum
    # of the relevant sample counts is zero, grade the metric as no-data rather than pass/fail.
    $status = $null
    if ($def.Contains("sample_keys")) {
        $sampleGroup = Get-Prop -Object $portfolio -Name $def.sample_group
        $sampleTotal = 0.0
        foreach ($sk in $def.sample_keys) {
            $sampleCountRaw = if ($null -ne $sampleGroup) { Get-Prop -Object $sampleGroup -Name $sk } else { $null }
            if ($null -eq $sampleCountRaw) {
                throw "Rollup portfolio aggregate is missing sample count '$($def.sample_group).$sk' required to grade '$($def.key)'."
            }
            $sampleTotal += [double]$sampleCountRaw
        }
        if ($sampleTotal -le 0) {
            $status = "no-data"
        }
    }
    if ($null -eq $status) {
        $status = Get-MetricStatus -Value $value -Direction $def.direction -Pass $pass -Warn $warn
    }

    $statuses.Add($status)
    $metricResults.Add([pscustomobject]([ordered]@{
                metric = $def.key
                label = $def.label
                value = $value
                direction = $def.direction
                pass_target = $pass
                warn_target = $warn
                status = $status
                score = Get-MetricScore -Status $status
            }))
}

$overallOutcome = "pass"
if ($statuses -contains "fail") {
    $overallOutcome = "fail"
} elseif (($statuses -contains "warn") -or ($statuses -contains "no-data")) {
    # Missing evidence (no-data) is not a healthy pass; surface it as at least a warn.
    $overallOutcome = "warn"
}

# Normalized 0-100 delivery-flow maturity score (mean of per-metric scores) for participation in
# the audit-framework.md weighted portfolio composite. The score is kept consistent with the
# outcome banding (pass 85-100, warn 60-84, fail 0-59) using worst-status-in-band capping: a
# blocking fail caps the domain in the fail band, and any warn or missing-evidence (no-data)
# metric caps it in the warn band, so a single degraded control cannot yield a passing tier.
$scoreSum = 0.0
foreach ($m in $metricResults) { $scoreSum += [double]$m.score }
$rawScore = if ($metricResults.Count -gt 0) { $scoreSum / $metricResults.Count } else { 0 }
if ($statuses -contains "fail") {
    $rawScore = [math]::Min($rawScore, 59)
} elseif (($statuses -contains "no-data") -or ($statuses -contains "warn")) {
    $rawScore = [math]::Min($rawScore, 84)
}
$maturityScore = [int][math]::Round($rawScore, 0)

# Derive the domain outcome from the maturity-score band so status and score never disagree.
if ($maturityScore -ge 85) {
    $overallOutcome = "pass"
} elseif ($maturityScore -ge 60) {
    $overallOutcome = "warn"
} else {
    $overallOutcome = "fail"
}

# Maturity tier per audit-framework.md.
$maturityTier = if ($maturityScore -ge 90) { "Tier 4 (Optimized)" }
    elseif ($maturityScore -ge 75) { "Tier 3 (Managed)" }
    elseif ($maturityScore -ge 60) { "Tier 2 (Defined)" }
    else { "Tier 1 (Reactive)" }

$rollupGeneratedAt = Get-Prop -Object $rollup -Name "generated_at_utc"
# Parse and normalize the source timestamp to ISO UTC. A missing, blank, or malformed value
# (for example a non-date string that ConvertFrom-Json left as-is) is rejected so the scorecard
# cannot be published without an auditable as-of time.
$rollupGeneratedAtDt = ConvertTo-SafeUtcDateTime -Value $rollupGeneratedAt
if ($null -eq $rollupGeneratedAtDt) {
    throw "Rollup 'generated_at_utc' is missing or not a valid timestamp; refusing to publish an unauditable scorecard."
}
$rollupGeneratedAtText = ConvertTo-IsoUtc -Value $rollupGeneratedAtDt

$scorecard = [ordered]@{
    # The scorecard's as-of time is the source rollup's timestamp, so identical rollups produce
    # byte-identical scorecards (deterministic) rather than varying on wall-clock time.
    generated_at_utc = $rollupGeneratedAtText
    overall_outcome = $overallOutcome
    maturity_score = $maturityScore
    maturity_tier = $maturityTier
    metric_count = $metricResults.Count
    metrics = @($metricResults)
    evidence = [ordered]@{
        rollup_source = $RollupPath
        rollup_generated_at_utc = $rollupGeneratedAtText
        run_url = $RunUrl
    }
}

[System.IO.Directory]::CreateDirectory($resolvedOutputDir) | Out-Null

$jsonPath = Join-Path $resolvedOutputDir "portfolio-rollup-scorecard.json"
$markdownPath = Join-Path $resolvedOutputDir "portfolio-rollup-scorecard.md"

foreach ($destination in @($jsonPath, $markdownPath)) {
    $destinationParent = Split-Path -Parent $destination
    $destinationLeaf = Split-Path -Leaf $destination
    $existingEntries = @(Get-ChildItem -LiteralPath $destinationParent -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name.Equals($destinationLeaf, $pathComparison) })
    foreach ($existingEntry in $existingEntries) {
        $isReparsePoint = ($existingEntry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint
        if ($isReparsePoint -or $null -ne $existingEntry.ResolveLinkTarget($false)) {
            throw "Refusing to write through a symbolic link destination: $destination"
        }
    }
}

$scorecard | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$md = @()
$md += "# AIDL Portfolio Delivery-Flow Scorecard"
$md += ""
$md += "- Generated at (UTC): $($scorecard.generated_at_utc)"
$md += "- Overall outcome: **$overallOutcome**"
$md += "- Maturity score (0-100): **$maturityScore**"
$md += "- Maturity tier: **$maturityTier**"
$md += "- Rollup source: ``$RollupPath``"
$md += "- Producing run: $RunUrl"
$md += ""
$md += "| Metric | Value | Target (pass / warn) | Status |"
$md += "|---|---:|---|---|"
foreach ($m in @($metricResults)) {
    $targetText = if ($m.direction -eq "higher-is-better") { ">= $($m.pass_target) / >= $($m.warn_target)" } else { "<= $($m.pass_target) / <= $($m.warn_target)" }
    $md += "| $($m.label) | $($m.value) | $targetText | $($m.status) |"
}
Set-Content -LiteralPath $markdownPath -Value ($md -join "`n") -Encoding UTF8

Write-Host "AIDL portfolio rollup scorecard complete."
Write-Host "Overall outcome: $overallOutcome"
Write-Host "JSON: $jsonPath"
Write-Output ($scorecard | ConvertTo-Json -Depth 20)
