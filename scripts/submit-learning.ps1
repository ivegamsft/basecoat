#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Active learning submission — push a structured learning candidate directly to basecoat-memory.

.DESCRIPTION
    Consumer repos call this script to submit a learning without waiting for the weekly sweep.
    The script validates the candidate against the scope policy, writes a structured YAML+Markdown
    file to basecoat-memory/sweep-candidates/, and optionally opens a PR for steward review.

.PARAMETER Subject
    domain:key namespace for this learning. E.g., "ci:agent-pr-approval".
    Valid domains: ci, git, authoring, process, security, portal, testing, governance, memory, infra.

.PARAMETER Fact
    One-sentence pattern (300 chars max). Generic — no product names, internal system names,
    or org-specific tooling.

.PARAMETER Evidence
    URL to the PR, issue, CHANGELOG, or discussion that evidences this pattern.

.PARAMETER Domain
    Domain key. Must match the domain in -Subject. One of:
    ci, git, authoring, process, security, portal, testing, governance, memory, infra.

.PARAMETER Source
    org/repo of the contributing repository (e.g., "myorg/myrepo").

.PARAMETER Team
    Optional. Team name for steward context (e.g., "Platform Engineering").

.PARAMETER Contact
    Optional. GitHub handle for follow-up (e.g., "@alice").

.PARAMETER MemoryRepo
    Target memory repository. Provide explicitly or set env BASECOAT_SHARED_MEMORY_REPO.

.PARAMETER DryRun
    Print the candidate file without writing or pushing.

.PARAMETER OpenPR
    After pushing, open a PR in basecoat-memory for steward review.

.EXAMPLE
    pwsh scripts/submit-learning.ps1 `
        -Subject  "ci:agent-pr-approval" `
        -Fact     "Copilot agent PRs have action_required CI until a maintainer pushes an empty commit." `
        -Evidence "https://github.com/myorg/myrepo/pull/42" `
        -Domain   "ci" `
        -Source   "myorg/myrepo" `
        -OpenPR
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Subject,
    [Parameter(Mandatory)][string]$Fact,
    [Parameter(Mandatory)][string]$Evidence,
    [Parameter(Mandatory)][ValidateSet("ci","git","authoring","process","security","portal","testing","governance","memory","infra")]
    [string]$Domain,
    [Parameter(Mandatory)][string]$Source,
    [string]$Team    = "",
    [string]$Contact = "",
    [string]$MemoryRepo = $env:BASECOAT_SHARED_MEMORY_REPO,
    [switch]$DryRun,
    [switch]$OpenPR
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Validation ────────────────────────────────────────────────────────────────

$errors = [System.Collections.Generic.List[string]]::new()
if ([string]::IsNullOrWhiteSpace($MemoryRepo)) { $errors.Add("MemoryRepo or BASECOAT_SHARED_MEMORY_REPO is required.") }

# Subject format: domain:key
if ($Subject -notmatch '^[a-z]+:[a-z][a-z0-9-]+$') {
    $errors.Add("Subject '$Subject' must match domain:key format (e.g., 'ci:agent-pr-approval'). Lowercase letters, digits, hyphens only.")
}

# Subject domain prefix must match -Domain
$subjectDomain = ($Subject -split ':')[0]
if ($subjectDomain -ne $Domain) {
    $errors.Add("Subject domain '$subjectDomain' does not match -Domain '$Domain'.")
}

# Fact length
if ($Fact.Length -gt 300) {
    $errors.Add("Fact is $($Fact.Length) chars; must be ≤ 300.")
}

# Generic scope check — flag known project-specific technology markers
$projectSpecificMarkers = @(
    '\bTypeORM\b','\bJest\b','\bWinston\b','\bSupertest\b','\bJWT\b',
    '\bExpress\b','\bPostgres\b','\bMySQL\b','\bMongoDB\b',
    '\bNextAuth\b','\bPrisma\b','\bSequelize\b'
)
foreach ($marker in $projectSpecificMarkers) {
    if ($Fact -match $marker) {
        $errors.Add("Fact contains '$($Matches[0])' — possible project-specific technology. Generalize or remove.")
    }
}

# Evidence must look like a URL
if ($Evidence -notmatch '^https?://') {
    $errors.Add("Evidence '$Evidence' must be a URL starting with http:// or https://.")
}

if ($errors.Count -gt 0) {
    Write-Error "Validation failed:`n$($errors | ForEach-Object { "  • $_" } | Out-String)"
    exit 1
}

