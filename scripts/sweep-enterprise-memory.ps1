#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Enterprise memory sweep — discovers basecoat-enabled repos and extracts learning candidates.

.DESCRIPTION
    1. Discovers all repos in the target org with the 'basecoat-enabled' GitHub topic.
    2. For each repo, reads optional .basecoat.yml sweep config.
    3. Extracts signals: labelled PRs, labelled issues, CHANGELOG entries.
    4. Writes candidates to docs/memory/sweep-candidates/YYYY-MM-DD.md.

.PARAMETER Org
    GitHub org to sweep. Defaults to GITHUB_REPOSITORY_OWNER env var.

.PARAMETER DaysBack
    How many days back to look for signals. Default: 30.

.PARAMETER OutputDir
    Where to write candidate files. Default: sweep-candidates (relative to cwd).
    In CI the workflow checks out {org}/basecoat-memory and passes that path.

.PARAMETER DryRun
    Print candidates to console without writing files.

.EXAMPLE
    pwsh scripts/sweep-enterprise-memory.ps1 -Org example-org -DaysBack 30
#>

[CmdletBinding()]
param(
    [string]$Org       = ($env:GITHUB_REPOSITORY_OWNER ?? "example-org"),
    [int]   $DaysBack  = 30,
    [string]$OutputDir = "sweep-candidates",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Helpers ───────────────────────────────────────────────────────────────────

function Invoke-GhApi([string]$Path, [hashtable]$Query = @{}) {
    $qs = ($Query.GetEnumerator() | ForEach-Object { "$($_.Key)=$([Uri]::EscapeDataString($_.Value))" }) -join "&"
    $url = if ($qs) { "${Path}?${qs}" } else { $Path }
    $result = gh api $url --paginate 2>&1
    if ($LASTEXITCODE -ne 0) { throw "gh api failed for ${url}: $result" }
    return $result | ConvertFrom-Json
}

function Get-RepoConfig([string]$Owner, [string]$Repo) {
    try {
        $raw = gh api "repos/$Owner/$Repo/contents/.basecoat.yml" --jq '.content' 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $raw) { return $null }
        $decoded = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($raw -replace "`n", "")))
        # Basic YAML key extraction (avoid yq dependency)
        return $decoded
    } catch {
        return $null
    }
}

function Get-LearningLabels([string]$ConfigContent) {
    $defaults = @("learning", "retrospective", "decision")
    if (-not $ConfigContent) { return $defaults }
    # Extract learning_labels from .basecoat.yml if present
    $matches = [regex]::Matches($ConfigContent, '(?m)^\s+-\s+(\w+)')
    if ($matches.Count -gt 0) {
        $inLabels = $false
        $labels   = @()
        foreach ($line in ($ConfigContent -split "`n")) {
            if ($line -match 'learning_labels:') { $inLabels = $true; continue }
            if ($inLabels -and $line -match '^\s+-\s+(\S+)') { $labels += $Matches[1] }
            elseif ($inLabels -and $line -notmatch '^\s') { $inLabels = $false }
        }
        if ($labels.Count -gt 0) { return $labels }
    }
    return $defaults
}

function Get-SignalDaysBack([string]$ConfigContent, [int]$Default) {
    if (-not $ConfigContent) { return $Default }
    if ($ConfigContent -match 'days_back:\s*(\d+)') { return [int]$Matches[1] }
    return $Default
}

# ── Discover enlisted repos ───────────────────────────────────────────────────

Write-Host "🔍 Discovering basecoat-enabled repos in org: $Org"

$searchUrl  = "search/repositories"
$searchQuery = "topic:basecoat-enabled org:$Org"
$searchResult = gh api "${searchUrl}?q=$([Uri]::EscapeDataString($searchQuery))&per_page=100" | ConvertFrom-Json

if ($searchResult.total_count -eq 0) {
    Write-Warning "No repos found with topic 'basecoat-enabled' in org '$Org'."
    Write-Warning "Add the topic to repos: gh api repos/{org}/{repo}/topics --method PUT --field names[]=basecoat-enabled"
    exit 0
}

$repos = $searchResult.items
Write-Host "  Found $($repos.Count) enlisted repo(s)"

# ── Per-repo extraction ───────────────────────────────────────────────────────

$since       = (Get-Date).AddDays(-$DaysBack).ToString("yyyy-MM-ddTHH:mm:ssZ")
$allCandidates = [System.Collections.Generic.List[hashtable]]::new()

