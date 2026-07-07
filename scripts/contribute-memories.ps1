#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Batch-export session memories to the shared basecoat-memory repository.

.DESCRIPTION
    Reads a JSON array of memory facts and creates structured memory files
    (memories/{domain}/{subject}.md) in the {org}/basecoat-memory repo via
    the GitHub API. Opens a single PR for review.

    This is the "push" half of the memory contribution pipeline. The "pull"
    half is sync-shared-memory.ps1.

.PARAMETER InputFile
    Path to a JSON file containing an array of memory objects.
    Each object must have: subject (domain:key), fact, confidence.
    Optional fields: citations, applies_to, category.

.PARAMETER Sprint
    Sprint label used in the PR title and branch name (e.g., "sprint-20").

.PARAMETER DryRun
    Print formatted memory files to console without creating any PRs.

.PARAMETER Force
    Overwrite existing memory files in the target repo (default: skip existing).

.EXAMPLE
    pwsh scripts/contribute-memories.ps1 -InputFile memories-sprint20.json -Sprint sprint-20
    pwsh scripts/contribute-memories.ps1 -InputFile memories.json -Sprint sprint-20 -DryRun

.INPUT FORMAT
    [
      {
        "subject": "ci:copilot-agent-pr",
        "fact": "Copilot agent PRs show action_required (0 jobs). Maintainer must push an empty commit to trigger CI.",
        "confidence": 0.95,
        "citations": "IBuySpy-Shared/basecoat — PRs #312, #313, #314",
        "category": "convention",
        "applies_to": "all teams"
      }
    ]
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$InputFile,
    [string] $Sprint   = "sprint-$(Get-Date -Format 'yyyy-MM')",
    [switch] $DryRun,
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Configuration ──────────────────────────────────────────────────────────────

$SharedRepo = $env:BASECOAT_SHARED_MEMORY_REPO  # e.g. "your-org/basecoat-memory"
$BranchName = "memory-contribute/$Sprint-$(Get-Date -Format 'yyyyMMdd')"

# ── Helpers ────────────────────────────────────────────────────────────────────

function Write-Step([string]$msg) { Write-Host "  → $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-Err([string]$msg)  { Write-Host "  ✗ $msg" -ForegroundColor Red }

function Assert-SharedRepo {
    if (-not $SharedRepo) {
        Write-Err "BASECOAT_SHARED_MEMORY_REPO is not set."
        Write-Host '  Set: $env:BASECOAT_SHARED_MEMORY_REPO = "your-org/basecoat-memory"'
        exit 1
    }
}

function Assert-GhAuth {
    $null = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Not authenticated with gh CLI. Run: gh auth login"
        exit 1
    }
}

function Validate-Memory([hashtable]$m, [int]$idx) {
    $errors = @()
    if (-not $m.subject) { $errors += "missing 'subject'" }
    elseif ($m.subject -notmatch '^[a-z][a-z-]+:[a-z][a-z0-9-]+$') {
        $errors += "subject must be 'domain:key' (e.g. 'ci:copilot-agent-pr'), got: '$($m.subject)'"
    }
    if (-not $m.fact)   { $errors += "missing 'fact'" }
    elseif ($m.fact.Length -gt 300) { $errors += "fact exceeds 300 chars ($($m.fact.Length))" }
    if ($m.confidence -and ($m.confidence -lt 0 -or $m.confidence -gt 1)) {
        $errors += "confidence must be 0.0–1.0"
    }
    if ($errors.Count -gt 0) {
        throw "Memory[$idx] ($($m.subject ?? 'unknown')): $($errors -join '; ')"
    }
}

