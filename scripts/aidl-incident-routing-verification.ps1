#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verifies incident-to-remediation-to-verification linkage quality for AIDL reliability audits.

.DESCRIPTION
    Validates incident routing records against the reliability contract
    (docs/specs/aidl-portfolio/audit-reliability.md) and emits machine-readable and
    markdown scorecards for sprint or weekly audits. Scoring is deterministic and fails
    closed: malformed, duplicate, or unverifiable records produce fail findings rather
    than silently passing.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$OutputDir = [System.IO.Path]::Combine("artifacts", "aidl-incident-routing-verification"),

    [string]$AreaTaxonomyPath = "",

    [switch]$EnableOnlineVerification
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-IsoUtc([datetime]$Value) {
    return $Value.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

function Get-Prop {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-SafeBoolResult {
    param([object]$Value)

    # Returns the parsed boolean plus a validity flag. Fail closed for absent/blank or
    # unrecognized values so repeat-history provenance must be explicit on every record.
    if ($null -eq $Value) {
        return [pscustomobject]@{ Value = $false; Valid = $false }
    }
    if ($Value -is [bool]) {
        return [pscustomobject]@{ Value = [bool]$Value; Valid = $true }
    }
    $text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return [pscustomobject]@{ Value = $false; Valid = $false }
    }
    switch ($text.ToLowerInvariant()) {
        'true'  { return [pscustomobject]@{ Value = $true;  Valid = $true } }
        'false' { return [pscustomobject]@{ Value = $false; Valid = $true } }
        '1'     { return [pscustomobject]@{ Value = $true;  Valid = $true } }
        '0'     { return [pscustomobject]@{ Value = $false; Valid = $true } }
        'yes'   { return [pscustomobject]@{ Value = $true;  Valid = $true } }
        'no'    { return [pscustomobject]@{ Value = $false; Valid = $true } }
        default { return [pscustomobject]@{ Value = $false; Valid = $false } }
    }
}

function ConvertTo-SafeUtcDateTime {
    param([object]$Value)

    if ($null -eq $Value) {
        return $null
    }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }
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

function Format-MarkdownCell {
    param([object]$Value)

    if ($null -eq $Value) {
        return ''
    }
    # Escape backslashes first, then pipes, and collapse CR/LF so a value cannot inject
    # extra table cells or rows (a backslash immediately before a pipe must not un-escape it).
    return (((([string]$Value) -replace '[\r\n]+', ' ') -replace '\\', '\\') -replace '\|', '\|')
}

function Test-GitHubIssueOrPrUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $false
    }
    return ($Url.Trim() -match '^https://github\.com/[\w.-]+/[\w.-]+/(issues|pull)/\d+(?:[/#?].*)?$')
}

function Test-GitHubArtifactUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $false
    }
    $trimmed = $Url.Trim()
    if (Test-GitHubIssueOrPrUrl -Url $trimmed) {
        return $true
    }
    if ($trimmed -match '^https://github\.com/[\w.-]+/[\w.-]+/actions/runs/\d+(?:[/#?].*)?$') {
        return $true
    }
    if ($trimmed -match '^https://github\.com/[\w.-]+/[\w.-]+/commit/[0-9a-fA-F]{7,40}(?:[/#?].*)?$') {
        return $true
    }
    if ($trimmed -match '^https://github\.com/[\w.-]+/[\w.-]+/blob/[0-9a-fA-F]{7,40}/[^?\s#]+(?:[?#].*)?$') {
        return $true
    }
    if ($trimmed -match '^https://github\.com/[\w.-]+/[\w.-]+/checks/runs/\d+(?:[/#?].*)?$') {
        return $true
    }
    if ($trimmed -match '^https://github\.com/[\w.-]+/[\w.-]+/releases/(tag|download)/[^/\s]+(?:/.*)?$') {
        return $true
    }
    return $false
}

