$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$failures = @()

Write-Host 'Running failure-pattern script tests...'

$rawScript = Join-Path $repoRoot 'scripts\generate-failure-pattern-raw-findings-issue.ps1'
$planScript = Join-Path $repoRoot 'scripts\generate-failure-pattern-triage-plan-issue.ps1'
$linkScript = Join-Path $repoRoot 'scripts\link-failure-pattern-issues.ps1'

foreach ($path in @($rawScript, $planScript, $linkScript)) {
    if (-not (Test-Path $path)) {
        $failures += "Missing script: $path"
    }
}

if ($failures.Count -eq 0) {
    $rawOutput = & $rawScript `
        -RepoName 'octo/example' `
        -AnalysisWindow '2025-01-01..2025-01-31' `
        -RunId 'fp-2025-01' `
        -Owner 'alice' `
        -SourceEvidence @('https://example.test/source-1', 'artifacts/source-2.md') `
        -PatternCandidatesRef 'artifacts/A2.md' `
        -RawFindingsLogRef 'artifacts/B1.md'

    $rawText = $rawOutput -join "`n"
    if (-not $rawText.Contains('# Failure Pattern Run: octo/example (2025-01-01..2025-01-31)')) {
        $failures += 'Raw issue title default does not match run contract pattern.'
    }
    if ($rawText -notmatch 'Current Stage: raw_logged') {
        $failures += 'Raw issue output missing raw_logged stage.'
    }
    if ($rawText -notmatch 'B1-raw-findings-log \(no pruning\)') {
        $failures += 'Raw issue output missing B1 no-pruning artifact line.'
    }

    $planOutput = & $planScript `
        -RepoName 'octo/example' `
        -RunId 'fp-2025-01' `
        -RawIssueReference 'https://github.com/octo/example/issues/12' `
        -TriageMatrixRef 'artifacts/C1.md' `
        -ClassificationRationaleRef 'artifacts/C2.md' `
        -CommonPatternsRef 'artifacts/common.md' `
        -RepoSpecificPatternsRef 'artifacts/repo.md' `
        -EnhancementBacklogRef 'artifacts/D1.md' `
        -EarlyDetectionGatesRef 'artifacts/D2.md' `
        -RunSummaryRef 'artifacts/run-summary.md'

    $planText = $planOutput -join "`n"
    if (-not $planText.Contains('# Failure Pattern Enhancements: octo/example (fp-2025-01)')) {
        $failures += 'Plan issue title default does not match run contract pattern.'
    }
    if ($planText -notmatch '## Common Patterns \(Reusable\)') {
        $failures += 'Plan issue output missing common patterns section.'
    }
    if ($planText -notmatch '## Repo-Specific Patterns') {
        $failures += 'Plan issue output missing repo-specific patterns section.'
    }

    $linkOutput = & $linkScript `
        -RepoName 'octo/example' `
        -RawIssueNumber 12 `
        -PlanIssueNumber 13 `
        -RunId 'fp-2025-01'

    $linkText = $linkOutput -join "`n"
    if ($linkText -notmatch 'Comment for Raw Findings Issue \(octo/example#12\)') {
        $failures += 'Link script missing raw issue heading.'
    }
    if ($linkText -notmatch 'Triaged Plan Issue: octo/example#13') {
        $failures += 'Link script missing raw-to-plan linkage.'
    }
    if ($linkText -notmatch 'Raw Findings Issue: octo/example#12') {
        $failures += 'Link script missing plan-to-raw linkage.'
    }
}

if ($failures.Count -gt 0) {
    Write-Host "failure-pattern script tests FAILED ($($failures.Count) issue(s))" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'failure-pattern script tests passed' -ForegroundColor Green
exit 0
