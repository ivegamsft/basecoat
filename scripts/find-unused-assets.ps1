#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Identifies BaseCoat assets that have no known consumer references.

.DESCRIPTION
    Cross-references agents, skills, instructions, and prompts against all files
    in the repository to find assets that are never referenced by name.
    Assets with no references for more than 90 days are flagged for review.

    This is a heuristic scan — it cannot detect runtime telemetry usage. Assets
    that are loaded by agent runners at runtime (e.g. via glob) may be flagged
    even though they are actively used.

.PARAMETER ThresholdDays
    Assets with no references AND older than this many days are flagged as
    candidates for removal. Default: 90.

.PARAMETER Format
    Output format: table (default), json, or markdown.

.PARAMETER Category
    Limit scan to one category: all (default), agents, skills, instructions, prompts.

.PARAMETER ShowAll
    Show all assets including those with references (for debugging).

.EXAMPLE
    pwsh scripts/find-unused-assets.ps1
    pwsh scripts/find-unused-assets.ps1 -ThresholdDays 60 -Format json
    pwsh scripts/find-unused-assets.ps1 -Category skills
    pwsh scripts/find-unused-assets.ps1 -ShowAll
#>
[CmdletBinding()]
param(
    [int]$ThresholdDays = 90,

    [ValidateSet('table', 'json', 'markdown')]
    [string]$Format = 'table',

    [ValidateSet('all', 'agents', 'skills', 'instructions', 'prompts')]
    [string]$Category = 'all',

    [switch]$ShowAll
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path $PSScriptRoot -Parent
$Now = Get-Date

# ── Collect assets ────────────────────────────────────────────────────────────

$assets = [System.Collections.Generic.List[hashtable]]::new()

function Get-GitAge {
    param([string]$FilePath)
    $rel = Resolve-Path -Relative -Path $FilePath -ErrorAction SilentlyContinue
    if (-not $rel) { return 0 }
    $dateStr = git -C $RepoRoot log -1 --format="%cI" -- $FilePath 2>$null
    if (-not $dateStr) { return 0 }
    try { ([datetime]$dateStr.Trim() | ForEach-Object { ($Now - $_).Days }) } catch { 0 }
}

if ($Category -in @('all', 'agents')) {
    foreach ($f in Get-ChildItem "$RepoRoot\agents" -Filter '*.agent.md') {
        $name = $f.BaseName -replace '\.agent$', ''
        $assets.Add(@{
            type     = 'agent'
            name     = $name
            file     = "agents/$($f.Name)"
            fullPath = $f.FullName
            age      = Get-GitAge $f.FullName
        })
    }
}

if ($Category -in @('all', 'skills')) {
    foreach ($d in Get-ChildItem "$RepoRoot\skills" -Directory) {
        $skillMd = Join-Path $d.FullName 'SKILL.md'
        if (-not (Test-Path $skillMd)) { continue }
        $assets.Add(@{
            type     = 'skill'
            name     = $d.Name
            file     = "skills/$($d.Name)/SKILL.md"
            fullPath = $skillMd
            age      = Get-GitAge $skillMd
        })
    }
}

if ($Category -in @('all', 'instructions')) {
    foreach ($f in Get-ChildItem "$RepoRoot\instructions" -Filter '*.instructions.md') {
        $name = $f.BaseName -replace '\.instructions$', ''
        $assets.Add(@{
            type     = 'instruction'
            name     = $name
            file     = "instructions/$($f.Name)"
            fullPath = $f.FullName
            age      = Get-GitAge $f.FullName
        })
    }
}

if ($Category -in @('all', 'prompts')) {
    foreach ($f in Get-ChildItem "$RepoRoot\prompts" -Filter '*.prompt.md') {
        $name = $f.BaseName -replace '\.prompt$', ''
        $assets.Add(@{
            type     = 'prompt'
            name     = $name
            file     = "prompts/$($f.Name)"
            fullPath = $f.FullName
            age      = Get-GitAge $f.FullName
        })
    }
}

# ── Build reference index ─────────────────────────────────────────────────────
# Search all text files in the repo for each asset name

# Gather all searchable files (exclude binary and generated)
$searchFiles = Get-ChildItem $RepoRoot -Recurse -File |
    Where-Object {
        $_.Extension -in @('.md', '.yml', '.yaml', '.json', '.ps1', '.sh', '.ts', '.js') -and
        $_.FullName -notmatch '[\\\/]\.git[\\\/]' -and
        $_.FullName -notmatch 'node_modules'
    }

$allText = $searchFiles | ForEach-Object { Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue } | Join-String -Separator "`n"

# ── Scan references ───────────────────────────────────────────────────────────

$results = [System.Collections.Generic.List[hashtable]]::new()

foreach ($asset in $assets) {
    $name = $asset.name
    # Count occurrences outside the asset's own file
    $ownFile = $asset.fullPath
    $refs = 0
    foreach ($f in $searchFiles) {
        if ($f.FullName -eq $ownFile) { continue }
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -and $content -match [regex]::Escape($name)) {
            $refs++
        }
    }
    $asset['refs']    = $refs
    $asset['unused']  = ($refs -eq 0)
    $asset['stale']   = ($refs -eq 0) -and ($asset.age -gt $ThresholdDays)
    $results.Add($asset)
}

# ── Filter output ─────────────────────────────────────────────────────────────

$display = if ($ShowAll) { $results } else { $results | Where-Object { $_.unused } }
$staleCount  = ($results | Where-Object { $_.stale }).Count
$unusedCount = ($results | Where-Object { $_.unused }).Count
$total       = $results.Count

# ── Render ────────────────────────────────────────────────────────────────────

switch ($Format) {
    'json' {
        $display | ForEach-Object {
            [ordered]@{
                type    = $_.type
                name    = $_.name
                file    = $_.file
                refs    = $_.refs
                ageDays = $_.age
                unused  = $_.unused
                stale   = $_.stale
            }
        } | ConvertTo-Json -Depth 3
    }

    'markdown' {
        Write-Output "## Unused Asset Report"
        Write-Output ""
        Write-Output "| Type | Name | File | Refs | Age (days) | Stale? |"
        Write-Output "|---|---|---|---|---|---|"
        foreach ($r in ($display | Sort-Object @{e='stale';d=$true}, 'type', 'name')) {
            $staleFlag = if ($r.stale) { '⚠️ yes' } else { 'no' }
            Write-Output "| $($r.type) | $($r.name) | $($r.file) | $($r.refs) | $($r.age) | $staleFlag |"
        }
        Write-Output ""
        Write-Output "**Summary**: $unusedCount / $total assets have no references. $staleCount exceed the ${ThresholdDays}-day stale threshold."
    }

    default {
        # table
        if ($display.Count -eq 0) {
            Write-Host "✓ No unused assets found." -ForegroundColor Green
        } else {
            $display |
                Sort-Object @{e='stale';d=$true}, 'type', 'name' |
                ForEach-Object {
                    $staleFlag = if ($_.stale) { '[STALE]' } else { '' }
                    [PSCustomObject]@{
                        Type    = $_.type
                        Name    = $_.name
                        Refs    = $_.refs
                        Age     = $_.age
                        Stale   = $staleFlag
                        File    = $_.file
                    }
                } |
                Format-Table -AutoSize
        }
        $color = if ($staleCount -gt 0) { 'Yellow' } else { 'Cyan' }
        Write-Host "Summary: $unusedCount / $total assets unreferenced; $staleCount stale (>${ThresholdDays}d)" -ForegroundColor $color
    }
}
