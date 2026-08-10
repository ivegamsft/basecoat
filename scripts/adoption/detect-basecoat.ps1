#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Detects basecoat asset adoption across organization repositories.

.DESCRIPTION
    Scans all repos in the org for synced basecoat assets (agents, instructions,
    prompts, skills). Reports which repos have which assets, version drift vs.
    basecoat main, and active Copilot seat data.

.PARAMETER Org
    GitHub organization to scan. Defaults to example-org.

.PARAMETER BasecoatRepo
    The basecoat source repository. Defaults to basecoat.

.PARAMETER OutputFormat
    Output format: 'table' (default), 'json', or 'markdown'.

.EXAMPLE
    ./detect-basecoat.ps1
    ./detect-basecoat.ps1 -Org "MyOrg" -OutputFormat json
#>
[CmdletBinding()]
param(
    [string]$Org = "example-org",
    [string]$BasecoatRepo = "basecoat",
    [ValidateSet("table", "json", "markdown")]
    [string]$OutputFormat = "table",
    [switch]$AssetDetail   # Flip view: show per-asset adoption rate across repos
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Helpers ---

function Invoke-GhApi {
    param([string]$Endpoint)
    $result = gh api $Endpoint 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    return $result | ConvertFrom-Json
}

function Get-ContentMeta {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Path
    )
    return Invoke-GhApi "/repos/$Owner/$Repo/contents/$Path"
}

function Get-FileSha {
    param([string]$Owner, [string]$Repo, [string]$Path)
    $data = Get-ContentMeta -Owner $Owner -Repo $Repo -Path $Path
    if ($data -and $data.sha) { return $data.sha }
    return $null
}

function Get-FrontmatterVersionFromContent {
    param($ContentMeta)
    if (-not $ContentMeta -or -not $ContentMeta.content) { return $null }
    try {
        $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(($ContentMeta.content -replace "`n", "")))
        if ($decoded -match '^---\r?\n([\s\S]+?)\r?\n---') {
            $fm = $matches[1]
            if ($fm -match '(?m)^version:\s*["'']?([0-9]+\.[0-9]+\.[0-9]+)["'']?\s*$') {
                return $matches[1]
            }
        }
    } catch {
        return $null
    }
    return $null
}

# --- Main ---

Write-Host "`n=== Basecoat Adoption Scanner ===" -ForegroundColor Cyan
Write-Host "Org: $Org | Source: $Org/$BasecoatRepo`n"

# 1. Get all repos in org (excluding basecoat itself)
Write-Host "Scanning repositories..." -ForegroundColor Yellow
$repos = gh repo list $Org --json name,visibility --limit 100 2>&1 | ConvertFrom-Json
$targetRepos = $repos | Where-Object { $_.name -ne $BasecoatRepo }

if (-not $targetRepos -or $targetRepos.Count -eq 0) {
    Write-Host "No target repositories found in $Org (excluding $BasecoatRepo)." -ForegroundColor Red
    exit 0
}

Write-Host "Found $($targetRepos.Count) target repo(s)`n"

# 2. Get basecoat source asset manifest
Write-Host "Building basecoat source manifest..." -ForegroundColor Yellow
$sourceAssets = @{}
$manifestMeta = Get-ContentMeta -Owner $Org -Repo $BasecoatRepo -Path 'asset-manifest.json'
if ($manifestMeta -and $manifestMeta.content) {
    try {
        $manifestJson = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(($manifestMeta.content -replace "`n", "")))
        $manifest = $manifestJson | ConvertFrom-Json
        foreach ($asset in $manifest.assets) {
            $syncPath = switch ($asset.type) {
                'agent' { ".github/agents/$([System.IO.Path]::GetFileName($asset.path))" }
                'instruction' { ".github/instructions/$([System.IO.Path]::GetFileName($asset.path))" }
                'prompt' { ".github/prompts/$([System.IO.Path]::GetFileName($asset.path))" }
                'skill' { ".github/skills/$((($asset.path -split '/')[1]))/SKILL.md" }
                default { $null }
            }
            if (-not $syncPath) { continue }
            $sourceAssets[$asset.path] = @{
                sha      = $asset.sha
                type     = $asset.type
                syncPath = $syncPath
                version  = $asset.effectiveVersion
            }
        }
    } catch {
        Write-Host "  WARNING: Unable to parse asset-manifest.json, falling back to SHA-only discovery." -ForegroundColor Yellow
    }
}

