#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Memory hygiene cleanup sweep for the AIDL learning-and-memory pipeline.

.DESCRIPTION
    Implements the cleanup rules for stale items in section 4 of
    docs/specs/aidl-portfolio/sprint-41/learning-promotion-memory-hygiene.md. Given a JSON
    export of memory entries, it flags:
      - hold candidates past their re-review date (evaluation timestamp + a fixed interval) with
        no newer evidence, recommending rejection;
      - entries whose repository file citations no longer resolve (dead references);
      - superseded/dead-citation entries that must be deprecated with a replacement link (or an
        explicit no-replacement rationale) rather than deleted outright;
      - duplicate entries (same normalized subject+fact), retaining the entry with the most
        recent evidence_recorded_at (tie-break: lexicographically greatest id) and recommending
        consolidation of the rest.
    The sweep is deterministic and offline: repository file citations are checked against the
    working tree; URL citations are reported as requiring online verification (not resolved
    here). Stale evaluation and the report timestamp use -AsOf so a fixed value is reproducible.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$OutputDir = [System.IO.Path]::Combine("artifacts", "aidl-memory-hygiene-sweep"),

    [int]$ReviewAfterDays = 30,

    [string]$AsOf = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($ReviewAfterDays -le 0) {
    throw "ReviewAfterDays must be a positive integer (got $ReviewAfterDays)."
}

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

function Get-FirstProp {
    # Returns the first non-null/non-blank property among a list of accepted field-name aliases,
    # so the sweep can consume either the documented memory-entry schema or the learning
    # promotion pipeline's field names (candidate_id, decision/recommendation, audited_at_utc).
    param([object]$Object, [string[]]$Names)

    foreach ($name in $Names) {
        $value = Get-Prop -Object $Object -Name $name
        if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
            return $value
        }
    }
    return $null
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

function Test-CitationResolves {
    # Classifies a citation and, for repository code references, checks whether the file exists
    # within the repository as a leaf file. Returns @{ kind = 'url'|'file'|'other'; resolves }.
    # Only citations that look like code references (a path with a :line[/range] suffix or a file
    # extension, containing no whitespace) are treated as repository files; prose such as
    # "owner/repo -> PRs #312" is classified 'other'. Symlinks are resolved before the
    # containment check so a link pointing outside the repository is not counted as resolved.
    param([string]$Citation, [string]$RepoRoot)

    $text = ([string]$Citation).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return [pscustomobject]@{ kind = 'other'; resolves = $false }
    }
    # Strip surrounding quotes/backticks before classification.
    $text = $text.Trim([char[]]@('`', '"', "'")).Trim()
    if ($text -match '^(https?://|www\.)') {
        return [pscustomobject]@{ kind = 'url'; resolves = $false }
    }
    if ($text -match '\s') {
        return [pscustomobject]@{ kind = 'other'; resolves = $false }
    }
    $hasLine = $text -match ':\d+(-\d+)?$'
    $pathPart = ($text -replace ':\d+(-\d+)?$', '').Trim()
    $hasExt = $pathPart -match '\.[A-Za-z0-9]{1,10}$'
    if (-not ($hasLine -or $hasExt)) {
        return [pscustomobject]@{ kind = 'other'; resolves = $false }
    }
    $normalized = $pathPart -replace '/', [System.IO.Path]::DirectorySeparatorChar
    $comparison = if ($IsWindows) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }
    try {
        $requested = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $normalized))
    } catch {
        return [pscustomobject]@{ kind = 'file'; resolves = $false }
    }
    # Resolve symlinks/junctions on the candidate before enforcing containment so a link to a
    # file outside the repository is not accepted as an in-repository citation.
    $candidate = Get-CanonicalRealPath -Path $requested
    $rootTrimmed = $RepoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $boundary = $rootTrimmed + [System.IO.Path]::DirectorySeparatorChar
    $inside = $candidate.Equals($rootTrimmed, $comparison) -or $candidate.StartsWith($boundary, $comparison)
    $resolves = $inside -and (Test-Path -LiteralPath $candidate -PathType Leaf)
    return [pscustomobject]@{ kind = 'file'; resolves = [bool]$resolves }
}

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input file not found: $InputPath"
}

