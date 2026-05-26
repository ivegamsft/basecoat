#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates deterministic cross-link content between raw and triage/plan issues.

.DESCRIPTION
    Produces markdown snippets to paste as comments or body updates so raw findings
    and triage/plan issues are explicitly linked without mutating GitHub state.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoName,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$RawIssueNumber,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$PlanIssueNumber,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RunId,

    [ValidateSet("both", "raw", "plan")]
    [string]$Mode = "both",

    [string]$OutputPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$rawRef = "$RepoName#$RawIssueNumber"
$planRef = "$RepoName#$PlanIssueNumber"

$rawComment = @(
    "### Failure Pattern Linkage",
    "- Run ID: $RunId",
    "- Triaged Plan Issue: $planRef",
    "- Status: raw_logged artifacts handed off to planning",
    ""
) -join "`n"

$planComment = @(
    "### Failure Pattern Linkage",
    "- Run ID: $RunId",
    "- Raw Findings Issue: $rawRef",
    "- Status: plan scoped from unpruned raw findings",
    ""
) -join "`n"

switch ($Mode) {
    "raw" {
        $output = @(
            "# Comment for Raw Findings Issue ($rawRef)",
            "",
            $rawComment
        ) -join "`n"
    }
    "plan" {
        $output = @(
            "# Comment for Triage/Plan Issue ($planRef)",
            "",
            $planComment
        ) -join "`n"
    }
    default {
        $output = @(
            "# Comment for Raw Findings Issue ($rawRef)",
            "",
            $rawComment,
            "",
            "# Comment for Triage/Plan Issue ($planRef)",
            "",
            $planComment
        ) -join "`n"
    }
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    Set-Content -Path $OutputPath -Value $output -Encoding utf8
}

$output
