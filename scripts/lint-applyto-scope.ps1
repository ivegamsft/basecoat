#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates that at most one instruction file uses applyTo: "**/*".

.DESCRIPTION
    Scans all *.instructions.md files under .github/instructions/ and fails if
    more than one uses the broad applyTo: "**/*" pattern. Only the top-level
    routing guide (.github/copilot-instructions.md) should have all-files scope.

.PARAMETER RootDir
    Repository root. Defaults to the current directory.

.EXAMPLE
    ./scripts/lint-applyto-scope.ps1
#>
param(
    [string]$RootDir = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$instructionsDir = Join-Path $RootDir '.github' 'instructions'
if (-not (Test-Path $instructionsDir)) {
    Write-Host "No .github/instructions/ directory found — skipping applyTo scope check." -ForegroundColor Yellow
    exit 0
}

$broadPattern = 'applyTo:\s*["'']?\*\*/\*["'']?'

$broadFiles = @(
    Get-ChildItem $instructionsDir -Filter '*.instructions.md' -File |
    Where-Object { (Get-Content $_.FullName -Raw) -match $broadPattern } |
    ForEach-Object { $_.Name }
)

if ($broadFiles.Count -gt 1) {
    Write-Host "ERROR: More than one instruction file uses applyTo: `"**/*`"." -ForegroundColor Red
    Write-Host "Only the routing guide (.github/copilot-instructions.md) may use all-files scope." -ForegroundColor Red
    Write-Host "Offending files:" -ForegroundColor Red
    $broadFiles | ForEach-Object { Write-Host "  .github/instructions/$_" -ForegroundColor Red }
    Write-Host ""
    Write-Host "Narrow the applyTo pattern in each file to match only the paths relevant to its content." -ForegroundColor Yellow
    exit 1
}

if ($broadFiles.Count -eq 1) {
    Write-Host "OK: Exactly one instruction file uses applyTo: `"**/*`": $($broadFiles[0])" -ForegroundColor Green
} else {
    Write-Host "OK: No instruction files use broad applyTo: `"**/*`"." -ForegroundColor Green
}

exit 0
