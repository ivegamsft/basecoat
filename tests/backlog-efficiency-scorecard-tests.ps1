#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests for backlog-efficiency-scorecard acceptance gating.
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running backlog-efficiency-scorecard tests...'

$failures = @()

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        $script:failures += $Message
    }
}

function New-SessionRecord {
    param(
        [string]$SessionId,
        [long]$InputTokens,
        [bool]$PhaseCompactionApplied = $true,
        [bool]$SprintTemplateUsed = $true,
        [bool]$FileReferencesOnly = $true,
        [bool]$DelegatedScanOrTriage = $true
    )

    return [ordered]@{
        sessionId              = $SessionId
        inputTokens            = $InputTokens
        phaseCompactionApplied = $PhaseCompactionApplied
        sprintTemplateUsed     = $SprintTemplateUsed
        fileReferencesOnly     = $FileReferencesOnly
        delegatedScanOrTriage  = $DelegatedScanOrTriage
    }
}

function Invoke-Scorecard {
    param(
        [array]$Sessions
    )

    $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ("efficiency-scorecard-test-" + [Guid]::NewGuid().ToString() + '.json')
    try {
        $Sessions | ConvertTo-Json -Depth 6 | Set-Content -Path $tempFile -Encoding UTF8
        $json = pwsh -NoProfile -File (Join-Path $repoRoot 'scripts\backlog-efficiency-scorecard.ps1') -InputFile $tempFile -Json
        return (($json -join "`n") | ConvertFrom-Json)
    }
    finally {
        if (Test-Path $tempFile) {
            Remove-Item -Path $tempFile -Force
        }
    }
}

# Test 1: 5 compliant sessions in 35M-45M range should pass
$status = Invoke-Scorecard -Sessions @(
    (New-SessionRecord -SessionId 's1' -InputTokens 38000000),
    (New-SessionRecord -SessionId 's2' -InputTokens 41000000),
    (New-SessionRecord -SessionId 's3' -InputTokens 43000000),
    (New-SessionRecord -SessionId 's4' -InputTokens 39000000),
    (New-SessionRecord -SessionId 's5' -InputTokens 40000000)
)

Assert-True ($status.measurementReady) 'Expected measurementReady to be true with 5 sessions'
Assert-True ($status.targetMetByAverage) 'Expected targetMetByAverage to be true in 35M-45M range'
Assert-True ($status.allPracticesCompliant) 'Expected all practices compliant for all-true flags'
Assert-True ($status.overallPass) 'Expected overallPass to be true for fully compliant in-range sessions'

# Test 2: fewer than 5 sessions should block pass
$status = Invoke-Scorecard -Sessions @(
    (New-SessionRecord -SessionId 's1' -InputTokens 39000000),
    (New-SessionRecord -SessionId 's2' -InputTokens 39500000),
    (New-SessionRecord -SessionId 's3' -InputTokens 40500000),
    (New-SessionRecord -SessionId 's4' -InputTokens 41000000)
)

Assert-True (-not $status.measurementReady) 'Expected measurementReady false when fewer than 5 sessions are provided'
Assert-True (-not $status.overallPass) 'Expected overallPass false when measurementReady is false'

# Test 3: out-of-range average should fail target
$status = Invoke-Scorecard -Sessions @(
    (New-SessionRecord -SessionId 's1' -InputTokens 50000000),
    (New-SessionRecord -SessionId 's2' -InputTokens 52000000),
    (New-SessionRecord -SessionId 's3' -InputTokens 51000000),
    (New-SessionRecord -SessionId 's4' -InputTokens 53000000),
    (New-SessionRecord -SessionId 's5' -InputTokens 54000000)
)

Assert-True (-not $status.targetMetByAverage) 'Expected targetMetByAverage false when average is above 45M'
Assert-True (-not $status.overallPass) 'Expected overallPass false when target is not met'

# Test 4: non-compliant practice should fail overall pass
$status = Invoke-Scorecard -Sessions @(
    (New-SessionRecord -SessionId 's1' -InputTokens 39000000 -DelegatedScanOrTriage $false),
    (New-SessionRecord -SessionId 's2' -InputTokens 40000000),
    (New-SessionRecord -SessionId 's3' -InputTokens 41000000),
    (New-SessionRecord -SessionId 's4' -InputTokens 42000000),
    (New-SessionRecord -SessionId 's5' -InputTokens 43000000)
)

Assert-True (-not $status.allPracticesCompliant) 'Expected allPracticesCompliant false when one practice flag is false'
Assert-True (-not $status.overallPass) 'Expected overallPass false when practice compliance is incomplete'

@'
import importlib.util
import pathlib
import tempfile
root = pathlib.Path.cwd()
spec = importlib.util.spec_from_file_location("generator", root / "scripts" / "generate-backlog-efficiency-scorecard.py")
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)
source = generator.load_source(root / ".github" / "backlog-session-metrics.json")
with tempfile.TemporaryDirectory() as directory:
    capture = pathlib.Path(directory) / "nonexistent-source.json"
    rendered = generator.render_markdown(capture, pathlib.Path("source.json"), pathlib.Path("scorecard.md"), source)
    assert f"- Generated: {source['generatedAt']}" in rendered
    source.pop("generatedAt")
    fallback = generator.render_markdown(capture, pathlib.Path("source.json"), pathlib.Path("scorecard.md"), source)
    assert "- Generated: " + max(session["date"] for session in source["sessions"]) in fallback
print("Scorecard generation uses tracked cut, not filesystem timestamps.")
'@ | python -
Assert-True ($LASTEXITCODE -eq 0) 'Tracked timestamp generator must not depend on filesystem mtime.'

if ($failures.Count -gt 0) {
    Write-Host "backlog-efficiency-scorecard tests FAILED ($($failures.Count) issue(s))" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'backlog-efficiency-scorecard tests passed' -ForegroundColor Green
exit 0
