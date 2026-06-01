#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Updates basecoat-metadata.json with any agents missing from the registry.

.DESCRIPTION
    Scans agents/*.agent.md for YAML frontmatter, then adds any agents not already
    present in basecoat-metadata.json. Existing entries (with their curated keywords,
    aliases, and argumentHints) are preserved unchanged.

    Newly discovered agents get minimal metadata extracted from frontmatter
    (name, description, category, keywords from tags, model). After running, review
    new entries and enrich aliases/argumentHint as needed.

.PARAMETER MetadataPath
    Path to basecoat-metadata.json. Defaults to repo root.

.PARAMETER BumpVersion
    If set, increments the minor version number in the output.

.EXAMPLE
    pwsh scripts/update-metadata.ps1
    pwsh scripts/update-metadata.ps1 -BumpVersion

.NOTES
    Run this after adding new agents to keep the router skill current.
    Commit the updated basecoat-metadata.json along with the new agent file.
#>
param(
    [string]$MetadataPath = (Join-Path $PSScriptRoot ".." "basecoat-metadata.json"),
    [switch]$BumpVersion
)

$ErrorActionPreference = "Stop"

$repoRoot   = Split-Path -Parent $PSScriptRoot
$agentsDir  = Join-Path $repoRoot "agents"

# ── Category mapping: frontmatter metadata.category → metadata.json category key ──
$categoryMap = @{
    "Development"          = "Development"
    "Architecture"         = "Architecture"
    "Quality"              = "Quality"
    "DevOps"               = "DevOps"
    "Process"              = "Process"
    "Meta"                 = "Meta"
    "Security"             = "Quality"
    "Security & Compliance"= "Quality"
    "Operations"           = "DevOps"
    "Data"                 = "Development"
    "ML/AI"                = "Development"
    "Finance"              = "Process"
}

$originalMetadataJson = Get-Content $MetadataPath -Raw
$meta = $originalMetadataJson | ConvertFrom-Json

# Migrate legacy short agent names to full file-based names to match current validation.
$agentFiles = Get-ChildItem $agentsDir -Filter "*.agent.md" | Sort-Object Name
$knownAgentNames = @{}
foreach ($file in $agentFiles) {
    $fullName = $file.BaseName -replace '\.agent$', ''
    $knownAgentNames[$fullName] = $true
}

$legacyToFull = @{}
foreach ($entry in @($meta.agents)) {
    if (-not $entry.file) { continue }
    if ($entry.name -and $knownAgentNames.ContainsKey($entry.name)) { continue }

    $entryFileName = Split-Path -Leaf ([string]$entry.file)
    $fullNameFromFile = $entryFileName -replace '\.agent\.md$', ''
    if ($fullNameFromFile -and $knownAgentNames.ContainsKey($fullNameFromFile)) {
        if ($entry.name -and $entry.name -ne $fullNameFromFile) {
            $legacyToFull[[string]$entry.name] = $fullNameFromFile
        }
        $entry.name = $fullNameFromFile
    }
}

foreach ($category in $meta.categories.PSObject.Properties) {
    $agentList = @($category.Value.agents)
    if (-not $agentList) { continue }
    $category.Value.agents = @(
        foreach ($name in $agentList) {
            if ($legacyToFull.ContainsKey([string]$name)) { $legacyToFull[[string]$name] } else { $name }
        }
    )
}

$dedupedAgents = [System.Collections.Generic.List[object]]::new()
$seenByFile = @{}
foreach ($entry in @($meta.agents)) {
    $entryFile = [string]$entry.file
    if (-not $entryFile) {
        $dedupedAgents.Add($entry)
        continue
    }

    $fullNameFromFile = (Split-Path -Leaf $entryFile) -replace '\.agent\.md$', ''
    if (-not $seenByFile.ContainsKey($entryFile)) {
        $seenByFile[$entryFile] = $entry
        $dedupedAgents.Add($entry)
        continue
    }

    $current = $seenByFile[$entryFile]
    $preferCurrent = [string]$current.name -eq $fullNameFromFile
    $preferIncoming = [string]$entry.name -eq $fullNameFromFile
    if ($preferIncoming -and -not $preferCurrent) {
        $index = [Array]::IndexOf($dedupedAgents.ToArray(), $current)
        if ($index -ge 0) {
            $dedupedAgents[$index] = $entry
        }
        $seenByFile[$entryFile] = $entry
    }
}
$meta.agents = $dedupedAgents.ToArray()

$existingNames = $meta.agents | Select-Object -ExpandProperty name

$newAgents = [System.Collections.Generic.List[object]]::new()

Get-ChildItem $agentsDir -Filter "*.agent.md" | Sort-Object Name | ForEach-Object {
    $baseName = $_.BaseName -replace '\.agent$', ''
    $agentName = $baseName
    if ($agentName -in $existingNames) { return }

    $content      = Get-Content $_.FullName -Raw
    $agentDesc    = ""
    $agentCatRaw  = ""
    $agentModel   = "claude-sonnet-4.6"
    $agentTags    = @()

    if ($content -match '(?m)^description:\s*[''"]?(.*?)[''"]?\s*$') {
        $agentDesc = $Matches[1].Trim('"').Trim("'")
    }
    if ($content -match '(?ms)^metadata:.*?^\s+category:\s*[''"]?(.*?)[''"]?\s*$') {
        $agentCatRaw = $Matches[1].Trim('"').Trim("'")
    }
    if ($content -match '(?m)^\s+tags:\s*\[(.*?)\]') {
        $agentTags = $Matches[1] -split ',' |
            ForEach-Object { $_.Trim().Trim('"').Trim("'") } |
            Where-Object { $_ }
    }
    if ($content -match '(?m)^model:\s*(\S+)') {
        $agentModel = $Matches[1]
    }

    $category = if ($categoryMap[$agentCatRaw]) { $categoryMap[$agentCatRaw] } else { "Meta" }

    $newAgents.Add([PSCustomObject]@{
        name        = $agentName
        description = if ($agentDesc) { $agentDesc } else { "$agentName agent" }
        category    = $category
        keywords    = @($agentTags)
        aliases     = @()
        pairedSkill = ""
        file        = "agents/$($_.Name)"
        model       = $agentModel
        argumentHint= ""
    })
}

if ($newAgents.Count -eq 0) {
    $normalizedJson = $meta | ConvertTo-Json -Depth 10
    if ($normalizedJson -ne $originalMetadataJson) {
        $normalizedJson | Set-Content $MetadataPath -Encoding UTF8
        Write-Host "✅  Normalized basecoat-metadata.json ($($existingNames.Count) agents)."
    }
    else {
        Write-Host "✅  basecoat-metadata.json is up to date ($($existingNames.Count) agents)."
    }
    return
}

# ── Merge new agents ──────────────────────────────────────────────────────────
$meta.agents   = @($meta.agents) + $newAgents.ToArray()
$meta.generated = (Get-Date -Format "yyyy-MM-dd")

if ($BumpVersion) {
    $parts           = $meta.version -split '\.'
    $parts[1]        = [int]$parts[1] + 1
    $parts[2]        = "0"
    $meta.version    = $parts -join '.'
}

$meta | ConvertTo-Json -Depth 10 | Set-Content $MetadataPath -Encoding UTF8

$total = ($meta.agents | Measure-Object).Count
Write-Host "✅  Added $($newAgents.Count) agent(s). Total: $total. Version: $($meta.version)."
Write-Host "   Review new entries in basecoat-metadata.json and enrich aliases/argumentHint as needed."
