#!/usr/bin/env pwsh
<#
.SYNOPSIS
Generate missing .agent.eval.yaml companion files for agent definitions.

.DESCRIPTION
Scans the agents directory for *.agent.md files that lack a corresponding
*.agent.eval.yaml companion and generates stub eval files.

The generated filename matches exactly what the agent-merge CI guardrail
expects: <full-stem>.agent.eval.yaml (e.g. basecoat-10-core-sprint-planner.agent.eval.yaml).

.PARAMETER AgentsDir
Path to the agents directory. Relative paths are resolved from the repo root;
absolute paths are also supported. Default: "agents"

.PARAMETER Force
Regenerate eval stubs even if they already exist.

.PARAMETER DryRun
Preview generated content without writing files.

.PARAMETER AgentName
Filter to a specific agent by full filename stem or partial match
(e.g., "sprint-planner" or "basecoat-10-core-sprint-planner").

.EXAMPLE
# Generate stubs for any agents missing an eval companion
.\scripts\generate-agent-eval-stubs.ps1

# Preview what would be generated without writing
.\scripts\generate-agent-eval-stubs.ps1 -DryRun

# Regenerate a specific agent's eval stub
.\scripts\generate-agent-eval-stubs.ps1 -AgentName "sprint-planner" -Force
#>
[CmdletBinding()]
param(
    [string]$AgentsDir = "agents",
    [switch]$Force,
    [switch]$DryRun,
    [string]$AgentName = ""
)

$ErrorActionPreference = "Stop"

function Get-FrontmatterName {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Raw
    if ($content -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') {
        return $null
    }
    $yaml = $Matches[1]

    if ($yaml -match '(?m)^name:\s*"(.*)"') { return $Matches[1] }
    if ($yaml -match "(?m)^name:\s*'(.*)'") { return $Matches[1] }
    if ($yaml -match '(?m)^name:\s*(.+)') { return $Matches[1].Trim() }
    return $null
}

function Build-AgentEvalYaml {
    param(
        # Full filename stem, e.g. "basecoat-10-core-sprint-retrospective"
        [string]$FileStem,
        # Internal agent name from frontmatter, e.g. "sprint-retrospective"
        [string]$InternalName
    )

    $lines = @(
        "name: '$FileStem-routing'"
        "description: 'Routing evaluation - validates trigger activation for the $InternalName agent.'"
        "skill: 'agents/$FileStem.agent.md'"
        "scenarios:"
        "  - id: 'pos-1'"
        "    input: 'Use the $InternalName agent to handle its documented responsibilities.'"
        "    expect_activation: true"
        "  - id: 'pos-2'"
        "    input: 'Please route this task to the $InternalName agent.'"
        "    expect_activation: true"
        "  - id: 'neg-1'"
        "    input: 'Write a haiku about programming.'"
        "    expect_activation: false"
        "  - id: 'neg-2'"
        "    input: 'Give me a recipe for chocolate chip cookies.'"
        "    expect_activation: false"
    )

    return ($lines -join "`n") + "`n"
}

$repoRoot = Split-Path $PSScriptRoot -Parent
# Support both relative (resolved from repo root) and absolute paths
if ([System.IO.Path]::IsPathRooted($AgentsDir)) {
    $resolvedAgentsDir = $AgentsDir
} else {
    $resolvedAgentsDir = Join-Path $repoRoot $AgentsDir
}

if (-not (Test-Path $resolvedAgentsDir)) {
    Write-Error "Agents directory not found: $resolvedAgentsDir"
    exit 1
}

$agentFiles = Get-ChildItem $resolvedAgentsDir -File -Filter *.agent.md

if ($AgentName) {
    $agentFiles = $agentFiles | Where-Object {
        $stem = $_.BaseName -replace '\.agent$', ''
        $stem -eq $AgentName -or $stem -like "*$AgentName*"
    }
    if (-not $agentFiles) {
        Write-Error "No agent file matching '$AgentName' found in $resolvedAgentsDir"
        exit 1
    }
}

$generated = 0
$skipped   = 0
$warned    = 0

foreach ($file in $agentFiles) {
    # Full stem, e.g. "basecoat-10-core-sprint-retrospective"
    $stem     = $file.BaseName -replace '\.agent$', ''
    # Expected eval file path — must match what agent-merge CI guardrail checks
    $evalPath = Join-Path $resolvedAgentsDir "$stem.agent.eval.yaml"

    if ((Test-Path $evalPath) -and -not $Force) {
        $skipped++
        continue
    }

    $internalName = Get-FrontmatterName $file.FullName
    if (-not $internalName) {
        Write-Warning "[$($file.Name)] No name field in frontmatter — skipping."
        $warned++
        continue
    }

    $yaml = Build-AgentEvalYaml -FileStem $stem -InternalName $internalName

    if ($DryRun) {
        Write-Host "=== DRY RUN: $evalPath ===" -ForegroundColor Cyan
        Write-Host $yaml
    } else {
        [System.IO.File]::WriteAllText($evalPath, $yaml)
        Write-Host "  Generated: $stem.agent.eval.yaml" -ForegroundColor Green
    }

    $generated++
}

Write-Host ""
if ($DryRun) {
    Write-Host "DRY RUN complete — would generate $generated new .agent.eval.yaml files, skip $skipped existing." -ForegroundColor Yellow
} else {
    Write-Host "Generated $generated new .agent.eval.yaml files, skipped $skipped existing." -ForegroundColor Green
}
if ($warned -gt 0) {
    Write-Host "$warned agent(s) skipped (no parseable name in frontmatter)." -ForegroundColor Yellow
}
