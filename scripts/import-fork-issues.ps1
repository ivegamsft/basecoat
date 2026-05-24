#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [string]$SourceRepo = "ivegamsft/basecoat",
    [string]$TargetRepo = $(if ($env:GITHUB_REPOSITORY) { $env:GITHUB_REPOSITORY } else { "IBuySpy-Shared/basecoat" }),
    [ValidateSet("open", "closed", "all")]
    [string]$SourceState = "open",
    [ValidateRange(1, 500)]
    [int]$MaxItems = 100,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-Title {
    param([string]$Title)
    if ([string]::IsNullOrWhiteSpace($Title)) { return "" }
    $normalized = $Title.ToLowerInvariant().Trim()
    $normalized = [regex]::Replace($normalized, "[^\p{L}\p{N}\s-]", " ")
    $normalized = [regex]::Replace($normalized, "\s+", " ")
    return $normalized.Trim()
}

function Add-GitHubOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT)) {
        Add-Content -Path $env:GITHUB_OUTPUT -Value "$Name=$Value"
    }
}

function Invoke-GhJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )
    $result = & gh @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "gh command failed: gh $($Arguments -join ' ')`n$result"
    }
    return $result | ConvertFrom-Json
}

Write-Host "Source repo: $SourceRepo"
Write-Host "Target repo: $TargetRepo"
Write-Host "Source state: $SourceState"
Write-Host "Max items: $MaxItems"
Write-Host "Dry run: $DryRun"

$sourceIssues = Invoke-GhJson -Arguments @(
    "issue", "list",
    "--repo", $SourceRepo,
    "--state", $SourceState,
    "--limit", "$MaxItems",
    "--json", "number,title,body,url"
)

$targetOpenIssues = Invoke-GhJson -Arguments @(
    "issue", "list",
    "--repo", $TargetRepo,
    "--state", "open",
    "--limit", "500",
    "--json", "number,title,body,url"
)

$targetClosedIssues = Invoke-GhJson -Arguments @(
    "issue", "list",
    "--repo", $TargetRepo,
    "--state", "closed",
    "--limit", "500",
    "--json", "number,title,body,url"
)

$targetIssues = @($targetOpenIssues + $targetClosedIssues)

$sourceUrlToIssueNumber = @{}
$normalizedTitleToIssueNumber = @{}

foreach ($targetIssue in $targetIssues) {
    if ($targetIssue.body -match 'https://github\.com/[^/\s]+/[^/\s]+/issues/\d+') {
        $sourceUrl = $Matches[0].ToLowerInvariant()
        if (-not $sourceUrlToIssueNumber.ContainsKey($sourceUrl)) {
            $sourceUrlToIssueNumber[$sourceUrl] = $targetIssue.number
        }
    }

    $normalizedTargetTitle = Normalize-Title -Title $targetIssue.title
    if ($normalizedTargetTitle -and -not $normalizedTitleToIssueNumber.ContainsKey($normalizedTargetTitle)) {
        $normalizedTitleToIssueNumber[$normalizedTargetTitle] = $targetIssue.number
    }
}

$created = 0
$skipped = 0
$scanned = 0
$skippedSourceUrlMatch = 0
$skippedTitleMatch = 0

foreach ($sourceIssue in $sourceIssues) {
    $scanned++
    $sourceIssueUrl = ($sourceIssue.url ?? "").ToLowerInvariant()
    $normalizedSourceTitle = Normalize-Title -Title $sourceIssue.title

    $skipReason = $null
    if ($sourceIssueUrl -and $sourceUrlToIssueNumber.ContainsKey($sourceIssueUrl)) {
        $skippedSourceUrlMatch++
        $skipReason = "source-fork URL already imported as #$($sourceUrlToIssueNumber[$sourceIssueUrl])"
    } elseif ($normalizedSourceTitle -and $normalizedTitleToIssueNumber.ContainsKey($normalizedSourceTitle)) {
        $skippedTitleMatch++
        $skipReason = "normalized title already present as #$($normalizedTitleToIssueNumber[$normalizedSourceTitle])"
    }

    if ($skipReason) {
        $skipped++
        Write-Host "SKIP #$($sourceIssue.number): $($sourceIssue.title)"
        Write-Host "  Reason: $skipReason"
        continue
    }

    $importBody = @"
Imported from fork for tracking.

Source fork issue: $($sourceIssue.url)
"@.Trim()

    if ($sourceIssue.body) {
        $trimmedSourceBody = $sourceIssue.body.Trim()
        if ($trimmedSourceBody.Length -gt 0) {
            $importBody = "$importBody`n`n---`n`n$trimmedSourceBody"
        }
    }

    if ($DryRun) {
        Write-Host "DRY RUN create issue for source #$($sourceIssue.number): $($sourceIssue.title)"
        $created++
    } else {
        & gh issue create --repo $TargetRepo --title $sourceIssue.title --body $importBody | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create issue for source #$($sourceIssue.number)"
        }
        $created++
        Write-Host "CREATED issue from source #$($sourceIssue.number): $($sourceIssue.title)"
    }
}

Write-Host ""
Write-Host "Fork import summary"
Write-Host "  Scanned: $scanned"
Write-Host "  Created: $created"
Write-Host "  Skipped: $skipped"
Write-Host "    - Source URL matches: $skippedSourceUrlMatch"
Write-Host "    - Normalized title matches: $skippedTitleMatch"

Add-GitHubOutput -Name "scanned" -Value "$scanned"
Add-GitHubOutput -Name "created" -Value "$created"
Add-GitHubOutput -Name "skipped" -Value "$skipped"
Add-GitHubOutput -Name "skipped_source_url_match" -Value "$skippedSourceUrlMatch"
Add-GitHubOutput -Name "skipped_title_match" -Value "$skippedTitleMatch"