if ($sourceAssets.Count -eq 0) {
    # Fallback discovery for repos without asset-manifest.json
    $agentFiles = gh api "/repos/$Org/$BasecoatRepo/contents/agents" 2>&1 | ConvertFrom-Json
    if ($agentFiles) {
        foreach ($f in $agentFiles | Where-Object { $_.name -match '\.agent\.md$' }) {
            $sourceAssets["agents/$($f.name)"] = @{
                sha      = $f.sha
                type     = "agent"
                syncPath = ".github/agents/$($f.name)"
                version  = $null
            }
        }
    }
    $instrFiles = gh api "/repos/$Org/$BasecoatRepo/contents/instructions" 2>&1 | ConvertFrom-Json
    if ($instrFiles) {
        foreach ($f in $instrFiles | Where-Object { $_.name -match '\.instructions\.md$' }) {
            $sourceAssets["instructions/$($f.name)"] = @{
                sha      = $f.sha
                type     = "instruction"
                syncPath = ".github/instructions/$($f.name)"
                version  = $null
            }
        }
    }
    $promptFiles = gh api "/repos/$Org/$BasecoatRepo/contents/prompts" 2>&1 | ConvertFrom-Json
    if ($promptFiles) {
        foreach ($f in $promptFiles | Where-Object { $_.name -match '\.prompt\.md$' }) {
            $sourceAssets["prompts/$($f.name)"] = @{
                sha      = $f.sha
                type     = "prompt"
                syncPath = ".github/prompts/$($f.name)"
                version  = $null
            }
        }
    }
}

Write-Host "Source manifest: $($sourceAssets.Count) assets`n"

# 3. Scan each repo for synced assets (optimized: list .github dirs first, then SHA-check matches)
Write-Host "Scanning target repos for basecoat assets..." -ForegroundColor Yellow
$adoptionReport = @()

# Build lookup of sync path -> source asset info
$syncPathLookup = @{}
foreach ($asset in $sourceAssets.GetEnumerator()) {
    $syncPathLookup[$asset.Value.syncPath] = $asset
}

foreach ($repo in $targetRepos) {
    $repoName = $repo.name
    $repoAssets = @()
    $currentCount = 0
    $staleCount = 0

    # List .github/agents, .github/instructions, .github/prompts, .github/skills in one pass
    $syncDirs = @(".github/agents", ".github/instructions", ".github/prompts", ".github/skills")
    $foundFiles = @()

    foreach ($dir in $syncDirs) {
        $listing = Invoke-GhApi "/repos/$Org/$repoName/contents/$dir"
        if ($listing) {
            foreach ($f in $listing) {
                # For skills, list one level deeper (SKILL.md)
                if ($f.type -eq 'dir' -and $dir -eq '.github/skills') {
                    $skillFile = Invoke-GhApi "/repos/$Org/$repoName/contents/$dir/$($f.name)/SKILL.md"
                    if ($skillFile) {
                        $foundFiles += @{ name = 'SKILL.md'; sha = $skillFile.sha; path = "$dir/$($f.name)/SKILL.md" }
                    }
                    continue
                }
                if ($f.type -eq 'file') {
                    $foundFiles += @{ name = $f.name; sha = $f.sha; path = "$dir/$($f.name)" }
                }
            }
        }
    }

    # Match found files against basecoat source manifest
    foreach ($f in $foundFiles) {
        $match = $syncPathLookup[$f.path]
        if ($match) {
            $comparison = "sha"
            $sourceVersion = $match.Value.version
            $consumerVersion = $null
            if ($sourceVersion) {
                $meta = Get-ContentMeta -Owner $Org -Repo $repoName -Path $f.path
                $consumerVersion = Get-FrontmatterVersionFromContent -ContentMeta $meta
            }
            $isCurrent = $false
            if ($sourceVersion -and $consumerVersion) {
                $comparison = "version"
                $isCurrent = ($consumerVersion -eq $sourceVersion)
            } else {
                $isCurrent = ($f.sha -eq $match.Value.sha)
            }

            if ($isCurrent) {
                $currentCount++
                $repoAssets += @{ asset = $match.Key; status = "current"; type = $match.Value.type; comparison = $comparison; sourceVersion = $sourceVersion; consumerVersion = $consumerVersion }
            }
            else {
                $staleCount++
                $repoAssets += @{ asset = $match.Key; status = "stale"; type = $match.Value.type; comparison = $comparison; sourceVersion = $sourceVersion; consumerVersion = $consumerVersion }
            }
        }
    }

    $totalSynced = $currentCount + $staleCount
    if ($totalSynced -gt 0 -or $foundFiles.Count -gt 0) {
        $nonBasecoat = $foundFiles.Count - $totalSynced
        $adoptionReport += @{
            repo        = $repoName
            visibility  = $repo.visibility
            synced      = $totalSynced
            current     = $currentCount
            stale       = $staleCount
            custom      = $nonBasecoat
            totalFiles  = $foundFiles.Count
            coverage    = if ($sourceAssets.Count -gt 0) { [math]::Round(($totalSynced / $sourceAssets.Count) * 100, 1) } else { 0 }
            assets      = $repoAssets
        }
    }
}

