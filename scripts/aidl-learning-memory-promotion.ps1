#!/usr/bin/env pwsh
<#
.SYNOPSIS
    AIDL learning-to-memory promotion pipeline.

.DESCRIPTION
    Extracts promotion candidates from sprint/incident/review artifacts, filters
    ephemeral noise, applies sensitive-content safeguards, scores recurrence and
    impact, and emits reviewable promotion packets with an audit ledger and
    adoption-impact tracking plan.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$OutputDir = "artifacts\aidl-learning-memory-pipeline",

    [ValidateRange(1, 10)]
    [int]$MinimumRecurrence = 2,

    [ValidateRange(1, 5)]
    [int]$MinimumImpact = 3,

    [ValidateRange(1, 100)]
    [int]$PromoteScoreThreshold = 70,

    [ValidateRange(1, 100)]
    [int]$HoldScoreThreshold = 45
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host "  -> $Message" -ForegroundColor Cyan
}

function Normalize-Token([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    $normalized = $Value.ToLowerInvariant()
    $normalized = [regex]::Replace($normalized, "[^a-z0-9]+", "-")
    return $normalized.Trim("-")
}

function Normalize-Evidence($RawEvidence) {
    $normalized = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @($RawEvidence)) {
        $value = [string]$item
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $normalized.Add($value.Trim())
        }
    }

    return [string[]]$normalized.ToArray()
}

function Normalize-SubjectDomain([string]$Category) {
    $domain = Normalize-Token $Category
    if ([string]::IsNullOrWhiteSpace($domain)) {
        return "memory"
    }
    if ($domain -notmatch "^[a-z]") {
        $domain = "memory-$domain"
    }

    return $domain
}

