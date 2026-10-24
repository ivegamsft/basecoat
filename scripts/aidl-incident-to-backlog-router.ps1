#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Produces a deterministic incident-to-backlog routing plan from an incident export.

.DESCRIPTION
    Reads an incident routing export (the same JSON contract consumed by
    scripts/aidl-incident-routing-verification.ps1) and emits a routing plan that maps each
    incident to a backlog remediation action, applying the canonical severity-to-priority map
    from docs/specs/aidl-portfolio/sprint-41/incident-to-backlog-routing-contract.md.

    The plan is deterministic and offline: it performs no network calls and creates no issues.
    A workflow (or operator) executes the plan by creating or updating the described issues.
    Incidents that already carry a valid GitHub remediation issue/PR link are marked "skip"
    (already routed); unrouted incidents are marked "create" with a priority label, the incident
    owner (DRI), customer impact, and any verification artifact preserved in the body.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$OutputDir = [System.IO.Path]::Combine("artifacts", "aidl-incident-to-backlog-router"),

    [string]$Repo = "ivegamsft/basecoat",

    [string]$AreaTaxonomyPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-IsoUtc([datetime]$Value) {
    return $Value.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

function Get-Prop {
    param([object]$Object, [string]$Name)

    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Test-GitHubIssueOrPrUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return $false }
    return ($Url.Trim() -match '^https://github\.com/[\w.-]+/[\w.-]+/(issues|pull)/\d+(?:[/#?].*)?$')
}

function Test-GitHubArtifactUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return $false }
    $trimmed = $Url.Trim()
    if (Test-GitHubIssueOrPrUrl -Url $trimmed) { return $true }
    if ($trimmed -match '^https://github\.com/[\w.-]+/[\w.-]+/actions/runs/\d+(?:[/#?].*)?$') { return $true }
    if ($trimmed -match '^https://github\.com/[\w.-]+/[\w.-]+/commit/[0-9a-fA-F]{7,40}(?:[/#?].*)?$') { return $true }
    if ($trimmed -match '^https://github\.com/[\w.-]+/[\w.-]+/releases/(tag|download)/[^/\s]+(?:/.*)?$') { return $true }
    return $false
}

# Closure lifecycle states that require verification evidence (contract section 5).
$ClosureStatuses = @("resolved", "closed")

function ConvertTo-SafeUtcDateTime {
    param([object]$Value)

    if ($null -eq $Value) { return $null }
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

# Canonical severity-to-priority map (contract section 4).
$SeverityPriorityMap = @{
    "SEV1" = "critical"
    "SEV2" = "high"
    "SEV3" = "medium"
    "SEV4" = "low"
    "SEV5" = "low"
}

# Lifecycle status enum (contract section 1 / input contract).
$LifecycleStatuses = @(
    "open", "investigating", "identified", "monitoring", "mitigated", "resolved", "closed"
)

function Get-CanonicalRealPath {
    param([string]$Path)

    # Resolve symbolic links / junctions on every existing path segment (not just the leaf)
    # so a linked ancestor beneath the repo cannot redirect writes outside the repository root.
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

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input file not found: $InputPath"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$repoRootTrimmed = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    $requestedOutputDir = [System.IO.Path]::GetFullPath($OutputDir)
} else {
    # Resolve relative paths against the repository root, not the current working directory.
    $requestedOutputDir = [System.IO.Path]::GetFullPath((Join-Path $repoRootTrimmed $OutputDir))
}
$resolvedOutputDir = Get-CanonicalRealPath -Path $requestedOutputDir
$resolvedRepoRoot = Get-CanonicalRealPath -Path $repoRootTrimmed
$resolvedOutputDirTrimmed = $resolvedOutputDir.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
$repoRootBoundary = $resolvedRepoRoot + [System.IO.Path]::DirectorySeparatorChar
# Windows paths are case-insensitive; case-sensitive filesystems must compare with Ordinal
# so a differently cased sibling (for example /Repo vs /repo) cannot bypass the guard.
$pathComparison = if ($IsWindows) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }
$isInsideRepoRoot = $resolvedOutputDirTrimmed.Equals($resolvedRepoRoot, $pathComparison) -or
    $resolvedOutputDirTrimmed.StartsWith($repoRootBoundary, $pathComparison)
if (-not $isInsideRepoRoot) {
    throw "OutputDir must resolve inside repository root. Resolved path: $resolvedOutputDir"
}

