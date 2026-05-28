#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests for plan-first and Azure preflight routing guardrails.

.DESCRIPTION
    Validates that intent-routing instruction and guardrail files contain
    the required plan-first and Azure preflight rules, and that referenced
    instruction files exist.
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running routing guardrail tests...'

$failures = @()

# Test 1: intent-routing instruction contains plan-first enforcement section
Write-Host '  Test 1: Validate plan-first enforcement is present in intent-routing...'
$routingFile = Join-Path $repoRoot 'instructions\intent-routing.instructions.md'
if (-not (Test-Path $routingFile)) {
    $failures += 'intent-routing file missing'
    Write-Host '    ✗ instructions/intent-routing.instructions.md not found' -ForegroundColor Red
}
else {
    $content = Get-Content $routingFile -Raw
    if ($content -notmatch 'Plan-First Enforcement') {
        $failures += 'plan-first-section-missing'
        Write-Host '    ✗ Plan-First Enforcement section missing from intent-routing' -ForegroundColor Red
    }
    else {
        Write-Host '    ✓ Plan-First Enforcement section present'
    }

    if ($content -notmatch "feature:.*refactor:.*architect:|architect:.*refactor:.*feature:|refactor:.*feature:|feature:.*refactor:") {
        # Check that plan-first lists the affected prefixes
        if ($content -notmatch 'feature:.*refactor:' -and $content -notmatch 'refactor:.*architect:') {
            $failures += 'plan-first-prefixes-missing'
            Write-Host '    ✗ Plan-first affected prefixes (feature:, refactor:, architect:) not found' -ForegroundColor Red
        }
        else {
            Write-Host '    ✓ Plan-first affected prefixes referenced'
        }
    }
    else {
        Write-Host '    ✓ Plan-first affected prefixes referenced'
    }
}

# Test 2: intent-routing instruction contains sprint-style nudge
Write-Host '  Test 2: Validate sprint-style nudge is present in intent-routing...'
if (Test-Path $routingFile) {
    $content = Get-Content $routingFile -Raw
    if ($content -notmatch 'Sprint-Style Request Nudge|sprint-planner.*first|sprint plan.*confirmation') {
        $failures += 'sprint-nudge-missing'
        Write-Host '    ✗ Sprint-style request nudge missing from intent-routing' -ForegroundColor Red
    }
    else {
        Write-Host '    ✓ Sprint-style request nudge present'
    }
}

# Test 3: intent-routing instruction contains Azure preflight guardrail
Write-Host '  Test 3: Validate Azure preflight guardrail is present in intent-routing...'
if (Test-Path $routingFile) {
    $content = Get-Content $routingFile -Raw
    if ($content -notmatch 'Azure Preflight Guardrail') {
        $failures += 'azure-preflight-section-missing'
        Write-Host '    ✗ Azure Preflight Guardrail section missing from intent-routing' -ForegroundColor Red
    }
    else {
        Write-Host '    ✓ Azure Preflight Guardrail section present'
    }
}

# Test 4: intent-routing references ci-firewall and rbac-authentication
Write-Host '  Test 4: Validate Azure preflight references ci-firewall and rbac-authentication...'
if (Test-Path $routingFile) {
    $content = Get-Content $routingFile -Raw
    $missingRefs = @()
    if ($content -notmatch 'ci-firewall') {
        $missingRefs += 'ci-firewall.instructions.md'
    }
    if ($content -notmatch 'rbac-authentication') {
        $missingRefs += 'rbac-authentication.instructions.md'
    }
    if ($missingRefs.Count -gt 0) {
        $failures += 'azure-preflight-refs-missing'
        Write-Host "    ✗ Missing references: $($missingRefs -join ', ')" -ForegroundColor Red
    }
    else {
        Write-Host '    ✓ ci-firewall and rbac-authentication referenced'
    }
}

# Test 5: intent-routing includes azure: and infra: in prefix vocabulary
Write-Host '  Test 5: Validate azure: and infra: prefixes are in intent-routing vocabulary...'
if (Test-Path $routingFile) {
    $content = Get-Content $routingFile -Raw
    $missingPrefixes = @()
    if ($content -notmatch '`azure:`') { $missingPrefixes += 'azure:' }
    if ($content -notmatch '`infra:`') { $missingPrefixes += 'infra:' }
    if ($content -notmatch '`architect:`') { $missingPrefixes += 'architect:' }
    if ($missingPrefixes.Count -gt 0) {
        $failures += 'new-prefixes-missing'
        Write-Host "    ✗ Prefix vocabulary missing: $($missingPrefixes -join ', ')" -ForegroundColor Red
    }
    else {
        Write-Host '    ✓ azure:, infra:, and architect: prefixes present'
    }
}

