#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Coverage tests for pr-lifecycle routing and closeout guardrails.

.DESCRIPTION
    Validates instruction contracts and eval scenario coverage for
    pr-lifecycle modifier semantics (`none|standard|full`), negative routing
    cases, and closeout guardrails.
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running pr-lifecycle routing coverage tests...'

$failures = @()

function Add-Failure {
    param([string]$Message)
    $script:failures += $Message
}

# Test 1: canonical intent-routing instruction includes lifecycle enum semantics
# and dual-prefix rejection; the compatibility alias must point to the canonical source.
Write-Host '  Test 1: Validate pr-lifecycle parsing contract in routing instructions...'
$canonicalRouting = Join-Path $repoRoot 'instructions\basecoat-10-core-intent-routing.instructions.md'
$compatRouting = Join-Path $repoRoot 'instructions\intent-routing.instructions.md'

if (-not (Test-Path $canonicalRouting)) {
    Add-Failure "Missing canonical routing instruction file: $canonicalRouting"
}
else {
    $content = Get-Content -Raw -Path $canonicalRouting
    if ($content -notmatch 'pr-lifecycle=<none\|standard\|full>') {
        Add-Failure "$canonicalRouting missing pr-lifecycle enum contract"
    }
    if ($content -notmatch 'default to[\s\S]{0,120}pr-lifecycle=standard') {
        Add-Failure "$canonicalRouting missing default standard lifecycle guidance"
    }
    if ($content -notmatch 'Reject invalid `pr-lifecycle` values|validate enum values') {
        Add-Failure "$canonicalRouting missing invalid enum rejection guidance"
    }
    if ($content -notmatch 'dual-prefix|feature:\s*pr:|single authoritative prefix') {
        Add-Failure "$canonicalRouting missing dual-prefix rejection guidance"
    }
}
if (-not (Test-Path $compatRouting)) {
    Add-Failure "Missing compatibility routing instruction file: $compatRouting"
}
else {
    $content = Get-Content -Raw -Path $compatRouting
    if ($content -notmatch 'canonicalInstruction:\s*"basecoat-10-core-intent-routing\.instructions\.md"' -or
        $content -notmatch 'See `basecoat-10-core-intent-routing\.instructions\.md`') {
        Add-Failure "$compatRouting must point to the canonical routing instruction"
    }
}

# Test 2: intent-prefix guide documents closeout guardrails.
Write-Host '  Test 2: Validate closeout guardrails in intent-prefix guide...'
$prefixGuide = Join-Path $repoRoot 'docs\guides\intent-prefixes.md'
if (-not (Test-Path $prefixGuide)) {
    Add-Failure 'docs/guides/intent-prefixes.md missing'
}
else {
    $guideContent = Get-Content -Raw -Path $prefixGuide
    if ($guideContent -notmatch 'required builds are still pending') {
        Add-Failure 'intent-prefixes guide missing required-check gating before closeout'
    }
    if ($guideContent -notmatch 'Only run branch cleanup.*merged/closed') {
        Add-Failure 'intent-prefixes guide missing cleanup sequencing guardrail'
    }
    if ($guideContent -notmatch 'WIP tasks or uncommitted changes') {
        Add-Failure 'intent-prefixes guide missing no-complete-with-WIP/uncommitted rule'
    }
}

# Helper: extract the YAML block for a test entry by its id value.
# Returns the text from "- id: <testId>" up to the next "- id:" (or end).
function Get-YamlTestBlock {
    param(
        [string]$Content,
        [string]$TestId
    )
    # Match everything from "- id: <testId>" to the next "- id:" or end of string
    if ($Content -match "(?s)(- id:\s+$([regex]::Escape($TestId))\s*\n.*?)(?=\n\s*- id:|\z)") {
        return $Matches[1]
    }
    return $null
}

