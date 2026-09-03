#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [string]$CaseFile = "tests/evals/smoke.behavior.json",
    [string]$OutputDir = "test-results",
    [string]$SummaryFile = "",
    [switch]$AbComparison,
    [double]$MinimumLift = 0.5
)

$ErrorActionPreference = "Stop"

function Get-ScoreFromRatio {
    param(
        [double]$Ratio,
        [int]$MaxScore
    )
    if ($Ratio -le 0) { return 0 }
    if ($Ratio -ge 1) { return $MaxScore }
    return [Math]::Round($Ratio * $MaxScore, 2)
}

function Get-WordCount {
    param([string]$Text)
    if (-not $Text) { return 0 }
    return (@($Text -split '\s+' | Where-Object { $_ -and $_.Trim().Length -gt 0 })).Count
}

function Evaluate-Case {
    param(
        $Case,
        [string]$Response1,
        [string]$Response2
    )

    $assertions = $Case.assertions

    $required = @($assertions.required_contains)
    $forbidden = @($assertions.forbidden_contains)
    $requiredSections = @($assertions.required_sections)
    $maxWords = [int]($assertions.max_words | ForEach-Object { if ($_ -eq $null) { 0 } else { $_ } })

    $requiredPass = 0
    foreach ($token in $required) {
        if ($response1 -match [regex]::Escape($token)) { $requiredPass++ }
    }
    $requiredRatio = if ($required.Count -gt 0) { $requiredPass / $required.Count } else { 1.0 }

    $forbiddenHit = $false
    foreach ($token in $forbidden) {
        if ($response1 -match [regex]::Escape($token)) { $forbiddenHit = $true; break }
    }

    $sectionsPass = 0
    foreach ($section in $requiredSections) {
        if ($response1 -match [regex]::Escape($section)) { $sectionsPass++ }
    }
    $sectionsRatio = if ($requiredSections.Count -gt 0) { $sectionsPass / $requiredSections.Count } else { 1.0 }

    $wordCount = Get-WordCount -Text $response1
    $lengthPass = if ($maxWords -gt 0) { [double]($wordCount -le $maxWords) } else { 1.0 }

    # 0-3
    $instructionFollowing = Get-ScoreFromRatio -Ratio (($requiredRatio + $sectionsRatio + $lengthPass) / 3.0) -MaxScore 3
    # 0-2
    $determinism = if ($response1 -eq $response2) { 2 } elseif ($sectionsRatio -ge 0.5) { 1 } else { 0 }
    # 0-2
    $safety = if ($forbiddenHit) { 0 } else { 2 }
    # 0-2
    $usefulness = Get-ScoreFromRatio -Ratio (($requiredRatio + $sectionsRatio) / 2.0) -MaxScore 2
    # 0-1 (latency proxy: bounded size and non-empty response)
    $latencyProxy = if ($wordCount -gt 0 -and ($maxWords -eq 0 -or $wordCount -le $maxWords)) { 1 } else { 0 }

    $weights = $Case.weights
    if (-not $weights) {
        $weights = @{
            instruction_following = 0.3
            determinism = 0.2
            safety = 0.2
            usefulness = 0.2
            latency_proxy = 0.1
        }
    }

    $total = (
        ($instructionFollowing / 3.0) * [double]$weights.instruction_following +
        ($determinism / 2.0) * [double]$weights.determinism +
        ($safety / 2.0) * [double]$weights.safety +
        ($usefulness / 2.0) * [double]$weights.usefulness +
        ($latencyProxy / 1.0) * [double]$weights.latency_proxy
    ) * 10.0

    return [PSCustomObject]@{
        id = $Case.id
        category = $Case.category
        asset_path = $Case.asset_path
        word_count = $wordCount
        scores = [PSCustomObject]@{
            instruction_following = [Math]::Round($instructionFollowing, 2)
            determinism = [Math]::Round($determinism, 2)
            safety = [Math]::Round($safety, 2)
            usefulness = [Math]::Round($usefulness, 2)
            latency_proxy = [Math]::Round($latencyProxy, 2)
            total = [Math]::Round($total, 2)
        }
        checks = [PSCustomObject]@{
            required_match_ratio = [Math]::Round($requiredRatio, 2)
            section_match_ratio = [Math]::Round($sectionsRatio, 2)
            forbidden_hit = $forbiddenHit
            max_words = $maxWords
        }
    }
}

if (-not (Test-Path $CaseFile)) {
    throw "Case file not found: $CaseFile"
}

$raw = Get-Content $CaseFile -Raw
$suite = $raw | ConvertFrom-Json

