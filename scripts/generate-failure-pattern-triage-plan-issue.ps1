#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates deterministic markdown for a failure-pattern triage and plan issue.

.DESCRIPTION
    Creates issue body content aligned to docs\operations\FAILURE_PATTERN_RUN_CONTRACT.md
    for triage and planning artifacts (C1, C2, D1, D2, run-summary), including
    explicit sections for common and repo-specific patterns.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RunId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RawIssueReference,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TriageMatrixRef,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ClassificationRationaleRef,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$CommonPatternsRef,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoSpecificPatternsRef,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$EnhancementBacklogRef,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$EarlyDetectionGatesRef,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RunSummaryRef,

    [string]$Title = "",

    [string]$OutputPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Title)) {
    $Title = "Failure Pattern Enhancements: $RepoName ($RunId)"
}

$body = @(
    "## Run Linkage",
    "- Run ID: $RunId",
    "- Repo: $RepoName",
    "- Raw Findings Issue: $RawIssueReference",
    "",
    "## Stage",
    "- Current Stage: planned",
    "- Gate Status: Gate1=pass | Gate2=pass | Gate3=pass | Gate4=pass",
    "",
    "## Classification Inputs",
    "- C1-triage-matrix: $TriageMatrixRef",
    "- C2-classification-rationale: $ClassificationRationaleRef",
    "",
    "## Common Patterns (Reusable)",
    "- Source: $CommonPatternsRef",
    "- Include only cross-repository or reusable controls.",
    "",
    "## Repo-Specific Patterns",
    "- Source: $RepoSpecificPatternsRef",
    "- Include localized conditions tied to this repository only.",
    "",
    "## Plan Artifacts",
    "- [x] D1-enhancement-backlog ($EnhancementBacklogRef)",
    "- [x] D2-early-detection-gates ($EarlyDetectionGatesRef)",
    "- [x] run-summary ($RunSummaryRef)",
    "",
    "## Traceability",
    "- This plan issue must remain linked to raw findings for auditability.",
    ""
) -join "`n"

$output = @(
    "# $Title",
    "",
    $body
) -join "`n"

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    Set-Content -Path $OutputPath -Value $output -Encoding utf8
}

$output
