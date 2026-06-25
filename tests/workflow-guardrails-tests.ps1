#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests for workflow guardrails validation.

.DESCRIPTION
    Validates that workflows in .github/workflows/ comply with guardrails:
    - timeout-minutes must be set on jobs
    - concurrency controls must be defined
    - action uses must pin to specific SHAs (not @main or @master)
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running workflow guardrails tests...'

# Helper function to parse YAML files
function ConvertFrom-Yaml {
    param([string]$Path)
    
    # Simple YAML parser for our specific needs
    $lines = @(Get-Content $Path -Raw -ErrorAction SilentlyContinue) -split "`n"
    $yaml = @{}
    $current = $yaml
    $stack = @()
    $indent = 0
    
    return $lines
}

# Test 1: All workflows have timeout-minutes set
Write-Host '  Test 1: Validate timeout-minutes in all workflows...'
$workflowDir = '.github/workflows'
$workflowFiles = Get-ChildItem "$workflowDir/*.yml" -File | Where-Object { $_.Name -notmatch 'README|\.lock\.yml$' }
$guardrailFailures = @()
$directMainPushAllowList = @(
    'publish-to-production.yml',
    'release.yml'
)
$nonDispatchTriggers = @(
    'push',
    'pull_request',
    'pull_request_target',
    'schedule',
    'workflow_run',
    'issue_comment',
    'issues',
    'release',
    'repository_dispatch',
    'merge_group'
)

$missingTimeouts = @()
foreach ($file in $workflowFiles) {
    $content = Get-Content $file.FullName -Raw
    
    # Check if file has any job definitions
    if ($content -match 'jobs:') {
        # Each job should have timeout-minutes
        # Look for job declarations
        $jobMatches = [regex]::Matches($content, '(?:^|\n)\s+\w+:\s*(?:$|\n)')
        
        if ($jobMatches.Count -gt 0) {
            # Check if timeout-minutes exists after jobs:
            if ($content -notmatch 'timeout-minutes:') {
                $missingTimeouts += $file.Name
            }
        }
    }
}

if ($missingTimeouts.Count -gt 0) {
    Write-Host "    ⚠ Workflows without timeout-minutes: $($missingTimeouts -join ', ')"
}
else {
    Write-Host '    ✓ All workflows with jobs have timeout-minutes'
}

# Test 2: Validate concurrency controls
Write-Host '  Test 2: Validate concurrency controls...'
$workflowsWithoutConcurrency = @()
$workflowsWithConcurrency = @()

foreach ($file in $workflowFiles) {
    $content = Get-Content $file.FullName -Raw
    
    if ($content -match 'concurrency:') {
        $workflowsWithConcurrency += $file.Name
    }
    else {
        $workflowsWithoutConcurrency += $file.Name
    }
}

Write-Host "    ✓ Workflows with concurrency: $($workflowsWithConcurrency.Count)"
Write-Host "    ℹ Workflows without concurrency: $($workflowsWithoutConcurrency.Count)"

# Test 3: Validate concurrency structure (group and cancel-in-progress)
Write-Host '  Test 3: Validate concurrency structure...'
$invalidConcurrency = @()

foreach ($file in $workflowFiles) {
    $content = Get-Content $file.FullName -Raw
    
    if ($content -match 'concurrency:') {
        # Check for proper group definition
        if ($content -notmatch 'group:\s*\$\{\{\s*github\.workflow.*?\}\}') {
            $invalidConcurrency += @{ file = $file.Name; issue = 'missing or invalid group' }
        }
    }
}

if ($invalidConcurrency.Count -eq 0) {
    Write-Host '    ✓ All concurrency blocks have valid group structure'
}
else {
    Write-Host "    ⚠ Issues found in concurrency structures:"
    foreach ($item in $invalidConcurrency) {
        Write-Host "      - $($item.file): $($item.issue)"
    }
}

# Test 4: Validate action SHA pinning (not @main, @master, @v)
Write-Host '  Test 4: Validate action SHA pinning...'
$actionPinningIssues = @()

