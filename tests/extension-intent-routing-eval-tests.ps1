$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

function Assert-PathExists {
    param(
        [string]$Path,
        [string]$Message
    )

    if (-not (Test-Path $Path)) {
        throw $Message
    }
}

Write-Host 'Running extension intent routing eval baseline checks...'

$outputDir = Join-Path $repoRoot 'test-results\extension-intent-routing'
pwsh scripts\eval-extension-intent-routing.ps1 -OutputDir $outputDir | Out-Null

$summaryJsonPath = Join-Path $outputDir 'summary.json'
$summaryMdPath = Join-Path $outputDir 'summary.md'
Assert-PathExists -Path $summaryJsonPath -Message 'Extension eval summary.json not generated'
Assert-PathExists -Path $summaryMdPath -Message 'Extension eval summary.md not generated'

$summary = Get-Content $summaryJsonPath -Raw | ConvertFrom-Json
if ($summary.case_count -lt 50) {
    throw "Expected at least 50 cases, found $($summary.case_count)"
}

if ($summary.negative_case_count -lt 5) {
    throw "Expected at least 5 negative cases, found $($summary.negative_case_count)"
}

$coverageFailures = @($summary.tool_coverage | Where-Object { -not $_.meets_minimum })
if ($coverageFailures.Count -gt 0) {
    throw "Tool coverage minimum failed for $($coverageFailures.Count) tool(s)"
}

Write-Host 'Running extension intent routing prediction mode checks...'

$fixturePredictions = Join-Path $repoRoot 'tests\evals\extension-intent-routing\predictions.fixture.json'
pwsh scripts\eval-extension-intent-routing.ps1 `
  -PredictionsFile $fixturePredictions `
  -OutputDir $outputDir `
  -MinPassRate 0.80 | Out-Null

$summary = Get-Content $summaryJsonPath -Raw | ConvertFrom-Json
if (-not $summary.prediction_mode) {
    throw 'Prediction mode did not run as expected'
}

if ($summary.evaluated_case_count -lt 5) {
    throw "Expected prediction mode to evaluate at least 5 cases; found $($summary.evaluated_case_count)"
}

Write-Host 'Extension intent routing eval tests passed' -ForegroundColor Green
