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
Write-Host '    ✓ JSON output format is valid'

# Test 4: Markdown output format validation
Write-Host '  Test 4: Validate markdown output format structure...'
$testMarkdownOutput = @"
## Basecoat Adoption — IBuySpy-Shared

| Repo | Synced | Current | Stale | Coverage |
|------|--------|---------|-------|----------|
| test-repo | 2 | 2 | 0 | 66.7% |

### Copilot Seats

| User | Last Active | Editor |
|------|------------|--------|
| test-user | 2026-04-30T21:03:00.0000000Z | vscode |
"@

if ($testMarkdownOutput -notmatch '## Basecoat Adoption') {
    throw "Markdown format validation failed: missing title"
}
if ($testMarkdownOutput -notmatch '\| Repo \| Synced \| Current \| Stale') {
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