# 4. Get Copilot seat data
Write-Host "`nFetching Copilot seat data..." -ForegroundColor Yellow
$seats = Invoke-GhApi "/orgs/$Org/copilot/billing/seats"
$seatInfo = @()
if ($seats -and $seats.seats) {
    foreach ($s in $seats.seats) {
        $seatInfo += @{
            login           = $s.assignee.login
            last_activity   = $s.last_activity_at
            editor          = $s.last_activity_editor
            created         = $s.created_at
        }
    }
}

# 5. Output results
Write-Host "`n=== Adoption Report ===" -ForegroundColor Cyan

if ($adoptionReport.Count -eq 0) {
    Write-Host "No basecoat assets detected in any target repositories." -ForegroundColor Yellow
    Write-Host "  Tip: Run sync.ps1 or sync.sh to deploy assets to consumer repos.`n"
}

switch ($OutputFormat) {
    "json" {
        @{
            scan_date  = (Get-Date -Format "o")
            org        = $Org
            source     = "$Org/$BasecoatRepo"
            total_source_assets = $sourceAssets.Count
            repos      = $adoptionReport
            copilot_seats = $seatInfo
        } | ConvertTo-Json -Depth 5
    }
    "markdown" {
        Write-Host "`n## Basecoat Adoption — $Org`n"
        Write-Host "| Repo | Synced | Current | Stale | Coverage |"
        Write-Host "|------|--------|---------|-------|----------|"
        foreach ($r in $adoptionReport) {
            $staleFlag = if ($r.stale -gt 0) { " ⚠️" } else { "" }
            Write-Host "| $($r.repo) | $($r.synced) | $($r.current) | $($r.stale)$staleFlag | $($r.coverage)% |"
        }
        if ($seatInfo.Count -gt 0) {
            Write-Host "`n### Copilot Seats`n"
            Write-Host "| User | Last Active | Editor |"
            Write-Host "|------|------------|--------|"
            foreach ($s in $seatInfo) {
                Write-Host "| $($s.login) | $($s.last_activity) | $($s.editor) |"
            }
        }
    }
    default {
        # Table format
        foreach ($r in $adoptionReport) {
            $staleFlag = if ($r.stale -gt 0) { " (⚠️ $($r.stale) stale)" } else { "" }
            $customFlag = if ($r.custom -gt 0) { " + $($r.custom) custom" } else { "" }
            Write-Host "  $($r.repo) — $($r.synced)/$($sourceAssets.Count) basecoat assets ($($r.coverage)%)$staleFlag$customFlag" -ForegroundColor Green
            foreach ($a in $r.assets) {
                $icon = if ($a.status -eq "current") { "✓" } else { "⟳" }
                $color = if ($a.status -eq "current") { "Gray" } else { "DarkYellow" }
                Write-Host "    $icon $($a.asset) [$($a.status)]" -ForegroundColor $color
            }
        }
        if ($seatInfo.Count -gt 0) {
            Write-Host "`n  Copilot Seats:" -ForegroundColor Cyan
            foreach ($s in $seatInfo) {
                Write-Host "    $($s.login) — last active: $($s.last_activity) ($($s.editor))"
            }
        }
    }
}