function Parse-GitHubIssueOrPrUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $null
    }
    $trimmed = $Url.Trim()
    if ($trimmed -match '^https://github\.com/([\w.-]+)/([\w.-]+)/(issues|pull)/(\d+)(?:[/#?].*)?$') {
        return [pscustomobject]@{
            repo   = "$($Matches[1])/$($Matches[2])"
            kind   = $Matches[3]
            number = [int]$Matches[4]
        }
    }
    return $null
}

function Test-ImmutableVerificationArtifactUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $false
    }
    $trimmed = $Url.Trim()
    if ($trimmed -match '^https://github\.com/[\w.-]+/[\w.-]+/actions/runs/\d+/attempts/\d+(?:[/#?].*)?$') {
        return $true
    }
    if ($trimmed -match '^https://github\.com/[\w.-]+/[\w.-]+/checks/runs/\d+(?:[/#?].*)?$') {
        return $true
    }
    if ($trimmed -match '^https://github\.com/[\w.-]+/[\w.-]+/commit/[0-9a-fA-F]{7,40}(?:[/#?].*)?$') {
        return $true
    }
    if ($trimmed -match '^https://github\.com/[\w.-]+/[\w.-]+/blob/[0-9a-fA-F]{7,40}/[^?\s#]+(?:[?#].*)?$') {
        return $true
    }
    if ($trimmed -match '^https://github\.com/[\w.-]+/[\w.-]+/releases/(tag|download)/[^/\s]+(?:/.*)?$') {
        return $true
    }
    return $false
}

function Invoke-GhJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Endpoint
    )

    $output = & gh api $Endpoint 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "gh api failed for endpoint: $Endpoint"
    }
    return ($output | ConvertFrom-Json -Depth 100)
}

function Get-IssueOrPrEvidenceText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Repo,
        [Parameter(Mandatory = $true)]
        [int]$Number
    )

    $issue = Invoke-GhJson -Endpoint "/repos/$Repo/issues/$Number"
    $comments = @(Invoke-GhJson -Endpoint "/repos/$Repo/issues/$Number/comments?per_page=100")

    $parts = [System.Collections.Generic.List[string]]::new()
    foreach ($value in @($issue.title, $issue.body)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
            $parts.Add([string]$value)
        }
    }
    foreach ($comment in $comments) {
        $body = [string](Get-Prop -Object $comment -Name 'body')
        if (-not [string]::IsNullOrWhiteSpace($body)) {
            $parts.Add($body)
        }
    }
    return ($parts -join "`n")
}

function Get-ExpectedPriority {
    param([string]$Severity)

    # Canonical severity-to-priority mapping
    # (agents/references/incident-to-backlog-router-detail.md).
    switch (([string]$Severity).Trim().ToUpperInvariant()) {
        'SEV1'  { return 'critical' }
        'SEV2'  { return 'high' }
        'SEV3'  { return 'medium' }
        'SEV4'  { return 'low' }
        'SEV5'  { return 'low' }
        default { return $null }
    }
}

function Get-PriorityAlignmentStatus {
    param(
        [string]$Severity,
        [string]$Priority
    )

    # Routing contract: remediation priority must match the canonical map exactly.
    if ([string]::IsNullOrWhiteSpace($Priority)) {
        return "not-required"
    }
    $expected = Get-ExpectedPriority -Severity $Severity
    if ($null -eq $expected) {
        return "fail"
    }
    $normalized = $Priority.Trim().ToLowerInvariant() -replace '^priority:\s*', ''
    if ($normalized -eq $expected) {
        return "pass"
    }
    return "fail"
}

function Get-SeverityBucket([string]$Severity) {
    $normalized = ([string]$Severity).Trim().ToUpperInvariant()
    switch ($normalized) {
        "SEV1" { return "critical-high" }
        "SEV2" { return "critical-high" }
        "SEV3" { return "medium" }
        "SEV4" { return "low" }
        "SEV5" { return "low" }
        default { return "unknown" }
    }
}

