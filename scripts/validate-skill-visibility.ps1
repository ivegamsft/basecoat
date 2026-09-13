#!/usr/bin/env pwsh
# Validates that skill `visibility` frontmatter, when present, is one of the
# allowed skill values (public|private). Agents intentionally use a different
# routing-tier taxonomy (basic|specialized|advanced|internal), so this check is
# scoped to SKILL.md only. Extracted as a standalone validator so both
# validate-basecoat.ps1 and the test suite exercise identical production logic.
[CmdletBinding()]
param(
    [string]$RootDir = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $RootDir).Path
$skillsDir = Join-Path $root 'skills'

function Get-Frontmatter {
    param([string]$Path)
    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -match '(?s)^---\r?\n(.*?)\r?\n---') { return $matches[1] }
    return ''
}

$errors = 0
if (Test-Path $skillsDir) {
    Get-ChildItem -Path $skillsDir -Recurse -Filter 'SKILL.md' -File | ForEach-Object {
        $fm = Get-Frontmatter $_.FullName
        if (-not $fm) { return }
        $visLine = ($fm -split "`n") | Select-String -Pattern '^visibility:\s*' | Select-Object -First 1
        if ($visLine) {
            $vis = ($visLine -replace '^visibility:\s*', '').Trim().Trim('"').Trim("'")
            if ($vis -notin @('public', 'private')) {
                Write-Host "ERROR: $($_.FullName) has invalid skill visibility '$vis' (expected 'public' or 'private')" -ForegroundColor Red
                $errors++
            }
        }
    }
}

if ($errors -gt 0) {
    throw "Skill visibility validation failed with $errors error(s)"
}

Write-Host 'Skill visibility validation passed.'
