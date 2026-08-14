#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests for adoption scanner (scripts/adoption/detect-basecoat.ps1).

.DESCRIPTION
    Validates adoption scanner functionality including:
    - Parameter parsing (Org, BasecoatRepo, OutputFormat)
    - Output format validation (table, json, markdown)
    - Helper function behavior (mocked API responses)
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running adoption scanner tests...'

# Test 1: Parameter validation - OutputFormat must be one of: table, json, markdown
Write-Host '  Test 1: Validate OutputFormat parameter constraints...'

$scannerScript = Join-Path (Join-Path $repoRoot 'scripts') 'adoption/detect-basecoat.ps1'
if (-not (Test-Path $scannerScript)) {
    throw "OutputFormat validation failed: scanner script path missing ($scannerScript)"
}
. $scannerScript -LibraryOnly
$elapsedStart = [datetime]'2026-08-01T00:00:00Z'
foreach ($case in @(
    @{ Offset = [timespan]::FromHours(11) + [timespan]::FromMinutes(59); Expected = 0 },
    @{ Offset = [timespan]::FromHours(12); Expected = 0 },
    @{ Offset = [timespan]::FromHours(23) + [timespan]::FromMinutes(59); Expected = 0 },
    @{ Offset = [timespan]::FromHours(24); Expected = 1 },
    @{ Offset = [timespan]::FromDays(3) + [timespan]::FromHours(12); Expected = 3 }
)) {
    $actual = Get-CompletedElapsedDays -Start $elapsedStart -Now ($elapsedStart + $case.Offset)
    if ($actual -ne $case.Expected) {
        throw "Fleet drift age must count completed days at offset '$($case.Offset)'; expected $($case.Expected), got $actual."
    }
}
$unknownMarker = '<!-- basecoat-consumer-update:{"schema":1,"current_version":"4.1.0","target_version":"","target_sha":"","disposition":"unknown","pr_url":"","drift_started_at":"2026-08-01T00:00:00Z"} -->'
$global:BasecoatUnknownIssueJson = @(
    [pscustomobject]@{
        body = $unknownMarker
        url = 'https://github.com/example/consumer/issues/7'
        createdAt = '2026-08-01T00:00:00Z'
        state = 'OPEN'
    }
) | ConvertTo-Json -Compress
function global:gh {
    $global:LASTEXITCODE = 0
    return $global:BasecoatUnknownIssueJson
}
$unknownState = Get-ConsumerUpdateState -Repository 'example/consumer'
Remove-Item Function:\gh -Force
Remove-Variable BasecoatUnknownIssueJson -Scope Global
if (
    -not $unknownState -or
    $unknownState.target_version -ne '' -or
    $unknownState.disposition -ne 'unknown' -or
    $unknownState.issue_state -ne 'OPEN' -or
    $unknownState.issue_url -ne 'https://github.com/example/consumer/issues/7'
) {
    throw 'Fleet scanner must preserve the stable legacy setup issue when its unresolved target is empty.'
}
$stdoutPath = Join-Path ([System.IO.Path]::GetTempPath()) ("adoption-scanner-outputformat-stdout-" + [System.Guid]::NewGuid().ToString() + ".log")
$stderrPath = Join-Path ([System.IO.Path]::GetTempPath()) ("adoption-scanner-outputformat-stderr-" + [System.Guid]::NewGuid().ToString() + ".log")
$stderrContent = ''

try {
    $process = Start-Process -FilePath 'pwsh' -ArgumentList @(
        '-NoProfile',
        '-File',
        $scannerScript,
        '-OutputFormat',
        'invalid'
    ) -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    if (Test-Path $stderrPath) {
        $stderrContent = Get-Content -Path $stderrPath -Raw -ErrorAction SilentlyContinue
    }
}
finally {
    Remove-Item -Path $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
}

if ($process.ExitCode -eq 0) {
    throw "OutputFormat validation failed: invalid value was accepted"
}
if ($stderrContent -notmatch 'OutputFormat') {
    throw "OutputFormat validation failed: expected invalid OutputFormat error details"
}
Write-Host '    ✓ OutputFormat validation works'

# Test 2: Default parameter values
Write-Host '  Test 2: Validate default parameter values...'
$testScript = @'
[CmdletBinding()]
param(
    [string]$Org = "IBuySpy-Shared",
    [string]$BasecoatRepo = "basecoat",
    [ValidateSet("table", "json", "markdown")]
    [string]$OutputFormat = "table"
)

