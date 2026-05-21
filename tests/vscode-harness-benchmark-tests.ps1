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

Write-Host 'Running VS Code harness benchmark suite tests...'

$suitePath = Join-Path $repoRoot 'tests\evals\vscode-harness-benchmark-suite.json'
$thresholdPath = Join-Path $repoRoot 'tests\evals\vscode-harness-regression-thresholds.json'
$baselinePath = Join-Path $repoRoot 'tests\evals\vscode-harness-baseline.json'
$candidatePath = Join-Path $repoRoot 'tests\evals\vscode-harness-candidate.json'

Assert-PathExists -Path $suitePath -Message 'Missing benchmark suite definition file'
Assert-PathExists -Path $thresholdPath -Message 'Missing regression thresholds definition file'
Assert-PathExists -Path $baselinePath -Message 'Missing benchmark baseline metrics fixture'
Assert-PathExists -Path $candidatePath -Message 'Missing benchmark candidate metrics fixture'

$suite = Get-Content $suitePath -Raw | ConvertFrom-Json
$thresholds = Get-Content $thresholdPath -Raw | ConvertFrom-Json

if (-not $suite.cases -or $suite.cases.Count -lt 4) {
    throw 'Benchmark suite must contain at least four harness benchmark cases'
}

$requiredCategories = @('multi_turn_tool_use', 'mcp_external_tools', 'terminal_browser_interactions', 'loop_and_stop_conditions')
foreach ($category in $requiredCategories) {
    if ($suite.categories.id -notcontains $category) {
        throw "Benchmark suite is missing required category: $category"
    }
    if (-not $thresholds.category_thresholds.$category) {
        throw "Regression thresholds are missing required category: $category"
    }
}

$outputDir = Join-Path $repoRoot 'test-results'
$summaryFile = Join-Path $outputDir 'vscode-harness-regression-summary.md'

pwsh scripts\compare-vscode-harness-benchmarks.ps1 `
    -BaselineFile $baselinePath `
    -CandidateFile $candidatePath `
    -ThresholdFile $thresholdPath `
    -OutputDir $outputDir `
    -SummaryFile $summaryFile

$reportPath = Join-Path $outputDir 'vscode-harness-regression.json'
Assert-PathExists -Path $reportPath -Message 'Regression comparison did not create JSON output'
Assert-PathExists -Path $summaryFile -Message 'Regression comparison did not create summary output'

$report = Get-Content $reportPath -Raw | ConvertFrom-Json
if (-not $report.passed) {
    throw 'Expected fixture regression comparison to pass thresholds'
}

Write-Host 'VS Code harness benchmark suite tests passed' -ForegroundColor Green
