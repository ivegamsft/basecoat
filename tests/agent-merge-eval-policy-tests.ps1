#!/usr/bin/env pwsh
<#
.SYNOPSIS
Regression tests for agent-merge eval validation policy wiring.

.DESCRIPTION
Verifies that:
- The agent-merge.yml workflow contains the eval companion validation step
- The step name matches the documented required status check name
- The job name matches the documented required status check prefix
- The eval validation step exits non-zero on missing companions (bypass protection)
- Policy documentation exists and contains required status check name

.EXAMPLE
.\agent-merge-eval-policy-tests.ps1
#>

$ErrorActionPreference = 'Stop'
$script:testResults = @()

function Test-Result {
    param(
        [string]$TestName,
        [bool]$Pass,
        [string]$Details = ''
    )
    $result = @{
        Test    = $TestName
        Status  = if ($Pass) { 'PASS' } else { 'FAIL' }
        Details = $Details
    }
    $script:testResults += $result
    if ($Pass) {
        Write-Host "✓ $TestName" -ForegroundColor Green
    } else {
        Write-Host "✗ $TestName" -ForegroundColor Red
        if ($Details) {
            Write-Host "  └─ $Details" -ForegroundColor Yellow
        }
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running agent-merge eval policy regression tests...' -ForegroundColor Blue
Write-Host ''

# ── Workflow exists ────────────────────────────────────────────────────────────
$workflowPath = Join-Path $repoRoot '.github' 'workflows' 'agent-merge.yml'
Test-Result 'agent-merge.yml workflow exists' `
    (Test-Path $workflowPath) `
    "Expected: $workflowPath"

if (-not (Test-Path $workflowPath)) {
    Write-Host "`nCannot continue: workflow file missing." -ForegroundColor Red
    exit 1
}

$wf = Get-Content $workflowPath -Raw

# ── Job name matches required status check prefix ──────────────────────────────
Test-Result "Job display name is 'Agent merge guardrails'" `
    ($wf -match "name:\s*Agent merge guardrails") `
    "Job name must match documented required status check prefix"

# ── Eval companion validation step exists ─────────────────────────────────────
Test-Result "Workflow contains 'Validate eval companions' step" `
    ($wf -match "name:\s*Validate eval companions") `
    "Step name must match documented required status check suffix"

# ── Eval step checks for agent eval files ─────────────────────────────────────
Test-Result 'Eval step validates .agent.eval.yaml companions' `
    ($wf -match '\.agent\.eval\.yaml') `
    'Eval step must reference .agent.eval.yaml pattern'

# ── Eval step checks for skill eval files ─────────────────────────────────────
Test-Result 'Eval step validates skill eval.yaml companions' `
    ($wf -match 'skills.*eval\.yaml|eval\.yaml.*skills') `
    'Eval step must reference skill eval.yaml pattern'

# ── Eval step exits non-zero on failure (bypass protection) ───────────────────
Test-Result 'Eval step calls sys.exit(1) on missing companions' `
    ($wf -match 'sys\.exit\(1\)') `
    'Eval validation must exit 1 to block merge; no bypass path should be available'

# ── No bypass label for eval validation ───────────────────────────────────────
Test-Result 'Eval validation has no skip/bypass label' `
    ($wf -notmatch 'skip-eval|bypass-eval|skip_eval') `
    'Eval companion validation must not be bypassable via a label'

# ── Policy documentation exists ───────────────────────────────────────────────
$docPath = Join-Path $repoRoot 'docs' 'operations' 'agent-merge-eval-policy.md'
Test-Result 'Eval policy documentation exists' `
    (Test-Path $docPath) `
    "Expected: $docPath"

if (Test-Path $docPath) {
    $doc = Get-Content $docPath -Raw

    Test-Result 'Policy doc contains required status check name' `
        ($doc -match 'Agent merge guardrails / Validate eval companions') `
        'Documentation must specify the exact required status check name'

    Test-Result 'Policy doc contains branch protection setup instructions' `
        ($doc -match 'Branch protection|branch protection') `
        'Documentation must explain how to configure branch protection'
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ''
$passed = ($script:testResults | Where-Object { $_.Status -eq 'PASS' }).Count
$failed = ($script:testResults | Where-Object { $_.Status -eq 'FAIL' }).Count
Write-Host "Results: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Red' })

if ($failed -gt 0) {
    Write-Host "`nFailed tests:" -ForegroundColor Red
    $script:testResults | Where-Object { $_.Status -eq 'FAIL' } | ForEach-Object {
        Write-Host "  - $($_.Test)" -ForegroundColor Red
        if ($_.Details) {
            Write-Host "    $($_.Details)" -ForegroundColor Yellow
        }
    }
    exit 1
}