Write-Host "✅ Validation passed"

# ── Build candidate file ──────────────────────────────────────────────────────

$date      = (Get-Date -Format "yyyy-MM-dd")
$timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
$keyPart   = ($Subject -split ':')[1]
$fileName  = "submitted-${date}-${keyPart}.md"

$teamLine    = if ($Team)    { "`nteam: `"$Team`""    } else { "" }
$contactLine = if ($Contact) { "`ncontact: `"$Contact`"" } else { "" }

$content = @"
---
subject: "$Subject"
domain: "$Domain"
source: "$Source"
submitted: "$timestamp"
type: "active-submission"$teamLine$contactLine
---

## Fact

$Fact

## Evidence

$Evidence

## Does NOT apply to

<!-- Fill in before promoting: specific conditions where this pattern breaks down -->

## Scope check

- [ ] Applies broadly to this type of repo (not just one internal project)
- [ ] Free of product names, internal system names, org-specific tooling
- [ ] Has held true across ≥ 3 sprints or ≥ 2 similar incidents
- [ ] Another team would change their behavior based on this
"@

if ($DryRun) {
    Write-Host "`n── Dry run — candidate file ──────────────────────────────────────────────────"
    Write-Host $content
    Write-Host "─────────────────────────────────────────────────────────────────────────────"
    Write-Host "`nWould write to: $MemoryRepo/sweep-candidates/$fileName"
    exit 0
}

# ── Push to basecoat-memory ───────────────────────────────────────────────────

$token = $env:MEMORY_REPO_TOKEN
if (-not $token) {
    Write-Error "MEMORY_REPO_TOKEN environment variable is not set.`nSet a fine-grained PAT with Contents (R/W) and Pull Requests (R/W) on $MemoryRepo."
    exit 1
}

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "basecoat-submit-$([guid]::NewGuid().ToString('N').Substring(0,8))"
New-Item -ItemType Directory -Path $tmpDir | Out-Null

try {
    Write-Host "📥 Cloning $MemoryRepo..."
    $env:GH_TOKEN = $token
    git clone "https://x-access-token:${token}@github.com/${MemoryRepo}.git" $tmpDir --depth 1 --quiet

    $branch = "memory-submit/${date}-${keyPart}"
    Push-Location $tmpDir

    git config user.name  "github-actions[bot]"
    git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
    git checkout -b $branch

    $candidatesDir = Join-Path $tmpDir "sweep-candidates"
    if (-not (Test-Path $candidatesDir)) { New-Item -ItemType Directory -Path $candidatesDir | Out-Null }

    $outPath = Join-Path $candidatesDir $fileName
    Set-Content -Path $outPath -Value $content -Encoding utf8
    Write-Host "📝 Wrote $fileName"

    git add "sweep-candidates/$fileName"
    git commit -m "chore(memory): active submission — $Subject from $Source

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
    git push origin $branch
    Write-Host "📤 Pushed branch $branch to $MemoryRepo"

    if ($OpenPR) {
        $prUrl = gh pr create `
            --repo $MemoryRepo `
            --title "memory(submit): $Subject from $Source" `
            --base main `
            --head $branch `
            --label "memory-submission" `
            --body "## Active Memory Submission

Submitted by **$Source** via \`submit-learning.ps1\`.

| | |
|---|---|
| **Subject** | \`$Subject\` |
| **Domain** | \`$Domain\` |
| **Source** | \`$Source\` |
| **Submitted** | $timestamp |$(if ($Team) { "`n| **Team** | $Team |" })$(if ($Contact) { "`n| **Contact** | $Contact |" })

## Steward Review Checklist

- [ ] Generalize the fact if needed (remove org/project references)
- [ ] Complete the 'Does NOT apply to' section
- [ ] Confirm all four scope-check boxes are met
- [ ] Move to \`memories/$Domain/\` as a structured memory file
- [ ] Delete the candidate entry from \`sweep-candidates/\`

---
*Submitted by $Source — see [CONTRIBUTING.md](https://github.com/ivegamsft/basecoat/blob/main/docs/memory/CONTRIBUTING.md)*" 2>&1

        Write-Host "🔗 PR opened: $prUrl"
    } else {
        Write-Host "ℹ️  Branch pushed. The weekly sweep will include this candidate on its next run."
        Write-Host "   To open a PR immediately, re-run with -OpenPR."
    }

} finally {
    Pop-Location
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
}

Write-Host "`n✅ Learning submitted: $Subject"
