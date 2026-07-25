#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests for routing guardrails including plan-first, Azure preflight,
    and fleet control-loop contracts.

.DESCRIPTION
    Validates that intent-routing instruction and guardrail files contain
    the required plan-first/Azure preflight rules, fleet control-loop
    routing contracts, and that referenced instruction files exist.
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

# Test 5: intent-routing includes key prefixes in vocabulary
Write-Host '  Test 5: Validate portfolio:, azure:, infra:, optimize:, and chronicle: prefixes are in intent-routing vocabulary...'
if (Test-Path $routingFile) {
    $content = Get-Content $routingFile -Raw
    $missingPrefixes = @()
    if ($content -notmatch '`portfolio:`') { $missingPrefixes += 'portfolio:' }
    if ($content -notmatch '`azure:`') { $missingPrefixes += 'azure:' }
    if ($content -notmatch '`infra:`') { $missingPrefixes += 'infra:' }
    if ($content -notmatch '`architect:`') { $missingPrefixes += 'architect:' }
    if ($content -notmatch '`optimize:`') { $missingPrefixes += 'optimize:' }
    if ($content -notmatch '`chronicle:`') { $missingPrefixes += 'chronicle:' }
    if ($missingPrefixes.Count -gt 0) {
        $failures += 'new-prefixes-missing'
        Write-Host "    ✗ Prefix vocabulary missing: $($missingPrefixes -join ', ')" -ForegroundColor Red
    }
    else {
        Write-Host '    ✓ portfolio:, azure:, infra:, optimize:, chronicle:, and architect: prefixes present'
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

# Test 9: intent-prefixes guide includes key prefixes
Write-Host '  Test 9: Validate intent-prefixes guide includes portfolio:, azure:, infra:, optimize:, and chronicle: prefixes...'
$prefixGuide = Join-Path $repoRoot 'docs\guides\intent-prefixes.md'
if (Test-Path $prefixGuide) {
    $content = Get-Content $prefixGuide -Raw
    $missingPrefixes = @()
    if ($content -notmatch '`portfolio:`') { $missingPrefixes += 'portfolio:' }
    if ($content -notmatch '`azure:`') { $missingPrefixes += 'azure:' }
    if ($content -notmatch '`infra:`') { $missingPrefixes += 'infra:' }
    if ($content -notmatch '`optimize:`') { $missingPrefixes += 'optimize:' }
    if ($content -notmatch '`chronicle:`') { $missingPrefixes += 'chronicle:' }
    if ($missingPrefixes.Count -gt 0) {
        $failures += 'guide-prefixes-missing'
        Write-Host "    ✗ intent-prefixes guide missing: $($missingPrefixes -join ', ')" -ForegroundColor Red
    }
    else {
        Write-Host '    ✓ portfolio:, azure:, infra:, optimize:, and chronicle: prefixes in intent-prefixes guide'
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

# Test 12: intent-routing includes deterministic GitHub-native routing for portfolio:
Write-Host '  Test 12: Validate deterministic GitHub-native routing includes portfolio:...'
if (Test-Path $routingFile) {
    $content = Get-Content $routingFile -Raw
    if ($content -notmatch 'workflow:.*actions:.*pr:.*issue:.*portfolio:.*release:') {
        $failures += 'portfolio-github-native-routing-missing'
        Write-Host '    ✗ GitHub-native deterministic routing contract missing portfolio:' -ForegroundColor Red
    }
    else {
        Write-Host '    ✓ GitHub-native deterministic routing includes portfolio:'
    }
}

# Test 13: only the routing guide may use applyTo "**/*"
Write-Host '  Test 13: Validate applyTo scope policy for routing instruction files...'
$routingGuide = Join-Path $repoRoot '.github\copilot-instructions.md'
if (-not (Test-Path $routingGuide)) {
    $failures += 'routing-guide-missing'
    Write-Host '    ✗ .github/copilot-instructions.md not found' -ForegroundColor Red
}
else {
    $guideContent = Get-Content $routingGuide -Raw
    if ($guideContent -notmatch '(?m)^applyTo:\s*"\*\*/\*"') {
        $failures += 'routing-guide-not-global'
        Write-Host '    ✗ routing guide must retain applyTo "**/*"' -ForegroundColor Red
    }
    else {
        Write-Host '    ✓ routing guide retains applyTo "**/*"'
    }
}

$routingInstructionFiles = @()
$routingInstructionsDir = Join-Path $repoRoot '.github\instructions'
if (Test-Path $routingInstructionsDir) {
    $routingInstructionFiles += Get-ChildItem $routingInstructionsDir -Filter '*.instructions.md' -File
    $decisionTree = Join-Path $routingInstructionsDir 'routing-decision-tree.md'
    if (Test-Path $decisionTree) {
        $routingInstructionFiles += Get-Item $decisionTree
    }
}

$broadApplyToFiles = @()
foreach ($file in $routingInstructionFiles) {
    $header = (Get-Content $file.FullName -TotalCount 20) -join "`n"
    if ($header -match '(?m)^applyTo:\s*"\*\*/\*"') {
        $broadApplyToFiles += $file.Name
    }
}

if ($broadApplyToFiles.Count -gt 0) {
    $failures += 'routing-instruction-scope-too-broad'
    Write-Host "    ✗ Non-guide routing files using applyTo ""**/*"": $($broadApplyToFiles -join ', ')" -ForegroundColor Red
}
else {
    Write-Host '    ✓ All non-guide routing instruction files use scoped applyTo patterns'
}

# Test 14: intent-routing includes fleet persistent control-loop mode contract
Write-Host '  Test 14: Validate fleet persistent control-loop mode contract in intent-routing...'
if (Test-Path $routingFile) {
    $content = Get-Content $routingFile -Raw
    $missingContract = @()
    if ($content -notmatch 'Fleet Persistent Control-Loop Mode') { $missingContract += 'section heading' }
    if ($content -notmatch 'ship-it-control-loop') { $missingContract += 'ship-it-control-loop reference' }
    if ($content -notmatch '/tasks') { $missingContract += '/tasks checkpoint reference' }
    if ($content -notmatch 'max_cycles') { $missingContract += 'max_cycles contract' }
    if ($content -notmatch 'max_retries') { $missingContract += 'max_retries contract' }
    if ($missingContract.Count -gt 0) {
        $failures += 'fleet-control-loop-contract-missing'
        Write-Host "    ✗ Missing fleet control-loop contract elements: $($missingContract -join ', ')" -ForegroundColor Red
    }
    else {
        Write-Host '    ✓ Fleet persistent control-loop contract present'
    }
}

# Test 15: intent-prefixes guide includes persistent next-wave loop mode
Write-Host '  Test 15: Validate persistent next-wave loop guidance in intent-prefixes guide...'
if (Test-Path $prefixGuide) {
    $content = Get-Content $prefixGuide -Raw
    $missingGuide = @()
    if ($content -notmatch 'Persistent next-wave loop mode') { $missingGuide += 'section heading' }
    if ($content -notmatch 'plan and execute the next wave') { $missingGuide += 'next-wave phrase example' }
    if ($content -notmatch 'ship-it-control-loop') { $missingGuide += 'control-loop route reference' }
    if ($content -notmatch '/tasks') { $missingGuide += '/tasks checkpoint reference' }
    if ($missingGuide.Count -gt 0) {
        $failures += 'guide-next-wave-loop-missing'
        Write-Host "    ✗ Missing guide next-wave loop elements: $($missingGuide -join ', ')" -ForegroundColor Red
    }
    else {
        Write-Host '    ✓ Persistent next-wave loop guidance present in intent-prefixes guide'
    }
}

# Test 16: phase-boundary checklist exists and covers required pivots
Write-Host '  Test 16: Validate phase-boundary session checklist coverage...'
$phaseChecklist = Join-Path $repoRoot 'docs\guides\phase-boundary-session-checklist.md'
if (-not (Test-Path $phaseChecklist)) {
    $failures += 'phase-boundary-checklist-missing'
    Write-Host '    ✗ docs/guides/phase-boundary-session-checklist.md not found' -ForegroundColor Red
}
else {
    $content = Get-Content $phaseChecklist -Raw
    $missingCoverage = @()
    if ($content -notmatch '/compact') { $missingCoverage += '/compact guidance' }
    if ($content -notmatch '/new') { $missingCoverage += '/new guidance' }
    if ($content -notmatch '(?i)\bcleanup\b') { $missingCoverage += 'cleanup phase coverage' }
    if ($content -notmatch '(?i)\bimplementation\b') { $missingCoverage += 'implementation phase coverage' }
    if ($content -notmatch '(?i)\bRCA\b') { $missingCoverage += 'RCA phase coverage' }
    if ($content -notmatch '(?i)\bdocs\b') { $missingCoverage += 'docs phase coverage' }
    if ($missingCoverage.Count -gt 0) {
        $failures += 'phase-boundary-checklist-coverage-missing'
        Write-Host "    ✗ Missing phase checklist coverage: $($missingCoverage -join ', ')" -ForegroundColor Red
    }
    else {
        Write-Host '    ✓ Phase-boundary checklist covers cleanup/implementation/RCA/docs pivots'
    }
}

# Test 17: new design/sprint/wave prefixes present in canonical, alias, and guide
Write-Host '  Test 17: Validate ui:, ux:, ia:, sprint:, wave: map to expected route targets...'
$canonicalFile = Join-Path $repoRoot 'instructions\basecoat-10-core-intent-routing.instructions.md'
$newPrefixTargets = @{
    'canonical (basecoat-10-core-intent-routing)' = $canonicalFile
    'alias (intent-routing)'                       = $routingFile
    'guide (intent-prefixes)'                      = $prefixGuide
}
foreach ($label in $newPrefixTargets.Keys) {
    $path = $newPrefixTargets[$label]
    if (-not (Test-Path $path)) {
        $failures += "new-prefix-file-missing-$label"
        Write-Host "    FAIL $label file not found" -ForegroundColor Red
        continue
    }
    $content = Get-Content $path -Raw
    $routeExpectations = [ordered]@{
        'ui:'     = '@frontend-dev'
        'ux:'     = '@ux-designer'
        'ia:'     = '@tech-writer'
        'sprint:' = '@sprint-closeout-auditor'
        'wave:'   = '@parallel-session-coordinator'
    }
    $missing = @()
    foreach ($p in $routeExpectations.Keys) {
        $agent = $routeExpectations[$p]
        $rowPattern = '(?m)^\|[^\r\n]*`' + $p + '`[^\r\n]*' + [regex]::Escape($agent)
        if ($content -notmatch $rowPattern) { $missing += "$p->$agent" }
    }
    if ($missing.Count -gt 0) {
        $failures += "new-prefix-routes-missing-$label"
        Write-Host "    FAIL $label missing route targets: $($missing -join ', ')" -ForegroundColor Red
    }
    else {
        Write-Host "    PASS $label binds ui:/ux:/ia:/sprint:/wave: to distinct route targets"
    }
}

# Test 18: Term Disambiguation section and UI/UX/IA distinction with ambiguity guidance
Write-Host '  Test 18: Validate Term Disambiguation section and disambiguation-question guidance...'
foreach ($label in @('canonical (basecoat-10-core-intent-routing)', 'alias (intent-routing)')) {
    $path = $newPrefixTargets[$label]
    if (-not (Test-Path $path)) { continue }
    $content = Get-Content $path -Raw
    $missing = @()
    if ($content -notmatch 'Term Disambiguation and Aliases') { $missing += 'disambiguation section' }
    if ($content -notmatch 'must not collapse to one route') { $missing += 'UI/UX/IA distinction' }
    if ($content -notmatch 'ask one disambiguation question') { $missing += 'ambiguity guidance' }
    if ($missing.Count -gt 0) {
        $failures += "disambiguation-missing-$label"
        Write-Host "    FAIL $label missing: $($missing -join ', ')" -ForegroundColor Red
    }
    else {
        Write-Host "    PASS $label has disambiguation section, UI/UX/IA distinction, and ambiguity guidance"
    }
}

# Test 19: canonical/alias/guide route synchronization for corrected routes
Write-Host '  Test 19: Validate outage/worktree/burndown routes are synchronized and actionable...'
foreach ($label in $newPrefixTargets.Keys) {
    $path = $newPrefixTargets[$label]
    if (-not (Test-Path $path)) { continue }
    $content = Get-Content $path -Raw
    $missing = @()
    if ($content -notmatch 'outage:.*@incident-responder') { $missing += 'outage:->@incident-responder' }
    if ($content -notmatch 'prune worktrees.*git-worktrees') { $missing += 'worktree cleanup->git-worktrees skill' }
    if ($content -notmatch 'clean up work trees') { $missing += 'two-word work-trees alias' }
    if ($content -notmatch 'burndown.*@orphaned-pr-cleanup') { $missing += 'burndown->@orphaned-pr-cleanup' }
    if ($missing.Count -gt 0) {
        $failures += "route-sync-missing-$label"
        Write-Host "    FAIL $label missing route sync: $($missing -join ', ')" -ForegroundColor Red
    }
    else {
        Write-Host "    PASS $label routes outage/worktree/burndown to correct assets"
    }
}

# Test 20: backlog-burndown skill ingests open PRs (skill + eval coverage)
Write-Host '  Test 20: Validate backlog-burndown skill covers open PRs...'
$burndownSkill = Join-Path $repoRoot 'skills\backlog-burndown\SKILL.md'
$burndownEval = Join-Path $repoRoot 'skills\backlog-burndown\eval.yaml'
$burndownRef = Join-Path $repoRoot 'skills\backlog-burndown\references\burndown-workflow.md'
$burndownMissing = @()
if (-not (Test-Path $burndownSkill)) {
    $burndownMissing += 'SKILL.md missing'
}
else {
    $skillContent = Get-Content $burndownSkill -Raw
    if ($skillContent -notmatch '(?i)\bPRs?\b|pull request') { $burndownMissing += 'SKILL.md does not mention PRs' }
    if ($skillContent -notmatch 'orphaned-pr-cleanup') { $burndownMissing += 'SKILL.md missing orphaned-pr-cleanup pairing' }
}
if (-not (Test-Path $burndownEval)) {
    $burndownMissing += 'eval.yaml missing'
}
else {
    $evalContent = Get-Content $burndownEval -Raw
    if ($evalContent -notmatch '(?i)open PRs|pull request') { $burndownMissing += 'eval.yaml missing PR scenario' }
}
if (-not (Test-Path $burndownRef)) {
    $burndownMissing += 'burndown-workflow.md missing'
}
else {
    $refContent = Get-Content $burndownRef -Raw
    if ($refContent -notmatch '(?i)draft/open') { $burndownMissing += 'workflow missing open-PR (In Progress) classification' }
    if ($refContent -notmatch '(?i)merged to Done') { $burndownMissing += 'workflow missing merged-to-Done classification' }
    if ($refContent -notmatch '(?i)closed-unmerged') { $burndownMissing += 'workflow missing closed-unmerged classification' }
}
if ($burndownMissing.Count -gt 0) {
    $failures += 'burndown-pr-coverage-missing'
    Write-Host "    FAIL backlog-burndown PR coverage gaps: $($burndownMissing -join ', ')" -ForegroundColor Red
}
else {
    Write-Host '    PASS backlog-burndown skill and eval cover open PRs'
}

if ($failures.Count -gt 0) {
    Write-Host "Routing guardrail tests FAILED: $($failures -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host 'All routing guardrail tests passed' -ForegroundColor Green
exit 0