function Format-MemoryFile([hashtable]$m) {
    $domain      = $m.subject.Split(':')[0]
    $key         = $m.subject.Split(':')[1]
    $confidence  = if ($m.confidence) { [math]::Round([double]$m.confidence, 2) } else { 0.80 }
    $category    = if ($m.category)   { $m.category }   else { "convention" }
    $appliesTo   = if ($m.applies_to) { $m.applies_to } else { "all teams" }
    $citations   = if ($m.citations)  { $m.citations }  else { "basecoat session store" }
    $date        = Get-Date -Format "yyyy-MM-dd"

    $title = ($key -replace '-', ' ') -replace '\b(.)', { $_.Value.ToUpper() }

    return @"
---
subject: "$($m.subject)"
category: "$category"
confidence: $confidence
created: "$date"
applies_to: "$appliesTo"
---

# $title

## Pattern

$($m.fact)

## Evidence

- Source: $citations

## Does NOT apply to

- Project-specific implementations that override this pattern
"@
}

function Get-RepoDefaultBranch {
    $info = gh api "repos/$SharedRepo" --jq '.default_branch' 2>&1
    if ($LASTEXITCODE -ne 0) { return "main" }
    return $info.Trim()
}

function Get-FileTree([string]$branch) {
    # Returns list of existing memory file paths in the repo
    try {
        $tree = gh api "repos/$SharedRepo/git/trees/${branch}?recursive=1" --jq '.tree[].path' 2>&1
        if ($LASTEXITCODE -ne 0) { return @() }
        return $tree -split "`n" | Where-Object { $_ -match '^memories/' }
    } catch { return @() }
}

function Push-MemoryFile([string]$path, [string]$content, [string]$branch, [string]$sha) {
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($content))
    $payload = @{ message = "feat(memory): add $path"; content = $encoded; branch = $branch }
    if ($sha) { $payload.sha = $sha }
    $payloadJson = $payload | ConvertTo-Json -Compress

    $result = $payloadJson | gh api "repos/$SharedRepo/contents/$path" `
        --method PUT --input - 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Failed to push $path`: $result" }
}

function Get-ExistingFileSha([string]$path, [string]$branch) {
    $result = gh api "repos/$SharedRepo/contents/$($path)?ref=$branch" --jq '.sha' 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    return $result.Trim()
}

# ── Main ───────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "  BaseCoat Memory Contribution" -ForegroundColor White
Write-Host "  Source: $InputFile"
Write-Host "  Target: $($SharedRepo ?? '(dry-run)')"
Write-Host ""

# Load memories
if (-not (Test-Path $InputFile)) {
    Write-Err "Input file not found: $InputFile"
    exit 1
}

$rawJson = Get-Content $InputFile -Raw
$memoriesRaw = $rawJson | ConvertFrom-Json
$memories = @($memoriesRaw | ForEach-Object {
    $ht = @{}
    $_.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
    $ht
})

Write-Step "Loaded $($memories.Count) memory fact(s)"

# Validate
$idx = 0
foreach ($m in $memories) {
    Validate-Memory $m $idx
    $idx++
}
Write-Ok "All $($memories.Count) memories validated"

if ($DryRun) {
    Write-Host ""
    Write-Host "  ── Dry Run Output ──" -ForegroundColor Yellow
    foreach ($m in $memories) {
        $domain = $m.subject.Split(':')[0]
        $key    = $m.subject.Split(':')[1]
        $path   = "memories/$domain/$key.md"
        Write-Host ""
        Write-Host "  FILE: $path" -ForegroundColor Cyan
        Write-Host (Format-MemoryFile $m)
    }
    exit 0
}

Assert-SharedRepo
Assert-GhAuth

# Get default branch and create contribution branch
$defaultBranch = Get-RepoDefaultBranch
Write-Step "Default branch: $defaultBranch"

# Get SHA of default branch tip
$branchSha = gh api "repos/$SharedRepo/git/ref/heads/$defaultBranch" --jq '.object.sha' 2>&1
if ($LASTEXITCODE -ne 0) { throw "Cannot get branch SHA: $branchSha" }
$branchSha = $branchSha.Trim()

# Create contribution branch
Write-Step "Creating branch: $BranchName"
$createBranch = @{ ref = "refs/heads/$BranchName"; sha = $branchSha } | ConvertTo-Json -Compress
$branchResult = $createBranch | gh api "repos/$SharedRepo/git/refs" --method POST --input - 2>&1
if ($LASTEXITCODE -ne 0 -and $branchResult -notmatch "already exists") {
    throw "Failed to create branch: $branchResult"
}