# Test 3: skill routing eval covers lifecycle enum modes and negative parser cases.
Write-Host '  Test 3: Validate ship-it skill eval coverage for pr-lifecycle routing...'
$shipItSkillEvalPath = Join-Path $repoRoot 'skills\ship-it\eval.yaml'
if (-not (Test-Path $shipItSkillEvalPath)) {
    Add-Failure 'skills/ship-it/eval.yaml missing'
}
else {
    $skillEvalContent = Get-Content -Raw -Path $shipItSkillEvalPath

    $requiredSkillTests = @(
        @{ id = 'pr-lifecycle-none-routing'; expectedDecision = 'trigger'; requiredText = 'pr-lifecycle=none' },
        @{ id = 'pr-lifecycle-standard-routing'; expectedDecision = 'trigger'; requiredText = 'pr-lifecycle=standard' },
        @{ id = 'pr-lifecycle-full-routing'; expectedDecision = 'trigger'; requiredText = 'pr-lifecycle=full' },
        @{ id = 'pr-lifecycle-dual-prefix-negative'; expectedDecision = 'no_trigger'; requiredText = 'feature: pr:' },
        @{ id = 'pr-lifecycle-invalid-enum-negative'; expectedDecision = 'no_trigger'; requiredText = 'pr-lifecycle=fast' }
    )

    foreach ($required in $requiredSkillTests) {
        $block = Get-YamlTestBlock -Content $skillEvalContent -TestId $required.id
        if ($null -eq $block) {
            Add-Failure "skills/ship-it/eval.yaml missing test id: $($required.id)"
            continue
        }

        if ($block -notmatch "decision:\s+$([regex]::Escape($required.expectedDecision))") {
            Add-Failure "skills/ship-it/eval.yaml test $($required.id) expected decision '$($required.expectedDecision)'"
        }

        if ($block -notmatch [regex]::Escape($required.requiredText)) {
            Add-Failure "skills/ship-it/eval.yaml test $($required.id) missing required input marker '$($required.requiredText)'"
        }
    }
}

# Test 4: orchestrator agent eval covers closeout guardrails and cross-surface behavior.
Write-Host '  Test 4: Validate ship-it orchestrator eval guardrail coverage...'
$shipItAgentEvalPath = Join-Path $repoRoot 'agents\basecoat-60-workflow-ship-it-orchestrator.agent.eval.yaml'
if (-not (Test-Path $shipItAgentEvalPath)) {
    Add-Failure 'agents/basecoat-60-workflow-ship-it-orchestrator.agent.eval.yaml missing'
}
else {
    $agentEvalContent = Get-Content -Raw -Path $shipItAgentEvalPath

    $requiredAgentTests = @(
        @{ id = 'pr-lifecycle-full-required-check-gating'; terms = @('required checks', 'closeout', 'blocked') },
        @{ id = 'pr-lifecycle-full-cleanup-sequencing'; terms = @('cleanup', 'after merge', 'explicitly closed') },
        @{ id = 'pr-lifecycle-full-no-complete-with-wip'; terms = @('WIP', 'uncommitted', 'cannot complete') },
        @{ id = 'pr-lifecycle-cross-surface-fallback'; terms = @('CLI', 'VS Code', 'cloud', 'fallback') }
    )

    foreach ($required in $requiredAgentTests) {
        $block = Get-YamlTestBlock -Content $agentEvalContent -TestId $required.id
        if ($null -eq $block) {
            Add-Failure "agents/basecoat-60-workflow-ship-it-orchestrator.agent.eval.yaml missing test id: $($required.id)"
            continue
        }

        foreach ($term in $required.terms) {
            if ($block -notmatch [regex]::Escape($term)) {
                Add-Failure "agents/basecoat-60-workflow-ship-it-orchestrator.agent.eval.yaml test $($required.id) missing expect.contains term '$term'"
            }
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host "pr-lifecycle routing coverage tests FAILED: $($failures -join '; ')" -ForegroundColor Red
    exit 1
}

Write-Host 'All pr-lifecycle routing coverage tests passed' -ForegroundColor Green
exit 0
