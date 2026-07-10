#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests for reviewer-autoassign.yml collaborator eligibility filtering (#1575).

.DESCRIPTION
    Validates that the auto-assign reviewers workflow correctly filters candidates
    against repository collaborators before calling the request-reviewers API,
    preventing "Reviews may only be requested from collaborators" failures.
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$workflowPath = '.github/workflows/reviewer-autoassign.yml'
$failures = @()

Write-Host 'Running reviewer-autoassign workflow tests (#1575)...'

if (-not (Test-Path $workflowPath)) {
    Write-Host "  FAIL: $workflowPath not found" -ForegroundColor Red
    exit 1
}

$content = Get-Content $workflowPath -Raw

# Test 1: Workflow calls checkCollaborator before requestReviewers
Write-Host '  Test 1: checkCollaborator guard is present...'
if ($content -notmatch 'checkCollaborator') {
    $failures += 'Missing checkCollaborator call — candidates are not validated against repo collaborators'
} else {
    Write-Host '    ✓ checkCollaborator present' -ForegroundColor Green
}

# Test 2: requestReviewers uses the filtered list (eligibleReviewers), not raw candidates
Write-Host '  Test 2: requestReviewers uses eligibleReviewers (not raw candidates)...'
if ($content -notmatch 'eligibleReviewers') {
    $failures += 'eligibleReviewers variable missing — fix may not filter out non-collaborators'
} else {
    # Ensure requestReviewers references eligibleReviewers
    if ($content -notmatch 'reviewers:\s*eligibleReviewers') {
        $failures += 'requestReviewers call does not reference eligibleReviewers'
    } else {
        Write-Host '    ✓ requestReviewers uses eligibleReviewers' -ForegroundColor Green
    }
}

# Test 3: 404 (non-collaborator) responses are handled with a warning, not a throw
Write-Host '  Test 3: Non-collaborator 404 responses are caught and warned (not thrown)...'
if ($content -notmatch "err\.status\s*===\s*404" -and $content -notmatch "err\.status\s*==\s*404") {
    $failures += 'No 404 status check found — non-collaborator errors may propagate as failures'
} else {
    if ($content -notmatch 'core\.warning') {
        $failures += 'Non-collaborator case emits no warning via core.warning'
    } else {
        Write-Host '    ✓ 404 non-collaborator case handled with core.warning' -ForegroundColor Green
    }
}

# Test 4: Graceful exit when all candidates are non-collaborators
Write-Host '  Test 4: Graceful no-op when all candidates are filtered out...'
if ($content -notmatch 'eligibleReviewers\.length\s*===\s*0') {
    $failures += 'No empty-eligibleReviewers guard — workflow may error when every candidate is non-collaborator'
} else {
    Write-Host '    ✓ Empty eligibleReviewers guard present' -ForegroundColor Green
}

# Test 5: Candidate pool is ≥ 2 to account for filtering (rawCandidates > final limit)
Write-Host '  Test 5: Candidate pool is larger than the 2-reviewer limit (allows for filtering losses)...'
if ($content -notmatch 'rawCandidates') {
    $failures += 'rawCandidates variable missing — pool sizing for filter headroom is absent'
} else {
    # Pool should be at least 5 (slice(0, 5) or similar) to allow filtering
    if ($content -notmatch '\.slice\(0,\s*[3-9]\d*\)') {
        $failures += 'rawCandidates pool appears too small (≤ 2); filtering could leave 0 reviewers even when valid ones exist further down the list'
    } else {
        Write-Host '    ✓ Candidate pool provides filtering headroom' -ForegroundColor Green
    }
}

# Test 6: Workflow has required structural properties (regression guard)
Write-Host '  Test 6: Structural guardrails (workflow_dispatch, concurrency, timeout, SHA pin)...'

if ($content -notmatch '(?m)^\s{2}workflow_dispatch:\s*$') {
    $failures += "$workflowPath missing workflow_dispatch trigger"
}
if ($content -notmatch '(?m)^\s{2}group:\s*\$\{\{\s*github\.workflow') {
    $failures += "$workflowPath missing workflow-based concurrency group"
}
if ($content -notmatch 'timeout-minutes:') {
    $failures += "$workflowPath missing timeout-minutes"
}

$lines = $content -split "`n"
foreach ($line in $lines) {
    if ($line -match 'uses:\s*([^@\s]+)@(.+)') {
        $action = $matches[1]
        $ref = $matches[2].Trim()
        if ($action -notmatch '^\./' -and $action -notmatch 'docker://') {
            if ($ref -notmatch '^[a-f0-9]{40}$') {
                $failures += "$workflowPath uses non-SHA action reference: $action@$ref"
            }
        }
    }
}

if ($failures.Count -eq 0 -or (-not ($failures | Where-Object { $_ -match 'trigger|concurrency|timeout|SHA' }))) {
    Write-Host '    ✓ Structural guardrails intact' -ForegroundColor Green
}

if ($failures.Count -gt 0) {
    Write-Host "`nReviewer autoassign test FAILURES:" -ForegroundColor Red
    foreach ($f in $failures) {
        Write-Host "  - $f" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'Reviewer autoassign tests passed (#1575)' -ForegroundColor Green
exit 0
