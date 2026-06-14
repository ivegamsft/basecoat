#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Audits all BaseCoat skills for compliance with quality standards.

.DESCRIPTION
    Checks each skill directory for token budget, description length,
    required frontmatter fields, eval.yaml presence, and trigger patterns.

.PARAMETER SkillsDir
    Path to the skills directory. Defaults to 'skills'.

.PARAMETER OutputFile
    Path to write the audit report. Defaults to 'test-results/skill-audit.txt'.

.PARAMETER FailOnError
    Exit with code 1 if any ERROR-level findings are found.

.PARAMETER Quiet
    Only print the summary line, not per-skill details.
#>
param(
    [string]$SkillsDir = 'skills',
    [string]$OutputFile = 'test-results/skill-audit.txt',
    [switch]$FailOnError,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve paths relative to repo root (script lives in scripts/)
$repoRoot = Split-Path $PSScriptRoot -Parent
$SkillsDir = Join-Path $repoRoot $SkillsDir
$OutputFile = Join-Path $repoRoot $OutputFile

$outputDir = Split-Path $OutputFile -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$date = Get-Date -Format 'yyyy-MM-dd'
$lines = [System.Collections.Generic.List[string]]::new()

function Add-Line {
    param([string]$Text)
    $lines.Add($Text)
    if (-not $Quiet -or $Text -match '^(=|Summary)') {
        Write-Host $Text
    }
}

Add-Line "BaseCoat Skill Audit — $date"
Add-Line "=================================="

$skillDirs = Get-ChildItem -Path $SkillsDir -Directory | Sort-Object Name
$totalErrors = 0
$totalWarnings = 0

foreach ($skillDir in $skillDirs) {
    $skillName = $skillDir.Name
    $skillFile = Join-Path $skillDir.FullName 'SKILL.md'
    $evalFile = Join-Path $skillDir.FullName 'eval.yaml'

    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    if (-not (Test-Path $skillFile)) {
        $errors.Add("missing SKILL.md")
    } else {
        $content = Get-Content $skillFile -Raw

        # Parse YAML frontmatter (between first --- delimiters)
        $frontmatter = ''
        if ($content -match '(?s)^---\s*\n(.*?)\n---') {
            $frontmatter = $Matches[1]
        }

        # Check 1: Token budget — word count * 1.35 > 500 → ERROR
        $wordCount = ($content -split '\s+' | Where-Object { $_ -ne '' }).Count
        $approxTokens = [math]::Round($wordCount * 1.35)
        if ($approxTokens -gt 500) {
            $errors.Add("exceeds 500-token budget (approx $approxTokens tokens)")
        }

        # Check 2: Description length — extract description value
        $descriptionValue = ''
        if ($frontmatter -match '(?m)^description:\s*"([^"]*)"') {
            $descriptionValue = $Matches[1]
        } elseif ($frontmatter -match '(?m)^description:\s*(.+)$') {
            $descriptionValue = $Matches[1].Trim()
        }
        $descLen = $descriptionValue.Length
        if ($descLen -lt 150) {
            $errors.Add("description too short ($descLen chars, min 150)")
        }

        # Check 3: Required frontmatter fields
        foreach ($field in @('name', 'description', 'compatibility')) {
            if ($frontmatter -notmatch "(?m)^$field\s*:") {
                $errors.Add("missing field: $field")
            }
        }

        # Check 5: metadata.category presence
        $metadataBlock = ''
        $hasMetadataBlock = $frontmatter -match '(?ms)^metadata\s*:\s*\r?\n((?:[ \t]{2,}.*(?:\r?\n|$))*)'
        if ($hasMetadataBlock) {
            $metadataBlock = $Matches[1]
        }
        if ($hasMetadataBlock -and $metadataBlock -notmatch '(?m)^[ \t]{2,}category\s*:') {
            $warnings.Add("missing metadata.category")
        }

        # Check 6: USE FOR / DO NOT USE FOR triggers
        if ($descriptionValue -notmatch 'USE FOR' -or $descriptionValue -notmatch 'DO NOT USE FOR') {
            $warnings.Add("missing USE FOR or DO NOT USE FOR triggers")
        }
    }

    # Check 4: eval.yaml presence
    if (-not (Test-Path $evalFile)) {
        $warnings.Add("no eval.yaml found")
    }

    $errCount = $errors.Count
    $warnCount = $warnings.Count
    $totalErrors += $errCount
    $totalWarnings += $warnCount

    if ($errCount -gt 0) {
        $detail = ($errors | ForEach-Object { $_ }) -join '; '
        Add-Line "[FAIL] $skillName — $errCount error$(if ($errCount -ne 1) {'s'}): $detail"
    } elseif ($warnCount -gt 0) {
        $detail = ($warnings | ForEach-Object { $_ }) -join '; '
        Add-Line "[WARN] $skillName — 0 errors, $warnCount warning$(if ($warnCount -ne 1) {'s'}): $detail"
    } else {
        Add-Line "[PASS] $skillName — 0 errors, 0 warnings"
    }
}

$skillCount = $skillDirs.Count
Add-Line "=================================="

$summary = "Summary: $skillCount skills audited. Errors: $totalErrors. Warnings: $totalWarnings."
if ($Quiet) {
    Write-Host $summary
}
$lines.Add($summary)

$lines | Set-Content -Path $OutputFile -Encoding UTF8

if ($FailOnError -and $totalErrors -gt 0) {
    Write-Host "Audit failed: $totalErrors error(s) found." -ForegroundColor Red
    exit 1
}