function Get-MetricStatus {
    param(
        [double]$Value,
        [double]$WarnThreshold,
        [double]$FailThreshold,
        [string]$Direction
    )

    if ($Direction -eq "lower-is-better") {
        if ($Value -gt $FailThreshold) { return "fail" }
        if ($Value -gt $WarnThreshold) { return "warn" }
        return "pass"
    }

    if ($Value -lt $FailThreshold) { return "fail" }
    if ($Value -lt $WarnThreshold) { return "warn" }
    return "pass"
}

function Get-Median([double[]]$Values) {
    if ($Values.Count -eq 0) {
        return 0.0
    }
    $sorted = @($Values | Sort-Object)
    $middle = [int][math]::Floor($sorted.Count / 2)
    if ($sorted.Count % 2 -eq 0) {
        return ($sorted[$middle - 1] + $sorted[$middle]) / 2.0
    }
    return $sorted[$middle]
}

function Get-BusinessHoursBetween {
    param(
        [datetime]$Start,
        [datetime]$End
    )

    if ($End -le $Start) {
        return 0.0
    }
    $hours = 0.0
    $cursor = $Start
    while ($cursor -lt $End) {
        # Split at midnight so a segment spanning a weekend boundary is attributed
        # to the correct day (for example Friday 23:30 to Saturday 00:30 is 0.5 hours).
        $nextMidnight = $cursor.Date.AddDays(1)
        $segmentEnd = if ($nextMidnight -lt $End) { $nextMidnight } else { $End }
        if ($cursor.DayOfWeek -ne [System.DayOfWeek]::Saturday -and $cursor.DayOfWeek -ne [System.DayOfWeek]::Sunday) {
            $hours += ($segmentEnd - $cursor).TotalHours
        }
        $cursor = $segmentEnd
    }
    return $hours
}

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
$jsonDocument = [System.Text.Json.JsonDocument]::Parse($raw)
if ($jsonDocument.RootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Array) {
    throw "Input must be a JSON array of incident records."
}
$incidents = @($raw | ConvertFrom-Json -Depth 100)
if ($incidents.Count -eq 0) {
    throw "Input must contain at least one incident record."
}

$issueTextCache = @{}
if ($EnableOnlineVerification) {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "EnableOnlineVerification requires gh CLI."
    }
    & gh auth status 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "EnableOnlineVerification requires authenticated gh CLI access."
    }
}

# Optional portfolio-area taxonomy: when supplied, affected_service must match a known area.
$areaTaxonomy = $null
if (-not [string]::IsNullOrWhiteSpace($AreaTaxonomyPath)) {
    if (-not (Test-Path -LiteralPath $AreaTaxonomyPath)) {
        throw "Area taxonomy file not found: $AreaTaxonomyPath"
    }
    $taxonomyRaw = Get-Content -LiteralPath $AreaTaxonomyPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20
    $areaTaxonomy = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($area in @($taxonomyRaw)) {
        $areaText = ([string]$area).Trim()
        if (-not [string]::IsNullOrWhiteSpace($areaText)) {
            [void]$areaTaxonomy.Add($areaText)
        }
    }
}

$findings = [System.Collections.Generic.List[object]]::new()
$latencies = [System.Collections.Generic.List[double]]::new()
$seenIncidentIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

$linkedCount = 0
$criticalHighClosedCount = 0
$criticalHighClosedVerifiedCount = 0
$repeatWithoutVerificationCount = 0
$latencyExpectedCount = 0