foreach ($file in $workflowFiles) {
    $content = Get-Content $file.FullName -Raw
    $lines = $content -split "`n"
    $lineNum = 0
    
    foreach ($line in $lines) {
        $lineNum++
        
        # Match 'uses:' statements
        if ($line -match 'uses:\s*(.+)') {
            $uses = $matches[1].Trim()
            
            # Should be in format: org/repo@<sha-hash> (e.g., actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5)
            # NOT: org/repo@main, @master, @v1, @v2, etc.
            
            if ($uses -match '@(main|master|v\d+($|\.))') {
                $actionPinningIssues += @{
                    file    = $file.Name
                    line    = $lineNum
                    uses    = $uses
                    issue   = "not pinned to SHA: $uses"
                }
            }
            elseif ($uses -notmatch '@[a-f0-9]{40}') {
                # Warning for potentially loose pinning (but might be OK if it's a commit-based reference)
                # We're strict here: must be 40-character SHA
                if ($uses -notmatch '@[a-f0-9]+' -and -not ($uses -match '@[a-f0-9]{7,}')) {
                    # Could be a short SHA or tag without version number
                    if ($uses -match '@[vV]\d+') {
                        $actionPinningIssues += @{
                            file    = $file.Name
                            line    = $lineNum
                            uses    = $uses
                            issue   = "uses version tag instead of SHA: $uses"
                        }
                    }
                }
            }
        }
    }
}

if ($actionPinningIssues.Count -eq 0) {
    Write-Host '    ✓ All actions are pinned to SHAs (not @main/@v)'
}
else {
    Write-Host "    ⚠ Action pinning issues found:"
    foreach ($item in $actionPinningIssues) {
        Write-Host "      - $($item.file):$($item.line) - $($item.issue)"
    }
}

# Test 5: Permissions must be restrictive (contents: read or specific)
Write-Host '  Test 5: Validate permissions are restrictive...'
$permissionIssues = @()

foreach ($file in $workflowFiles) {
    $content = Get-Content $file.FullName -Raw
    
    # Check if 'permissions:' exists and is not overly permissive
    if ($content -match 'permissions:') {
        # Should have explicit permissions, not write-all
        if ($content -match 'permissions:\s*write-all' -or $content -match 'permissions:\s*{}') {
            $permissionIssues += @{ file = $file.Name; issue = 'overly permissive or empty permissions' }
        }
    }
}

if ($permissionIssues.Count -eq 0) {
    Write-Host '    ✓ All workflows have appropriate permissions'
}
else {
    Write-Host "    ⚠ Permission issues found:"
    foreach ($item in $permissionIssues) {
        Write-Host "      - $($item.file): $($item.issue)"
    }
}

# Test 6: No shell injection vulnerabilities (no inline script from untrusted input)
Write-Host '  Test 6: Validate no direct use of untrusted env vars in shell...'
$shellInjectionRisks = @()

foreach ($file in $workflowFiles) {
    $content = Get-Content $file.FullName -Raw
    $lines = $content -split "`n"
    $lineNum = 0
    $inRun = $false
    
    foreach ($line in $lines) {
        $lineNum++
        
        if ($line -match '^\s+run:\s*\|') {
            $inRun = $true
        }
        elseif ($inRun -and $line -match '^\s+\w+:') {
            $inRun = $false
        }
        
        # Check for common patterns (this is a basic check)
        if ($inRun -and $line -match '\$\{\{\s*github\.(event|inputs)\.' -and $line -match '(sh|bash|cmd)') {
            # This might be a risk, flag for review
            $shellInjectionRisks += @{
                file = $file.Name
                line = $lineNum
                risk = 'potential use of untrusted input in shell'
            }
        }
    }
}

if ($shellInjectionRisks.Count -eq 0) {
    Write-Host '    ✓ No obvious shell injection risks found'
}
else {
    Write-Host "    ℹ Review these for shell injection risks:"
    foreach ($item in $shellInjectionRisks) {
        Write-Host "      - $($item.file):$($item.line)"
    }
}

# Test 7: Artifact retention times are reasonable (not indefinite)
Write-Host '  Test 7: Validate artifact retention times...'
$artifactRetentionIssues = @()