# Push memory files
$pushed = 0
$skipped = 0
foreach ($m in $memories) {
    $domain  = $m.subject.Split(':')[0]
    $key     = $m.subject.Split(':')[1]
    $path    = "memories/$domain/$key.md"
    $content = Format-MemoryFile $m

    $existingSha = Get-ExistingFileSha $path $BranchName
    if ($existingSha -and -not $Force) {
        Write-Warn "Skipping existing: $path (use -Force to overwrite)"
        $skipped++
        continue
    }

    Write-Step "Pushing: $path"
    Push-MemoryFile $path $content $BranchName $existingSha
    Write-Ok "  Pushed: $path"
    $pushed++
}

if ($pushed -eq 0) {
    Write-Warn "No new memories to contribute (all skipped). Branch created but no PR will be opened."
    exit 0
}

# Open PR
$prTitle = "feat(memory): contribute memories — $Sprint ($pushed new)"
$prBody = @"
## Memory Contribution — $Sprint

Auto-generated by \`scripts/contribute-memories.ps1\` from the BaseCoat session memory store.

| | |
|---|---|
| **Sprint** | $Sprint |
| **Memories** | $pushed pushed, $skipped skipped |
| **Branch** | \`$BranchName\` |

## Memories Included

$(($memories | Where-Object {
    $d = $_.subject.Split(':')[0]; $k = $_.subject.Split(':')[1]
    $path = "memories/$d/$k.md"
    $existingSha = $null
    $existingSha = Get-ExistingFileSha $path $BranchName
    $true
} | ForEach-Object { "- \`$($_.subject)\` — $($_.fact.Substring(0, [Math]::Min(80, $_.fact.Length)))..." }) -join "`n")

## Review Instructions

For each memory file:

1. **Validate scope** — is the pattern generic enough for all teams?
2. **Check confidence** — does the stated evidence justify the confidence score?
3. **Edit if needed** — you may tighten the wording or adjust domain placement
4. **Approve and merge** when satisfied

Unmerited memories should have their confidence lowered or be closed with a comment.

---

*Generated by [BaseCoat memory-contribute.yml](https://github.com/ivegamsft/basecoat/actions/workflows/memory-contribute.yml)*
"@

$env:GH_TOKEN = $env:MEMORY_REPO_TOKEN ?? $env:GH_TOKEN

Write-Step "Opening PR in $SharedRepo..."
$prUrl = gh pr create `
    --repo $SharedRepo `
    --title $prTitle `
    --base $defaultBranch `
    --head $BranchName `
    --body $prBody 2>&1

if ($LASTEXITCODE -ne 0) { throw "Failed to open PR: $prUrl" }

Write-Host ""
Write-Ok "Contribution complete!"
Write-Host "  Pushed:  $pushed memories"
Write-Host "  Skipped: $skipped (already exist)"
Write-Host "  PR:      $prUrl"

# ── Loopback: flag high-confidence memories for hot-index promotion ────────────
$hotCandidates = @($memories | Where-Object {
    $conf = if ($_.confidence) { [double]$_.confidence } else { 0 }
    $conf -ge 0.90
})

if ($hotCandidates.Count -gt 0) {
    Write-Host ""
    Write-Warn "Hot-index promotion candidates ($($hotCandidates.Count) memories with confidence >= 0.90):"
    foreach ($hc in $hotCandidates) {
        $conf = [math]::Round([double]$hc.confidence, 2)
        Write-Host "  → $($hc.subject) (confidence: $conf)"
        Write-Host "    Fact: $($hc.fact.Substring(0, [Math]::Min(100, $hc.fact.Length)))..."
    }
    Write-Host ""
    Write-Host "  These should be added to basecoat-memory/hot-index.md after PR merges." -ForegroundColor Yellow
    Write-Host "  Run after merge: pwsh scripts/audit-memories.ps1 -Validate to confirm, then"
    Write-Host "  manually add trigger entries to hot-index.md for each candidate above."
    Write-Host ""
}