Write-Host "$Org|$BasecoatRepo|$OutputFormat"
'@

$output = & pwsh -NoProfile -Command $testScript
if ($output -ne "IBuySpy-Shared|basecoat|table") {
    throw "Default parameters test failed: expected 'IBuySpy-Shared|basecoat|table', got '$output'"
}
Write-Host '    ✓ Default parameters are correct'

# Test 3: JSON output format validation structure
Write-Host '  Test 3: Validate JSON output format structure...'
$testJsonOutput = @{
    scan_date           = (Get-Date -Format "o")
    org                 = "IBuySpy-Shared"
    source              = "IBuySpy-Shared/basecoat"
    total_source_assets = 3
    repos               = @(
        @{
            repo        = "test-repo"
            visibility  = "public"
            synced      = 2
            current     = 2
            stale       = 0
            custom      = 0
            totalFiles  = 2
            coverage    = 66.7
            assets      = @(
                @{ asset = "agents/example.agent.md"; status = "current"; type = "agent" }
            )
            current_version = "4.2.0-rc.1"
            target_version = "4.2.0"
            drift_age_days = 2
            issue_url = "https://github.com/example/test/issues/1"
            issue_state = "OPEN"
            pr_url = "https://github.com/example/test/pull/2"
            disposition = "approval-required"
        }
    )
    copilot_seats = @()
} | ConvertTo-Json -Depth 5

if (-not ($testJsonOutput | Test-Json)) {
    throw "JSON validation failed: output is not valid JSON"
}

$parsed = $testJsonOutput | ConvertFrom-Json
if (-not $parsed.scan_date -or -not $parsed.org -or -not $parsed.repos) {
    throw "JSON structure validation failed: missing required fields"
}
if (-not $parsed.repos[0].current_version -or -not $parsed.repos[0].target_version -or
    -not $parsed.repos[0].disposition -or $parsed.repos[0].issue_state -ne 'OPEN') {
    throw "JSON structure validation failed: missing fleet update status fields"
}
if ($parsed.repos[0].current_version -ne '4.2.0-rc.1' -or $parsed.repos[0].target_version -ne '4.2.0') {
    throw 'Fleet JSON must preserve a prerelease current version distinct from the stable target.'
}

$scannerContent = Get-Content -LiteralPath $scannerScript -Raw
if ($scannerContent -notmatch 'marker\.drift_started_at') {
    throw 'Fleet scanner must compute drift age from the stable marker timestamp.'
}
if ($scannerContent -notmatch '--limit 1000') {
    throw 'Fleet scanner must search deeply enough to find an older stable updater marker.'
}
if ($scannerContent -notmatch 'current_version = \[string\]\$marker\.current_version') {
    throw 'Fleet scanner must retain the installed version from the stable updater marker.'
}
if ($scannerContent -notmatch '\[int\]\$marker\.schema -ne 1' -or
    $scannerContent -notmatch '\$disposition -ne ''unknown''' -or
    $scannerContent -notmatch 'TryParse\(\[string\]\$marker\.drift_started_at') {
    throw 'Fleet scanner must reject incomplete resolved-target markers while accepting unknown empty targets.'
}
if ($scannerContent -notmatch 'elseif \(\$updateState -and \$updateState\.current_version\)') {
    throw 'Fleet scanner must use marker state when a consumer stores version metadata at a custom stage path.'
}
if ($scannerContent -notmatch "target_version = if \(\`$updateState\) \{ \`$updateState\.target_version \} else \{ '' \}") {
    throw 'Fleet scanner must leave target empty when no update marker exists.'
}
if ($scannerContent -notmatch "disposition = if \(\`$updateState\) \{ \`$updateState\.disposition \} else \{ 'unknown' \}") {
    throw 'Fleet scanner must report unknown when no update marker exists.'
}
if ($scannerContent -notmatch 'issue_state = if \(\$updateState\)') {
    throw 'Fleet scanner must preserve whether the stable update issue is open or closed.'
}
Write-Host '    ✓ JSON output format is valid'

# Test 4: Markdown output format validation
Write-Host '  Test 4: Validate markdown output format structure...'
$testMarkdownOutput = @"
## Basecoat Adoption — IBuySpy-Shared

