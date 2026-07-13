$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

Write-Host "Running Keep/Fix/Throttle weekly scorecard tests..."

$scriptPath = Join-Path $repoRoot "scripts\keep-fix-throttle-weekly-scorecard.ps1"
$workflowPath = Join-Path $repoRoot ".github\workflows\keep-fix-throttle-weekly-scorecard.yml"
$runbookPath = Join-Path $repoRoot "docs\operations\keep-fix-throttle-weekly-scorecard.md"
$specPath = Join-Path $repoRoot "docs\spec\keep-fix-throttle-weekly-scorecard.spec.md"
$fixturePath = Join-Path $repoRoot "tests\fixtures\keep-fix-throttle-weekly-snapshots.example.json"

foreach ($required in @($scriptPath, $workflowPath, $runbookPath, $specPath, $fixturePath)) {
    if (-not (Test-Path $required)) {
        throw "Missing required artifact: $required"
    }
}

$tempDir = Join-Path $repoRoot ("test-results\kft-scorecard-tests-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    & $scriptPath `
        -Repository "IBuySpy-Shared/basecoat" `
        -SnapshotPath $fixturePath `
        -TrendWindowWeeks 4 `
        -DryRun `
        -OutputDir $tempDir

    if (-not $?) {
        throw "Scorecard script failed."
    }

    $jsonPath = Join-Path $tempDir "keep-fix-throttle-weekly-scorecard.json"
    $mdPath = Join-Path $tempDir "keep-fix-throttle-weekly-scorecard.md"
    foreach ($artifact in @($jsonPath, $mdPath)) {
        if (-not (Test-Path $artifact)) {
            throw "Expected artifact missing: $artifact"
        }
    }

    $result = Get-Content -Raw -Path $jsonPath | ConvertFrom-Json -Depth 100
    if ($result.schema_version -ne "1.0.0") {
        throw "Unexpected schema version: $($result.schema_version)"
    }
    if ($result.samples_analyzed -ne 4) {
        throw "Expected samples_analyzed = 4, got $($result.samples_analyzed)"
    }
    if ($result.metrics.throughput.trend -ne "improving") {
        throw "Expected throughput trend improving, got $($result.metrics.throughput.trend)"
    }
    if ($result.metrics.failure_rate.trend -ne "improving") {
        throw "Expected failure_rate trend improving, got $($result.metrics.failure_rate.trend)"
    }
    if ($result.metrics.mttr_hours.trend -ne "improving") {
        throw "Expected mttr_hours trend improving, got $($result.metrics.mttr_hours.trend)"
    }
    if ($result.metrics.manual_intervention_rate.trend -ne "improving") {
        throw "Expected manual_intervention_rate trend improving, got $($result.metrics.manual_intervention_rate.trend)"
    }
    if ([string]::IsNullOrWhiteSpace([string]$result.metrics.failure_rate.remediation_link)) {
        throw "Expected remediation link for failure_rate metric."
    }

    $markdown = Get-Content -Raw -Path $mdPath
    if ($markdown -notmatch "## Metric Readout") {
        throw "Markdown readout missing Metric Readout section."
    }
    if ($markdown -notmatch "Throughput") {
        throw "Markdown readout missing throughput metric."
    }
    if ($markdown -notmatch "Manual intervention rate") {
        throw "Markdown readout missing manual intervention metric."
    }
    if ($markdown -notmatch "## Review Workflow") {
        throw "Markdown readout missing review workflow section."
    }

    $workflow = Get-Content -Raw -Path $workflowPath
    if ($workflow -notmatch "schedule:") {
        throw "Workflow must include schedule trigger."
    }
    if ($workflow -notmatch "workflow_dispatch:") {
        throw "Workflow must include workflow_dispatch trigger."
    }
    if ($workflow -notmatch "Upload weekly scorecard artifacts") {
        throw "Workflow must upload scorecard artifacts."
    }
    if ($workflow -notmatch "Post weekly readout comment") {
        throw "Workflow must post weekly readout comment."
    }

    # Single-snapshot run: exercises the empty-history path that failed under StrictMode.
    $singlePath = Join-Path $tempDir "single-snapshot.json"
    '[{"week_start":"2026-06-23","throughput":13,"failure_rate":0.06,"mttr_hours":29.5,"manual_intervention_rate":0.50}]' |
        Set-Content -Path $singlePath -Encoding UTF8
    $singleOut = Join-Path $tempDir "single"
    & $scriptPath `
        -Repository "IBuySpy-Shared/basecoat" `
        -SnapshotPath $singlePath `
        -TrendWindowWeeks 4 `
        -DryRun `
        -OutputDir $singleOut
    if (-not $?) {
        throw "Single-snapshot scorecard run failed (empty-history path)."
    }
    $singleResult = Get-Content -Raw -Path (Join-Path $singleOut "keep-fix-throttle-weekly-scorecard.json") | ConvertFrom-Json -Depth 100
    if ($singleResult.samples_analyzed -ne 1) {
        throw "Expected samples_analyzed = 1 for a single snapshot, got $($singleResult.samples_analyzed)."
    }
    foreach ($metricName in @('throughput', 'failure_rate', 'mttr_hours', 'manual_intervention_rate')) {
        if ($singleResult.metrics.$metricName.trend -ne 'insufficient-data') {
            throw "Expected $metricName trend insufficient-data for a single snapshot, got $($singleResult.metrics.$metricName.trend)."
        }
    }
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
}

Write-Host "Keep/Fix/Throttle weekly scorecard tests passed." -ForegroundColor Green
exit 0