$asOfDt = if ([string]::IsNullOrWhiteSpace($AsOf)) { (Get-Date).ToUniversalTime() } else { ConvertTo-SafeUtcDateTime -Value $AsOf }
if ($null -eq $asOfDt) {
    throw "The -AsOf value is not a valid timestamp: $AsOf"
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

$raw = Get-Content -LiteralPath $InputPath -Raw -Encoding UTF8
$parsed = $raw | ConvertFrom-Json -NoEnumerate
if ($null -eq $parsed) {
    throw "Input file is empty or not valid JSON: $InputPath"
}
if ($parsed -isnot [System.Collections.IEnumerable] -or $parsed -is [string] -or
    $parsed -is [System.Management.Automation.PSCustomObject]) {
    throw "Input must be a top-level JSON array of memory entries: $InputPath"
}
$entries = @($parsed)

# First pass: index entries for duplicate detection by normalized (subject, fact).
$dupGroups = @{}
$entryIndex = 0
$entryMeta = [System.Collections.Generic.List[object]]::new()
$idCounts = @{}
$allowedStatuses = @("promote", "hold", "reject")
foreach ($entry in $entries) {
    $entryIndex++
    $id = [string](Get-FirstProp -Object $entry -Names @("id", "candidate_id"))
    $subject = [string](Get-Prop -Object $entry -Name "subject")
    $fact = [string](Get-Prop -Object $entry -Name "fact")
    $statusVal = ([string](Get-FirstProp -Object $entry -Names @("status", "decision", "recommendation"))).Trim().ToLowerInvariant()
    $evidenceAt = ConvertTo-SafeUtcDateTime -Value (Get-FirstProp -Object $entry -Names @("evidence_recorded_at", "evidence_recorded_at_utc"))
    # Build an injective duplicate key so values containing the delimiter cannot collide
    # (e.g. subject "a|b"/fact "c" must not equal subject "a"/fact "b|c").
    $dupKey = (@($subject.Trim().ToLowerInvariant(), $fact.Trim().ToLowerInvariant()) | ConvertTo-Json -Compress)
    if (-not [string]::IsNullOrWhiteSpace($id)) {
        $idKey = $id.Trim()
        if ($idCounts.ContainsKey($idKey)) { $idCounts[$idKey]++ } else { $idCounts[$idKey] = 1 }
    }
    $meta = [pscustomobject]@{
        index = $entryIndex
        id = $id
        dupKey = $dupKey
        evidenceAt = $evidenceAt
        statusValid = ($allowedStatuses -contains $statusVal)
    }
    $entryMeta.Add($meta)
}

# Ids appearing more than once are a data-integrity violation and are rejected as invalid, so
# duplicate consolidation never has to break an order-dependent tie between same-id records.
$duplicateIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($key in $idCounts.Keys) {
    if ($idCounts[$key] -gt 1) { [void]$duplicateIds.Add($key) }
}

# Duplicate grouping is restricted to well-formed entries (unique id, subject, fact, valid
# status) so a malformed record cannot become the retained winner over a valid duplicate.
foreach ($meta in $entryMeta) {
    $entry = $entries[$meta.index - 1]
    $subject = [string](Get-Prop -Object $entry -Name "subject")
    $fact = [string](Get-Prop -Object $entry -Name "fact")
    $idTrim = if ([string]::IsNullOrWhiteSpace($meta.id)) { "" } else { $meta.id.Trim() }
    if ([string]::IsNullOrWhiteSpace($idTrim) -or $duplicateIds.Contains($idTrim)) { continue }
    if ([string]::IsNullOrWhiteSpace($subject) -or [string]::IsNullOrWhiteSpace($fact) -or -not $meta.statusValid) { continue }
    if (-not $dupGroups.ContainsKey($meta.dupKey)) {
        $dupGroups[$meta.dupKey] = [System.Collections.Generic.List[object]]::new()
    }
    $dupGroups[$meta.dupKey].Add($meta)
}

# Determine the retained entry per duplicate group (most recent evidence_recorded_at; tie-break
# the lexicographically greatest id, then the smallest index for a fully deterministic result).
$retainedByKey = @{}
foreach ($key in $dupGroups.Keys) {
    $group = @($dupGroups[$key])
    if ($group.Count -lt 2) { continue }
    $winner = $null
    foreach ($member in $group) {
        if ($null -eq $winner) { $winner = $member; continue }
        $memberEv = if ($null -ne $member.evidenceAt) { $member.evidenceAt } else { [datetime]::MinValue }
        $winnerEv = if ($null -ne $winner.evidenceAt) { $winner.evidenceAt } else { [datetime]::MinValue }
        if ($memberEv -gt $winnerEv) {
            $winner = $member
        } elseif ($memberEv -eq $winnerEv) {
            $idCompare = [string]::CompareOrdinal([string]$member.id, [string]$winner.id)
            if ($idCompare -gt 0 -or ($idCompare -eq 0 -and $member.index -lt $winner.index)) {
                $winner = $member
            }
        }
    }
    $retainedByKey[$key] = $winner.index
}

$flagged = [System.Collections.Generic.List[object]]::new()
$onlineCheckEntries = [System.Collections.Generic.List[object]]::new()
$urlCitationCount = 0
$counts = [ordered]@{
    invalid_entry = 0
    reject_stale = 0
    dead_citation = 0
    needs_replacement_or_rationale = 0
    deprecate_with_replacement = 0
    remove_with_rationale = 0
    consolidate_duplicate = 0
    ok = 0
}
$reviewInterval = [timespan]::FromDays($ReviewAfterDays)

foreach ($meta in $entryMeta) {
    $entry = $entries[$meta.index - 1]
    $id = $meta.id
    $subject = [string](Get-Prop -Object $entry -Name "subject")
    $fact = [string](Get-Prop -Object $entry -Name "fact")
    $status = ([string](Get-FirstProp -Object $entry -Names @("status", "decision", "recommendation"))).Trim().ToLowerInvariant()
    $decidedAt = ConvertTo-SafeUtcDateTime -Value (Get-FirstProp -Object $entry -Names @("decided_at", "audited_at_utc", "decided_at_utc"))
    $evidenceAt = $meta.evidenceAt
    $supersededRaw = Get-Prop -Object $entry -Name "superseded"
    $superseded = ($supersededRaw -is [bool]) -and [bool]$supersededRaw
    $replacedBy = [string](Get-Prop -Object $entry -Name "replaced_by")
    $noReplacementRationale = [string](Get-Prop -Object $entry -Name "no_replacement_rationale")
    $rawCitations = Get-Prop -Object $entry -Name "citations"
    $citations = if ($null -ne $rawCitations) { @($rawCitations) } else { @() }

    $actions = [System.Collections.Generic.List[string]]::new()
    $reasons = [System.Collections.Generic.List[string]]::new()

    # Every field required by the hygiene schema must be present and valid; a malformed entry
    # (even with an id) is flagged invalid rather than silently counted ok.
    $missingFields = [System.Collections.Generic.List[string]]::new()
    if ([string]::IsNullOrWhiteSpace($id)) { $missingFields.Add("id") }
    if ([string]::IsNullOrWhiteSpace($subject)) { $missingFields.Add("subject") }
    if ([string]::IsNullOrWhiteSpace($fact)) { $missingFields.Add("fact") }
    if ([string]::IsNullOrWhiteSpace($status)) { $missingFields.Add("status") }
    if ($missingFields.Count -gt 0) {
        $actions.Add("invalid-entry")
        $reasons.Add("missing required field(s): $($missingFields -join ', ')")
    }
    # An unsupported status value (not promote/hold/reject) is invalid, so a typo cannot bypass
    # stale-hold processing and yield a clean report.
    if (-not [string]::IsNullOrWhiteSpace($status) -and ($allowedStatuses -notcontains $status)) {
        $actions.Add("invalid-entry")
        $reasons.Add("unsupported status '$status' (expected promote/hold/reject)")
    }
    # A duplicated id is a data-integrity violation.
    if (-not [string]::IsNullOrWhiteSpace($id) -and $duplicateIds.Contains($id.Trim())) {
        $actions.Add("invalid-entry")
        $reasons.Add("duplicate id (memory entry ids must be unique)")
    }

    # Stale hold: past the re-review date with no newer evidence. A hold whose decided_at is
    # missing or malformed cannot be aged, so it is flagged (not silently skipped) to avoid
    # evading cleanup indefinitely.
    if ($status -eq "hold") {
        if ($null -eq $decidedAt) {
            $actions.Add("reject-stale")
            $reasons.Add("hold without a valid decided_at cannot be aged for re-review; treat as stale")
        } else {
            # Evidence only counts as "newer" when it falls after decided_at and at or before the
            # evaluation time, so a future-dated evidence value cannot clear a stale hold.
            $hasNewerEvidence = ($null -ne $evidenceAt) -and ($evidenceAt -gt $decidedAt) -and ($evidenceAt -le $asOfDt)
            if (-not $hasNewerEvidence -and (($asOfDt - $decidedAt) -gt $reviewInterval)) {
                $actions.Add("reject-stale")
                $reasons.Add("hold past the $ReviewAfterDays-day re-review date with no newer evidence")
            }
        }
    }

    # Dead repository file citations, and URL citations pending online verification.
    $deadFileCitations = [System.Collections.Generic.List[string]]::new()
    $urlCitations = [System.Collections.Generic.List[string]]::new()
    foreach ($citation in $citations) {
        $result = Test-CitationResolves -Citation ([string]$citation) -RepoRoot $resolvedRepoRoot
        if ($result.kind -eq "file" -and -not $result.resolves) {
            $deadFileCitations.Add(([string]$citation).Trim())
        } elseif ($result.kind -eq "url") {
            $urlCitations.Add(([string]$citation).Trim())
        }
    }
    if ($urlCitations.Count -gt 0) {
        $urlCitationCount += $urlCitations.Count
        $onlineCheckEntries.Add([pscustomobject]([ordered]@{
                    id = if ([string]::IsNullOrWhiteSpace($id)) { "(missing-id)" } else { $id }
                    url_citations = @($urlCitations)
                }))
    }
    $hasDeadCitation = $deadFileCitations.Count -gt 0
    if ($hasDeadCitation) {
        $actions.Add("dead-citation")
        $reasons.Add("unresolved repository file citation(s): $($deadFileCitations -join '; ')")
    }

    # Deprecation governance: a superseded or dead-citation entry must carry a replacement link
    # or an explicit no-replacement rationale before removal.
    if ($superseded -or $hasDeadCitation) {
        if (-not [string]::IsNullOrWhiteSpace($replacedBy)) {
            $actions.Add("deprecate-with-replacement")
            $reasons.Add("deprecate in favor of replacement: $($replacedBy.Trim())")
        } elseif (-not [string]::IsNullOrWhiteSpace($noReplacementRationale)) {
            $actions.Add("remove-with-rationale")
            $reasons.Add("removal permitted with recorded no-replacement rationale")
        } else {
            $actions.Add("needs-replacement-or-rationale")
            $reasons.Add("cannot be removed without a replaced_by link or a no_replacement_rationale")
        }
    }

    # Duplicate consolidation: non-retained members of a duplicate group (compared by unique
    # entry index so duplicate records sharing the same id are still consolidated).
    if ($retainedByKey.ContainsKey($meta.dupKey) -and $retainedByKey[$meta.dupKey] -ne $meta.index) {
        $actions.Add("consolidate-duplicate")
        $reasons.Add("duplicate entry; retained the most recent evidence (tie-break greatest id)")
    }

    if ($actions.Count -eq 0) {
        $counts.ok++
        continue
    }

    # Count every distinct action so the summary is complete; retain primary_action for display.
    foreach ($action in ($actions | Select-Object -Unique)) {
        switch ($action) {
            "invalid-entry" { $counts.invalid_entry++ }
            "reject-stale" { $counts.reject_stale++ }
            "dead-citation" { $counts.dead_citation++ }
            "needs-replacement-or-rationale" { $counts.needs_replacement_or_rationale++ }
            "deprecate-with-replacement" { $counts.deprecate_with_replacement++ }
            "remove-with-rationale" { $counts.remove_with_rationale++ }
            "consolidate-duplicate" { $counts.consolidate_duplicate++ }
        }
    }
    $primary = @("invalid-entry", "reject-stale", "dead-citation", "needs-replacement-or-rationale", "deprecate-with-replacement", "remove-with-rationale", "consolidate-duplicate") |
        Where-Object { $actions -contains $_ } | Select-Object -First 1

    $flagged.Add([pscustomobject]([ordered]@{
                id = if ([string]::IsNullOrWhiteSpace($id)) { "(missing-id)" } else { $id }
                status = $status
                primary_action = $primary
                actions = @($actions | Select-Object -Unique)
                reasons = @($reasons)
            }))
}

$report = [ordered]@{
    as_of_utc = ConvertTo-IsoUtc -Value $asOfDt
    review_after_days = $ReviewAfterDays
    input_count = $entries.Count
    flagged_count = $flagged.Count
    url_citations_pending_online_check = $urlCitationCount
    summary = $counts
    flagged = @($flagged)
    online_check_entries = @($onlineCheckEntries)
}

[System.IO.Directory]::CreateDirectory($resolvedOutputDir) | Out-Null

$jsonPath = Join-Path $resolvedOutputDir "memory-hygiene-report.json"
$markdownPath = Join-Path $resolvedOutputDir "memory-hygiene-report.md"

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

$report | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$md = @()
$md += "# AIDL Memory Hygiene Sweep"
$md += ""
$md += "- As of (UTC): $($report.as_of_utc)"
$md += "- Entries scanned: $($report.input_count)"
$md += "- Flagged: $($report.flagged_count)"
$md += "- URL citations pending online verification: $($report.url_citations_pending_online_check)"
$md += ""
$md += "| Summary | Count |"
$md += "|---|---:|"
foreach ($prop in $counts.GetEnumerator()) {
    $md += "| $($prop.Key) | $($prop.Value) |"
}
$md += ""
$md += "## Flagged entries"
$md += ""
if ($flagged.Count -eq 0) {
    $md += "_No cleanup actions recommended._"
} else {
    $md += "| Entry | Status | Primary action | Reasons |"
    $md += "|---|---|---|---|"
    foreach ($f in @($flagged)) {
        $reasonText = (($f.reasons -join '; ') -replace '\|', '\|')
        $md += "| $($f.id) | $($f.status) | $($f.primary_action) | $reasonText |"
    }
}
Set-Content -LiteralPath $markdownPath -Value ($md -join "`n") -Encoding UTF8

Write-Host "AIDL memory hygiene sweep complete."
Write-Host "Flagged $($flagged.Count) of $($entries.Count) entries."
Write-Host "JSON: $jsonPath"
Write-Output ($report | ConvertTo-Json -Depth 20)