foreach ($repo in $repos) {
    $owner    = $repo.owner.login
    $repoName = $repo.name
    $fullName = "$owner/$repoName"
    Write-Host "`n📦 Sweeping: $fullName"

    # Load optional per-repo config
    $config    = Get-RepoConfig $owner $repoName
    $labels    = Get-LearningLabels $config
    $repoDays  = Get-SignalDaysBack $config $DaysBack
    $repoSince = (Get-Date).AddDays(-$repoDays).ToString("yyyy-MM-ddTHH:mm:ssZ")

    # ── Signal 1: Merged PRs with learning labels ──────────────────────────
    Write-Host "  → PRs labelled: $($labels -join ', ')"
    foreach ($label in $labels) {
        try {
            $prs = gh api "repos/$fullName/pulls?state=closed&sort=updated&direction=desc&per_page=50" | ConvertFrom-Json
            $recent = $prs | Where-Object {
                $_.merged_at -and [datetime]$_.merged_at -gt [datetime]$repoSince -and
                ($_.labels | Where-Object { $_.name -eq $label })
            }
            foreach ($pr in $recent) {
                $allCandidates.Add(@{
                    source     = $fullName
                    type       = "pull_request"
                    signal     = "label:$label"
                    title      = $pr.title
                    body       = ($pr.body ?? "") -replace '(?s)<!--.*?-->', '' -replace '\r?\n', ' ' | Select-Object -First 1
                    url        = $pr.html_url
                    date       = $pr.merged_at
                    labels     = ($pr.labels | ForEach-Object { $_.name }) -join ", "
                })
            }
        } catch {
            Write-Warning "    Could not fetch PRs from ${fullName}: $_"
        }
    }

    # ── Signal 2: Closed issues with learning labels ───────────────────────
    Write-Host "  → Issues labelled: $($labels -join ', ')"
    foreach ($label in $labels) {
        try {
            $issues = gh api "repos/$fullName/issues?state=closed&labels=$label&sort=updated&direction=desc&per_page=50" | ConvertFrom-Json
            $recent = $issues | Where-Object {
                $_.closed_at -and [datetime]$_.closed_at -gt [datetime]$repoSince -and
                -not $_.pull_request  # exclude PRs that show up in issues endpoint
            }
            foreach ($issue in $recent) {
                $allCandidates.Add(@{
                    source  = $fullName
                    type    = "issue"
                    signal  = "label:$label"
                    title   = $issue.title
                    body    = ($issue.body ?? "") -replace '(?s)<!--.*?-->', '' -replace '\r?\n', ' '
                    url     = $issue.html_url
                    date    = $issue.closed_at
                    labels  = ($issue.labels | ForEach-Object { $_.name }) -join ", "
                })
            }
        } catch {
            Write-Warning "    Could not fetch issues from ${fullName}: $_"
        }
    }

    # ── Signal 3: CHANGELOG entries ───────────────────────────────────────
    Write-Host "  → CHANGELOG"
    try {
        $clRaw = gh api "repos/$fullName/contents/CHANGELOG.md" --jq '.content' 2>$null
        if ($LASTEXITCODE -eq 0 -and $clRaw) {
            $cl = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($clRaw -replace "`n", "")))
            # Extract H2 sections (## [version] - YYYY-MM-DD)
            $sections = [regex]::Matches($cl, '(?m)^## \[?[^\]]+\]?(?: - (\d{4}-\d{2}-\d{2}))?.*$')
            foreach ($match in $sections) {
                $entryDate = $match.Groups[1].Value
                if ($entryDate -and [datetime]$entryDate -gt [datetime]$repoSince) {
                    $allCandidates.Add(@{
                        source = $fullName
                        type   = "changelog"
                        signal = "CHANGELOG"
                        title  = $match.Value.Trim()
                        body   = ""
                        url    = "https://github.com/$fullName/blob/main/CHANGELOG.md"
                        date   = $entryDate
                        labels = ""
                    })
                }
            }
        }
    } catch {
        Write-Verbose "    No CHANGELOG in ${fullName}"
    }

    Write-Host "  ✓ $($allCandidates.Count) candidates so far"
}

if ($allCandidates.Count -eq 0) {
    Write-Host "`n✅ Sweep complete — no new learning candidates found (last $DaysBack days)."
    exit 0
}

# ── Format output ─────────────────────────────────────────────────────────────