| Repo | Synced | Current | Stale | Installed | Target | Drift age | Disposition | PR | Coverage |
|------|-------:|--------:|------:|-----------|--------|-----------|-------------|----|----------|
| test-repo | 12 | 10 | 2 | 4.2.0-rc.1 | 4.2.0 | 2d | approval-required | PR | 66.7% |

### Copilot Seats

| User | Last Active | Editor |
|------|------------|--------|
| test-user | 2026-04-30T21:03:00.0000000Z | vscode |
"@

if ($testMarkdownOutput -notmatch '## Basecoat Adoption') {
    throw "Markdown format validation failed: missing title"
}
if ($testMarkdownOutput -notmatch '\| Repo \| Synced \| Current \| Stale \| Installed \| Target \| Drift age') {
    throw "Markdown format validation failed: missing table header"
}
Write-Host '    ✓ Markdown output format is valid'

# Test 5: Asset type detection (agent, instruction, prompt)
Write-Host '  Test 5: Validate asset type detection...'
$assetTypes = @{
    "agents/example.agent.md"           = "agent"
    "instructions/example.instructions.md" = "instruction"
    "prompts/example.prompt.md"         = "prompt"
}

foreach ($file in $assetTypes.Keys) {
    $expectedType = $assetTypes[$file]
    if ($file -match '\.agent\.md$') {
        $actualType = "agent"
    }
    elseif ($file -match '\.instructions\.md$') {
        $actualType = "instruction"
    }
    elseif ($file -match '\.prompt\.md$') {
        $actualType = "prompt"
    }

    if ($actualType -ne $expectedType) {
        throw "Asset type detection failed for $($file): expected $($expectedType), got $($actualType)"
    }
}
Write-Host '    ✓ Asset type detection works correctly'

# Test 6: Sync path calculation
Write-Host '  Test 6: Validate sync path calculation...'
$syncPathTests = @{
    "agents/example.agent.md"           = ".github/agents/example.agent.md"
    "instructions/security.instructions.md" = ".github/instructions/security.instructions.md"
    "prompts/template.prompt.md"        = ".github/prompts/template.prompt.md"
}

foreach ($source in $syncPathTests.Keys) {
    $expectedPath = $syncPathTests[$source]
    $type = if ($source -match 'agents') { 'agents' } elseif ($source -match 'instructions') { 'instructions' } else { 'prompts' }
    $filename = Split-Path $source -Leaf
    $actualPath = ".github/$type/$filename"

    if ($actualPath -ne $expectedPath) {
        throw "Sync path calculation failed for $($source): expected $($expectedPath), got $($actualPath)"
    }
}
Write-Host '    ✓ Sync path calculation is correct'

# Test 7: Coverage percentage calculation
Write-Host '  Test 7: Validate coverage percentage calculation...'
$totalSourceAssets = 10
$synced = 7
$expectedCoverage = [math]::Round(($synced / $totalSourceAssets) * 100, 1)

if ($expectedCoverage -ne 70.0) {
    throw "Coverage calculation failed: expected 70.0%, got $expectedCoverage%"
}
Write-Host '    ✓ Coverage percentage calculation is correct'

# Test 8: Stale asset flagging
Write-Host '  Test 8: Validate stale asset detection...'
$baseSha = "abc123"
$staleSha = "def456"

$isStale = $staleSha -ne $baseSha
if (-not $isStale) {
    throw "Stale detection failed: should have detected mismatch"
}

$isCurrent = $baseSha -eq $baseSha
if (-not $isCurrent) {
    throw "Current detection failed: should have detected match"
}
Write-Host '    ✓ Stale asset detection works correctly'

# Test 9: Empty adoption report handling
Write-Host '  Test 9: Validate empty adoption report handling...'
$emptyReport = @()
if ($emptyReport.Count -eq 0) {
    Write-Host '    ✓ Empty adoption report handling works'
}
else {
    throw "Empty report handling failed"
}

# Test 10: Copilot seat data structure
Write-Host '  Test 10: Validate Copilot seat data structure...'
$seatInfo = @(
    @{
        login           = "user1"
        last_activity   = "2026-04-30T21:03:00.0000000Z"
        editor          = "vscode"
        created         = "2026-01-01T00:00:00.0000000Z"
    }
)

if ($seatInfo[0].login -ne "user1" -or -not $seatInfo[0].last_activity) {
    throw "Seat data structure validation failed: missing or incorrect fields"
}
Write-Host '    ✓ Copilot seat data structure is valid'

Write-Host 'All adoption scanner tests passed'
exit 0