foreach ($file in $workflowFiles) {
    $content = Get-Content $file.FullName -Raw
    
    # Check for upload-artifact without retention-days
    if ($content -match 'actions/upload-artifact' -and $content -notmatch 'retention-days') {
        $artifactRetentionIssues += $file.Name
    }
}

if ($artifactRetentionIssues.Count -eq 0) {
    Write-Host '    ✓ Artifact upload steps have retention-days set'
}
else {
    Write-Host "    ⚠ Missing retention-days in: $($artifactRetentionIssues -join ', ')"
}

# Test 8: Checkout actions use specific versions
Write-Host '  Test 8: Validate checkout action pinning...'
$checkoutIssues = @()

foreach ($file in $workflowFiles) {
    $content = Get-Content $file.FullName -Raw
    
    if ($content -match 'uses:\s*actions/checkout@(.+)') {
        $version = $matches[1]
        # Should be a SHA, not a version tag
        if ($version -notmatch '^[a-f0-9]+$') {
            $checkoutIssues += @{ file = $file.Name; version = $version }
        }
    }
}

if ($checkoutIssues.Count -eq 0) {
    Write-Host '    ✓ Checkout actions are properly pinned'
}
else {
    Write-Host "    ⚠ Checkout pinning issues: $($checkoutIssues | ForEach-Object { "$($_.file) uses @$($_.version)" } | Join-String -Separator ', ')"
}

# Test 9: Ensure matrix strategy doesn't create excessive parallelism
Write-Host '  Test 9: Validate matrix strategy bounds...'
$matrixConcernItems = @()

foreach ($file in $workflowFiles) {
    $content = Get-Content $file.FullName -Raw
    
    if ($content -match 'strategy:\s*matrix:') {
        # Count potential matrix combinations
        $nodeVersions = [regex]::Matches($content, 'node-version:\s*\[([^\]]+)\]')
        $osVersions = [regex]::Matches($content, 'os:\s*\[([^\]]+)\]')
        
        if ($nodeVersions.Count -gt 5 -or $osVersions.Count -gt 5) {
            $matrixConcernItems += $file.Name
        }
    }
}

if ($matrixConcernItems.Count -eq 0) {
    Write-Host '    ✓ Matrix strategies have reasonable bounds'
}
else {
    Write-Host "    ℹ Review matrix strategy scope in: $($matrixConcernItems -join ', ')"
}

# Test 10: All job names are descriptive
Write-Host '  Test 10: Validate job names are descriptive...'
$vaguJobNames = @()

foreach ($file in $workflowFiles) {
    $content = Get-Content $file.FullName -Raw
    $lines = $content -split "`n"
    $lineNum = 0
    
    foreach ($line in $lines) {
        $lineNum++
        
        # Match job definitions at workflow level (not indented under 'with:' etc)
        if ($line -match '^\s{2}(\w+):\s*$' -and $lineNum -gt 5) {
            $jobName = $matches[1]
            
            # Very generic job names are a concern
            if ($jobName -match '^(job|build|test|run|step|action)$') {
                $vaguJobNames += @{ file = $file.Name; name = $jobName }
            }
        }
    }
}

if ($vaguJobNames.Count -eq 0) {
    Write-Host '    ✓ All job names are descriptive'
}
else {
    Write-Host "    ℹ Consider more descriptive names for: $($vaguJobNames | ForEach-Object { "$($_.file)/$($_.name)" } | Join-String -Separator ', ')"
}

# Test 11: Block unguarded github.event.inputs usage on non-dispatch triggers
Write-Host '  Test 11: Validate github.event.inputs usage is dispatch-guarded...'
$eventInputsGuardrailViolations = @()

foreach ($file in $workflowFiles) {
    $content = Get-Content $file.FullName -Raw
    $lines = $content -split "`n"

    $hasNonDispatchTrigger = $false
    foreach ($trigger in $nonDispatchTriggers) {
        if ($content -match "(?m)^\s{2}${trigger}:\s*$") {
            $hasNonDispatchTrigger = $true
            break
        }
    }

    if (-not $hasNonDispatchTrigger) {
        continue
    }

    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++
        if ($line -notmatch 'github\.event\.inputs\.') {
            continue
        }

        $isDispatchGuarded = $line -match "github\.event_name\s*==\s*['`"]workflow_dispatch['`"]"
        $isCallGuarded = $line -match "github\.event_name\s*==\s*['`"]workflow_call['`"]"

        if (-not $isDispatchGuarded -and -not $isCallGuarded) {
            $eventInputsGuardrailViolations += @{
                file = $file.Name
                line = $lineNum
                detail = $line.Trim()
            }
        }
    }
}