Write-Host "`n=== Scan Complete ===" -ForegroundColor Cyan

# If -AssetDetail was requested, output a flipped view: per-asset adoption across repos
if ($AssetDetail) {
    Write-Host "`n=== Per-Asset Adoption Detail ===" -ForegroundColor Cyan
    Write-Host "Shows how many consumer repos have each BaseCoat asset (current/stale/missing)`n"

    # Build per-asset stats
    $assetStats = @{}
    foreach ($key in $sourceAssets.Keys) {
        $assetStats[$key] = @{
            asset    = $key
            type     = $sourceAssets[$key].type
            current  = 0
            stale    = 0
            missing  = 0
            repos    = @()
        }
    }

    $totalReposScanned = $adoptionReport.Count

    foreach ($r in $adoptionReport) {
        $seen = @{}
        foreach ($a in $r.assets) {
            $seen[$a.asset] = $a.status
            if ($assetStats.ContainsKey($a.asset)) {
                $assetStats[$a.asset][$a.status]++
                $assetStats[$a.asset].repos += "$($r.repo):$($a.status)"
            }
        }
        # Count missing for assets not seen in this repo
        foreach ($key in $sourceAssets.Keys) {
            if (-not $seen.ContainsKey($key)) {
                $assetStats[$key].missing++
            }
        }
    }

    # Sort by adoption rate descending
    $sorted = $assetStats.Values | Sort-Object {
        if ($totalReposScanned -gt 0) { ($_.current + $_.stale) / $totalReposScanned } else { 0 }
    } -Descending

    switch ($OutputFormat) {
        "json" {
            @{
                scan_date        = (Get-Date -Format "o")
                org              = $Org
                total_repos      = $totalReposScanned
                assets           = ($sorted | ForEach-Object {
                    @{
                        asset       = $_.asset
                        type        = $_.type
                        current     = $_.current
                        stale       = $_.stale
                        missing     = $_.missing
                        adoptionPct = if ($totalReposScanned -gt 0) {
                            [math]::Round(($_.current + $_.stale) / $totalReposScanned * 100, 1)
                        } else { 0 }
                        repos       = $_.repos
                    }
                })
            } | ConvertTo-Json -Depth 5
        }
        "markdown" {
            Write-Host "## Per-Asset Adoption — $Org"
            Write-Host ""
            Write-Host "| Asset | Type | Current | Stale | Missing | Adoption% |"
            Write-Host "|-------|------|---------|-------|---------|-----------|"
            foreach ($a in $sorted) {
                $pct = if ($totalReposScanned -gt 0) {
                    [math]::Round(($a.current + $a.stale) / $totalReposScanned * 100, 1)
                } else { 0 }
                $flag = if ($a.stale -gt 0) { " ⚠️" } else { "" }
                Write-Host "| $($a.asset) | $($a.type) | $($a.current) | $($a.stale)$flag | $($a.missing) | $pct% |"
            }
        }
        default {
            foreach ($a in $sorted) {
                $pct = if ($totalReposScanned -gt 0) {
                    [math]::Round(($a.current + $a.stale) / $totalReposScanned * 100, 1)
                } else { 0 }
                $adopted = $a.current + $a.stale
                $color = if ($pct -ge 50) { "Green" } elseif ($pct -ge 20) { "Yellow" } else { "DarkGray" }
                Write-Host ("  {0,-60} [{1}] {2}/{3} repos ({4}%)" -f $a.asset, $a.type, $adopted, $totalReposScanned, $pct) -ForegroundColor $color
            }
        }
    }
}

