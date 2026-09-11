# Base Coat Adoption Dashboard — Bootstrap Script (PowerShell)
# Configures GitHub secrets and enables Pages for metrics collection.
# No secrets are stored in code — they are set via gh CLI at setup time.
#
# Usage:
#   pwsh scripts/bootstrap-dashboard.ps1              — Interactive setup
#   pwsh scripts/bootstrap-dashboard.ps1 -Add         — Add repos to existing config
#   pwsh scripts/bootstrap-dashboard.ps1 -Remove      — Remove repos from config
#   pwsh scripts/bootstrap-dashboard.ps1 -List        — Show current repos

param(
    [switch]$Add,
    [switch]$Remove,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
$REPO = "ivegamsft/basecoat"

function Get-CurrentRepos {
    $raw = gh secret list --repo $REPO 2>&1 | Select-String "DASHBOARD_REPOS"
    if (-not $raw) { return @() }
    # We can't read secret values, so we store a local cache
    $cachePath = Join-Path $PSScriptRoot ".dashboard-repos-cache.json"
    if (Test-Path $cachePath) {
        return (Get-Content $cachePath -Raw | ConvertFrom-Json)
    }
    return @()
}

function Save-RepoCache {
    param([string[]]$Repos)
    $cachePath = Join-Path $PSScriptRoot ".dashboard-repos-cache.json"
    $Repos | ConvertTo-Json | Set-Content $cachePath
    # Also update the secret
    $json = $Repos | ConvertTo-Json -Compress
    $json | gh secret set DASHBOARD_REPOS --repo $REPO
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Base Coat Adoption Dashboard — Bootstrap Setup      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: gh CLI required. Install from https://cli.github.com" -ForegroundColor Red
    exit 1
}
$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Not authenticated. Run 'gh auth login' first." -ForegroundColor Red
    exit 1
}

# Handle -List mode
if ($List) {
    $current = Get-CurrentRepos
    if ($current.Count -eq 0) {
        Write-Host "  No repos configured. Run without flags to set up." -ForegroundColor Yellow
    } else {
        Write-Host "  Currently monitoring $($current.Count) repos:" -ForegroundColor Green
        $current | ForEach-Object { Write-Host "    • $_" }
    }
    exit 0
}

# Handle -Add mode
if ($Add) {
    $current = Get-CurrentRepos
    Write-Host "  Currently monitoring: $($current -join ', ')" -ForegroundColor Gray
    Write-Host "  Enter repos to ADD (org/repo format, blank to finish):"
    $added = 0
    while ($true) {
        $r = Read-Host "  + repo"
        if ([string]::IsNullOrWhiteSpace($r)) { break }
        if ($current -contains $r) {
            Write-Host "    Already tracked: $r" -ForegroundColor Yellow
        } else {
            $current += $r
            $added++
            Write-Host "    Added: $r" -ForegroundColor Green
        }
    }
    if ($added -gt 0) {
        Save-RepoCache -Repos $current
        Write-Host "`n  ✓ Updated. Now monitoring $($current.Count) repos." -ForegroundColor Green
    } else {
        Write-Host "`n  No changes." -ForegroundColor Gray
    }
    exit 0
}