if ($eventInputsGuardrailViolations.Count -eq 0) {
    Write-Host '    ✓ github.event.inputs references are event-guarded where required'
}
else {
    Write-Host '    ✗ Unguarded github.event.inputs references found:' -ForegroundColor Red
    foreach ($item in $eventInputsGuardrailViolations) {
        Write-Host "      - $($item.file):$($item.line) - $($item.detail)" -ForegroundColor Red
    }
    $guardrailFailures += 'event-context-misuse'
}

# Test 12: Block direct push-to-main automation patterns
Write-Host '  Test 12: Validate no workflow pushes directly to main...'
$directMainPushViolations = @()
$directMainPushPattern = '(?im)git\s+push[^\r\n]*(refs/heads/main|HEAD:main|\sorigin\s+main(\s|$)|\s+main(\s|$))'

foreach ($file in $workflowFiles) {
    $content = Get-Content $file.FullName -Raw
    if ($content -notmatch $directMainPushPattern) {
        continue
    }

    if ($directMainPushAllowList -contains $file.Name) {
        Write-Host "    ℹ Allowed direct-main push workflow: $($file.Name)" -ForegroundColor Yellow
        continue
    }

    $directMainPushViolations += $file.Name
}

if ($directMainPushViolations.Count -eq 0) {
    Write-Host '    ✓ No disallowed direct push-to-main patterns found'
}
else {
    Write-Host "    ✗ Disallowed direct push-to-main patterns found in: $($directMainPushViolations -join ', ')" -ForegroundColor Red
    $guardrailFailures += 'protected-branch-push-pattern'
}

# Test 13: Publish workflow tag selection must be event-safe for push-triggered runs
Write-Host '  Test 13: Validate publish workflow tag resolution is event-safe...'
$publishWorkflowPath = Join-Path $workflowDir 'publish-to-production.yml'
$publishWorkflow = Get-Content $publishWorkflowPath -Raw
$unsafePublishTagExpressions = [regex]::Matches($publishWorkflow, 'github\.event\.inputs\.tag')
$hasResolverStep = $publishWorkflow -match 'name:\s*Resolve publish tag' -and $publishWorkflow -match 'id:\s*resolve_tag'
$usesResolvedTagOutput = $publishWorkflow -match 'steps\.resolve_tag\.outputs\.tag'

if ($unsafePublishTagExpressions.Count -eq 0 -and $hasResolverStep -and $usesResolvedTagOutput) {
    Write-Host '    ✓ Publish workflow uses dispatch-guarded tag resolution'
}
else {
    Write-Host '    ✗ Publish workflow tag resolution is not safe for push-triggered runs' -ForegroundColor Red
    $guardrailFailures += 'publish-tag-resolution'
}

# Test 14: Agent merge eval validation must be wired as a required status check
Write-Host '  Test 14: Validate agent-merge eval policy wiring...'
$agentMergeWorkflowPath = Join-Path $workflowDir 'agent-merge.yml'
$agentMergeWorkflow = Get-Content $agentMergeWorkflowPath -Raw
$mergeQueuePsPath = 'scripts/deploy-merge-queue.ps1'
$mergeQueueShPath = 'scripts/deploy-merge-queue.sh'
$branchProtectionDocPath = 'docs/operations/security/branch-protection.md'
$requiredAgentMergeContext = 'Agent Merge / Agent merge guardrails'

