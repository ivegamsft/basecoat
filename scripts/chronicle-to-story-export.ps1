#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Exports chronicle/session learnings into a story update packet.

.DESCRIPTION
    Builds markdown story updates from structured session history input,
    supports append/update write modes, emits issue-ready learning items,
    and optionally creates memory-promotion suggestions with dedupe checks.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$StoryPath = "docs\operations\repo-story.md",

    [ValidateSet("append", "update")]
    [string]$Mode = "append",

    [string]$OutputDir = "test-results\chronicle-story-export",

    [switch]$IncludeMemorySuggestions
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-Key {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    $normalized = $Value.ToLowerInvariant()
    $normalized = [regex]::Replace($normalized, "[^a-z0-9]+", "-")
    return $normalized.Trim("-")
}

function Ensure-RepoScopedPath {
    param(
        [string]$RootPath,
        [string]$RelativeOrAbsolutePath,
        [string]$Label
    )

    $candidate = if ([System.IO.Path]::IsPathRooted($RelativeOrAbsolutePath)) {
        $RelativeOrAbsolutePath
    } else {
        Join-Path $RootPath $RelativeOrAbsolutePath
    }
    $resolved = [System.IO.Path]::GetFullPath($candidate)
    if (-not $resolved.StartsWith($RootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label must resolve inside repository root. Resolved: $resolved"
    }

    return $resolved
}

function Normalize-Array {
    param($Items)
    $result = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @($Items)) {
        $value = [string]$item
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $result.Add($value.Trim())
        }
    }

    return [string[]]$result.ToArray()
}

function Get-OptionalString {
    param(
        $Object,
        [string]$PropertyName
    )

    if ($null -eq $Object) {
        return ""
    }
    if ($Object.PSObject.Properties.Name -contains $PropertyName) {
        return [string]$Object.$PropertyName
    }

    return ""
}

function Get-OptionalArray {
    param(
        $Object,
        [string]$PropertyName
    )

    if ($null -eq $Object) {
        return @()
    }
    if ($Object.PSObject.Properties.Name -contains $PropertyName) {
        return @($Object.$PropertyName)
    }

    return @()
}