$raw = Get-Content -LiteralPath $InputPath -Raw -Encoding UTF8
# Preserve the parsed container so a single top-level object is not silently accepted; the
# routing contract requires a top-level JSON array.
$parsed = $raw | ConvertFrom-Json -NoEnumerate
if ($null -eq $parsed) {
    throw "Input file is empty or not valid JSON: $InputPath"
}
if ($parsed -isnot [System.Collections.IEnumerable] -or $parsed -is [string] -or
    $parsed -is [System.Management.Automation.PSCustomObject]) {
    throw "Input must be a top-level JSON array of incident records: $InputPath"
}
$records = @($parsed)
if ($records.Count -lt 1) {
    throw "Input must contain at least one incident record."
}

# Optional area taxonomy: when supplied, affected_service must match a listed portfolio area.
$areaSet = $null
if (-not [string]::IsNullOrWhiteSpace($AreaTaxonomyPath)) {
    if (-not (Test-Path -LiteralPath $AreaTaxonomyPath)) {
        throw "Area taxonomy file not found: $AreaTaxonomyPath"
    }
    $areaRaw = Get-Content -LiteralPath $AreaTaxonomyPath -Raw -Encoding UTF8
    $areaParsed = $areaRaw | ConvertFrom-Json -NoEnumerate
    if ($areaParsed -isnot [System.Collections.IEnumerable] -or $areaParsed -is [string] -or
        $areaParsed -is [System.Management.Automation.PSCustomObject]) {
        throw "Area taxonomy must be a JSON array of allowed portfolio areas: $AreaTaxonomyPath"
    }
    $areaSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($area in @($areaParsed)) {
        $areaText = [string]$area
        if (-not [string]::IsNullOrWhiteSpace($areaText)) {
            [void]$areaSet.Add($areaText.Trim())
        }
    }
}