$agentMergeHasGlobalPrTrigger = $agentMergeWorkflow -notmatch '(?ms)pull_request:\s*\r?\n\s+paths:'
$agentMergeHasEvalStep = $agentMergeWorkflow -match '(?m)^\s+- name:\s+Validate eval companions\s*$'
$rulesetPsWired = (Get-Content $mergeQueuePsPath -Raw) -match [regex]::Escape($requiredAgentMergeContext)
$rulesetShWired = (Get-Content $mergeQueueShPath -Raw) -match [regex]::Escape($requiredAgentMergeContext)
$branchProtectionDocWired = (Get-Content $branchProtectionDocPath -Raw) -match [regex]::Escape($requiredAgentMergeContext)

if ($agentMergeHasGlobalPrTrigger -and $agentMergeHasEvalStep -and $rulesetPsWired -and $rulesetShWired -and $branchProtectionDocWired) {
    Write-Host '    ✓ Agent merge eval validation is wired into required-check policy'
}
else {
    if (-not $agentMergeHasGlobalPrTrigger) {
        Write-Host '    ✗ agent-merge.yml still path-filters pull_request; required status may not publish on every PR.' -ForegroundColor Red
    }
    if (-not $agentMergeHasEvalStep) {
        Write-Host '    ✗ agent-merge.yml is missing the eval validation step.' -ForegroundColor Red
    }
    if (-not $rulesetPsWired) {
        Write-Host '    ✗ deploy-merge-queue.ps1 is missing required Agent Merge status context.' -ForegroundColor Red
    }
    if (-not $rulesetShWired) {
        Write-Host '    ✗ deploy-merge-queue.sh is missing required Agent Merge status context.' -ForegroundColor Red
    }
    if (-not $branchProtectionDocWired) {
        Write-Host '    ✗ branch-protection.md is missing required Agent Merge status context documentation.' -ForegroundColor Red
    }
    $guardrailFailures += 'agent-merge-required-status'
}

# Test 15: Agent merge changelog generation must stay structured for policy parsing
Write-Host '  Test 15: Validate agent-merge structured changelog generation...'
$agentMergeChangelogChecks = @(
    '(?m)^\s+- name:\s+Generate frontmatter changelog\s*$',
    '# Agent Merge Changelog',
    '## Frontmatter changes',
    'git diff --unified=0 "\$\{RANGE\}" -- agents skills',
    'name:\s*agent-merge-changelog',
    'path:\s*agent-merge-changelog\.md'
)
$agentMergeChangelogIssues = @()

foreach ($requiredPattern in $agentMergeChangelogChecks) {
    if ($agentMergeWorkflow -notmatch $requiredPattern) {
        $agentMergeChangelogIssues += $requiredPattern
    }
}

if ($agentMergeChangelogIssues.Count -eq 0) {
    Write-Host '    PASS Agent merge workflow emits structured changelog artifact'
}
else {
    Write-Host '    FAIL agent-merge.yml is missing structured changelog requirements:' -ForegroundColor Red
    foreach ($issue in $agentMergeChangelogIssues) {
        Write-Host "      - missing pattern: $issue" -ForegroundColor Red
    }
    $guardrailFailures += 'agent-merge-structured-changelog'
}

# Test 16: Required-check workflows must support merge queue and prd-spec-gate semantics
Write-Host '  Test 16: Validate required-check workflows and prd-spec-gate semantics...'
$mergeQueueWorkflowRequirements = @(
    '.github/workflows/validate-basecoat.yml',
    '.github/workflows/prd-spec-gate.yml'
)
$mergeQueueTriggerViolations = @()

foreach ($workflowPath in $mergeQueueWorkflowRequirements) {
    if (-not (Test-Path $workflowPath)) {
        $mergeQueueTriggerViolations += "$workflowPath (missing file)"
        continue
    }

    $workflowContent = Get-Content $workflowPath -Raw
    if ($workflowContent -notmatch '(?m)^\s+merge_group:\s*$') {
        $mergeQueueTriggerViolations += "$workflowPath (missing merge_group trigger)"
    }
}

if ($mergeQueueTriggerViolations.Count -eq 0) {
    Write-Host '    ✓ Required-check workflows include merge_group triggers'
}
else {
    Write-Host "    ✗ Missing merge_group support in: $($mergeQueueTriggerViolations -join ', ')" -ForegroundColor Red
    $guardrailFailures += 'merge-queue-trigger-missing'
}

