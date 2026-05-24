#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [string]$AgentsDir = "agents",
    [switch]$Force,
    [switch]$DryRun,
    [string]$AgentName = ""
)

$ErrorActionPreference = "Stop"

function Get-FrontmatterDescription {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Raw
    if ($content -notmatch '(?s)^---\s*\n(.*?)\n---') {
        return $null
    }

    $yaml = $Matches[1]
    if ($yaml -match '(?m)^description:\s*"(.*)"') {
        return $Matches[1]
    }
    if ($yaml -match "(?m)^description:\s*'(.*)'") {
        return $Matches[1]
    }
    if ($yaml -match '(?m)^description:\s*(.+)') {
        return $Matches[1].Trim()
    }

    return $null
}

function Normalize-TriggerText {
    param([string]$Text)

    $value = $Text.Trim()
    $value = $value.TrimEnd('.').Trim()
    $value = $value -replace '^(?:a task|the user|you)\s+needs?\s+(?:to\s+)?', ''
    $value = $value -replace '^(?:and|or)\s+', ''
    $value = $value.Trim(' -–—')
    return $value
}

function Split-TriggerList {
    param([string]$Raw)

    $items = $Raw -split '[,;]' | ForEach-Object {
        Normalize-TriggerText $_
    } | Where-Object { $_ -ne '' }

    return @($items)
}

function Parse-Description {
    param([string]$Description)

    $positive = @()
    $negative = @()

    if ($Description -match '(?i)Use when\s+(.+?)(?:\.\s*$)') {
        $positive = @(Normalize-TriggerText $Matches[1])
    }
    elseif ($Description -match '(?i)USE FOR:\s*(.+?)(?:\.\s*DO NOT USE FOR:|$)') {
        $positive = Split-TriggerList $Matches[1]
    }

    if ($Description -match '(?i)DO NOT USE FOR:\s*(.+?)(?:\.?\s*$)') {
        $negative = Split-TriggerList $Matches[1]
    }

    return @{
        Positive = $positive
        Negative = $negative
    }
}

function Build-EvalYaml {
    param(
        [string]$AgentName,
        [string]$AgentPath,
        [string[]]$PositiveItems,
        [string[]]$NegativeItems
    )

    $positives = @() + $PositiveItems
    if ($positives.Count -eq 0) {
        $positives = @("use the $AgentName agent")
    }
    while ($positives.Count -lt 3) {
        $positives += $positives[-1]
    }
    $positives = $positives[0..2]

    $negatives = @() + $NegativeItems
    if ($negatives.Count -lt 2) {
        $negatives += @(
            "Write a haiku about programming."
            "Give me a recipe for chocolate chip cookies."
        )
    }
    while ($negatives.Count -lt 2) {
        $negatives += $negatives[-1]
    }
    $negatives = $negatives[0..1]

    $lines = @(
        "name: `"$AgentName-routing`""
        "description: `"Routing evaluation — validates trigger activation for the $AgentName agent.`""
        "skill: `"$AgentPath`""
        "scenarios:"
        "  - id: `"pos-1`""
        "    input: `"I need help with $($positives[0]).`""
        "    expect_activation: true"
        "  - id: `"pos-2`""
        "    input: `"Can you handle $($positives[1])?`""
        "    expect_activation: true"
        "  - id: `"pos-3`""
        "    input: `"Please use the $AgentName agent for $($positives[2]).`""
        "    expect_activation: true"
        "  - id: `"neg-1`""
        "    input: `"$($negatives[0])`""
        "    expect_activation: false"
        "  - id: `"neg-2`""
        "    input: `"$($negatives[1])`""
        "    expect_activation: false"
    )

    return ($lines -join "`n") + "`n"
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$resolvedAgentsDir = Join-Path $repoRoot $AgentsDir

if (-not (Test-Path $resolvedAgentsDir)) {
    Write-Error "Agents directory not found: $resolvedAgentsDir"
    exit 1
}

$agentFiles = Get-ChildItem $resolvedAgentsDir -File -Filter *.agent.md
if ($AgentName) {
    $agentFiles = $agentFiles | Where-Object { ($_.BaseName -replace '\.agent$', '') -eq $AgentName }
    if (-not $agentFiles) {
        Write-Error "Agent '$AgentName' not found in $resolvedAgentsDir"
        exit 1
    }
}

$generated = 0
$skipped = 0
$warned = 0

foreach ($file in $agentFiles) {
    $logicalName = $file.BaseName -replace '\.agent$', ''
    $evalFile = Join-Path $file.DirectoryName ($file.BaseName + ".eval.yaml")
    if ((Test-Path $evalFile) -and -not $Force) {
        $skipped++
        continue
    }

    $description = Get-FrontmatterDescription $file.FullName
    if (-not $description) {
        Write-Warning "[$($file.BaseName)] No description found in frontmatter — skipping."
        $warned++
        continue
    }

    $parsed = Parse-Description $description
    $yaml = Build-EvalYaml -AgentName $logicalName -AgentPath ("agents/" + $file.Name) -PositiveItems $parsed.Positive -NegativeItems $parsed.Negative

    if ($DryRun) {
        Write-Host "=== DRY RUN: $evalFile ===" -ForegroundColor Cyan
        Write-Host $yaml
    }
    else {
        [System.IO.File]::WriteAllText($evalFile, $yaml)
    }

    $generated++
}

Write-Host ""
if ($DryRun) {
    Write-Host "DRY RUN complete — Generated $generated new eval.yaml files, skipped $skipped existing." -ForegroundColor Yellow
}
else {
    Write-Host "Generated $generated new eval.yaml files, skipped $skipped existing." -ForegroundColor Green
}

if ($warned -gt 0) {
    Write-Host "$warned agent(s) had no parseable description and were skipped." -ForegroundColor Yellow
}