if (-not $suite.cases -or $suite.cases.Count -eq 0) {
    throw "No evaluation cases found in: $CaseFile"
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$results = @()
foreach ($case in $suite.cases) {
    $response1 = $case.mock_responses[0]
    $response2 = if ($case.mock_responses.Count -gt 1) { $case.mock_responses[1] } else { $response1 }
    $results += Evaluate-Case -Case $case -Response1 $response1 -Response2 $response2
}

$avg = [Math]::Round((($results | Measure-Object -Property { $_.scores.total } -Average).Average), 2)
$min = [Math]::Round((($results | Measure-Object -Property { $_.scores.total } -Minimum).Minimum), 2)
$max = [Math]::Round((($results | Measure-Object -Property { $_.scores.total } -Maximum).Maximum), 2)

$report = [PSCustomObject]@{
    collected_at = (Get-Date).ToUniversalTime().ToString("o")
    suite = $suite.suite
    case_count = $results.Count
    avg_score = $avg
    min_score = $min
    max_score = $max
    results = $results
}

if ($AbComparison) {
    $baselineResults = @()
    $enhancedResults = @()
    foreach ($case in $suite.cases) {
        $baseline = if ($case.baseline_response) { $case.baseline_response } else { $case.mock_responses[0] }
        $enhanced = if ($case.enhanced_response) { $case.enhanced_response } else { $case.mock_responses[0] }
        $baselineResults += Evaluate-Case -Case $case -Response1 $baseline -Response2 $baseline
        $enhancedResults += Evaluate-Case -Case $case -Response1 $enhanced -Response2 $enhanced
    }

    $baselineScore = [Math]::Round((($baselineResults | Measure-Object -Property { $_.scores.total } -Average).Average), 2)
    $enhancedScore = [Math]::Round((($enhancedResults | Measure-Object -Property { $_.scores.total } -Average).Average), 2)
    $lift = [Math]::Round($enhancedScore - $baselineScore, 2)
    $report | Add-Member -NotePropertyName ab_comparison -NotePropertyValue ([PSCustomObject]@{
        baseline_avg_score = $baselineScore
        enhanced_avg_score = $enhancedScore
        score_lift = $lift
        minimum_lift = $MinimumLift
        decision = if ($lift -ge $MinimumLift) { 'retain' } else { 'demote' }
        baseline_word_count = [int](($baselineResults | Measure-Object -Property word_count -Average).Average)
        enhanced_word_count = [int](($enhancedResults | Measure-Object -Property word_count -Average).Average)
        baseline_turns = [int](($suite.cases | ForEach-Object { if ($_.baseline_turns) { $_.baseline_turns } else { 1 } } | Measure-Object -Average).Average)
        enhanced_turns = [int](($suite.cases | ForEach-Object { if ($_.enhanced_turns) { $_.enhanced_turns } else { 1 } } | Measure-Object -Average).Average)
    })
    if ($lift -lt $MinimumLift) {
        throw "A/B evaluation failed: score lift $lift is below minimum $MinimumLift; demote the cognitive layer."
    }
}

$jsonPath = Join-Path $OutputDir "eval-agents.json"
$report | ConvertTo-Json -Depth 8 | Out-File -FilePath $jsonPath -Encoding utf8

if (-not $SummaryFile) {
    $SummaryFile = Join-Path $OutputDir "eval-summary.md"
}

$summary = @()
$summary += "# Behavioral Evaluation Summary"
$summary += ""
$summary += "- Suite: ``$($suite.suite)``"
$summary += "- Cases: **$($results.Count)**"
$summary += "- Avg score: **$avg / 10**"
$summary += "- Min/Max: **$min / $max**"
$summary += ""
$summary += "| Case | Category | Total | Instruction | Determinism | Safety | Usefulness |"
$summary += "|---|---|---:|---:|---:|---:|---:|"
foreach ($r in $results) {
    $summary += "| $($r.id) | $($r.category) | $($r.scores.total) | $($r.scores.instruction_following) | $($r.scores.determinism) | $($r.scores.safety) | $($r.scores.usefulness) |"
}
if ($report.ab_comparison) {
    $summary += ""
    $summary += "## HRM/TRM/memory A/B decision"
    $summary += ""
    $summary += "- Baseline average: **$($report.ab_comparison.baseline_avg_score) / 10**"
    $summary += "- Enhanced average: **$($report.ab_comparison.enhanced_avg_score) / 10**"
    $summary += "- Score lift: **$($report.ab_comparison.score_lift)** (minimum: $($report.ab_comparison.minimum_lift))"
    $summary += "- Turn count baseline/enhanced: **$($report.ab_comparison.baseline_turns) / $($report.ab_comparison.enhanced_turns)**"
    $summary += "- Decision: **$($report.ab_comparison.decision)**"
}
$summary += ""
$summary += "_Generated by scripts/eval-assets.ps1_"

$summary -join "`n" | Out-File -FilePath $SummaryFile -Encoding utf8
Write-Output ($summary -join "`n")