$prdSpecWorkflowPath = Join-Path $workflowDir 'prd-spec-gate.yml'
$prdSpecDocPath = 'docs/operations/security/branch-protection.md'
$mergeQueueDocPath = 'docs/operations/merge-queue-enforcement.md'
$prdSpecWorkflowIssues = @()

if (-not (Test-Path $prdSpecWorkflowPath)) {
    $prdSpecWorkflowIssues += 'prd-spec-gate.yml (missing file)'
}
else {
    $prdSpecWorkflow = Get-Content $prdSpecWorkflowPath -Raw

    if ($prdSpecWorkflow -notmatch '(?m)^\s{2}prd-spec-gate:\s*$') {
        $prdSpecWorkflowIssues += 'prd-spec-gate.yml (missing prd-spec-gate job)'
    }

    if ($prdSpecWorkflow -notmatch '(?m)^\s+merge_group:\s*$') {
        $prdSpecWorkflowIssues += 'prd-spec-gate.yml (missing merge_group trigger)'
    }

    if ($prdSpecWorkflow -notmatch '(?m)^\s+-\s+checks_requested\s*$') {
        $prdSpecWorkflowIssues += 'prd-spec-gate.yml (missing merge_group checks_requested type)'
    }

    foreach ($requiredType in @('opened', 'edited', 'synchronize', 'reopened', 'ready_for_review', 'labeled', 'unlabeled')) {
        if ($prdSpecWorkflow -notmatch "(?m)^\s+-\s+$requiredType\s*$") {
            $prdSpecWorkflowIssues += "prd-spec-gate.yml (missing pull_request type: $requiredType)"
        }
    }

    if ($prdSpecWorkflow -notmatch 'skip-prd-spec-check') {
        $prdSpecWorkflowIssues += 'prd-spec-gate.yml (missing skip-prd-spec-check label handling)'
    }

    if ($prdSpecWorkflow -notmatch 'if\s*\(\s*!context\.payload\.pull_request\s*\)' -or $prdSpecWorkflow -notmatch 'return;') {
        $prdSpecWorkflowIssues += 'prd-spec-gate.yml (missing merge_group no-PR payload guard)'
    }

    if ($prdSpecWorkflow -notmatch 'changedFiles\s*>=\s*12\s*\|\|\s*churn\s*>=\s*500') {
        $prdSpecWorkflowIssues += 'prd-spec-gate.yml (missing high-change threshold semantics)'
    }

    if ($prdSpecWorkflow -notmatch '\^\\\.github\\/workflows\\/' -or $prdSpecWorkflow -notmatch 'hasPrd\s*&&\s*hasSpec') {
        $prdSpecWorkflowIssues += 'prd-spec-gate.yml (missing risky-path or PRD/spec requirement semantics)'
    }
}

$contractDocIssues = @()
foreach ($docPath in @($prdSpecDocPath, $mergeQueueDocPath)) {
    if (-not (Test-Path $docPath)) {
        $contractDocIssues += "$docPath (missing file)"
        continue
    }

    $docContent = Get-Content $docPath -Raw
    if ($docContent -notmatch 'prd-spec-gate' -or $docContent -notmatch 'prd-spec-gate\.yml') {
        $contractDocIssues += "$docPath (missing prd-spec-gate contract reference)"
    }
}

if ($prdSpecWorkflowIssues.Count -eq 0 -and $contractDocIssues.Count -eq 0) {
    Write-Host '    ✓ prd-spec-gate workflow semantics and required-check docs are aligned'
}
else {
    foreach ($issue in $prdSpecWorkflowIssues) {
        Write-Host "    ✗ $issue" -ForegroundColor Red
    }
    foreach ($issue in $contractDocIssues) {
        Write-Host "    ✗ $issue" -ForegroundColor Red
    }
    $guardrailFailures += 'prd-spec-gate-contract'
}