if (-not (Test-Path -Path $InputPath)) {
    throw "InputPath not found: $InputPath"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$storyAbsolutePath = Ensure-RepoScopedPath -RootPath $repoRoot -RelativeOrAbsolutePath $StoryPath -Label "StoryPath"
$outputAbsoluteDir = Ensure-RepoScopedPath -RootPath $repoRoot -RelativeOrAbsolutePath $OutputDir -Label "OutputDir"
New-Item -Path $outputAbsoluteDir -ItemType Directory -Force | Out-Null

$payload = Get-Content -Path $InputPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
if ($payload -is [System.Array]) {
    if ($payload.Count -eq 0) {
        throw "Input payload array is empty."
    }
    $payload = $payload[0]
}

$cycleId = Get-OptionalString -Object $payload -PropertyName "cycle_id"
if ([string]::IsNullOrWhiteSpace($cycleId)) {
    $cycleId = "cycle-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}
$cycleKey = Normalize-Key $cycleId
if ([string]::IsNullOrWhiteSpace($cycleKey)) {
    $cycleKey = "cycle-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

$storyTitle = Get-OptionalString -Object $payload -PropertyName "story_title"
if ([string]::IsNullOrWhiteSpace($storyTitle)) {
    $storyTitle = "Repository Story Chronicle"
}

$sessionRefs = @(Normalize-Array (Get-OptionalArray -Object $payload -PropertyName "source_sessions"))
$references = @(Normalize-Array (Get-OptionalArray -Object $payload -PropertyName "references"))
$timeline = @(Get-OptionalArray -Object $payload -PropertyName "timeline")
$learningsInput = @(Get-OptionalArray -Object $payload -PropertyName "learnings")

if ($learningsInput.Count -eq 0) {
    throw "Input payload must include at least one learning item."
}

$existingStoryContent = ""
if (Test-Path -Path $storyAbsolutePath) {
    $existingStoryContent = Get-Content -Path $storyAbsolutePath -Raw -Encoding UTF8
}

$existingLearningKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($match in [regex]::Matches($existingStoryContent, "\[learning:([a-z0-9-]+)\]")) {
    [void]$existingLearningKeys.Add($match.Groups[1].Value)
}

$dedupeKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$learningRows = [System.Collections.Generic.List[object]]::new()
$issueRows = [System.Collections.Generic.List[object]]::new()
$memoryRows = [System.Collections.Generic.List[object]]::new()

foreach ($learning in $learningsInput) {
    $title = Get-OptionalString -Object $learning -PropertyName "title"
    $detail = Get-OptionalString -Object $learning -PropertyName "detail"
    $action = Get-OptionalString -Object $learning -PropertyName "action"
    $issueTitle = Get-OptionalString -Object $learning -PropertyName "issue_title"

    if ([string]::IsNullOrWhiteSpace($title) -and [string]::IsNullOrWhiteSpace($detail)) {
        continue
    }

    $keySource = if (-not [string]::IsNullOrWhiteSpace($title)) { $title } else { $detail }
    $learningKey = Normalize-Key $keySource
    if ([string]::IsNullOrWhiteSpace($learningKey)) {
        $learningKey = "learning-" + [Guid]::NewGuid().ToString("N").Substring(0, 8)
    }

    if ($dedupeKeys.Contains($learningKey)) {
        continue
    }
    [void]$dedupeKeys.Add($learningKey)

    $alreadyInStory = $existingLearningKeys.Contains($learningKey)
    $learningRows.Add([pscustomobject]@{
            key = $learningKey
            title = $title
            detail = $detail
            action = $action
            issue_title = $issueTitle
            already_in_story = $alreadyInStory
        })

    if (-not [string]::IsNullOrWhiteSpace($issueTitle) -or -not [string]::IsNullOrWhiteSpace($action)) {
        $issueRows.Add([pscustomobject]@{
                issue_title = if ([string]::IsNullOrWhiteSpace($issueTitle)) { "Follow-up: $title" } else { $issueTitle }
                context = if ([string]::IsNullOrWhiteSpace($detail)) { $title } else { $detail }
                action = $action
                learning_key = $learningKey
            })
    }

    if ($IncludeMemorySuggestions -and -not $alreadyInStory) {
        $memoryRows.Add([pscustomobject]@{
                subject = "learnings:$learningKey"
                fact = if ([string]::IsNullOrWhiteSpace($detail)) { $title } else { $detail }
                citations = @($references)
                reason = "Chronicle-exported learning candidate from cycle $cycleId."
                dedupe_key = $learningKey
            })
    }
}

if ($learningRows.Count -eq 0) {
    throw "No valid learning entries were produced after normalization."
}

$sectionLines = [System.Collections.Generic.List[string]]::new()
$sectionLines.Add("<!-- CHRONICLE:START $cycleKey -->")
$sectionLines.Add("## Chronicle Update — $cycleId")
$sectionLines.Add("")
$sectionLines.Add("- **Generated**: " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz"))
$sectionLines.Add("- **Mode**: $Mode")
$sectionLines.Add("")

$sectionLines.Add("### Session Sources")
if ($sessionRefs.Count -eq 0) {
    $sectionLines.Add("- (none provided)")
} else {
    foreach ($session in $sessionRefs) {
        $sectionLines.Add("- $session")
    }
}
$sectionLines.Add("")

$sectionLines.Add("### Timeline")
if ($timeline.Count -eq 0) {
    $sectionLines.Add("- (none provided)")
} else {
    $sectionLines.Add("| Time | Event | Reference |")
    $sectionLines.Add("|---|---|---|")
    foreach ($entry in $timeline) {
        $t = [string]$entry.timestamp
        $e = [string]$entry.event
        $r = [string]$entry.reference
        if ([string]::IsNullOrWhiteSpace($t)) { $t = "-" }
        if ([string]::IsNullOrWhiteSpace($e)) { $e = "-" }
        if ([string]::IsNullOrWhiteSpace($r)) { $r = "-" }
        $sectionLines.Add("| $t | $e | $r |")
    }
}
$sectionLines.Add("")

$sectionLines.Add("### Learnings")
foreach ($row in $learningRows) {
    $rowTitle = [string]$row.title
    if ([string]::IsNullOrWhiteSpace($rowTitle)) { $rowTitle = "(untitled learning)" }
    $rowDetail = [string]$row.detail
    if ([string]::IsNullOrWhiteSpace($rowDetail)) { $rowDetail = "-" }

    $sectionLines.Add("- [learning:$($row.key)] **$rowTitle** — $rowDetail")
    if (-not [string]::IsNullOrWhiteSpace([string]$row.action)) {
        $sectionLines.Add("  - Follow-up action: $($row.action)")
    }
}
$sectionLines.Add("")

$sectionLines.Add("### References")
if ($references.Count -eq 0) {
    $sectionLines.Add("- (none provided)")
} else {
    foreach ($reference in $references) {
        $sectionLines.Add("- $reference")
    }
}
$sectionLines.Add("<!-- CHRONICLE:END $cycleKey -->")

$sectionBlock = ($sectionLines -join "`n")
$storyHeader = @(
    "# $storyTitle",
    "",
    "Chronicle-generated execution updates are appended below.",
    ""
) -join "`n"

$startMarker = "<!-- CHRONICLE:START $cycleKey -->"
$endMarker = "<!-- CHRONICLE:END $cycleKey -->"

if ([string]::IsNullOrWhiteSpace($existingStoryContent)) {
    $newContent = $storyHeader + $sectionBlock + "`n"
} elseif ($Mode -eq "update" -and $existingStoryContent.Contains($startMarker) -and $existingStoryContent.Contains($endMarker)) {
    $pattern = "(?s)" + [regex]::Escape($startMarker) + ".*?" + [regex]::Escape($endMarker)
    $newContent = [regex]::Replace($existingStoryContent, $pattern, $sectionBlock, 1)
    if (-not $newContent.EndsWith("`n")) {
        $newContent += "`n"
    }
} else {
    $separator = if ($existingStoryContent.EndsWith("`n`n")) { "" } else { "`n" }
    $newContent = $existingStoryContent + $separator + $sectionBlock + "`n"
}

New-Item -Path ([System.IO.Path]::GetDirectoryName($storyAbsolutePath)) -ItemType Directory -Force | Out-Null
Set-Content -Path $storyAbsolutePath -Value $newContent -Encoding UTF8

$packetPath = Join-Path $outputAbsoluteDir "story-update-packet.md"
$issuesPath = Join-Path $outputAbsoluteDir "issue-ready-learnings.md"
$summaryPath = Join-Path $outputAbsoluteDir "summary.json"
$memoryPath = Join-Path $outputAbsoluteDir "memory-promotion-suggestions.json"

Set-Content -Path $packetPath -Value $sectionBlock -Encoding UTF8

$issueLines = [System.Collections.Generic.List[string]]::new()
$issueLines.Add("# Issue-Ready Learnings")
$issueLines.Add("")
if ($issueRows.Count -eq 0) {
    $issueLines.Add("- No issue-ready learning items were produced.")
} else {
    $issueLines.Add("| Suggested Issue Title | Context | Action | Learning Key |")
    $issueLines.Add("|---|---|---|---|")
    foreach ($row in $issueRows) {
        $title = [string]$row.issue_title
        $context = [string]$row.context
        $action = [string]$row.action
        $key = [string]$row.learning_key
        if ([string]::IsNullOrWhiteSpace($context)) { $context = "-" }
        if ([string]::IsNullOrWhiteSpace($action)) { $action = "-" }
        $issueLines.Add("| $title | $context | $action | $key |")
    }
}
Set-Content -Path $issuesPath -Value ($issueLines -join "`n") -Encoding UTF8

if ($IncludeMemorySuggestions) {
    @($memoryRows) | ConvertTo-Json -Depth 20 | Set-Content -Path $memoryPath -Encoding UTF8
}

$summary = [ordered]@{
    cycle_id = $cycleId
    cycle_key = $cycleKey
    mode = $Mode
    story_path = $storyAbsolutePath
    output_dir = $outputAbsoluteDir
    timeline_count = $timeline.Count
    learning_count = $learningRows.Count
    issue_ready_count = $issueRows.Count
    memory_suggestion_count = $memoryRows.Count
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

$summary | ConvertTo-Json -Depth 20 | Set-Content -Path $summaryPath -Encoding UTF8

Write-Host "Chronicle story export complete." -ForegroundColor Green
Write-Host "  Story:   $storyAbsolutePath"
Write-Host "  Packet:  $packetPath"
Write-Host "  Issues:  $issuesPath"
if ($IncludeMemorySuggestions) {
    Write-Host "  Memory:  $memoryPath"
}
Write-Host "  Summary: $summaryPath"

$summary | ConvertTo-Json -Depth 20 | Write-Output
