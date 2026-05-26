#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates deterministic markdown for a failure-pattern raw findings run issue.

.DESCRIPTION
    Creates issue body content aligned to docs\operations\FAILURE_PATTERN_RUN_CONTRACT.md
    for the raw findings stage (A1, A2, B1).

.EXAMPLE
    pwsh scripts\generate-failure-pattern-raw-findings-issue.ps1 `
      -RepoName "octo/example" `
      -AnalysisWindow "2025-01-01..2025-01-31" `
      -RunId "fp-2025-01" `
      -Owner "alice" `
      -SourceEvidence @("https://github.com/octo/example/issues/1") `
      -PatternCandidatesRef "artifacts/A2-pattern-candidates.md" `
      -RawFindingsLogRef "artifacts/B1-raw-findings-log.md"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AnalysisWindow,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RunId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Owner,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$SourceEvidence,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$PatternCandidatesRef,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RawFindingsLogRef,

    [string]$Title = "",

    [string]$OutputPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($SourceEvidence.Count -eq 0) {
    throw "SourceEvidence must include at least one URL or path."
}

if ([string]::IsNullOrWhiteSpace($Title)) {
    $Title = "Failure Pattern Run: $RepoName ($AnalysisWindow)"
}

$evidenceLines = $SourceEvidence | ForEach-Object { "- $_" }
$body = @(
    "## Run Metadata",
    "- Run ID: $RunId",
    "- Repo: $RepoName",
    "- Analysis Window: $AnalysisWindow",
    "- Owner: $Owner",
    "",
    "## Stage",
    "- Current Stage: raw_logged",
    "- Gate Status: Gate1=pass | Gate2=pass | Gate3=pending | Gate4=pending",
    "",
    "## Artifacts",
    "- [x] A1-source-index",
    "- [x] A2-pattern-candidates ($PatternCandidatesRef)",
    "- [x] B1-raw-findings-log (no pruning) ($RawFindingsLogRef)",
    "- [ ] C1-triage-matrix",
    "- [ ] C2-classification-rationale",
    "- [ ] D1-enhancement-backlog",
    "- [ ] D2-early-detection-gates",
    "- [ ] run-summary",
    "",
    "## Blockers",
    "- None",
    "",
    "## Evidence Links",
    "- A1-source-index references:",
    $evidenceLines,
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