# Heuristic domain guesser — maps signal labels / titles to a domain hint
function Get-DomainHint([hashtable]$Candidate) {
    $text = "$($Candidate.title) $($Candidate.labels) $($Candidate.body)".ToLower()
    if ($text -match '\b(ci|workflow|action|pipeline|build|test|lint)\b') { return "ci" }
    if ($text -match '\b(git|commit|branch|merge|rebase|pr|pull.request)\b') { return "git" }
    if ($text -match '\b(security|secret|token|auth|permission|cve|dependabot)\b') { return "security" }
    if ($text -match '\b(skill|instruction|agent|prompt|authoring|guidanc)\b') { return "authoring" }
    if ($text -match '\b(deploy|infra|terraform|bicep|cloud|azure|aws)\b') { return "infra" }
    if ($text -match '\b(portal|dashboard|ui|frontend|ux)\b') { return "portal" }
    if ($text -match '\b(test|spec|coverage|mock|fixture)\b') { return "testing" }
    if ($text -match '\b(governance|policy|compliance|process|sprint|retro)\b') { return "process" }
    if ($text -match '\b(memory|learning|pattern|convention)\b') { return "memory" }
    return "process"  # safe default
}

$date          = Get-Date -Format "yyyy-MM-dd"
$timestamp     = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
$outputContent = @"
# Memory Sweep Candidates — $date

> Auto-generated by ``scripts/sweep-enterprise-memory.ps1``
> Org: **$Org** | Days back: **$DaysBack** | Repos swept: **$($repos.Count)**
> Candidates: **$($allCandidates.Count)**
>
> ## Steward Review Instructions
>
> Each candidate below has a pre-filled YAML promotion block.
> For each entry:
> 1. Confirm the four scope-check boxes (generic, durable, actionable, repo-scoped)
> 2. Fill in ``fact`` (≤ 300 chars) and ``subject`` (``domain:key``)
> 3. Copy the YAML block to ``memories/{domain}/{subject}.md`` in basecoat-memory
> 4. Delete this candidate entry once promoted (or if low-value)
>
> Unreviewed candidates that are not promoted should be deleted before merging.

---

"@

# Group by repo for readability; emit a structured promotion block per candidate
$byRepo = $allCandidates | Group-Object { $_["source"] }
$idx    = 0
foreach ($group in $byRepo) {
    $outputContent += "## $($group.Name)`n`n"
    foreach ($c in $group.Group) {
        $idx++
        $domainHint = Get-DomainHint $c
        $keyHint    = "$(($c.title -replace '[^a-zA-Z0-9\s]','') -replace '\s+','-' | ForEach-Object { $_.ToLower().Substring(0,[Math]::Min(30,$_.Length)) })"
        $snippet    = if ($c.body -and $c.body.Length -gt 0) {
            $c.body.Substring(0, [Math]::Min(200, $c.body.Length))
        } else { "" }

        $outputContent += @"
### [$($c.type.ToUpper())] $($c.title)

| | |
|---|---|
| **Signal** | $($c.signal) |
| **Date** | $($c.date) |
| **Source** | $($c.source) |
$(if ($c.labels) { "| **Labels** | $($c.labels) |`n" })| **URL** | $($c.url) |

$(if ($snippet) { "> $snippet`n`n" })**Promotion block** — copy to ``memories/$domainHint/$keyHint.md`` then fill in ``fact`` and ``subject``:

``````yaml
---
subject: "$domainHint:$keyHint"
domain: "$domainHint"
confidence: 0.70
created: "$date"
applies_to: "basecoat-enabled repos"
source: "$($c.source)"
swept: "$timestamp"
---
``````

## Pattern

<!-- fact (≤ 300 chars): -->

## Evidence

$($c.url)

## Does NOT apply to

<!-- conditions where this pattern breaks down -->

## Scope check

- [ ] Applies broadly (not just one internal project)
- [ ] Free of product names / org-specific tooling
- [ ] Durable across ≥ 3 sprints or ≥ 2 similar incidents
- [ ] Another team would change their behavior based on this

---

"@
    }
}

$outputContent += @"
*Generated by BaseCoat enterprise memory sweep.*
*Candidates are raw signals — they require human review before promotion to shared memory.*
*See [CONTRIBUTING.md](https://github.com/ivegamsft/basecoat/blob/main/docs/memory/CONTRIBUTING.md) for the full promotion process.*
"@

# ── Write or print ────────────────────────────────────────────────────────────

if ($DryRun) {
    Write-Host "`n--- DRY RUN OUTPUT ---"
    Write-Host $outputContent
} else {
    $null = New-Item -ItemType Directory -Force -Path $OutputDir
    $outFile = Join-Path $OutputDir "$date.md"
    $outputContent | Set-Content -Path $outFile -Encoding UTF8 -NoNewline
    # Ensure trailing newline
    Add-Content -Path $outFile -Value "" -NoNewline:$false
    Write-Host "`n✅ Wrote $($allCandidates.Count) candidates to: $outFile"
    Write-Host "   Next step: open a PR with this file for memory-curator review"
}