function Normalize-SubjectKey([string]$CandidateId) {
    $key = Normalize-Token $CandidateId
    if ([string]::IsNullOrWhiteSpace($key)) {
        $key = "candidate-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    }
    if ($key -notmatch "^[a-z]") {
        $key = "c-$key"
    }

    return $key
}

function Test-SensitiveContent([string]$Content) {
    if ([string]::IsNullOrWhiteSpace($Content)) {
        return $false
    }

    $patterns = @(
        "(?i)api[_-]?key",
        "(?i)client[_-]?secret",
        "(?i)connection\s*string",
        "(?i)password\s*[:=]",
        "(?i)bearer\s+[A-Za-z0-9\._\-]{16,}",
        "(?i)token\s*[:=]",
        "(?i)\btoken\b.{0,20}[A-Za-z0-9\-_]{12,}",
        "ghp_[A-Za-z0-9_]{36,}",
        "ghs_[A-Za-z0-9_]{36,}",
        "gho_[A-Za-z0-9_]{36,}",
        "github_pat_[A-Za-z0-9_]{82,}",
        "AKIA[0-9A-Z]{16}",
        "(?i)xox[bapors]-[A-Za-z0-9\-]{10,}",
        "(?i)-----BEGIN\s+[A-Z ]+PRIVATE KEY-----",
        "(?i)\bsk-[A-Za-z0-9]{20,}\b"
    )

    foreach ($pattern in $patterns) {
        if ($Content -match $pattern) {
            return $true
        }
    }

    return $false
}

function Get-SourceWeight([string]$SourceType) {
    switch ($SourceType) {
        "incident" { return 15 }
        "sprint" { return 10 }
        "review" { return 8 }
        "governance" { return 12 }
        default { return 0 }
    }
}

function Get-RoutePlan([string]$Category, [string]$SourceType) {
    $normalizedCategory = Normalize-Token $Category
    switch ($normalizedCategory) {
        "policy" {
            return [ordered]@{
                workflow = "decision-log-capture"
                target_path = "docs/decisions/"
                action = "open decision-log update"
            }
        }
        "runbook" {
            return [ordered]@{
                workflow = "failure-pattern-process"
                target_path = "docs/operations/"
                action = "open runbook update"
            }
        }
        "instruction" {
            return [ordered]@{
                workflow = "memory-promoter"
                target_path = ".github/instructions/"
                action = "open instruction update"
            }
        }
        "skill" {
            return [ordered]@{
                workflow = "memory-promoter"
                target_path = "skills/"
                action = "open skill update"
            }
        }
        "agent" {
            return [ordered]@{
                workflow = "memory-promoter"
                target_path = "agents/"
                action = "open agent update"
            }
        }
        default {
            $fallbackWorkflow = if ($SourceType -eq "incident") { "failure-pattern-process" } else { "memory-promoter" }
            return [ordered]@{
                workflow = $fallbackWorkflow
                target_path = "docs/memory/"
                action = "queue memory contribution packet"
            }
        }
    }
}

function Get-AdoptionMetric([string]$SourceType) {
    switch ($SourceType) {
        "incident" { return "repeat_incident_rate" }
        "review" { return "pr_rework_rate" }
        "governance" { return "guardrail_waiver_count" }
        default { return "blocker_recurrence_rate" }
    }
}

if (-not (Test-Path -Path $InputPath)) {
    throw "Input file not found: $InputPath"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$resolvedOutputDir = [System.IO.Path]::GetFullPath($OutputDir)
if (-not ($resolvedOutputDir.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase))) {
    throw "OutputDir must resolve inside repository root. Resolved path: $resolvedOutputDir"
}

Write-Step "Loading input candidates from $InputPath"
$rawInput = Get-Content -Path $InputPath -Raw -Encoding UTF8
$parsed = $rawInput | ConvertFrom-Json -Depth 100
$candidates = @($parsed)

if ($candidates.Count -eq 0) {
    throw "Input file must contain at least one candidate object."
}

$allowedSources = @("sprint", "incident", "review", "governance")
$evaluations = [System.Collections.Generic.List[object]]::new()
$packets = [System.Collections.Generic.List[object]]::new()
$auditLedger = [System.Collections.Generic.List[object]]::new()
$adoptionPlan = [System.Collections.Generic.List[object]]::new()

foreach ($candidate in $candidates) {
    $candidateId = if (-not [string]::IsNullOrWhiteSpace([string]$candidate.id)) { [string]$candidate.id } else { "candidate-$([Guid]::NewGuid().ToString('N').Substring(0,8))" }
    $sourceType = Normalize-Token ([string]$candidate.sourceType)
    $category = if ($candidate.PSObject.Properties.Name -contains "category") { [string]$candidate.category } else { "memory" }
    $title = [string]$candidate.title
    $pattern = [string]$candidate.pattern
    $resolution = [string]$candidate.resolution
    $outcome = [string]$candidate.outcome
    $rawEvidence = if ($candidate.PSObject.Properties.Name -contains "evidence") { $candidate.evidence } else { @() }
    $evidence = @((Normalize-Evidence -RawEvidence $rawEvidence))
    $recurrence = [int]$candidate.recurrence
    $impact = [int]$candidate.impact
    $affectedTeams = if ($candidate.PSObject.Properties.Name -contains "affectedTeams") { [int]$candidate.affectedTeams } else { 1 }

    $decisionReasons = [System.Collections.Generic.List[string]]::new()
    $decision = "reject"

    if (-not $allowedSources.Contains($sourceType)) {
        $decisionReasons.Add("Unsupported sourceType '$sourceType'. Allowed: $($allowedSources -join ', ')")
    }
    if ([string]::IsNullOrWhiteSpace($title)) { $decisionReasons.Add("Missing required field: title") }
    if ([string]::IsNullOrWhiteSpace($pattern)) { $decisionReasons.Add("Missing required field: pattern") }
    if ([string]::IsNullOrWhiteSpace($resolution)) { $decisionReasons.Add("Missing required field: resolution") }
    if ([string]::IsNullOrWhiteSpace($outcome)) { $decisionReasons.Add("Missing required field: outcome") }
    if ($evidence.Count -lt 1) { $decisionReasons.Add("Missing required evidence links") }
    if ($recurrence -lt 0) { $decisionReasons.Add("recurrence must be >= 0") }
    if ($impact -lt 1 -or $impact -gt 5) { $decisionReasons.Add("impact must be between 1 and 5") }

    $compositeText = "$title $pattern $resolution $outcome $(($evidence -join ' '))"
    $hasSensitiveContent = Test-SensitiveContent -Content $compositeText
    if ($hasSensitiveContent) {
        $decisionReasons.Add("Sensitive content detected. Candidate cannot be promoted.")
    }

    $isEphemeralNoise = ($recurrence -lt $MinimumRecurrence) -or ($impact -lt $MinimumImpact)
    if ($isEphemeralNoise) {
        $decisionReasons.Add("Filtered as ephemeral noise (recurrence<$MinimumRecurrence or impact<$MinimumImpact).")
    }

    $recurrenceScore = [Math]::Min(40, $recurrence * 10)
    $impactScore = [Math]::Min(30, $impact * 6)
    $evidenceScore = [Math]::Min(10, ($evidence.Count * 3))
    $reuseScore = if ($affectedTeams -ge 3) { 10 } elseif ($affectedTeams -eq 2) { 7 } elseif ($recurrence -ge 4) { 5 } else { 2 }
    $sourceScore = Get-SourceWeight -SourceType $sourceType
    $totalScore = [Math]::Min(100, ($recurrenceScore + $impactScore + $evidenceScore + $reuseScore + $sourceScore))

    $validationPassed = $decisionReasons.Count -eq 0
    if ($validationPassed -and -not $hasSensitiveContent -and -not $isEphemeralNoise) {
        if ($totalScore -ge $PromoteScoreThreshold) {
            $decision = "promote"
            $decisionReasons.Add("Meets promotion threshold ($totalScore >= $PromoteScoreThreshold).")
        } elseif ($totalScore -ge $HoldScoreThreshold) {
            $decision = "hold"
            $decisionReasons.Add("Needs manual review before promotion ($totalScore between $HoldScoreThreshold and $PromoteScoreThreshold).")
        } else {
            $decision = "reject"
            $decisionReasons.Add("Insufficient score for promotion ($totalScore < $HoldScoreThreshold).")
        }
    }

    $normalizedCategory = Normalize-SubjectDomain $category
    $subjectSuffix = Normalize-SubjectKey $candidateId
    $subject = "${normalizedCategory}:$subjectSuffix"
    $fact = "$pattern Recommended action: $resolution Outcome signal: $outcome"
    if ($fact.Length -gt 300) {
        $fact = $fact.Substring(0, 297) + "..."
    }

    $evaluationRecord = [ordered]@{
        id = $candidateId
        sourceType = $sourceType
        category = $normalizedCategory
        title = $title
        recurrence = $recurrence
        impact = $impact
        affectedTeams = $affectedTeams
        score = $totalScore
        decision = $decision
        reasons = @($decisionReasons)
        safeguards = [ordered]@{
            sensitive_content_detected = $hasSensitiveContent
            filtered_as_ephemeral_noise = $isEphemeralNoise
        }
        evidence = @($evidence)
    }
    $evaluations.Add([pscustomobject]$evaluationRecord)

    $auditLedger.Add([pscustomobject]([ordered]@{
            candidate_id = $candidateId
            decision = $decision
            score = $totalScore
            reviewer = "memory-curator (pending approval)"
            routed_workflow = if ($decision -eq "reject") { "" } else { (Get-RoutePlan -Category $normalizedCategory -SourceType $sourceType).workflow }
            rationale = ($decisionReasons -join " ")
            audited_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        }))

    if ($decision -ne "reject") {
        $routePlan = Get-RoutePlan -Category $normalizedCategory -SourceType $sourceType
        $packet = [ordered]@{
            id = $candidateId
            subject = $subject
            fact = $fact
            citations = @($evidence)
            reason = ($decisionReasons -join " ")
            score = $totalScore
            recommendation = $decision
            frequency = $recurrence
            route = $routePlan
        }
        $packets.Add([pscustomobject]$packet)
    }

    if ($decision -eq "promote") {
        $metric = Get-AdoptionMetric -SourceType $sourceType
        $adoptionPlan.Add([pscustomobject]([ordered]@{
                candidate_id = $candidateId
                subject = $subject
                metric = $metric
                baseline = "set-at-promotion"
                target = "improve-by-1-sprint-cycle"
                review_after_days = 30
                source_artifact = if ($evidence.Count -gt 0) { [string]$evidence[0] } else { "" }
            }))
    }
}

New-Item -Path $resolvedOutputDir -ItemType Directory -Force | Out-Null

$summaryPath = Join-Path $resolvedOutputDir "candidate-summary.json"
$packetPath = Join-Path $resolvedOutputDir "promotion-packets.json"
$auditPath = Join-Path $resolvedOutputDir "promotion-audit-ledger.json"
$adoptionPath = Join-Path $resolvedOutputDir "adoption-impact-tracking.json"
$reportPath = Join-Path $resolvedOutputDir "promotion-report.md"

$summaryPayload = [ordered]@{
    input_count = $candidates.Count
    promote_count = @($evaluations | Where-Object { $_.decision -eq "promote" }).Count
    hold_count = @($evaluations | Where-Object { $_.decision -eq "hold" }).Count
    reject_count = @($evaluations | Where-Object { $_.decision -eq "reject" }).Count
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    evaluations = @($evaluations)
}

$summaryPayload | ConvertTo-Json -Depth 100 | Set-Content -Path $summaryPath -Encoding UTF8
@($packets) | ConvertTo-Json -Depth 100 | Set-Content -Path $packetPath -Encoding UTF8
@($auditLedger) | ConvertTo-Json -Depth 100 | Set-Content -Path $auditPath -Encoding UTF8
@($adoptionPlan) | ConvertTo-Json -Depth 100 | Set-Content -Path $adoptionPath -Encoding UTF8

$report = @()
$report += "# AIDL Learning-to-Memory Promotion Report"
$report += ""
$report += "| Metric | Value |"
$report += "|---|---|"
$report += "| Input candidates | $($summaryPayload.input_count) |"
$report += "| Promote | $($summaryPayload.promote_count) |"
$report += "| Hold | $($summaryPayload.hold_count) |"
$report += "| Reject | $($summaryPayload.reject_count) |"
$report += ""
$report += "## Approval workflow"
$report += ""
$report += "1. Review `promotion-packets.json` and approve promote/hold recommendations."
$report += "2. Execute the routed workflow in each packet's `route` block."
$report += "3. Record final decision in `promotion-audit-ledger.json` with reviewer identity."
$report += "4. Track 30-day outcome using `adoption-impact-tracking.json`."
$report += ""
$report += "## Safeguard controls"
$report += ""
$report += "- Sensitive-content detection blocks promotion."
$report += "- Ephemeral-noise filter enforces recurrence and impact thresholds."
$report += "- Evidence links are required for all non-rejected recommendations."
$report += ""
$report += "## Output artifacts"
$report += ""
$report += '- `candidate-summary.json`'
$report += '- `promotion-packets.json`'
$report += '- `promotion-audit-ledger.json`'
$report += '- `adoption-impact-tracking.json`'

Set-Content -Path $reportPath -Value ($report -join "`n") -Encoding UTF8

Write-Host ""
Write-Host "AIDL learning-to-memory promotion pipeline complete." -ForegroundColor Green
Write-Host "  Summary: $summaryPath"
Write-Host "  Packets: $packetPath"
Write-Host "  Audit:   $auditPath"
Write-Host "  Adoption:$adoptionPath"
Write-Host "  Report:  $reportPath"

$summaryPayload | ConvertTo-Json -Depth 20 | Write-Output
