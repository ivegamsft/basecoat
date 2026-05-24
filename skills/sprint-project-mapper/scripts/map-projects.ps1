#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [string] $Repo = "",
    [int]    $Limit = 300,
    [double] $MergeThreshold = 0.65,
    [switch] $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $Repo) {
    $Repo = gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>$null
    if (-not $Repo) { throw "Could not resolve repo. Pass -Repo owner/repo." }
}

function Get-CanonicalTags {
    param([string[]]$Labels)
    $tags = @()
    foreach ($l in $Labels) {
        $x = $l.ToLower().Trim()
        if ($x -match '^sprint[:/\-]?(\d+)$') { $tags += "sprint:$($matches[1])"; continue }
        if ($x -match '^wave[:/\-]?(\d+)$')   { $tags += "wave:$($matches[1])"; continue }
        if ($x -match '^(project|proj|epic|initiative)[:/\-](.+)$') { $tags += "project:$($matches[2])"; continue }
        if ($x -match '^area\/.+$') { $tags += $x; continue }
        if ($x -match '^(priority|type)\/.+$') { $tags += $x; continue }
    }
    return @($tags | Sort-Object -Unique)
}

function Jaccard {
    param([string[]]$A,[string[]]$B)
    $a = @($A | Sort-Object -Unique)
    $b = @($B | Sort-Object -Unique)
    if ($a.Count -eq 0 -and $b.Count -eq 0) { return 0.0 }
    $i = (@($a | Where-Object { $b -contains $_ })).Count
    $u = (@($a + $b | Sort-Object -Unique)).Count
    if ($u -eq 0) { return 0.0 }
    return [math]::Round($i / $u, 2)
}

Write-Host "Collecting issues and PRs from $Repo..."
$issues = gh issue list --repo $Repo --state all --limit $Limit --json number,title,labels,state,createdAt,closedAt 2>$null | ConvertFrom-Json
$prs    = gh pr list --repo $Repo --state all --limit $Limit --json number,title,labels,state,createdAt,mergedAt,author,additions,deletions 2>$null | ConvertFrom-Json

# Build simple project keys from normalized tags
$groups = @{}
foreach ($i in $issues) {
    $labels = @($i.labels | ForEach-Object { $_.name })
    $tags = Get-CanonicalTags -Labels $labels

    $projectTag = @($tags | Where-Object { $_ -like 'project:*' } | Select-Object -First 1)
    $sprintTag  = @($tags | Where-Object { $_ -like 'sprint:*' } | Select-Object -First 1)
    $waveTag    = @($tags | Where-Object { $_ -like 'wave:*' } | Select-Object -First 1)
    $areaTag    = @($tags | Where-Object { $_ -like 'area/*' } | Select-Object -First 1)

    $keyParts = @()
    if ($projectTag) { $keyParts += $projectTag }
    if ($sprintTag)  { $keyParts += $sprintTag }
    if ($waveTag)    { $keyParts += $waveTag }
    if ($areaTag)    { $keyParts += $areaTag }
    if ($keyParts.Count -eq 0) { $keyParts += "unmapped" }
    $key = ($keyParts -join "|")

    if (-not $groups.ContainsKey($key)) {
        $groups[$key] = [ordered]@{
            Key = $key
            Issues = @()
            PRs = @()
            Tags = @()
        }
    }
    $groups[$key].Issues += $i
    $groups[$key].Tags += $tags
}

# Attach PRs by first matching sprint/project/area tags
foreach ($p in $prs) {
    $labels = @($p.labels | ForEach-Object { $_.name })
    $ptags = Get-CanonicalTags -Labels $labels
    $bestKey = $null
    $bestScore = -1
    foreach ($k in $groups.Keys) {
        $score = Jaccard -A $ptags -B $groups[$k].Tags
        if ($score -gt $bestScore) { $bestScore = $score; $bestKey = $k }
    }
    if (-not $bestKey) { $bestKey = "unmapped" }
    if (-not $groups.ContainsKey($bestKey)) {
        $groups[$bestKey] = [ordered]@{ Key=$bestKey; Issues=@(); PRs=@(); Tags=@() }
    }
    $groups[$bestKey].PRs += $p
    $groups[$bestKey].Tags += $ptags
}

# Evaluate significance and metrics
$report = @()
foreach ($g in $groups.Values) {
    $issueCount = $g.Issues.Count
    $closedCount = @($g.Issues | Where-Object { $_.state -eq 'CLOSED' }).Count
    $prCount = $g.PRs.Count
    $mergedPRs = @($g.PRs | Where-Object { $_.mergedAt }).Count
    $loc = 0
    foreach ($p in $g.PRs) { $loc += [int]($p.additions + $p.deletions) }

    $times = @()
    foreach ($i in $g.Issues) {
        if ($i.closedAt -and $i.createdAt) {
            $times += (([datetime]$i.closedAt - [datetime]$i.createdAt).TotalDays)
        }
    }
    $median = if ($times.Count -gt 0) { ($times | Sort-Object)[[int]([math]::Floor($times.Count/2))] } else { 0 }
    $closure = if ($issueCount -gt 0) { [math]::Round($closedCount / $issueCount, 2) } else { 0.0 }

    $hasExplicit = $g.Key -match 'sprint:|wave:|project:'
    $significant = (($issueCount -ge 5 -or $mergedPRs -ge 3) -and ($loc -ge 200 -or $hasExplicit))

    $report += [PSCustomObject]@{
        Group = $g.Key
        Issues = $issueCount
        Closed = $closedCount
        PRs = $prCount
        MergedPRs = $mergedPRs
        LOC = $loc
        MedianCycleDays = [math]::Round($median, 1)
        ClosureRatio = $closure
        Significant = $significant
    }
}

Write-Host ""
Write-Host "=== Sprint/Project Mapping Report: $Repo ==="
$report | Sort-Object -Property Significant,Issues -Descending | Format-Table -AutoSize

Write-Host ""
Write-Host "=== Debate (Split vs Merge) Suggestions ==="
$keys = @($groups.Keys)
for ($i = 0; $i -lt $keys.Count; $i++) {
    for ($j = $i + 1; $j -lt $keys.Count; $j++) {
        $a = $keys[$i]; $b = $keys[$j]
        $sim = Jaccard -A $groups[$a].Tags -B $groups[$b].Tags
        if ($sim -ge 0.40) {
            $decision = if ($sim -ge $MergeThreshold) { "MERGE" } else { "SPLIT" }
            $confidence = [math]::Round($sim,2)
            Write-Host "$a <> $b  | Decision=$decision | Confidence=$confidence"
        }
    }
}

Write-Host ""
Write-Host "=== Release-note-ready groups ==="
$report | Where-Object { $_.Significant } | ForEach-Object {
    Write-Host "- **$($_.Group)**: $($_.Issues) issues, $($_.MergedPRs) merged PRs, $($_.LOC) LOC changed, median cycle $($_.MedianCycleDays)d."
}

if (-not $DryRun) {
    # No write actions by default; script is analysis/report only.
    Write-Host ""
    Write-Host "Note: mapper script is read-only by default (no issue or PR modifications)."
}