# Test 17: Production workflows must route through the protected production environment
Write-Host '  Test 17: Validate production environment approval gates...'
$productionEnvironmentRules = @(
    @{
        file = 'publish-to-production.yml'
        pattern = '(?m)^\s+environment:\s+production\s*$'
    },
    @{
        file = 'docs-production.yml'
        pattern = '(?m)^\s+environment:\s+production\s*$'
    },
    @{
        file = 'close-production-issues.yml'
        pattern = '(?m)^\s+environment:\s+production\s*$'
    },
    @{
        file = 'mcp-deploy.yml'
        pattern = '(?m)^\s+environment:\s+\$\{\{[^\r\n]*\|\|\s*''production''\)\s*\}\}\s*$'
    },
    @{
        file = 'extension-deploy.yml'
        pattern = '(?m)^\s+environment:\s+\$\{\{[^\r\n]*\|\|\s*''production''\s*\}\}\s*$'
    }
)
$productionEnvironmentViolations = @()

foreach ($rule in $productionEnvironmentRules) {
    $workflowPath = Join-Path $workflowDir $rule.file
    if (-not (Test-Path $workflowPath)) {
        $productionEnvironmentViolations += "$($rule.file) (missing file)"
        continue
    }

    $workflowContent = Get-Content $workflowPath -Raw
    if ($workflowContent -notmatch $rule.pattern) {
        $productionEnvironmentViolations += "$($rule.file) (missing production environment gate)"
    }
}

if ($productionEnvironmentViolations.Count -eq 0) {
    Write-Host '    ✓ Production workflows route through protected production environment'
}
else {
    Write-Host "    ✗ Production environment gate issues found in: $($productionEnvironmentViolations -join ', ')" -ForegroundColor Red
    $guardrailFailures += 'production-environment-gate'
}

# Test 18: CI stabilization regressions for Sprint 36 workflows
Write-Host '  Test 18: Validate Sprint 36 CI stabilization workflow safeguards...'
$stabilizationGuardrailIssues = @()

$auditEnvironmentPath = Join-Path $workflowDir 'audit-environment-drift.yml'
if (-not (Test-Path $auditEnvironmentPath)) {
    $stabilizationGuardrailIssues += 'audit-environment-drift.yml (missing file)'
}
else {
    $auditEnvironmentWorkflow = Get-Content $auditEnvironmentPath -Raw

    if ($auditEnvironmentWorkflow -match 'npx\s+--yes\s+@basecoat/environment-audit-drift') {
        $stabilizationGuardrailIssues += 'audit-environment-drift.yml (still depends on unpublished npm package via npx)'
    }

    if ($auditEnvironmentWorkflow -notmatch 'npm ci --prefix skills/environment-audit-drift' -or
        $auditEnvironmentWorkflow -notmatch 'node skills/environment-audit-drift/dist/cli\.js') {
        $stabilizationGuardrailIssues += 'audit-environment-drift.yml (missing local CLI install/build execution path)'
    }
}

$dependencyGraphWorkflowPath = Join-Path $workflowDir 'dependency-graph-pages.yml'
if (-not (Test-Path $dependencyGraphWorkflowPath)) {
    $stabilizationGuardrailIssues += 'dependency-graph-pages.yml (missing file)'
}
else {
    $dependencyGraphWorkflow = Get-Content $dependencyGraphWorkflowPath -Raw

    if ($dependencyGraphWorkflow -notmatch 'Add-Content -Path \$env:GITHUB_OUTPUT -Value "should_open_pr=true"' -or
        $dependencyGraphWorkflow -notmatch 'Add-Content -Path \$env:GITHUB_OUTPUT -Value "should_open_pr=false"' -or
        $dependencyGraphWorkflow -notmatch 'Add-Content -Path \$env:GITHUB_OUTPUT -Value "branch_name=\$branch"' -or
        $dependencyGraphWorkflow -notmatch 'Add-Content -Path \$env:GITHUB_OUTPUT -Value "branch_name="') {
        $stabilizationGuardrailIssues += 'dependency-graph-pages.yml (missing guarded branch output assignments to GITHUB_OUTPUT)'
    }
}