$items = [System.Collections.Generic.List[object]]::new()
$createCount = 0
$skipCount = 0
$invalidCount = 0
$seenIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($record in $records) {
    $rawId = [string](Get-Prop -Object $record -Name "incident_id")
    $severityRaw = [string](Get-Prop -Object $record -Name "severity")
    $severity = if ($null -ne $severityRaw) { $severityRaw.Trim().ToUpperInvariant() } else { "" }
    $owner = [string](Get-Prop -Object $record -Name "owner")
    $affectedService = [string](Get-Prop -Object $record -Name "affected_service")
    $customerImpact = [string](Get-Prop -Object $record -Name "customer_impact")
    $detectedAt = [string](Get-Prop -Object $record -Name "detected_at")
    $remediationUrl = [string](Get-Prop -Object $record -Name "remediation_issue_url")
    $verificationUrl = [string](Get-Prop -Object $record -Name "verification_artifact_url")
    $statusRaw = [string](Get-Prop -Object $record -Name "status")
    $status = if ($null -ne $statusRaw) { $statusRaw.Trim().ToLowerInvariant() } else { "" }
    $rootCause = [string](Get-Prop -Object $record -Name "root_cause_summary")

    # Incident ID is the immutable routing identity: a missing or duplicate ID is a
    # contract-invalid record that must not generate backlog work.
    $incidentId = if ([string]::IsNullOrWhiteSpace($rawId)) { "" } else { $rawId.Trim() }

    $invalidReasons = [System.Collections.Generic.List[string]]::new()
    if ([string]::IsNullOrWhiteSpace($incidentId)) {
        $invalidReasons.Add("missing-incident-id")
    } elseif (-not $seenIds.Add($incidentId)) {
        $invalidReasons.Add("duplicate-incident-id")
    }
    if (-not $SeverityPriorityMap.ContainsKey($severity)) { $invalidReasons.Add("invalid-or-missing-severity") }
    if ($LifecycleStatuses -notcontains $status) { $invalidReasons.Add("invalid-or-missing-status") }
    if ([string]::IsNullOrWhiteSpace($owner)) { $invalidReasons.Add("missing-owner") }
    if ([string]::IsNullOrWhiteSpace($affectedService)) {
        $invalidReasons.Add("missing-affected-service")
    } elseif ($null -ne $areaSet -and -not $areaSet.Contains($affectedService.Trim())) {
        $invalidReasons.Add("service-outside-area-taxonomy")
    }
    if ([string]::IsNullOrWhiteSpace($customerImpact)) { $invalidReasons.Add("missing-customer-impact") }
    if ($null -eq (ConvertTo-SafeUtcDateTime -Value $detectedAt)) { $invalidReasons.Add("invalid-or-missing-detected-at") }
    # SEV1/SEV2 (critical/high) incidents require a root cause summary (contract section 5).
    if (($severity -eq "SEV1" -or $severity -eq "SEV2") -and [string]::IsNullOrWhiteSpace($rootCause)) {
        $invalidReasons.Add("missing-root-cause-for-high-severity")
    }
    # Closures (resolved/closed) require a valid verification artifact URL (contract section 5).
    if ($ClosureStatuses -contains $status -and -not (Test-GitHubArtifactUrl -Url $verificationUrl)) {
        $invalidReasons.Add("closure-missing-verification-artifact")
    }

    $displayId = if ([string]::IsNullOrWhiteSpace($incidentId)) { "(missing-id)" } else { $incidentId }

    if ($invalidReasons.Count -gt 0) {
        $invalidCount++
        $items.Add([pscustomobject]([ordered]@{
                incident_id = $displayId
                severity = $severityRaw
                priority = $null
                action = "skip"
                eligible = $false
                reason = ($invalidReasons -join ",")
                title = $null
                labels = @()
                body_markdown = $null
            }))
        continue
    }

    $priority = $SeverityPriorityMap[$severity]

    if (Test-GitHubIssueOrPrUrl -Url $remediationUrl) {
        # Already routed to a backlog issue/PR; preserve the existing link, no new issue.
        $skipCount++
        $items.Add([pscustomobject]([ordered]@{
                incident_id = $incidentId
                severity = $severity
                priority = $priority
                action = "skip"
                eligible = $false
                reason = "already-routed"
                remediation_issue_url = $remediationUrl.Trim()
                title = $null
                labels = @()
                body_markdown = $null
            }))
        continue
    }

    # Eligible (valid and unrouted) incident: emit a create action for a per-incident backlog issue.
    $createCount++
    $serviceLabel = $affectedService.Trim()
    # Title is keyed only on the immutable incident ID so mutable severity/service changes do not
    # fork deduplication; severity and service live in the body.
    $title = "Remediate incident $incidentId"
    $labels = @("incident", "priority:$priority")

    $verificationLine = if ([string]::IsNullOrWhiteSpace($verificationUrl)) { "pending" } else { $verificationUrl.Trim() }

    $bodyLines = @(
        "<!-- aidl-incident-id: $incidentId -->",
        "## Incident remediation routing",
        "",
        "Automatically routed from incident ``$incidentId`` in ``$Repo``.",
        "",
        "| Field | Value |",
        "|---|---|",
        "| Incident ID | ``$incidentId`` |",
        "| Severity | $severity |",
        "| Remediation priority | $priority |",
        "| Owner (DRI) | $($owner.Trim()) |",
        "| Affected service | $serviceLabel |",
        "| Customer impact | $($customerImpact.Trim()) |",
        "| Detected at (UTC) | $($detectedAt.Trim()) |",
        "| Verification artifact | $verificationLine |",
        "",
        "_This backlog item was created by the incident-to-backlog router. Confirm ownership,",
        "attach immutable closeout evidence, and link the incident on closure._"
    )
    $body = $bodyLines -join "`n"

    $items.Add([pscustomobject]([ordered]@{
            incident_id = $incidentId
            severity = $severity
            priority = $priority
            action = "create"
            eligible = $true
            reason = "eligible-unrouted-incident"
            marker = "aidl-incident-id: $incidentId"
            title = $title
            labels = $labels
            body_markdown = $body
        }))
}

$plan = [ordered]@{
    generated_at_utc = ConvertTo-IsoUtc -Value (Get-Date)
    repo = $Repo
    input_count = $records.Count
    summary = [ordered]@{
        create = $createCount
        skip = $skipCount
        invalid = $invalidCount
    }
    items = @($items)
}

[System.IO.Directory]::CreateDirectory($resolvedOutputDir) | Out-Null

$jsonPath = Join-Path $resolvedOutputDir "incident-routing-plan.json"

# Refuse to write through a symbolic link destination.
$destinationParent = Split-Path -Parent $jsonPath
$destinationLeaf = Split-Path -Leaf $jsonPath
$existingEntries = @(Get-ChildItem -LiteralPath $destinationParent -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name.Equals($destinationLeaf, $pathComparison) })
foreach ($existingEntry in $existingEntries) {
    $isReparsePoint = ($existingEntry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint
    if ($isReparsePoint -or $null -ne $existingEntry.ResolveLinkTarget($false)) {
        throw "Refusing to write through a symbolic link destination: $jsonPath"
    }
}

$plan | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

Write-Host "AIDL incident-to-backlog routing plan complete."
Write-Host "Create: $createCount  Skip: $skipCount  Invalid: $invalidCount"
Write-Host "Plan: $jsonPath"
Write-Output ($plan | ConvertTo-Json -Depth 20)
