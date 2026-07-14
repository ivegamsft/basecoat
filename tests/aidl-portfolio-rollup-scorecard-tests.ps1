$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running AIDL portfolio rollup scorecard tests...'

$scriptPath = Join-Path $repoRoot 'scripts\aidl-portfolio-rollup-scorecard.ps1'
if (-not (Test-Path $scriptPath)) {
    throw "Missing script: $scriptPath"
}

$tempDir = Join-Path $repoRoot ("test-results\aidl-rollup-scorecard-tests-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$caseIndex = 0
function New-Rollup {
    param(
        [double]$SprintPct = 95,
        [int]$Blocked = 0,
        [int]$Incidents = 0,
        [int]$RiskHigh = 0,
        [double]$MedianResolution = 10,
        [double]$PrLeadTime = 20,
        [int]$ClosedIncidents = 1,
        [int]$MergedPrs = 1,
        [int]$SprintOpen = 3,
        [int]$SprintClosed = 5,
        [string]$GeneratedAt = '2026-01-05T09:00:00Z'
    )
    $portfolio = [ordered]@{
        leading_indicators = [ordered]@{
            blocked_open_issues = $Blocked
            open_review_queue = 0
            open_risk_high_issues = $RiskHigh
            open_incidents = $Incidents
        }
        lagging_indicators = [ordered]@{
            incident_median_resolution_hours = $MedianResolution
            average_pr_lead_time_hours = $PrLeadTime
            closed_incidents = $ClosedIncidents
            merged_prs = $MergedPrs
        }
        roadmap_vs_sprint = [ordered]@{
            sprint_open_items = $SprintOpen
            sprint_closed_items = $SprintClosed
            sprint_completion_pct = $SprintPct
        }
    }
    $obj = [ordered]@{
        portfolio = $portfolio
    }
    if (-not [string]::IsNullOrEmpty($GeneratedAt)) {
        $obj.Insert(0, 'generated_at_utc', $GeneratedAt)
    }
    return ($obj | ConvertTo-Json -Depth 10)
}

function Invoke-Scorecard {
    param([string]$RollupJson, [string]$ThresholdsPath = '', [string]$RunUrl = 'https://github.com/IBuySpy-Shared/basecoat/actions/runs/1/attempts/1')

    $script:caseIndex++
    $rollupPath = Join-Path $tempDir ("rollup-$script:caseIndex.json")
    $outputDir = Join-Path $tempDir ("output-$script:caseIndex")
    Set-Content -Path $rollupPath -Value $RollupJson -Encoding UTF8

    $args = @('-NoProfile', '-File', $scriptPath, '-RollupPath', $rollupPath, '-OutputDir', $outputDir, '-RunUrl', $RunUrl)
    if ($ThresholdsPath) { $args += @('-ThresholdsPath', $ThresholdsPath) }
    & pwsh @args 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Case $script:caseIndex scorecard run failed (exit $LASTEXITCODE)." }
    return (Get-Content (Join-Path $outputDir 'portfolio-rollup-scorecard.json') -Raw | ConvertFrom-Json)
}

function Get-MetricStatus {
    param([object]$Card, [string]$Metric)
    return (@($Card.metrics | Where-Object { $_.metric -eq $Metric })[0]).status
}

try {
    # --- Case 1: all-healthy portfolio grades pass overall. ---
    $card = Invoke-Scorecard -RollupJson (New-Rollup -SprintPct 95 -Blocked 0 -Incidents 0 -RiskHigh 0 -MedianResolution 10 -PrLeadTime 20)
    if ($card.overall_outcome -ne 'pass') { throw "Case 1: expected pass, got $($card.overall_outcome)." }

    # --- Case 2: higher-is-better (sprint completion) boundaries. ---
    if ((Get-MetricStatus -Card (Invoke-Scorecard -RollupJson (New-Rollup -SprintPct 80)) -Metric 'sprint_completion_pct') -ne 'pass') { throw 'Case 2: sprint 80 must pass.' }
    if ((Get-MetricStatus -Card (Invoke-Scorecard -RollupJson (New-Rollup -SprintPct 70)) -Metric 'sprint_completion_pct') -ne 'warn') { throw 'Case 2: sprint 70 must warn.' }
    if ((Get-MetricStatus -Card (Invoke-Scorecard -RollupJson (New-Rollup -SprintPct 50)) -Metric 'sprint_completion_pct') -ne 'fail') { throw 'Case 2: sprint 50 must fail.' }

    # --- Case 3: lower-is-better (open incidents) boundaries. ---
    if ((Get-MetricStatus -Card (Invoke-Scorecard -RollupJson (New-Rollup -Incidents 0)) -Metric 'open_incidents') -ne 'pass') { throw 'Case 3: 0 incidents must pass.' }
    if ((Get-MetricStatus -Card (Invoke-Scorecard -RollupJson (New-Rollup -Incidents 2)) -Metric 'open_incidents') -ne 'warn') { throw 'Case 3: 2 incidents must warn.' }
    if ((Get-MetricStatus -Card (Invoke-Scorecard -RollupJson (New-Rollup -Incidents 5)) -Metric 'open_incidents') -ne 'fail') { throw 'Case 3: 5 incidents must fail.' }

    # --- Case 4: outcome is derived from the maturity band and never contradicts the score. ---
    # A blocking fail caps the domain in the fail band.
    $card = Invoke-Scorecard -RollupJson (New-Rollup -SprintPct 95 -Incidents 5)
    if ($card.overall_outcome -ne 'fail') { throw 'Case 4: any fail metric must make the overall outcome fail.' }
    if ($card.maturity_score -ge 60) { throw 'Case 4: a fail must cap the maturity score in the fail band (<60).' }
    # An all-warn portfolio (no fail, no no-data) lands in the warn band.
    $card = Invoke-Scorecard -RollupJson (New-Rollup -SprintPct 70 -Blocked 2 -Incidents 2 -RiskHigh 2 -MedianResolution 50 -PrLeadTime 80)
    if ($card.overall_outcome -ne 'warn') { throw "Case 4: an all-warn portfolio must be warn, got $($card.overall_outcome)." }
    if ($card.maturity_score -lt 60 -or $card.maturity_score -gt 84) { throw 'Case 4: an all-warn portfolio score must be in the warn band (60-84).' }
    # A single warn control (with the rest passing) still cannot yield a passing tier.
    $card = Invoke-Scorecard -RollupJson (New-Rollup -Blocked 2)
    if ($card.overall_outcome -ne 'warn') { throw "Case 4: a single warn metric must keep the outcome at warn, got $($card.overall_outcome)." }

    # --- Case 5: threshold overrides change grading. ---
    $thresholds = Join-Path $tempDir 'thresholds.json'
    Set-Content -Path $thresholds -Value '{ "open_incidents": { "pass": 5, "warn": 10 } }' -Encoding UTF8
    $card = Invoke-Scorecard -RollupJson (New-Rollup -Incidents 5) -ThresholdsPath $thresholds
    if ((Get-MetricStatus -Card $card -Metric 'open_incidents') -ne 'pass') { throw 'Case 5: override should let 5 incidents pass.' }

    # --- Case 6: evidence links are attached. ---
    $runUrl = 'https://github.com/IBuySpy-Shared/basecoat/actions/runs/10/attempts/1'
    $card = Invoke-Scorecard -RollupJson (New-Rollup) -RunUrl $runUrl
    if ($card.evidence.run_url -ne $runUrl) { throw 'Case 6: run_url evidence must be attached.' }
    if ([string]::IsNullOrWhiteSpace($card.evidence.rollup_source)) { throw 'Case 6: rollup_source evidence must be attached.' }
    $capturedUtc = ([datetimeoffset]$card.evidence.rollup_generated_at_utc).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    if ($capturedUtc -ne '2026-01-05T09:00:00Z') { throw "Case 6: rollup generated_at must be captured as evidence, got $capturedUtc." }

    # --- Case 7: a rollup without a portfolio aggregate is rejected. ---
    $noPortfolio = Join-Path $tempDir 'no-portfolio.json'
    Set-Content -Path $noPortfolio -Value '{ "generated_at_utc": "2026-01-05T09:00:00Z" }' -Encoding UTF8
    $noPortfolioOut = Join-Path $tempDir 'output-noportfolio'
    & pwsh -NoProfile -File $scriptPath -RollupPath $noPortfolio -OutputDir $noPortfolioOut -RunUrl 'https://example/run' 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Case 7: a rollup without a portfolio aggregate must be rejected.' }

    # --- Case 8: OutputDir outside the repository root is rejected. ---
    $guardRollup = Join-Path $tempDir 'guard-rollup.json'
    Set-Content -Path $guardRollup -Value (New-Rollup) -Encoding UTF8
    $outsideDir = Join-Path ([System.IO.Path]::GetTempPath()) ("aidl-scorecard-outside-" + [Guid]::NewGuid().ToString('N'))
    & pwsh -NoProfile -File $scriptPath -RollupPath $guardRollup -OutputDir $outsideDir -RunUrl 'https://example/run' 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Case 8: OutputDir outside the repo root must be rejected.' }

    # --- Case 9: duration metrics with zero samples grade as no-data (not pass). ---
    $card = Invoke-Scorecard -RollupJson (New-Rollup -MedianResolution 0 -PrLeadTime 0 -ClosedIncidents 0 -MergedPrs 0)
    if ((Get-MetricStatus -Card $card -Metric 'incident_median_resolution_hours') -ne 'no-data') { throw 'Case 9: zero closed_incidents must grade resolution as no-data.' }
    if ((Get-MetricStatus -Card $card -Metric 'average_pr_lead_time_hours') -ne 'no-data') { throw 'Case 9: zero merged_prs must grade lead time as no-data.' }
    if ($card.overall_outcome -eq 'pass') { throw 'Case 9: a no-data metric must prevent a healthy pass outcome.' }

    # --- Case 10: incoherent threshold overrides are rejected. ---
    $badThresholds = Join-Path $tempDir 'bad-thresholds.json'
    Set-Content -Path $badThresholds -Value '{ "open_incidents": { "pass": 5, "warn": 2 } }' -Encoding UTF8
    $badRollup = Join-Path $tempDir 'bad-thresholds-rollup.json'
    Set-Content -Path $badRollup -Value (New-Rollup) -Encoding UTF8
    $badOut = Join-Path $tempDir 'output-badthresholds'
    & pwsh -NoProfile -File $scriptPath -RollupPath $badRollup -OutputDir $badOut -ThresholdsPath $badThresholds -RunUrl 'https://example/run' 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Case 10: inverted lower-is-better thresholds (pass > warn) must be rejected.' }

    # --- Case 11: a rollup missing generated_at_utc is rejected. ---
    $noTs = Join-Path $tempDir 'no-timestamp.json'
    Set-Content -Path $noTs -Value (New-Rollup -GeneratedAt '') -Encoding UTF8
    $noTsOut = Join-Path $tempDir 'output-nots'
    & pwsh -NoProfile -File $scriptPath -RollupPath $noTs -OutputDir $noTsOut -RunUrl 'https://example/run' 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Case 11: a rollup without generated_at_utc must be rejected.' }

    # --- Case 12: sprint completion with no sprint items grades no-data (not fail). ---
    $card = Invoke-Scorecard -RollupJson (New-Rollup -SprintPct 0 -SprintOpen 0 -SprintClosed 0)
    if ((Get-MetricStatus -Card $card -Metric 'sprint_completion_pct') -ne 'no-data') { throw 'Case 12: zero sprint items must grade sprint completion as no-data.' }
    if ($card.overall_outcome -eq 'fail') { throw 'Case 12: no sprint items must not force an overall fail via sprint completion alone.' }

    # --- Case 13: a malformed (non-date) generated_at_utc is rejected. ---
    $badTs = Join-Path $tempDir 'bad-timestamp.json'
    Set-Content -Path $badTs -Value (New-Rollup -GeneratedAt 'not-a-date') -Encoding UTF8
    $badTsOut = Join-Path $tempDir 'output-badts'
    & pwsh -NoProfile -File $scriptPath -RollupPath $badTs -OutputDir $badTsOut -RunUrl 'https://example/run' 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Case 13: a malformed generated_at_utc must be rejected.' }

    # --- Case 14: identical rollups produce byte-identical scorecards (deterministic). ---
    $detRollup = Join-Path $tempDir 'det-rollup.json'
    Set-Content -Path $detRollup -Value (New-Rollup -SprintPct 72 -Blocked 1) -Encoding UTF8
    $detOut1 = Join-Path $tempDir 'output-det1'
    $detOut2 = Join-Path $tempDir 'output-det2'
    & pwsh -NoProfile -File $scriptPath -RollupPath $detRollup -OutputDir $detOut1 -RunUrl 'https://example/run' 2>$null
    & pwsh -NoProfile -File $scriptPath -RollupPath $detRollup -OutputDir $detOut2 -RunUrl 'https://example/run' 2>$null
    $json1 = Get-Content (Join-Path $detOut1 'portfolio-rollup-scorecard.json') -Raw
    $json2 = Get-Content (Join-Path $detOut2 'portfolio-rollup-scorecard.json') -Raw
    if ($json1 -ne $json2) { throw 'Case 14: identical rollups must produce byte-identical scorecards.' }

    # --- Case 15: the markdown companion exists and contains the outcome, a metric, and evidence. ---
    $mdRollup = Join-Path $tempDir 'md-rollup.json'
    Set-Content -Path $mdRollup -Value (New-Rollup -Incidents 5) -Encoding UTF8
    $mdOut = Join-Path $tempDir 'output-md'
    & pwsh -NoProfile -File $scriptPath -RollupPath $mdRollup -OutputDir $mdOut -RunUrl 'https://example/run' 2>$null
    $mdPath = Join-Path $mdOut 'portfolio-rollup-scorecard.md'
    if (-not (Test-Path $mdPath)) { throw 'Case 15: the markdown scorecard companion must be written.' }
    $mdContent = Get-Content $mdPath -Raw
    if ($mdContent -notmatch 'Overall outcome') { throw 'Case 15: markdown must include the overall outcome.' }
    if ($mdContent -notmatch 'Open incidents') { throw 'Case 15: markdown must include the metric table.' }
    if ($mdContent -notmatch 'Rollup source') { throw 'Case 15: markdown must include the rollup source evidence.' }

    # --- Case 16: maturity_score is emitted, 0-100, and consistent with grades. ---
    $card = Invoke-Scorecard -RollupJson (New-Rollup -SprintPct 95 -Blocked 0 -Incidents 0 -RiskHigh 0 -MedianResolution 10 -PrLeadTime 20)
    if ($card.maturity_score -ne 100) { throw "Case 16: an all-pass portfolio must score 100, got $($card.maturity_score)." }
    $card = Invoke-Scorecard -RollupJson (New-Rollup -Incidents 5)
    if ($card.maturity_score -lt 0 -or $card.maturity_score -gt 100) { throw 'Case 16: maturity_score must be within 0-100.' }
    if ($card.maturity_score -ge 100) { throw 'Case 16: a failing metric must lower the maturity score below 100.' }

    # --- Case 17: an unknown threshold key is rejected. ---
    $unknownThresholds = Join-Path $tempDir 'unknown-thresholds.json'
    Set-Content -Path $unknownThresholds -Value '{ "open_incident": { "pass": 0, "warn": 2 } }' -Encoding UTF8
    $unknownRollup = Join-Path $tempDir 'unknown-rollup.json'
    Set-Content -Path $unknownRollup -Value (New-Rollup) -Encoding UTF8
    $unknownOut = Join-Path $tempDir 'output-unknown'
    & pwsh -NoProfile -File $scriptPath -RollupPath $unknownRollup -OutputDir $unknownOut -ThresholdsPath $unknownThresholds -RunUrl 'https://example/run' 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Case 17: an unknown threshold key must be rejected.' }

    # --- Case 18: a run URL is required for an auditable scorecard. ---
    $reqRollup = Join-Path $tempDir 'req-run-rollup.json'
    Set-Content -Path $reqRollup -Value (New-Rollup) -Encoding UTF8
    $reqOut = Join-Path $tempDir 'output-reqrun'
    & pwsh -NoProfile -NonInteractive -File $scriptPath -RollupPath $reqRollup -OutputDir $reqOut 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Case 18: a scorecard without a run URL must be rejected.' }

    # --- Case 19: overall_outcome always agrees with the maturity-score band. ---
    foreach ($fixture in @(
            (New-Rollup),
            (New-Rollup -SprintPct 70 -Blocked 2 -Incidents 2 -RiskHigh 2 -MedianResolution 50 -PrLeadTime 80),
            (New-Rollup -Incidents 5),
            (New-Rollup -MedianResolution 0 -PrLeadTime 0 -ClosedIncidents 0 -MergedPrs 0))) {
        $card = Invoke-Scorecard -RollupJson $fixture
        $expected = if ($card.maturity_score -ge 85) { 'pass' } elseif ($card.maturity_score -ge 60) { 'warn' } else { 'fail' }
        if ($card.overall_outcome -ne $expected) { throw "Case 19: outcome $($card.overall_outcome) disagrees with band for score $($card.maturity_score) (expected $expected)." }
    }

    # --- Case 20: a whitespace-only run URL is rejected. ---
    $wsRollup = Join-Path $tempDir 'ws-run-rollup.json'
    Set-Content -Path $wsRollup -Value (New-Rollup) -Encoding UTF8
    $wsOut = Join-Path $tempDir 'output-wsrun'
    & pwsh -NoProfile -File $scriptPath -RollupPath $wsRollup -OutputDir $wsOut -RunUrl '   ' 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Case 20: a whitespace-only run URL must be rejected.' }

    # --- Case 21: malformed overrides for a known key are rejected. ---
    foreach ($bad in @('{ "open_incidents": {} }', '{ "open_incidents": 5 }', '{ "open_incidents": { "pass": "x" } }')) {
        $badOvFile = Join-Path $tempDir ("bad-override-" + [Guid]::NewGuid().ToString('N') + '.json')
        Set-Content -Path $badOvFile -Value $bad -Encoding UTF8
        $badOvRollup = Join-Path $tempDir ("bad-override-rollup-" + [Guid]::NewGuid().ToString('N') + '.json')
        Set-Content -Path $badOvRollup -Value (New-Rollup) -Encoding UTF8
        $badOvOut = Join-Path $tempDir ("output-badov-" + [Guid]::NewGuid().ToString('N'))
        & pwsh -NoProfile -File $scriptPath -RollupPath $badOvRollup -OutputDir $badOvOut -ThresholdsPath $badOvFile -RunUrl 'https://example/run' 2>$null
        if ($LASTEXITCODE -eq 0) { throw "Case 21: malformed override '$bad' must be rejected." }
    }
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
}

Write-Host 'AIDL portfolio rollup scorecard tests passed' -ForegroundColor Green
exit 0
