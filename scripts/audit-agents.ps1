#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Audits BaseCoat agents for syntax and best-practice compliance.

.DESCRIPTION
    Validates each file in agents/*.agent.md for frontmatter structure, required
    metadata, routing trigger coverage, and key content sections. Writes a
    machine-readable text report for follow-up and optional CI enforcement.

.PARAMETER AgentsDir
    Path to the agents directory. Defaults to 'agents'.

.PARAMETER OutputFile
    Report output path. Defaults to 'test-results/agent-audit.txt'.

.PARAMETER FailOnError
    Exit with code 1 if any ERROR-level findings are present.

.PARAMETER Quiet
    Print only the summary line.
#>
param(
    [string]$AgentsDir = 'agents',
    [string]$OutputFile = 'test-results/agent-audit.txt',
    [switch]$FailOnError,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
$AgentsDir = Join-Path $repoRoot $AgentsDir
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

Add-Line "BaseCoat Agent Audit — $date"
Add-Line "=================================="

$agentFiles = Get-ChildItem -Path $AgentsDir -Filter '*.agent.md' -File | Sort-Object Name
$totalErrors = 0
$totalWarnings = 0

foreach ($agentFile in $agentFiles) {
    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $content = Get-Content $agentFile.FullName -Raw

    $frontmatter = ''
    $body = $content
    if ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---\s*\r?\n?(.*)$') {
        $frontmatter = $Matches[1]
        $body = $Matches[2]
    } else {
        $errors.Add('missing or malformed YAML frontmatter')
    }

    $fileSlug = $agentFile.BaseName -replace '\.agent$', ''
    # Extract short agent name from new naming convention: basecoat-XX-category-agent-name -> agent-name
    $shortFileSlug = $fileSlug -replace '^basecoat-\d+-\w+-', ''
    $nameValue = ''
    if ($frontmatter -match '(?m)^name:\s*"([^"]+)"') {
        $nameValue = $Matches[1].Trim()
    } elseif ($frontmatter -match '(?m)^name:\s*(.+)$') {
        $nameValue = $Matches[1].Trim().Trim("'").Trim('"')
    }

    $descriptionValue = ''
    if ($frontmatter -match '(?m)^description:\s*"([^"]*)"') {
        $descriptionValue = $Matches[1].Trim()
    } elseif ($frontmatter -match '(?m)^description:\s*(.+)$') {
        $descriptionValue = $Matches[1].Trim().Trim("'").Trim('"')
    }

    if (-not $nameValue) {
        $errors.Add('missing field: name')
    } elseif ($nameValue -ne $shortFileSlug) {
        $warnings.Add("name '$nameValue' does not match filename slug '$shortFileSlug'")
    }

    if (-not $descriptionValue) {
        $errors.Add('missing field: description')
    } else {
        if ($descriptionValue.Length -lt 150) {
            $warnings.Add("description short ($($descriptionValue.Length) chars, target >= 150)")
        }
        if ($descriptionValue -notmatch 'USE FOR') {
            $warnings.Add('description missing USE FOR trigger section')
        }
        if ($descriptionValue -notmatch 'DO NOT USE FOR') {
            $warnings.Add('description missing DO NOT USE FOR trigger section')
        }
    }

    if ($frontmatter -notmatch '(?m)^model:\s*') {
        $warnings.Add('missing model field')
    }
    if ($frontmatter -notmatch '(?m)^color:\s*') {
        $warnings.Add('missing color field')
    }
    if ($frontmatter -notmatch '(?m)^tools:\s*') {
        $warnings.Add('missing tools field')
    }
    if ($frontmatter -notmatch '(?m)^allowed_skills:\s*') {
        $warnings.Add('missing allowed_skills field')
    }
    if ($frontmatter -notmatch '(?m)^handoffs:\s*') {
        $warnings.Add('missing handoffs field')
    }
    if ($frontmatter -match '(?m)^category:\s*(.+)$') {
        $categoryValue = $Matches[1].Trim().Trim("'").Trim('"')
        if ($categoryValue -eq 'Uncategorized') {
            $warnings.Add('category is Uncategorized')
        }
    }

    if ($body -notmatch '(?im)^##\s+inputs\b') {
        $warnings.Add('missing ## Inputs section')
    }
    if ($body -notmatch '(?im)^##\s+(workflow|process)\b') {
        $warnings.Add('missing ## Workflow/Process section')
    }
    if ($body -notmatch '(?im)^##\s+(output|outputs|results|deliverables)\b') {
        $warnings.Add('missing ## Output/Results/Deliverables section')
    }

    $boldHeadingLines = @(
        $body -split "`r?`n" | Where-Object { $_ -match '^\s*\*\*[^*]+\*\*\s*$' }
    )
    if ($boldHeadingLines.Count -gt 0) {
        $warnings.Add("contains $($boldHeadingLines.Count) bold-as-heading line(s) (MD036 risk)")
    }

    $errCount = $errors.Count
    $warnCount = $warnings.Count
    $totalErrors += $errCount
    $totalWarnings += $warnCount

    if ($errCount -gt 0) {
        $detail = ($errors | ForEach-Object { $_ }) -join '; '
        Add-Line "[FAIL] $shortFileSlug — $errCount error$(if ($errCount -ne 1) {'s'}): $detail"
    } elseif ($warnCount -gt 0) {
        $detail = ($warnings | ForEach-Object { $_ }) -join '; '
        Add-Line "[WARN] $shortFileSlug — 0 errors, $warnCount warning$(if ($warnCount -ne 1) {'s'}): $detail"
    } else {
        Add-Line "[PASS] $shortFileSlug — 0 errors, 0 warnings"
    }
}

$metadataPath = Join-Path (Get-Location) 'basecoat-metadata.json'
if (Test-Path $metadataPath) {
    $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
    $uncategorized = @($metadata.categories.PSObject.Properties | Where-Object { $_.Name -eq 'Uncategorized' -or $_.Value.label -eq 'Uncategorized' })
    foreach ($bucket in $uncategorized) {
        $agentList = @($bucket.Value.agents)
        if ($agentList.Count -gt 0) {
            Add-Line "[WARN] metadata — Uncategorized category still contains $($agentList.Count) agent(s): $($agentList -join ', ')"
            $totalWarnings++
        }
    }
}

$agentCount = $agentFiles.Count
Add-Line "=================================="

$summary = "Summary: $agentCount agents audited. Errors: $totalErrors. Warnings: $totalWarnings."
if ($Quiet) {
    Write-Host $summary
}
$lines.Add($summary)

$lines | Set-Content -Path $OutputFile -Encoding UTF8

if ($FailOnError -and $totalErrors -gt 0) {
    Write-Host "Audit failed: $totalErrors error(s) found." -ForegroundColor Red
    exit 1
}
