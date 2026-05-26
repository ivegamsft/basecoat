#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Contract gate for issue-triage workflow alignment.

.DESCRIPTION
    Fails when .github/workflows/issue-triage.md drifts from the
    skills/issue-triage policy contract.
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$promptPath = Join-Path $repoRoot '.github/workflows/issue-triage.md'
$lockPath = Join-Path $repoRoot '.github/workflows/issue-triage.lock.yml'

if (-not (Test-Path $promptPath)) {
    throw "Missing workflow prompt file: $promptPath"
}

if (-not (Test-Path $lockPath)) {
    throw "Missing workflow lock file: $lockPath"
}

$prompt = Get-Content $promptPath -Raw
$failures = @()

function Require-Pattern {
    param(
        [string]$Name,
        [string]$Pattern
    )
    if ($prompt -notmatch $Pattern) {
        $script:failures += $Name
    }
}

Write-Host 'Running issue-triage workflow contract checks...'

# Source-of-truth references must be explicit.
Require-Pattern -Name 'source-of-truth references' -Pattern 'skills/issue-triage/references/quality-checklist\.md'
Require-Pattern -Name 'triage-workflow reference' -Pattern 'skills/issue-triage/references/triage-workflow\.md'

# Required type taxonomy from skill contract.
Require-Pattern -Name 'type label: bug' -Pattern '\bbug\b'
Require-Pattern -Name 'type label: enhancement' -Pattern '\benhancement\b'
Require-Pattern -Name 'type label: documentation' -Pattern '\bdocumentation\b'
Require-Pattern -Name 'type label: chore' -Pattern '\bchore\b'
Require-Pattern -Name 'type label: security' -Pattern '\bsecurity\b'
Require-Pattern -Name 'type label: question' -Pattern '\bquestion\b'

# Required priority taxonomy.
Require-Pattern -Name 'priority label: priority:critical' -Pattern 'priority:critical'
Require-Pattern -Name 'priority label: priority:high' -Pattern 'priority:high'
Require-Pattern -Name 'priority label: priority:medium' -Pattern 'priority:medium'
Require-Pattern -Name 'priority label: priority:low' -Pattern 'priority:low'

# Guardrail: prompt should not use legacy canonical priority labels.
if ($prompt -match '\bP[0-3]-(critical|high|medium|low)\b') {
    $script:failures += 'legacy priority labels present in prompt'
}

# Core behavioral invariants.
Require-Pattern -Name 'duplicate-type exclusivity' -Pattern 'duplicate/type exclusivity'
Require-Pattern -Name 'minimum-bar quality check' -Pattern 'minimum-bar quality check'

if ($failures.Count -gt 0) {
    Write-Host 'Issue-triage workflow contract FAILED.' -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - Missing invariant: $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'Issue-triage workflow contract passed.' -ForegroundColor Green
exit 0