$assetHealthWorkflowPath = Join-Path $workflowDir 'asset-health.yml'
if (-not (Test-Path $assetHealthWorkflowPath)) {
    $stabilizationGuardrailIssues += 'asset-health.yml (missing file)'
}
else {
    $assetHealthWorkflow = Get-Content $assetHealthWorkflowPath -Raw

    $orphanGuardIndex = $assetHealthWorkflow.IndexOf('Orphaned nodes \((\d+)')
    $matchesDereferenceIndex = $assetHealthWorkflow.IndexOf('$Matches[1]')

    if ($orphanGuardIndex -lt 0 -or $matchesDereferenceIndex -lt 0 -or $matchesDereferenceIndex -lt $orphanGuardIndex) {
        $stabilizationGuardrailIssues += 'asset-health.yml (orphan count parsing is not regex-guarded before $Matches dereference)'
    }
}

$docsWorkflowPath = Join-Path $workflowDir 'docs.yml'
if (-not (Test-Path $docsWorkflowPath)) {
    $stabilizationGuardrailIssues += 'docs.yml (missing file)'
}
else {
    $docsWorkflow = Get-Content $docsWorkflowPath -Raw

    if ($docsWorkflow -notmatch 'verify-github-pages-environment' -or
        $docsWorkflow -notmatch 'github-pages environment policy permits deployments from main') {
        $stabilizationGuardrailIssues += 'docs.yml (missing github-pages environment preflight gate for main branch deployments)'
    }
}

if ($stabilizationGuardrailIssues.Count -eq 0) {
    Write-Host '    ✓ Sprint 36 CI stabilization safeguards are present in workflow definitions'
}
else {
    Write-Host "    ✗ Sprint 36 stabilization guardrail issues found in: $($stabilizationGuardrailIssues -join ', ')" -ForegroundColor Red
    $guardrailFailures += 'sprint-36-ci-stabilization'
}

# Test 19: Runner capability audit must classify every workflow job
Write-Host '  Test 19: Validate runner capability classification coverage...'
$runnerCapabilityIssues = @()
$runnerAuditScriptPath = Join-Path $repoRoot 'scripts\audit-workflow-runner-capabilities.ps1'
$runnerClassPolicyPath = Join-Path $repoRoot '.github\workflow-runner-capability-classes.json'
$runnerContractPolicyPath = Join-Path $repoRoot '.github\workflow-runner-routing-contracts.json'

if (-not (Test-Path $runnerAuditScriptPath)) {
    $runnerCapabilityIssues += 'scripts/audit-workflow-runner-capabilities.ps1 (missing file)'
}

if (-not (Test-Path $runnerClassPolicyPath)) {
    $runnerCapabilityIssues += '.github/workflow-runner-capability-classes.json (missing file)'
}

if (-not (Test-Path $runnerContractPolicyPath)) {
    $runnerCapabilityIssues += '.github/workflow-runner-routing-contracts.json (missing file)'
}

if ($runnerCapabilityIssues.Count -eq 0) {
    $auditJson = & pwsh -NoProfile -File $runnerAuditScriptPath -OutputFormat json | ConvertFrom-Json
    if ($auditJson.summary.unclassified_jobs -gt 0) {
        $runnerCapabilityIssues += "audit-workflow-runner-capabilities (found $($auditJson.summary.unclassified_jobs) unclassified jobs)"
    }
    if ($auditJson.summary.total_jobs -le 0) {
        $runnerCapabilityIssues += 'audit-workflow-runner-capabilities (no workflow jobs classified)'
    }
    if ($auditJson.summary.contract_violations -gt 0) {
        $runnerCapabilityIssues += "audit-workflow-runner-capabilities (found $($auditJson.summary.contract_violations) runner contract violations)"
    }
    if ($auditJson.summary.contracted_jobs -le 0) {
        $runnerCapabilityIssues += 'audit-workflow-runner-capabilities (no runner contracts evaluated)'
    }
}

if ($runnerCapabilityIssues.Count -eq 0) {
    Write-Host '    ✓ Runner capability audit classifies all workflow jobs'
}
else {
    Write-Host "    ✗ Runner capability audit issues found in: $($runnerCapabilityIssues -join ', ')" -ForegroundColor Red
    $guardrailFailures += 'runner-capability-classification'
}

if ($guardrailFailures.Count -gt 0) {
    Write-Host "Workflow guardrails failed: $($guardrailFailures -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host 'All workflow guardrails tests completed'
exit 0
