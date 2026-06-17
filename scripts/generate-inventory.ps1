#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Auto-generates INVENTORY.md asset counts and validates the README.md asset counts.

.DESCRIPTION
    Counts assets in agents/, skills/, instructions/, prompts/, and portal/prompts/,
    then reports discrepancies vs. INVENTORY.md and README.md. Optionally updates both.

.PARAMETER Update
    When set, writes updated counts to README.md and regenerates the INVENTORY.md header.

.EXAMPLE
    pwsh scripts/generate-inventory.ps1
    pwsh scripts/generate-inventory.ps1 -Update
#>

param(
    [switch]$Update
)

$repoRoot = Split-Path -Parent $PSScriptRoot

function Count-Assets {
    param([string]$Pattern, [string]$Path)
    $dir = Join-Path $repoRoot $Path
    if (-not (Test-Path $dir)) { return 0 }
    return (Get-ChildItem $dir -Filter $Pattern -File).Count
}

$counts = @{
    agents       = Count-Assets "*.agent.md"    "agents"
    skills       = (Get-ChildItem (Join-Path $repoRoot "skills") -Directory).Count
    instructions = Count-Assets "*.instructions.md" "instructions"
    prompts      = (Count-Assets "*.prompt.md" "prompts") + (Count-Assets "*.prompt.md" "portal/prompts")
}

Write-Host ""
Write-Host "=== Base Coat Asset Counts ===" -ForegroundColor Cyan
Write-Host "  Agents:       $($counts.agents)"
Write-Host "  Skills:       $($counts.skills)"
Write-Host "  Instructions: $($counts.instructions)"
Write-Host "  Prompts:      $($counts.prompts) ($(Count-Assets '*.prompt.md' 'prompts') core + $(Count-Assets '*.prompt.md' 'portal/prompts') portal)"
Write-Host ""

# --- Validate README.md counts ---
$readmePath = Join-Path $repoRoot "README.md"
$readmeContent = Get-Content $readmePath -Raw

$readmeAgents  = if ($readmeContent -match '\*\*(\d+) agents\*\*') { [int]$Matches[1] } else { -1 }
$readmeSkills  = if ($readmeContent -match '\*\*(\d+) skills\*\*') { [int]$Matches[1] } else { -1 }
$readmeInstr   = if ($readmeContent -match '\*\*(\d+) instruction') { [int]$Matches[1] } else { -1 }
$readmePrompts = if ($readmeContent -match '\*\*(\d+) prompt') { [int]$Matches[1] } else { -1 }

$errors = 0

function Check {
    param([string]$Label, [int]$Actual, [int]$InFile, [string]$File)
    if ($Actual -ne $InFile) {
        Write-Host "  MISMATCH $Label`: actual=$Actual, $File shows $InFile" -ForegroundColor Yellow
        return 1
    } else {
        Write-Host "  OK $Label`: $Actual" -ForegroundColor Green
        return 0
    }
}

Write-Host "=== README.md Validation ===" -ForegroundColor Cyan
$errors += Check "agents"       $counts.agents       $readmeAgents  "README.md"
$errors += Check "skills"       $counts.skills       $readmeSkills  "README.md"
$errors += Check "instructions" $counts.instructions $readmeInstr   "README.md"
$errors += Check "prompts"      $counts.prompts      $readmePrompts "README.md"
Write-Host ""

# --- Validate INVENTORY.md counts ---
$inventoryPath = @(
    (Join-Path $repoRoot "INVENTORY.md")
    (Join-Path $repoRoot "docs/reference/INVENTORY.md")
    (Join-Path $repoRoot "docs/reference/inventory.md")
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $inventoryPath) {
    throw "Cannot validate inventory counts: INVENTORY.md not found in root or docs/reference/"
}

$inventoryContent = Get-Content $inventoryPath -Raw

$invAgents = ($inventoryContent | Select-String '`agents/[^`]+\.agent\.md`' -AllMatches).Matches.Count
$invSkills = ($inventoryContent | Select-String '`skills/[^`]+`' -AllMatches).Matches.Count
$invInstr  = ($inventoryContent | Select-String '`instructions/[^`]+\.instructions\.md`' -AllMatches).Matches.Count
$invPrompts = ($inventoryContent | Select-String '`(?:prompts|portal/prompts)/[^`]+\.prompt\.md`' -AllMatches).Matches.Count

Write-Host "=== INVENTORY.md Validation ===" -ForegroundColor Cyan
$errors += Check "agents"       $counts.agents       $invAgents "INVENTORY.md"
$errors += Check "skills"       $counts.skills       $invSkills "INVENTORY.md"
$errors += Check "instructions" $counts.instructions $invInstr  "INVENTORY.md"
$errors += Check "prompts"      $counts.prompts      $invPrompts "INVENTORY.md"
Write-Host ""

if ($Update) {
    Write-Host "=== Updating README.md ===" -ForegroundColor Cyan

    # Update agent/skill/instruction/prompt counts in README.md
    $updated = $readmeContent `
        -replace '\*\*(\d+) agents\*\*',       "**$($counts.agents) agents**" `
        -replace '\*\*(\d+) skills\*\*',       "**$($counts.skills) skills**" `
        -replace '\*\*(\d+) instruction[^*]*\*\*', "**$($counts.instructions) instruction files**" `
        -replace '\*\*(\d+) prompt[^*]*\*\*',  "**$($counts.prompts) prompt starters**"

    Set-Content $readmePath $updated -NoNewline
    Write-Host "  README.md updated" -ForegroundColor Green
    Write-Host ""
}

if ($errors -gt 0) {
    Write-Host "$errors discrepancy(s) found. Run with -Update to fix README.md counts." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "All counts match. No updates needed." -ForegroundColor Green
    exit 0
}