for ($index = 0; $index -lt $incidents.Count; $index++) {
    $incident = $incidents[$index]

    $rawIncidentId = [string](Get-Prop -Object $incident -Name 'incident_id')
    $idMissing = [string]::IsNullOrWhiteSpace($rawIncidentId)
    if ($idMissing) {
        # Deterministic placeholder (position-based, never random) so identical inputs score identically.
        $incidentId = "MISSING-ID-$($index + 1)"
    } else {
        $incidentId = $rawIncidentId.Trim()
    }

    $isDuplicateId = $false
    if (-not $idMissing) {
        if (-not $seenIncidentIds.Add($incidentId)) {
            $isDuplicateId = $true
        }
    }

    $severity = ([string](Get-Prop -Object $incident -Name 'severity')).Trim().ToUpperInvariant()
    $severityBucket = Get-SeverityBucket -Severity $severity
    $isCriticalHigh = $severityBucket -eq "critical-high"
    $severityUnknown = $severityBucket -eq "unknown"

    $detectedAt = ConvertTo-SafeUtcDateTime -Value (Get-Prop -Object $incident -Name 'detected_at')
    $remediationCreatedAt = ConvertTo-SafeUtcDateTime -Value (Get-Prop -Object $incident -Name 'remediation_created_at')
    $statusValue = ([string](Get-Prop -Object $incident -Name 'status')).Trim().ToLowerInvariant()
    $knownStatuses = @('open', 'investigating', 'identified', 'monitoring', 'mitigated', 'resolved', 'closed')
    $closureStatuses = @('resolved', 'closed')
    $statusValid = $knownStatuses -contains $statusValue
    $isClosed = $closureStatuses -contains $statusValue

    $remediationLink = [string](Get-Prop -Object $incident -Name 'remediation_issue_url')
    $verificationLink = [string](Get-Prop -Object $incident -Name 'verification_artifact_url')
    $owner = [string](Get-Prop -Object $incident -Name 'owner')
    $service = [string](Get-Prop -Object $incident -Name 'affected_service')
    $customerImpact = [string](Get-Prop -Object $incident -Name 'customer_impact')
    $rootCauseSummary = [string](Get-Prop -Object $incident -Name 'root_cause_summary')
    $remediationPriority = [string](Get-Prop -Object $incident -Name 'remediation_priority')
    $repeatResult = Get-SafeBoolResult -Value (Get-Prop -Object $incident -Name 'repeat_without_prior_verification')
    $repeatNoVerification = $repeatResult.Value
    $repeatFlagValid = $repeatResult.Valid

    # Remediation linkage must point to a GitHub issue/PR.
    $hasRemediationLink = Test-GitHubIssueOrPrUrl -Url $remediationLink
    if ($hasRemediationLink) {
        $linkedCount++
    }

    if ($repeatNoVerification) {
        $repeatWithoutVerificationCount++
    }

    $hasRequiredCoreMetadata = -not [string]::IsNullOrWhiteSpace($owner) -and
        -not [string]::IsNullOrWhiteSpace($service) -and
        -not [string]::IsNullOrWhiteSpace($customerImpact)

    # When a taxonomy is supplied, the service/area must match a known portfolio area.
    $areaValid = $true
    if ($null -ne $areaTaxonomy) {
        $areaValid = (-not [string]::IsNullOrWhiteSpace($service)) -and $areaTaxonomy.Contains($service.Trim())
    }

    $requiresRootCause = $isCriticalHigh
    $hasRootCause = -not [string]::IsNullOrWhiteSpace($rootCauseSummary)
    $rootCauseStatus = if ($requiresRootCause -and -not $hasRootCause) { "fail" } elseif ($requiresRootCause) { "pass" } else { "not-required" }

    # Priority mapping is mandatory for a routed (linked) incident: a missing priority
    # cannot be confirmed to align with severity and fails, like a mismatch.
    $priorityStatus = if ($hasRemediationLink) {
        if ([string]::IsNullOrWhiteSpace($remediationPriority)) {
            "fail"
        } else {
            Get-PriorityAlignmentStatus -Severity $severity -Priority $remediationPriority
        }
    } else {
        "not-required"
    }

    # Detection timestamp must be present and chronologically valid.
    $detectionValid = $null -ne $detectedAt
    $timestampReversed = $false
    if ($null -ne $detectedAt -and $null -ne $remediationCreatedAt -and $remediationCreatedAt -lt $detectedAt) {
        $timestampReversed = $true
    }

    $onlineLinkageStatus = "not-run"
    $onlineRemediationMentionsIncident = $false
    $onlineVerificationAssociated = $false
    $verificationImmutable = Test-ImmutableVerificationArtifactUrl -Url $verificationLink
    if ($EnableOnlineVerification -and $hasRemediationLink) {
        $remediationRef = Parse-GitHubIssueOrPrUrl -Url $remediationLink
        if ($null -eq $remediationRef) {
            $onlineLinkageStatus = "fail"
        } else {
            try {
                $cacheKey = "$($remediationRef.repo)#$($remediationRef.number)"
                if (-not $issueTextCache.ContainsKey($cacheKey)) {
                    $issueTextCache[$cacheKey] = Get-IssueOrPrEvidenceText -Repo $remediationRef.repo -Number $remediationRef.number
                }
                $remediationEvidenceText = [string]$issueTextCache[$cacheKey]
                if (-not [string]::IsNullOrWhiteSpace($incidentId)) {
                    $onlineRemediationMentionsIncident = $remediationEvidenceText.IndexOf($incidentId, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
                }

                if ($isClosed) {
                    if ($verificationImmutable -and -not [string]::IsNullOrWhiteSpace($verificationLink)) {
                        $onlineVerificationAssociated = $remediationEvidenceText.IndexOf($verificationLink.Trim(), [System.StringComparison]::OrdinalIgnoreCase) -ge 0
                    } else {
                        $onlineVerificationAssociated = $false
                    }
                    if ($onlineRemediationMentionsIncident -and $verificationImmutable -and $onlineVerificationAssociated) {
                        $onlineLinkageStatus = "pass"
                    } else {
                        $onlineLinkageStatus = "fail"
                    }
                } else {
                    $onlineLinkageStatus = if ($onlineRemediationMentionsIncident) { "pass" } else { "fail" }
                }
            } catch {
                $onlineLinkageStatus = "fail"
            }
        }
    }

    # A verification artifact is required for every closure, not only high/critical.
    $hasVerificationArtifact = Test-GitHubArtifactUrl -Url $verificationLink
    if ($isClosed) {
        if ($hasVerificationArtifact) {
            $verificationStatus = "pass"
        } else {
            $verificationStatus = "fail"
        }
        if ($EnableOnlineVerification -and $onlineLinkageStatus -eq "fail") {
            $verificationStatus = "fail"
        }
        if ($isCriticalHigh) {
            $criticalHighClosedCount++
            if ($verificationStatus -eq "pass") {
                $criticalHighClosedVerifiedCount++
            }
        }
    } else {
        $verificationStatus = "not-required"
    }

    $latencyBusinessDays = $null
    $mitigationTimestampMissing = $false
    if ($hasRemediationLink) {
        $latencyExpectedCount++
        # A linked (mitigated) incident must carry a valid mitigation timestamp (spec: field quality).
        if ($detectionValid -and $null -ne $remediationCreatedAt -and -not $timestampReversed) {
            $latencyBusinessDays = [math]::Round((Get-BusinessHoursBetween -Start $detectedAt -End $remediationCreatedAt) / 24.0, 3)
            $latencies.Add($latencyBusinessDays)
        } else {
            $mitigationTimestampMissing = $true
        }
    }
    if ($statusValue -eq "mitigated") {
        if (-not $detectionValid -or $null -eq $remediationCreatedAt -or $timestampReversed) {
            $mitigationTimestampMissing = $true
        }
    }

    $mitigationTimestampRequired = $hasRemediationLink -or ($statusValue -eq "mitigated")
    $mitigationTimestampValid = if ($mitigationTimestampRequired) { -not $mitigationTimestampMissing } else { $true }

    $findingStatus = "pass"
    if ($idMissing -or
        $isDuplicateId -or
        $severityUnknown -or
        -not $statusValid -or
        -not $repeatFlagValid -or
        -not $detectionValid -or
        $timestampReversed -or
        $mitigationTimestampMissing -or
        -not $hasRequiredCoreMetadata -or
        -not $areaValid -or
        ($EnableOnlineVerification -and $onlineLinkageStatus -eq "fail") -or
        $rootCauseStatus -eq "fail" -or
        $priorityStatus -eq "fail" -or
        $verificationStatus -eq "fail") {
        $findingStatus = "fail"
    } elseif (-not $hasRemediationLink -or $repeatNoVerification) {
        # A missing remediation link is governed by the aggregate linkage metric (which has a
        # reachable warn band), so an individual unlinked record is a warn, not a hard fail.
        $findingStatus = "warn"
    }

    $findings.Add([pscustomobject]([ordered]@{
            incident_id = $incidentId
            severity = $severity
            affected_service = $service
            status = $findingStatus
            id_valid = (-not $idMissing -and -not $isDuplicateId)
            status_valid = $statusValid
            severity_valid = (-not $severityUnknown)
            detection_timestamp_valid = $detectionValid
            timestamp_chronological = (-not $timestampReversed)
            mitigation_timestamp_valid = $mitigationTimestampValid
            metadata_complete = $hasRequiredCoreMetadata
            area_valid = $areaValid
            remediation_linked = $hasRemediationLink
            remediation_reference = $remediationLink
            remediation_priority = $remediationPriority
            recommended_priority = (Get-ExpectedPriority -Severity $severity)
            priority_status = $priorityStatus
            verification_status = $verificationStatus
            verification_reference = $verificationLink
            verification_immutable = $verificationImmutable
            online_linkage_status = $onlineLinkageStatus
            online_remediation_mentions_incident = $onlineRemediationMentionsIncident
            online_verification_associated = $onlineVerificationAssociated
            root_cause_status = $rootCauseStatus
            repeat_without_prior_verification = $repeatNoVerification
            repeat_flag_valid = $repeatFlagValid
            latency_business_days = $latencyBusinessDays
        }))
}

$totalIncidents = $incidents.Count
$linkedPct = if ($totalIncidents -gt 0) { [math]::Round(($linkedCount * 100.0) / $totalIncidents, 2) } else { 0.0 }
$verifiedPct = if ($criticalHighClosedCount -gt 0) { [math]::Round(($criticalHighClosedVerifiedCount * 100.0) / $criticalHighClosedCount, 2) } else { 100.0 }
$medianLatencyBusinessDays = [math]::Round((Get-Median -Values @($latencies.ToArray())), 3)

$linkageStatus = Get-MetricStatus -Value $linkedPct -WarnThreshold 100 -FailThreshold 95 -Direction "higher-is-better"
$verificationMetricStatus = Get-MetricStatus -Value $verifiedPct -WarnThreshold 100 -FailThreshold 98 -Direction "higher-is-better"
if ($latencyExpectedCount -gt 0 -and $latencies.Count -lt $latencyExpectedCount) {
    # A remediation link exists but at least one expected latency sample is missing/invalid/
    # reversed: fail closed rather than scoring only the well-formed subset (false green).
    $latencyStatus = "fail"
} else {
    $latencyStatus = Get-MetricStatus -Value $medianLatencyBusinessDays -WarnThreshold 1 -FailThreshold 2 -Direction "lower-is-better"
}
$repeatStatus = if ($repeatWithoutVerificationCount -ge 2) { "fail" } elseif ($repeatWithoutVerificationCount -gt 0) { "warn" } else { "pass" }

$metricStatuses = @($linkageStatus, $verificationMetricStatus, $latencyStatus, $repeatStatus)
$incidentStatuses = @($findings | ForEach-Object { $_.status })
$allStatuses = @($metricStatuses + $incidentStatuses)

$overallStatus = "pass"
if ($allStatuses -contains "fail") {
    $overallStatus = "fail"
} elseif ($allStatuses -contains "warn") {
    $overallStatus = "warn"
}

$summary = [ordered]@{
    generated_at_utc = ConvertTo-IsoUtc -Value (Get-Date)
    input_count = $totalIncidents
    status = $overallStatus
    metrics = [ordered]@{
        routed_incidents_with_remediation_link = [ordered]@{
            value_pct = $linkedPct
            status = $linkageStatus
            target_pct = 100
            warn_below_pct = 100
            fail_below_pct = 95
        }
        verified_closures_high_critical = [ordered]@{
            value_pct = $verifiedPct
            numerator = $criticalHighClosedVerifiedCount
            denominator = $criticalHighClosedCount
            status = $verificationMetricStatus
            target_pct = 100
            warn_below_pct = 100
            fail_below_pct = 98
        }
        median_incident_to_remediation_creation_latency_business_days = [ordered]@{
            value = $medianLatencyBusinessDays
            status = $latencyStatus
            target_business_days_max = 1
            warn_above_business_days = 1
            fail_above_business_days = 2
            sampled_incidents = $latencies.Count
            expected_incidents = $latencyExpectedCount
        }
        repeat_incidents_without_prior_verification = [ordered]@{
            value = $repeatWithoutVerificationCount
            status = $repeatStatus
            target = 0
            warn_above = 0
            fail_at_or_above = 2
        }
    }
    incidents = @($findings)
}

[System.IO.Directory]::CreateDirectory($resolvedOutputDir) | Out-Null

$jsonPath = Join-Path $resolvedOutputDir "incident-routing-verification.json"
$markdownPath = Join-Path $resolvedOutputDir "incident-routing-verification.md"

foreach ($destination in @($jsonPath, $markdownPath)) {
    # Enumerate the parent directory so a pre-existing link entry is detected even when it is a
    # dangling symlink (Test-Path follows the link and returns false for a missing target).
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

$summary | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$md = @()
$md += "# AIDL Incident Routing Verification"
$md += ""
$md += "- Generated at (UTC): $($summary.generated_at_utc)"
$md += "- Overall status: **$($summary.status)**"
$md += "- Incident records: $($summary.input_count)"
$md += ""
$md += "## Metric Scorecard"
$md += ""
$md += "| Metric | Value | Status |"
$md += "|---|---:|---|"
$md += "| Routed incidents with remediation link (%) | $linkedPct | $linkageStatus |"
$md += "| Verified closures (SEV1/SEV2) (%) | $verifiedPct | $verificationMetricStatus |"
$md += "| Median incident-to-remediation creation latency (business days) | $medianLatencyBusinessDays | $latencyStatus |"
$md += "| Repeat incidents without prior verification | $repeatWithoutVerificationCount | $repeatStatus |"
$md += ""
$md += "## Incident Findings"
$md += ""
$md += "| Incident | Severity | Service/Area | Status | Metadata | Remediation | Priority | Verification | Root Cause | Latency (business days) |"
$md += "|---|---|---|---|---|---|---|---|---|---:|"
foreach ($row in @($findings)) {
    $latencyDisplay = if ($null -eq $row.latency_business_days) { "n/a" } else { [string]$row.latency_business_days }
    $md += "| $(Format-MarkdownCell $row.incident_id) | $(Format-MarkdownCell $row.severity) | $(Format-MarkdownCell $row.affected_service) | $(Format-MarkdownCell $row.status) | $($row.metadata_complete) | $($row.remediation_linked) | $(Format-MarkdownCell $row.priority_status) | $(Format-MarkdownCell $row.verification_status) | $(Format-MarkdownCell $row.root_cause_status) | $latencyDisplay |"
}
$md += ""
$md += "## Threshold Contract"
$md += ""
$md += "1. Routed incidents with remediation link: Warn < 100%, Fail < 95%"
$md += "2. Verified closures for SEV1/SEV2: Warn < 100%, Fail < 98%"
$md += "3. Median incident-to-remediation creation latency: Warn > 1 business day, Fail > 2 business days"
$md += "4. Repeat incidents without prior verification: Warn > 0, Fail >= 2"

Set-Content -LiteralPath $markdownPath -Value ($md -join "`n") -Encoding UTF8

Write-Host "AIDL incident routing verification complete."
Write-Host "JSON: $jsonPath"
Write-Host "Markdown: $markdownPath"
Write-Output ($summary | ConvertTo-Json -Depth 20)
