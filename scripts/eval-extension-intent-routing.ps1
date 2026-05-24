#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [string]$EvalFile = "mcp/basecoat-extension/evals/intent-routing-golden.yaml",
    [string]$PredictionsFile = "",
    [string]$OutputDir = "test-results/extension-intent-routing",
    [double]$MinPassRate = 0.90,
    [int]$MinTotalCases = 50,
    [int]$MinPerTool = 5,
    [int]$MinNegativeCases = 5
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $EvalFile)) {
    throw "Eval file not found: $EvalFile"
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

function Parse-InlineArray {
    param([string]$Value)
    $trimmed = $Value.Trim()
    if (-not ($trimmed.StartsWith('[') -and $trimmed.EndsWith(']'))) {
        return @()
    }
    $inner = $trimmed.Substring(1, $trimmed.Length - 2).Trim()
    if (-not $inner) {
        return @()
    }
    return @($inner -split ',' | ForEach-Object { $_.Trim().Trim('"').Trim("'") } | Where-Object { $_ })
}

$suiteName = ''
$requiredTools = @()
$cases = @()
$currentCase = $null
$inRequiredTools = $false
$inCases = $false

$lines = Get-Content $EvalFile
foreach ($line in $lines) {
    if ($line -match '^\s*suite:\s*(.+)\s*$') {
        $suiteName = $matches[1].Trim()
        continue
    }

    if ($line -match '^\s*required_tools:\s*$') {
        $inRequiredTools = $true
        $inCases = $false
        continue
    }

    if ($line -match '^\s*cases:\s*$') {
        $inCases = $true
        $inRequiredTools = $false
        continue
    }

    if ($inRequiredTools -and $line -match '^\s*-\s*(.+?)\s*$') {
        $requiredTools += $matches[1].Trim()
        continue
    }

    if ($inCases -and $line -match '^\s*-\s*id:\s*(.+?)\s*$') {
        if ($null -ne $currentCase) {
            $cases += [PSCustomObject]$currentCase
        }
        $currentCase = @{
            id = $matches[1].Trim()
            prompt = ''
            expected_tool = ''
            suggestion_if_misrouted = ''
            forbidden_tools = @()
        }
        continue
    }

    if ($inCases -and $null -ne $currentCase) {
        if ($line -match '^\s*prompt:\s*(.+?)\s*$') {
            $currentCase.prompt = $matches[1].Trim().Trim('"').Trim("'")
            continue
        }
        if ($line -match '^\s*expected_tool:\s*(.+?)\s*$') {
            $currentCase.expected_tool = $matches[1].Trim().Trim('"').Trim("'")
            continue
        }
        if ($line -match '^\s*suggestion_if_misrouted:\s*(.+?)\s*$') {
            $currentCase.suggestion_if_misrouted = $matches[1].Trim().Trim('"').Trim("'")
            continue
        }
        if ($line -match '^\s*forbidden_tools:\s*(.+?)\s*$') {
            $currentCase.forbidden_tools = Parse-InlineArray -Value $matches[1]
            continue
        }
    }
}

if ($null -ne $currentCase) {
    $cases += [PSCustomObject]$currentCase
}

if ($cases.Count -eq 0) {
    throw "No eval cases found in $EvalFile"
}

if (-not $suiteName) {
    $suiteName = 'extension-intent-routing-v1'
}

if ($requiredTools.Count -ne 10) {
    throw "Expected 10 required tools, found $($requiredTools.Count)"
}
$caseIds = @{}
foreach ($case in $cases) {
    if (-not $case.id) { throw "Case missing id" }
    if ($caseIds.ContainsKey($case.id)) { throw "Duplicate case id: $($case.id)" }
    $caseIds[$case.id] = $true
    if (-not $case.prompt -or [string]::IsNullOrWhiteSpace([string]$case.prompt)) {
        throw "Case $($case.id) has empty prompt"
    }
    if (-not $case.expected_tool) {
        throw "Case $($case.id) missing expected_tool"
    }
    if ($case.expected_tool -ne 'none' -and -not ($requiredTools -contains [string]$case.expected_tool)) {
        throw "Case $($case.id) expected_tool '$($case.expected_tool)' is not in required_tools"
    }
    if (-not $case.suggestion_if_misrouted) {
        throw "Case $($case.id) missing suggestion_if_misrouted"
    }
}

if ($cases.Count -lt $MinTotalCases) {
    throw "Expected at least $MinTotalCases cases; found $($cases.Count)"
}

$positiveCases = @($cases | Where-Object { $_.expected_tool -ne 'none' })
$negativeCases = @($cases | Where-Object { $_.expected_tool -eq 'none' })

if ($negativeCases.Count -lt $MinNegativeCases) {
    throw "Expected at least $MinNegativeCases negative cases; found $($negativeCases.Count)"
}

$coverage = @()
foreach ($tool in $requiredTools) {
    $count = @($positiveCases | Where-Object { $_.expected_tool -eq $tool }).Count
    $coverage += [PSCustomObject]@{
        tool = $tool
        count = $count
        meets_minimum = ($count -ge $MinPerTool)
    }
}

$coverageFailures = @($coverage | Where-Object { -not $_.meets_minimum })
if ($coverageFailures.Count -gt 0) {
    $details = ($coverageFailures | ForEach-Object { "$($_.tool):$($_.count)" }) -join ', '
    throw "Tool coverage check failed (minimum $MinPerTool per tool): $details"
}

$predictionMode = $false
$misroutes = @()
$passRate = 1.0
$evaluatedCases = 0
$matchedCases = 0

if ($PredictionsFile) {
    if (-not (Test-Path $PredictionsFile)) {
        throw "Predictions file not found: $PredictionsFile"
    }
    $predictionMode = $true
    $predictions = @(Get-Content $PredictionsFile -Raw | ConvertFrom-Json)
    $predictedById = @{}
    foreach ($prediction in $predictions) {
        if (-not $prediction.id) { throw "Prediction entry missing id" }
        $predictedById[[string]$prediction.id] = [string]$prediction.predicted_tool
    }

    foreach ($case in $cases) {
        if (-not $predictedById.ContainsKey([string]$case.id)) { continue }
        $evaluatedCases++
        $predictedTool = $predictedById[[string]$case.id]
        $expectedTool = [string]$case.expected_tool
        if ($predictedTool -eq $expectedTool) {
            $matchedCases++
            continue
        }

        $misroutes += [PSCustomObject]@{
            id = [string]$case.id
            prompt = [string]$case.prompt
            expected_tool = $expectedTool
            predicted_tool = $predictedTool
            suggestion = [string]$case.suggestion_if_misrouted
        }
    }

    if ($evaluatedCases -eq 0) {
        throw "Predictions file contained no matching case IDs."
    }

    $passRate = [double]$matchedCases / [double]$evaluatedCases
    if ($passRate -lt $MinPassRate) {
        $misroutesPath = Join-Path $OutputDir 'misroutes.jsonl'
        if (Test-Path $misroutesPath) {
            Remove-Item $misroutesPath -Force
        }
        foreach ($misroute in $misroutes) {
            ($misroute | ConvertTo-Json -Compress) | Add-Content -Path $misroutesPath
        }
        throw "Intent routing pass rate $([Math]::Round($passRate * 100, 2))% is below minimum $([Math]::Round($MinPassRate * 100, 2))%. See $misroutesPath."
    }
}

$summary = [PSCustomObject]@{
    suite = [string]$suiteName
    eval_file = $EvalFile
    case_count = $cases.Count
    positive_case_count = $positiveCases.Count
    negative_case_count = $negativeCases.Count
    required_tools = $requiredTools
    min_cases_per_tool = $MinPerTool
    tool_coverage = $coverage
    prediction_mode = $predictionMode
    evaluated_case_count = $evaluatedCases
    matched_case_count = $matchedCases
    pass_rate = [Math]::Round($passRate, 4)
    pass_rate_target = $MinPassRate
}

$jsonPath = Join-Path $OutputDir 'summary.json'
$summary | ConvertTo-Json -Depth 8 | Out-File -FilePath $jsonPath -Encoding utf8

$markdown = @()
$markdown += '# Extension Intent Routing Eval Summary'
$markdown += ''
$markdown += "- Suite: ``$([string]$suiteName)``"
$markdown += "- Cases: **$($cases.Count)** (positive: $($positiveCases.Count), negative: $($negativeCases.Count))"
$markdown += "- Prediction mode: **$predictionMode**"
if ($predictionMode) {
    $markdown += "- Pass rate: **$([Math]::Round($passRate * 100, 2))%** (target: $([Math]::Round($MinPassRate * 100, 2))%)"
} else {
    $markdown += '- Pass rate: **not evaluated** (baseline-only mode; runtime routing requires issue #1075 scaffold).'
}
$markdown += ''
$markdown += '| Tool | Cases | Meets Minimum |'
$markdown += '|---|---:|---|'
foreach ($entry in $coverage) {
    $markdown += "| $($entry.tool) | $($entry.count) | $($entry.meets_minimum) |"
}
$markdown += ''
$markdown += '_Generated by scripts/eval-extension-intent-routing.ps1_'

$summaryPath = Join-Path $OutputDir 'summary.md'
$markdown -join "`n" | Out-File -FilePath $summaryPath -Encoding utf8
Write-Output ($markdown -join "`n")
