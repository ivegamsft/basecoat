#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot
$outputDir = Join-Path $repoRoot 'test-results\hrm-trm-memory-ab'
$summary = Join-Path $outputDir 'eval-summary.md'

& pwsh scripts\eval-assets.ps1 `
    -CaseFile tests\evals\hrm-trm-memory-ab.behavior.json `
    -OutputDir $outputDir `
    -SummaryFile $summary `
    -AbComparison `
    -MinimumLift 0.5 | Out-Null

$report = Get-Content (Join-Path $outputDir 'eval-agents.json') -Raw | ConvertFrom-Json
if ($report.ab_comparison.decision -ne 'retain') {
    throw "Expected A/B evaluation to retain the cognitive layer."
}
if ($report.ab_comparison.score_lift -lt 0.5) {
    throw "Expected score lift of at least 0.5, got $($report.ab_comparison.score_lift)."
}
Write-Host 'HRM/TRM/memory A/B evaluation test passed' -ForegroundColor Green