# Test 6: guardrail reference file exists
Write-Host '  Test 6: Validate plan-first-azure-preflight.md guardrail file exists...'
$guardrailFile = Join-Path $repoRoot 'docs\reference\guardrails\plan-first-azure-preflight.md'
if (-not (Test-Path $guardrailFile)) {
    $failures += 'guardrail-file-missing'
    Write-Host '    ✗ docs/reference/guardrails/plan-first-azure-preflight.md not found' -ForegroundColor Red
}
else {
    Write-Host '    ✓ plan-first-azure-preflight.md exists'
}

# Test 7: guardrail file contains required sections
Write-Host '  Test 7: Validate guardrail file contains Plan-First and Azure Preflight sections...'
if (Test-Path $guardrailFile) {
    $content = Get-Content $guardrailFile -Raw
    $missingSections = @()
    if ($content -notmatch 'Plan-First Guardrail') { $missingSections += 'Plan-First Guardrail' }
    if ($content -notmatch 'Azure Preflight Guardrail') { $missingSections += 'Azure Preflight Guardrail' }
    if ($missingSections.Count -gt 0) {
        $failures += 'guardrail-sections-missing'
        Write-Host "    ✗ Missing sections in guardrail file: $($missingSections -join ', ')" -ForegroundColor Red
    }
    else {
        Write-Host '    ✓ Both guardrail sections present'
    }
}

# Test 8: referenced instruction files exist
Write-Host '  Test 8: Validate referenced instruction files exist...'
$referencedFiles = @(
    'instructions\ci-firewall.instructions.md',
    'instructions\rbac-authentication.instructions.md',
    'instructions\plan-first.instructions.md'
)
foreach ($ref in $referencedFiles) {
    $path = Join-Path $repoRoot $ref
    if (-not (Test-Path $path)) {
        $failures += "missing-ref-$ref"
        Write-Host "    ✗ Referenced file not found: $ref" -ForegroundColor Red
    }
    else {
        Write-Host "    ✓ $ref exists"
    }
}

# Test 9: intent-prefixes guide includes azure: and infra:
Write-Host '  Test 9: Validate intent-prefixes guide includes new prefixes...'
$prefixGuide = Join-Path $repoRoot 'docs\guides\intent-prefixes.md'
if (Test-Path $prefixGuide) {
    $content = Get-Content $prefixGuide -Raw
    $missingPrefixes = @()
    if ($content -notmatch '`azure:`') { $missingPrefixes += 'azure:' }
    if ($content -notmatch '`infra:`') { $missingPrefixes += 'infra:' }
    if ($missingPrefixes.Count -gt 0) {
        $failures += 'guide-prefixes-missing'
        Write-Host "    ✗ intent-prefixes guide missing: $($missingPrefixes -join ', ')" -ForegroundColor Red
    }
    else {
        Write-Host '    ✓ azure: and infra: prefixes in intent-prefixes guide'
    }
}
else {
    $failures += 'intent-prefixes-guide-missing'
    Write-Host '    ✗ docs/guides/intent-prefixes.md not found' -ForegroundColor Red
}

# Test 10: intent-prefixes guide includes plan-first section
Write-Host '  Test 10: Validate intent-prefixes guide includes plan-first section...'
if (Test-Path $prefixGuide) {
    $content = Get-Content $prefixGuide -Raw
    if ($content -notmatch 'Plan-first enforcement|plan-first enforcement') {
        $failures += 'guide-plan-first-missing'
        Write-Host '    ✗ Plan-first enforcement section missing from intent-prefixes guide' -ForegroundColor Red
    }
    else {
        Write-Host '    ✓ Plan-first enforcement section present in intent-prefixes guide'
    }
}

# Test 11: intent-prefixes guide includes Azure preflight section
Write-Host '  Test 11: Validate intent-prefixes guide includes Azure preflight section...'
if (Test-Path $prefixGuide) {
    $content = Get-Content $prefixGuide -Raw
    if ($content -notmatch 'Azure preflight|azure preflight') {
        $failures += 'guide-azure-preflight-missing'
        Write-Host '    ✗ Azure preflight section missing from intent-prefixes guide' -ForegroundColor Red
    }
    else {
        Write-Host '    ✓ Azure preflight section present in intent-prefixes guide'
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Routing guardrail tests FAILED: $($failures -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host 'All routing guardrail tests passed' -ForegroundColor Green
exit 0
