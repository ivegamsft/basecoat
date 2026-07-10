#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Regenerates docs/agents/agents.md from agents/*.agent.md frontmatter.

.DESCRIPTION
    Reads all agent files, extracts frontmatter name and description, then writes
    a markdown catalog with the current agent count and table rows.

.EXAMPLE
    pwsh scripts/generate-agents-doc.ps1
#>

param(
    [string]$OutputPath = (Join-Path $PSScriptRoot ".." "docs" "agents" "AGENTS.md"),
    [string]$RepositoryUrl
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$agentsDir = Join-Path $repoRoot "agents"
$maxDescriptionLength = 220

if (-not $RepositoryUrl) {
    $originUrl = (git -C $repoRoot config --get remote.origin.url) 2>$null
    if ($originUrl -match '^https://github\.com/([^/]+/[^/]+?)(?:\.git)?$') {
        $RepositoryUrl = "https://github.com/$($Matches[1])"
    }
    elseif ($originUrl -match '^git@github\.com:([^/]+/[^/]+?)(?:\.git)?$') {
        $RepositoryUrl = "https://github.com/$($Matches[1])"
    }
    else {
        $RepositoryUrl = 'https://github.com/IBuySpy-Shared/basecoat'
    }
}

if (-not (Test-Path $agentsDir)) {
    throw "Agents directory not found at: $agentsDir"
}

$agentRows = @()

Get-ChildItem -Path $agentsDir -Filter "*.agent.md" -File | Sort-Object Name | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -notmatch '(?ms)^---\s*\r?\n(.*?)\r?\n---') {
        return
    }

    $frontmatter = $Matches[1]
    $defaultName = $_.Name -replace '\.agent\.md$', ''
    $name = $defaultName
    $description = "No description provided."
    $lines = $frontmatter -split "\r?\n"

    if ($frontmatter -match '(?m)^name:\s*(.+)\s*$') {
        $name = $Matches[1].Trim().Trim('"')
    }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch '^\s*description:\s*(.*)$') {
            continue
        }

        $rawDescription = $Matches[1].Trim()
        # YAML block scalar indicators:
        # > / >- = folded block, | / |- = literal block
        if ($rawDescription -in @('>', '|', '>-', '|-')) {
            $blockLines = @()
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                $line = $lines[$j]
                if ($line -match '^[A-Za-z0-9_.-]+:\s*') {
                    break
                }

                if ($line -match '^\s{2,}(.*)$') {
                    $blockLines += $Matches[1]
                }
            }

            if ($blockLines.Count -gt 0) {
                if ($rawDescription.StartsWith('|')) {
                    $description = ($blockLines -join "`n").Trim()
                }
                else {
                    $description = ($blockLines -join ' ').Trim()
                }
            }
        }
        elseif ($rawDescription) {
            $description = $rawDescription.Trim('"')
        }

        break
    }

    $description = $description -replace '\|', '\|'
    $description = $description -replace '\s+', ' '
    if ($description.Length -gt $maxDescriptionLength) {
        $description = $description.Substring(0, $maxDescriptionLength - 3) + '...'
    }

    $agentRows += [ordered]@{
        Name        = $name
        FileName    = $_.Name
        Description = $description
    }
}

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('# Agents')
[void]$sb.AppendLine()
[void]$sb.AppendLine('This file lists all available agents in the BaseCoat framework.')
[void]$sb.AppendLine()
[void]$sb.AppendLine("> **$($agentRows.Count) agents** available")
[void]$sb.AppendLine()
[void]$sb.AppendLine('| Agent | Description |')
[void]$sb.AppendLine('|---|---|')

foreach ($row in $agentRows) {
    $url = "$RepositoryUrl/blob/main/agents/$($row.FileName)"
    [void]$sb.AppendLine("| [$($row.Name)]($url) | $($row.Description) |")
}

$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

Set-Content -Path $OutputPath -Value $sb.ToString().TrimEnd() -Encoding utf8

Write-Host "Agents doc written: $OutputPath"
Write-Host "Agents documented: $($agentRows.Count)"