# Handle -Remove mode
if ($Remove) {
    $current = Get-CurrentRepos
    if ($current.Count -eq 0) {
        Write-Host "  No repos configured." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "  Currently monitoring:" -ForegroundColor Gray
    for ($i = 0; $i -lt $current.Count; $i++) {
        Write-Host "    [$($i + 1)] $($current[$i])"
    }
    Write-Host ""
    Write-Host "  Enter numbers to remove (comma-separated), or 'q' to cancel:"
    $input = Read-Host "  remove"
    if ($input -eq 'q') { exit 0 }

    $indices = $input -split ',' | ForEach-Object { [int]$_.Trim() - 1 }
    $removed = @()
    $remaining = @()
    for ($i = 0; $i -lt $current.Count; $i++) {
        if ($indices -contains $i) {
            $removed += $current[$i]
        } else {
            $remaining += $current[$i]
        }
    }

    if ($removed.Count -gt 0) {
        Save-RepoCache -Repos $remaining
        Write-Host "`n  ✓ Removed: $($removed -join ', ')" -ForegroundColor Green
        Write-Host "  Now monitoring $($remaining.Count) repos." -ForegroundColor Green
    }
    exit 0
}

# Full setup mode
Write-Host "This script will:"
Write-Host "  1. Configure GitHub secrets for metrics collection"
Write-Host "  2. Set the list of dogfooding repos to monitor"
Write-Host "  3. Enable GitHub Pages on the gh-pages branch"
Write-Host ""

# Step 1: Collect dogfooding repo names
Write-Host "── Step 1: Dogfooding Repositories ──" -ForegroundColor Yellow
$existingRepos = Get-CurrentRepos
if ($existingRepos.Count -gt 0) {
    Write-Host "  Existing config found: $($existingRepos -join ', ')" -ForegroundColor Gray
    $keep = Read-Host "  Keep existing and add more? (Y/n)"
    if ($keep -ne 'n') {
        $repos = [System.Collections.ArrayList]@($existingRepos)
    } else {
        $repos = [System.Collections.ArrayList]@()
    }
} else {
    $repos = [System.Collections.ArrayList]@()
}

Write-Host "  How many repos to add?"
$count = Read-Host "  count"
$n = [int]$count

for ($i = 1; $i -le $n; $i++) {
    $r = Read-Host "  repo $i of ${n} (org/repo)"
    if (-not [string]::IsNullOrWhiteSpace($r)) {
        [void]$repos.Add($r)
    }
}

if ($repos.Count -eq 0) {
    Write-Host "ERROR: At least one repo required." -ForegroundColor Red
    exit 1
}

$reposJson = @($repos) | ConvertTo-Json -Compress
Write-Host "  Configured $($repos.Count) repos: $($repos -join ', ')" -ForegroundColor Green
Write-Host ""

# Save local cache
Save-RepoCache -Repos @($repos)

# Step 2: Copilot Metrics API token
Write-Host "── Step 2: GitHub Token for Copilot Metrics API ──" -ForegroundColor Yellow
Write-Host "The Copilot usage API requires a token with org:read scope."
Write-Host "Options:"
Write-Host "  a) Use existing GITHUB_TOKEN (works if workflow has org read access)"
Write-Host "  b) Provide a Personal Access Token (classic) with admin:org scope"
Write-Host ""
$usePat = Read-Host "  Use a separate PAT? (y/N)"

if ($usePat -eq 'y') {
    $pat = Read-Host "  Enter a PAT with admin:org scope" -AsSecureString
    $patPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pat))
    if ([string]::IsNullOrWhiteSpace($patPlain)) {
        Write-Host "ERROR: PAT cannot be empty." -ForegroundColor Red
        exit 1
    }
    $patPlain | gh secret set COPILOT_METRICS_TOKEN --repo $REPO
    Write-Host "  ✓ Secret COPILOT_METRICS_TOKEN configured" -ForegroundColor Green
} else {
    Write-Host "  ✓ Will use default GITHUB_TOKEN (ensure workflow has org read permission)" -ForegroundColor Green
}
Write-Host ""

# Step 3: Store repo list as secret (not in code)
Write-Host "── Step 3: Storing Configuration ──" -ForegroundColor Yellow
$reposJson | gh secret set DASHBOARD_REPOS --repo $REPO
Write-Host "  ✓ Secret DASHBOARD_REPOS configured with $($repos.Count) repos" -ForegroundColor Green

$org = $REPO.Split('/')[0]
$org | gh secret set DASHBOARD_ORG --repo $REPO
Write-Host "  ✓ Secret DASHBOARD_ORG configured as '$org'" -ForegroundColor Green
Write-Host ""

# Step 4: Enable GitHub Pages
Write-Host "── Step 4: GitHub Pages ──" -ForegroundColor Yellow
Write-Host "  Checking if gh-pages branch exists..."
$branchExists = gh api "repos/$REPO/branches/gh-pages" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ gh-pages branch already exists" -ForegroundColor Green
} else {
    Write-Host "  Creating gh-pages branch..."
    $mainSha = gh api "repos/$REPO/git/ref/heads/main" --jq '.object.sha'
    gh api --method POST "repos/$REPO/git/refs" -f ref="refs/heads/gh-pages" -f sha="$mainSha" 2>&1 | Out-Null
    Write-Host "  ✓ gh-pages branch created" -ForegroundColor Green
}

gh api --method POST "repos/$REPO/pages" -f 'source[branch]=gh-pages' -f 'source[path]=/' 2>&1 | Out-Null
Write-Host "  ✓ GitHub Pages enabled on gh-pages branch" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "── Setup Complete ──" -ForegroundColor Green
Write-Host ""
Write-Host "  Secrets configured:"
Write-Host "    • DASHBOARD_REPOS  — list of repos to monitor"
Write-Host "    • DASHBOARD_ORG    — organization name"
if ($usePat -eq 'y') {
    Write-Host "    • COPILOT_METRICS_TOKEN — PAT for Copilot API"
}
Write-Host ""
Write-Host "  Next steps:"
Write-Host "    1. Push the adoption-metrics workflow to main"
Write-Host "    2. Trigger manually: gh workflow run adoption-metrics.yml"
Write-Host "    3. View dashboard at: https://$($org.ToLower()).github.io/basecoat/"
Write-Host ""
Write-Host "  To reconfigure later, re-run this script."
Write-Host "  To add/remove repos: gh secret set DASHBOARD_REPOS --repo $REPO"
