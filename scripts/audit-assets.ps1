#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quality audit for BaseCoat guidance assets — agents, skills, and instructions.

.DESCRIPTION
    Scores every agent (max 10), skill (max 10), and instruction (max 10) against
    a quality rubric covering description clarity, content depth, example presence,
    convention compliance, and recency. Produces a per-asset score table and an
    overall library health grade (A–F).

.PARAMETER Path
    Root of the BaseCoat repository. Defaults to the current directory.

.PARAMETER Weak
    Only show assets scoring below the threshold (default 6.0).

.PARAMETER Threshold
    Score below which an asset is considered weak. Default: 6.0.

.PARAMETER Format
    Output format: 'table' (default), 'json', or 'markdown'.

.PARAMETER Category
    Filter to a specific category: 'agents', 'skills', 'instructions', or 'all' (default).

.PARAMETER SortBy
    Sort output by: 'score' (default, ascending), 'name', or 'category'.

.EXAMPLE
    pwsh scripts/audit-assets.ps1
    pwsh scripts/audit-assets.ps1 -Weak
    pwsh scripts/audit-assets.ps1 -Format json -Category agents
    pwsh scripts/audit-assets.ps1 -Weak -Threshold 7.0 -Format markdown
#>
[CmdletBinding()]
param(
    [string]$Path = (Get-Location).Path,
    [switch]$Weak,
    [double]$Threshold = 6.0,
    [ValidateSet("table", "json", "markdown")]
    [string]$Format = "table",
    [ValidateSet("agents", "skills", "instructions", "all")]
    [string]$Category = "all",
    [ValidateSet("score", "name", "category")]
    [string]$SortBy = "score"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Set-Location $Path

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Get-Frontmatter {
    param([string]$FilePath)
    $content = Get-Content $FilePath -Raw
    if ($content -match '(?s)^---\r?\n(.+?)\r?\n---') { return $matches[1] }
    return ""
}

function Get-BodyContent {
    param([string]$FilePath)
    $content = Get-Content $FilePath -Raw
    if ($content -match '(?s)^---\r?\n.+?\r?\n---\r?\n(.*)$') { return $matches[1] }
    return $content
}

function Get-YamlValue {
    param([string]$Frontmatter, [string]$Key)
    if ($Frontmatter -match "(?m)^${Key}\s*:\s*[`"']?([^`"'\r\n]+)[`"']?") {
        return $matches[1].Trim()
    }
    return ""
}

function Get-GitAge {
    param([string]$FilePath)
    $date = git log -1 --format="%ci" -- $FilePath 2>$null
    if (-not $date) { return 999 }
    try {
        $fileDate = [datetime]::Parse($date)
        return ([datetime]::UtcNow - $fileDate).Days
    } catch { return 999 }
}

function Count-Words {
    param([string]$Text)
    return ($Text -split '\s+' | Where-Object { $_ }).Count
}

function Get-GradeFromScore {
    param([double]$Score, [double]$Max = 10.0)
    $pct = $Score / $Max
    if ($pct -ge 0.9) { return "A" }
    if ($pct -ge 0.8) { return "B" }
    if ($pct -ge 0.7) { return "C" }
    if ($pct -ge 0.6) { return "D" }
    return "F"
}

function Get-Emoji {
    param([string]$Grade)
    switch ($Grade) {
        "A" { return "green" }
        "B" { return "green" }
        "C" { return "yellow" }
        "D" { return "yellow" }
        "F" { return "red" }
    }
    return "grey"
}

# ---------------------------------------------------------------------------
# Scoring: Agents (max 10)
# Rubric:
#   1.0 — description present and ≤ 160 chars
#   1.0 — description starts with "Use when"
#   0.5 — has ## Inputs section
#   0.5 — has ## Workflow or ## Process section
#   0.5 — has an output section (## Output / ## Results / ## Report)
#   1.5 — workflow has ≥ 3 numbered or bulleted steps
#   1.5 — has at least one fenced code block (``` ... ```)
#   0.5 — has handoffs: defined
#   1.0 — model field is a recognized current model
#   1.0 — last modified ≤ 180 days ago
#   0.5 — allowed_skills is present (even if empty [])
# ---------------------------------------------------------------------------

$validModels = @(
    "claude-sonnet-4.6", "claude-sonnet-4.5", "claude-haiku-4.5",
    "claude-opus-4.7", "claude-opus-4.6", "claude-opus-4.5",
    "gpt-4.1", "gpt-5-mini", "gpt-5.2", "gpt-5.4", "gpt-5.4-mini",
    "claude-sonnet-4", "o3", "o4-mini"
)

function Score-Agent {
    param([System.IO.FileInfo]$File)

    $frontmatter = Get-Frontmatter $File.FullName
    $body        = Get-BodyContent $File.FullName
    $score       = 0.0
    $notes       = @()

    # Description quality (2 pts)
    $desc = Get-YamlValue $frontmatter "description"
    if ($desc.Length -gt 0 -and $desc.Length -le 160) {
        $score += 1.0
    } elseif ($desc.Length -gt 160) {
        $notes += "description > 160 chars ($($desc.Length))"
        $score += 0.5
    } else {
        $notes += "missing description"
    }

    if ($desc -imatch '^use when') {
        $score += 1.0
    } else {
        $notes += "description should start with 'Use when'"
    }

    # Required sections (1.5 pts)
    if ($body -imatch '##\s+inputs\b') { $score += 0.5 } else { $notes += "missing ## Inputs" }
    if ($body -imatch '##\s+(workflow|process)\b') { $score += 0.5 } else { $notes += "missing ## Workflow/Process" }
    if ($body -imatch '##.*(output|results|report)') { $score += 0.5 } else { $notes += "missing output section" }

    # Workflow depth (1.5 pts)
    $stepMatches = [regex]::Matches($body, '(?m)^(\d+\.|[-*])\s+\*\*|\n\s*\d+\.\s+|\n\s*[-*]\s+\*\*')
    if ($stepMatches.Count -ge 5) { $score += 1.5 }
    elseif ($stepMatches.Count -ge 3) { $score += 1.0 }
    elseif ($stepMatches.Count -ge 1) { $score += 0.5 }
    else { $notes += "workflow has < 3 steps" }

    # Examples (1.5 pts)
    $codeBlocks = [regex]::Matches($body, '```')
    $blockCount = [math]::Floor($codeBlocks.Count / 2)
    if ($blockCount -ge 2) { $score += 1.5 }
    elseif ($blockCount -eq 1) { $score += 0.75; $notes += "only 1 code example" }
    else { $notes += "no code examples" }

    # Handoffs (0.5 pts)
    if ($frontmatter -imatch 'handoffs\s*:') { $score += 0.5 } else { $notes += "no handoffs defined" }

    # Model validity (1.0 pt)
    $model = Get-YamlValue $frontmatter "model"
    if ($model -and $model -in $validModels) {
        $score += 1.0
    } elseif ($model) {
        $notes += "model '$model' not in current supported list"
        $score += 0.3
    } else {
        $notes += "missing model field"
    }

    # Recency (1.0 pt)
    $ageDays = Get-GitAge $File.FullName
    if ($ageDays -le 90)  { $score += 1.0 }
    elseif ($ageDays -le 180) { $score += 0.7 }
    elseif ($ageDays -le 365) { $score += 0.3; $notes += "last modified $ageDays days ago" }
    else { $notes += "stale: last modified $ageDays days ago" }

    # allowed_skills present (0.5 pt)
    if ($frontmatter -imatch 'allowed_skills\s*:') { $score += 0.5 } else { $notes += "missing allowed_skills" }

    return [pscustomobject]@{
        Name     = ($File.BaseName -replace '^basecoat-\d+-\w+-', '')
        Category = "agent"
        Score    = [math]::Round([math]::Min($score, 10.0), 1)
        Max      = 10.0
        Notes    = ($notes -join "; ")
        Path     = $File.FullName
    }
}

# ---------------------------------------------------------------------------
# Scoring: Skills (max 10)
# Rubric:
#   1.0 — name frontmatter present
#   1.0 — description present and ≤ 160 chars
#   1.0 — description starts with "Use when"
#   2.0 — body word count ≥ 200 words (1.0 if ≥ 100)
#   2.0 — has a triggers / when-to-use section or bullet list
#   1.5 — has at least one fenced code block
#   1.0 — has inputs and outputs described
#   0.5 — last modified ≤ 180 days
# ---------------------------------------------------------------------------

function Score-Skill {
    param([System.IO.FileInfo]$File)

    $frontmatter = Get-Frontmatter $File.FullName
    $body        = Get-BodyContent $File.FullName
    $score       = 0.0
    $notes       = @()
    $dirName     = $File.Directory.Name

    # name field (1.0 pt)
    $name = Get-YamlValue $frontmatter "name"
    if ($name) { $score += 1.0 } else { $notes += "missing name" }

    # description quality (2.0 pts)
    $desc = Get-YamlValue $frontmatter "description"
    if ($desc.Length -gt 0 -and $desc.Length -le 160) {
        $score += 1.0
    } elseif ($desc.Length -gt 160) {
        $score += 0.5; $notes += "description > 160 chars ($($desc.Length))"
    } else {
        $notes += "missing description"
    }
    if ($desc -imatch '^use when') { $score += 1.0 } else { $notes += "description should start with 'Use when'" }

    # Body depth (2.0 pts)
    $wordCount = Count-Words $body
    if ($wordCount -ge 200)    { $score += 2.0 }
    elseif ($wordCount -ge 100) { $score += 1.0; $notes += "body only $wordCount words (target ≥ 200)" }
    else { $notes += "thin content: $wordCount words" }

    # Trigger section or bullet list (2.0 pts)
    $hasTriggers = $body -imatch '##\s*(when|trigger|use|overview)' -or
                   $body -imatch '(?m)^\s*[-*]\s+'
    if ($hasTriggers) { $score += 2.0 } else { $notes += "no trigger list or When-to-Use section" }

    # Code examples (1.5 pts)
    $blockCount = [math]::Floor(([regex]::Matches($body, '```')).Count / 2)
    if ($blockCount -ge 1) { $score += 1.5 } else { $notes += "no code examples" }

    # Inputs/outputs described (1.0 pt)
    $hasIO = $body -imatch '(input|output|param|argument|returns|produces)'
    if ($hasIO) { $score += 1.0 } else { $notes += "inputs/outputs not described" }

    # Recency (0.5 pt)
    $ageDays = Get-GitAge $File.FullName
    if ($ageDays -le 180) { $score += 0.5 } else { $notes += "stale: $ageDays days since last update" }

    return [pscustomobject]@{
        Name     = $dirName
        Category = "skill"
        Score    = [math]::Round([math]::Min($score, 10.0), 1)
        Max      = 10.0
        Notes    = ($notes -join "; ")
        Path     = $File.FullName
    }
}

# ---------------------------------------------------------------------------
# Scoring: Instructions (max 10)
# Rubric:
#   1.0 — description present
#   1.0 — applyTo present and not wildcard "**/*"
#   0.5 — applyTo is specific (not just **/*)
#   2.0 — body word count ≥ 300 words (1.0 if ≥ 150)
#   1.5 — has ≥ 2 ## sections
#   1.5 — has at least one fenced code block
#   1.0 — has do/don't guidance or explicit rules
#   1.0 — last modified ≤ 180 days
#   0.5 — has concrete examples (either code or bullet examples)
# ---------------------------------------------------------------------------

function Score-Instruction {
    param([System.IO.FileInfo]$File)

    $frontmatter = Get-Frontmatter $File.FullName
    $body        = Get-BodyContent $File.FullName
    $score       = 0.0
    $notes       = @()

    # description (1.0 pt)
    $desc = Get-YamlValue $frontmatter "description"
    if ($desc) { $score += 1.0 } else { $notes += "missing description" }

    # applyTo (1.5 pts)
    $applyTo = Get-YamlValue $frontmatter "applyTo"
    if ($applyTo) {
        $score += 1.0
        if ($applyTo -ne '**/*' -and $applyTo -ne '"**/*"') {
            $score += 0.5
        } else {
            $notes += "applyTo is overly broad ('**/*')"
        }
    } else {
        $notes += "missing applyTo"
    }

    # Body depth (2.0 pts)
    $wordCount = Count-Words $body
    if ($wordCount -ge 300)    { $score += 2.0 }
    elseif ($wordCount -ge 150) { $score += 1.0; $notes += "body only $wordCount words (target ≥ 300)" }
    else { $notes += "thin content: $wordCount words" }

    # Section count (1.5 pts)
    $sectionCount = ([regex]::Matches($body, '(?m)^##\s+')).Count
    if ($sectionCount -ge 3) { $score += 1.5 }
    elseif ($sectionCount -ge 2) { $score += 1.0 }
    elseif ($sectionCount -ge 1) { $score += 0.5 }
    else { $notes += "no ## sections" }

    # Code examples (1.5 pts)
    $blockCount = [math]::Floor(([regex]::Matches($body, '```')).Count / 2)
    if ($blockCount -ge 2) { $score += 1.5 }
    elseif ($blockCount -eq 1) { $score += 0.75; $notes += "only 1 code example" }
    else { $notes += "no code examples" }

    # Do/don't or explicit rules (1.0 pt)
    $hasRules = $body -imatch "(don'?t|do not|must|never|always|avoid|prefer|instead)" -or
                $body -imatch '(?m)^\s*[-*]\s+(do|don|must|never|always|avoid)'
    if ($hasRules) { $score += 1.0 } else { $notes += "no explicit do/don't rules" }

    # Recency (1.0 pt)
    $ageDays = Get-GitAge $File.FullName
    if ($ageDays -le 90)  { $score += 1.0 }
    elseif ($ageDays -le 180) { $score += 0.7 }
    elseif ($ageDays -le 365) { $score += 0.3; $notes += "last modified $ageDays days ago" }
    else { $notes += "stale: last modified $ageDays days ago" }

    return [pscustomobject]@{
        Name     = $File.Name -replace '\.instructions\.md$'
        Category = "instruction"
        Score    = [math]::Round([math]::Min($score, 10.0), 1)
        Max      = 10.0
        Notes    = ($notes -join "; ")
        Path     = $File.FullName
    }
}

# ---------------------------------------------------------------------------
# Collect and score all assets
# ---------------------------------------------------------------------------

$results = @()

if ($Category -in @("agents", "all")) {
    Write-Verbose "Scoring agents..."
    if ($Format -ne "json") { Write-Host "Scoring agents..." -ForegroundColor Cyan }
    Get-ChildItem agents -Filter "*.agent.md" -File | ForEach-Object {
        $results += Score-Agent $_
    }
}

if ($Category -in @("skills", "all")) {
    Write-Verbose "Scoring skills..."
    if ($Format -ne "json") { Write-Host "Scoring skills..." -ForegroundColor Cyan }
    Get-ChildItem skills -Directory | ForEach-Object {
        $skillMd = Join-Path $_.FullName "SKILL.md"
        if (Test-Path $skillMd) {
            $results += Score-Skill (Get-Item $skillMd)
        }
    }
}

if ($Category -in @("instructions", "all")) {
    Write-Verbose "Scoring instructions..."
    if ($Format -ne "json") { Write-Host "Scoring instructions..." -ForegroundColor Cyan }
    Get-ChildItem instructions -Filter "*.instructions.md" -File | ForEach-Object {
        $results += Score-Instruction $_
    }
}

# ---------------------------------------------------------------------------
# Filter and sort
# ---------------------------------------------------------------------------

if ($Weak) {
    $results = $results | Where-Object { $_.Score -lt $Threshold }
}

$results = switch ($SortBy) {
    "name"     { $results | Sort-Object Name }
    "category" { $results | Sort-Object Category, Score }
    default    { $results | Sort-Object Score }
}

# ---------------------------------------------------------------------------
# Summary statistics
# ---------------------------------------------------------------------------

$allScores   = @($results | Select-Object -ExpandProperty Score)
$totalAssets = $allScores.Count
$avgScore    = if ($totalAssets -gt 0) { [math]::Round(($allScores | Measure-Object -Average).Average, 1) } else { 0 }
$redCount    = @($results | Where-Object { $_.Score -lt 6.0 }).Count
$yellowCount = @($results | Where-Object { $_.Score -ge 6.0 -and $_.Score -lt 8.0 }).Count
$greenCount  = @($results | Where-Object { $_.Score -ge 8.0 }).Count
$overallGrade = Get-GradeFromScore $avgScore

# Per-category stats (use all results, not filtered)
$allResults = @()
if ($Category -in @("agents", "all")) {
    $agentScores = @($results | Where-Object { $_.Category -eq "agent" } | Select-Object -ExpandProperty Score)
    $agentAvg = if ($agentScores.Count -gt 0) { [math]::Round(($agentScores | Measure-Object -Average).Average, 1) } else { 0 }
}
if ($Category -in @("skills", "all")) {
    $skillScores = @($results | Where-Object { $_.Category -eq "skill" } | Select-Object -ExpandProperty Score)
    $skillAvg = if ($skillScores.Count -gt 0) { [math]::Round(($skillScores | Measure-Object -Average).Average, 1) } else { 0 }
}
if ($Category -in @("instructions", "all")) {
    $instrScores = @($results | Where-Object { $_.Category -eq "instruction" } | Select-Object -ExpandProperty Score)
    $instrAvg = if ($instrScores.Count -gt 0) { [math]::Round(($instrScores | Measure-Object -Average).Average, 1) } else { 0 }
}

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

switch ($Format) {
    "json" {
        @{
            timestamp    = [datetime]::UtcNow.ToString("o")
            overallGrade = $overallGrade
            avgScore     = $avgScore
            totalAssets  = $totalAssets
            red          = $redCount
            yellow       = $yellowCount
            green        = $greenCount
            assets       = $results
        } | ConvertTo-Json -Depth 5
    }

    "markdown" {
        $lines = @()
        $lines += "## BaseCoat Asset Health Report"
        $lines += ""
        $lines += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm UTC')"
        $lines += ""
        $lines += "### Summary"
        $lines += ""
        $lines += "| Metric | Value |"
        $lines += "|---|---|"
        $lines += "| Overall grade | **$overallGrade** ($avgScore / 10.0 avg) |"
        $lines += "| Total assets audited | $totalAssets |"
        $lines += "| 🔴 Red (< 6.0) | $redCount |"
        $lines += "| 🟡 Yellow (6.0–7.9) | $yellowCount |"
        $lines += "| 🟢 Green (≥ 8.0) | $greenCount |"
        if ($agentAvg) { $lines += "| Agents avg | $agentAvg / 10 |" }
        if ($skillAvg)  { $lines += "| Skills avg | $skillAvg / 10 |" }
        if ($instrAvg)  { $lines += "| Instructions avg | $instrAvg / 10 |" }
        $lines += ""
        $lines += "### Assets$(if ($Weak) { " (weak only, score < $Threshold)" })"
        $lines += ""
        $lines += "| Category | Name | Score | Notes |"
        $lines += "|---|---|---|---|"
        foreach ($r in $results) {
            $indicator = if ($r.Score -ge 8.0) { "🟢" } elseif ($r.Score -ge 6.0) { "🟡" } else { "🔴" }
            $notes = if ($r.Notes) { $r.Notes } else { "—" }
            $lines += "| $($r.Category) | $($r.Name) | $indicator $($r.Score) | $notes |"
        }
        $lines -join "`n"
    }

    default {
        # Table output
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "  BASECOAT ASSET HEALTH REPORT$(if ($Weak) { "  (weak assets only, score < $Threshold)" })" -ForegroundColor White
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host ""

        foreach ($r in $results) {
            $color  = if ($r.Score -ge 8.0) { "Green" } elseif ($r.Score -ge 6.0) { "Yellow" } else { "Red" }
            $indicator = if ($r.Score -ge 8.0) { "[GRN]" } elseif ($r.Score -ge 6.0) { "[YLW]" } else { "[RED]" }
            $scoreStr = "$($r.Score.ToString("F1"))/10"
            $nameStr  = "$($r.Category.PadRight(12)) $($r.Name)"
            Write-Host ("  {0} {1,-52} {2}" -f $indicator, $nameStr, $scoreStr) -ForegroundColor $color
            if ($r.Notes) {
                Write-Host ("              {0}" -f $r.Notes) -ForegroundColor DarkGray
            }
        }

        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

        $gradeColor = if ($overallGrade -in @("A","B")) { "Green" } elseif ($overallGrade -eq "C") { "Yellow" } else { "Red" }
        Write-Host ""
        Write-Host "  OVERALL GRADE: $overallGrade  (avg $avgScore / 10.0)" -ForegroundColor $gradeColor
        Write-Host ""
        Write-Host ("  Total: {0}   🔴 Red: {1}   🟡 Yellow: {2}   🟢 Green: {3}" -f $totalAssets, $redCount, $yellowCount, $greenCount)
        if ($null -ne $agentAvg)  { Write-Host "  Agents avg:       $agentAvg" }
        if ($null -ne $skillAvg)  { Write-Host "  Skills avg:       $skillAvg" }
        if ($null -ne $instrAvg)  { Write-Host "  Instructions avg: $instrAvg" }
        Write-Host ""
        Write-Host "  Run with -Weak to list only low-scoring assets." -ForegroundColor DarkGray
        Write-Host "  Run with -Format markdown to get a report for posting." -ForegroundColor DarkGray
        Write-Host ""
    }
}

# Exit 1 if any red assets found (useful in CI gate mode)
if ($env:CI -eq "true" -and $redCount -gt 0 -and $Format -ne "json") {
    Write-Warning "$redCount asset(s) scored below 6.0 — see above for details."
    # Do NOT exit 1 here; quality-gate-tests.ps1 enforces the threshold.
}
