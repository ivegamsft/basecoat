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
        # Accept: ${{ github.workflow }}-${{ github.ref }}, format() variants, entity-scoped patterns,
        # and intentional static singleton groups (e.g. publish-production, cloud-agent-execution)
        $hasValidGroup = $content -match 'group:\s*\$\{\{\s*github\.workflow' -or
                         $content -match '(?m)group:\s*\$\{\{[^}]*format\([^)]*github\.workflow' -or
                         $content -match 'group:\s*\$\{\{\s*inputs\.' -or
                         $content -match '(?m)group:\s*[a-zA-Z0-9][a-zA-Z0-9_-]*\s*[\r\n]' -or
                         $content -match 'group:\s*[a-zA-Z0-9_-]+-\$\{\{'
        if (-not $hasValidGroup) {
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
        
        # Match 'uses:' statements — skip comment lines
        if ($line -notmatch '^\s*#' -and $line -match 'uses:\s*(.+)') {
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
        $version = $matches[1].Trim().TrimEnd("`r") -replace '\s*#.*$', ''  # strip CRLF and inline comments
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
$requiredAgentMergeContext = 'BaseCoat - Agent Merge / Agent merge guardrails'

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

    # Policy: require BOTH criteria (AND) to avoid false-positives on pure-additive docs PRs.
    # Changed from OR to AND: see issue #1763 RCA.
    if ($prdSpecWorkflow -notmatch 'changedFiles\s*>=\s*12\s*&&\s*churn\s*>=\s*500') {
        $prdSpecWorkflowIssues += 'prd-spec-gate.yml (missing high-change threshold semantics)'
    }

    if ($prdSpecWorkflow -notmatch "pr\.user\.type\s*===\s*'Bot'" -or
        $prdSpecWorkflow -notmatch "pr\.user\.login\s*===\s*'ibuyspy'" -or
        $prdSpecWorkflow -notmatch 'Skipping PRD/spec gate for bot/agent-authored PR') {
        $prdSpecWorkflowIssues += 'prd-spec-gate.yml (missing bot/agent bypass semantics)'
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

$extensionDeployPath = Join-Path $workflowDir 'extension-deploy.yml'
if (Test-Path $extensionDeployPath) {
    $extensionDeployWorkflow = Get-Content $extensionDeployPath -Raw
    if ($extensionDeployWorkflow -match 'Resolver policy requires human approval.*automated deploy is blocked') {
        Write-Host '    ✗ Extension deployment still rejects protected-environment approval' -ForegroundColor Red
        $guardrailFailures += 'extension-protected-environment-approval'
    }
    elseif ($extensionDeployWorkflow -notmatch '(?s)if \[\[ "\$\{APPROVAL_REQUIRED\}" == "true" \]\]; then\s+if \[\[ "\$\{GITHUB_ENVIRONMENT\}" != "production" \]\]; then.*?exit 1.*?Human approval requirement is enforced by the protected GitHub environment') {
        Write-Host '    ✗ Extension deployment does not fail closed before accepting protected-environment approval' -ForegroundColor Red
        $guardrailFailures += 'extension-protected-environment-approval'
    }
    else {
        Write-Host '    ✓ Extension deployment accepts protected-environment approval'
    }
}

$productionProtectionPath = Join-Path $repoRoot '.github\environment-protection-production.json'
if (Test-Path $productionProtectionPath) {
    $productionProtection = Get-Content $productionProtectionPath -Raw | ConvertFrom-Json
    if ($productionProtection.protection_rules.prevent_self_review -ne $false) {
        Write-Host '    ✗ Production environment would deadlock the designated single reviewer' -ForegroundColor Red
        $guardrailFailures += 'production-environment-self-review'
    }
    else {
        Write-Host '    ✓ Production environment permits the designated single reviewer'
    }
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

    if ($auditEnvironmentWorkflow -match 'npx\s+(--yes\s+)?@basecoat/environment-audit-drift') {
        $stabilizationGuardrailIssues += 'audit-environment-drift.yml (still depends on unpublished npm package via npx)'
    }

    if ($auditEnvironmentWorkflow -notmatch 'npm ci --prefix skills/environment-audit-drift' -or
        $auditEnvironmentWorkflow -notmatch 'node skills/environment-audit-drift/dist/cli\.js') {
        $stabilizationGuardrailIssues += 'audit-environment-drift.yml (missing local CLI install/build execution path)'
    }

    if ($auditEnvironmentWorkflow -notmatch 'Do not use npm registry fallback for @basecoat/environment-audit-drift') {
        $stabilizationGuardrailIssues += 'audit-environment-drift.yml (missing explicit npm-registry fallback guardrail for local CLI source)'
    }
}

$auditTemplatePath = 'skills/environment-audit-drift/templates/audit-environment-drift.yml'
if (-not (Test-Path $auditTemplatePath)) {
    $stabilizationGuardrailIssues += 'skills/environment-audit-drift/templates/audit-environment-drift.yml (missing file)'
}
else {
    $auditTemplateWorkflow = Get-Content $auditTemplatePath -Raw
    $templateLines = $auditTemplateWorkflow -split "`n"
    $templateLineNum = 0
    foreach ($templateLine in $templateLines) {
        $templateLineNum++
        if ($templateLine -match 'uses:\s*(.+)') {
            $templateUses = $matches[1].Trim()
            if ($templateUses -notmatch '@[a-f0-9]{40}$') {
                $stabilizationGuardrailIssues += "skills/environment-audit-drift/templates/audit-environment-drift.yml:$templateLineNum (action reference must be pinned to a full-length SHA: $templateUses)"
            }
        }
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

    if ($dependencyGraphWorkflow -match '"- Source workflow: `\.github/workflows/dependency-graph-pages\.yml`"') {
        $stabilizationGuardrailIssues += 'dependency-graph-pages.yml (uses markdown backticks in a PowerShell double-quoted string, which can escape the terminator and break parsing)'
    }

    if ($dependencyGraphWorkflow -notmatch '''- Source workflow: \.github/workflows/dependency-graph-pages\.yml''') {
        $stabilizationGuardrailIssues += 'dependency-graph-pages.yml (missing parser-safe source workflow metadata line in dependency graph report content)'
    }

    # Regression: stdout must be flattened (joined) before interpolation so the
    # report never contains the literal string "System.Object[]".
    if ($dependencyGraphWorkflow -notmatch [regex]::Escape('(pwsh scripts/graph-dependencies.ps1') -or
        $dependencyGraphWorkflow -notmatch [regex]::Escape(') -join "')) {
        $stabilizationGuardrailIssues += 'dependency-graph-pages.yml (graph-dependencies.ps1 stdout must be joined with -join before interpolation to prevent System.Object[] in the report)'
    }
}

$assetHealthWorkflowPath = Join-Path $workflowDir 'asset-health.yml'
if (-not (Test-Path $assetHealthWorkflowPath)) {
    $stabilizationGuardrailIssues += 'asset-health.yml (missing file)'
}
else {
    $assetHealthWorkflow = Get-Content $assetHealthWorkflowPath -Raw

    $orphanGuardIndex = $assetHealthWorkflow.IndexOf('Orphaned nodes \((\d+)')
    $regexMatchIndex = $assetHealthWorkflow.IndexOf('[regex]::Match($graphText')
    $groupValueIndex = $assetHealthWorkflow.IndexOf('$orphanMatch.Groups[1].Value')
    $legacyMatchesIndex = $assetHealthWorkflow.IndexOf('$Matches[1]')

    if ($orphanGuardIndex -lt 0 -or
        $regexMatchIndex -lt 0 -or
        $groupValueIndex -lt 0 -or
        $groupValueIndex -lt $regexMatchIndex -or
        $legacyMatchesIndex -ge 0) {
        $stabilizationGuardrailIssues += 'asset-health.yml (orphan count parsing is not guarded via [regex]::Match before capture-group read)'
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
    if ($auditJson.summary.mismatches -gt 0) {
        $runnerCapabilityIssues += "audit-workflow-runner-capabilities (found $($auditJson.summary.mismatches) runner mismatches)"
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

# Test 20: Incident regression — production dispatch jobs must stay on Ubuntu/bash
# and must never inline PRODUCTION_REPO_TOKEN into run: bodies (RCA: run 30214820425).
# The runner/shell checks are scoped to the specific named dispatch job block so an
# unrelated Ubuntu/bash job added later cannot mask a regression on the dispatch job.
# The token check parses run: block boundaries so a secret interpolated inside a
# run: body is rejected even if the line resembles an env: assignment.
Write-Host '  Test 20: Validate production dispatch jobs (runner/shell/token exposure)...'
$dispatchRegressionTargets = @(
    @{ File = 'docs-production.yml'; Job = 'dispatch-production-docs' },
    @{ File = 'close-production-issues.yml'; Job = 'close-issues' }
)
$dispatchRegressionViolations = @()
$tokenEnvAssignmentPattern = '^\s*[A-Za-z_][A-Za-z0-9_]*:\s*\$\{\{\s*secrets\.PRODUCTION_REPO_TOKEN\s*\}\}\s*$'

# Extract a single job block (from "  <job>:" until the next line indented <= 2 spaces).
function Get-WorkflowJobBlock {
    param([string[]] $Lines, [string] $JobName)
    $start = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match "^\s{2}$([regex]::Escape($JobName)):\s*$") { $start = $i; break }
    }
    if ($start -lt 0) { return $null }
    $block = @()
    for ($i = $start + 1; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        if ($line.Trim().Length -gt 0 -and $line -notmatch '^\s{3,}') { break }
        $block += $line
    }
    return , $block
}

foreach ($target in $dispatchRegressionTargets) {
    $file = $target.File
    $job = $target.Job
    $workflowPath = Join-Path $workflowDir $file
    if (-not (Test-Path $workflowPath)) {
        $dispatchRegressionViolations += "$file (missing file)"
        continue
    }

    $lines = Get-Content $workflowPath
    $jobBlock = Get-WorkflowJobBlock -Lines $lines -JobName $job
    if ($null -eq $jobBlock -or $jobBlock.Count -eq 0) {
        $dispatchRegressionViolations += "$file (job '$job' not found)"
        continue
    }

    if (-not ($jobBlock | Where-Object { $_ -match '^\s+runs-on:\s+ubuntu-latest\s*$' })) {
        $dispatchRegressionViolations += "$file/$job (not pinned to ubuntu-latest)"
    }
    if (-not ($jobBlock | Where-Object { $_ -match '^\s+shell:\s+bash\s*$' })) {
        $dispatchRegressionViolations += "$file/$job (missing shell: bash default)"
    }

    # Walk the whole file tracking run: block boundaries. PRODUCTION_REPO_TOKEN may
    # only appear as a top-level env: assignment — never inside a run: body, and
    # never on a non-env line elsewhere.
    $inRunBlock = $false
    $runBlockIndent = 0
    foreach ($line in $lines) {
        $hasToken = $line -match 'secrets\.PRODUCTION_REPO_TOKEN'
        $indent = ($line -replace '\S.*$', '').Length

        if ($inRunBlock) {
            if ($line.Trim().Length -gt 0 -and $indent -le $runBlockIndent) {
                $inRunBlock = $false
            }
            elseif ($hasToken) {
                $dispatchRegressionViolations += "$file (PRODUCTION_REPO_TOKEN inside run: body — leak risk)"
                continue
            }
            else {
                continue
            }
        }

        if ($line -match '^(\s*)run:\s*[|>]') {
            $inRunBlock = $true
            $runBlockIndent = $matches[1].Length
            continue
        }
        if ($line -match '^\s*run:\s*\S' -and $hasToken) {
            $dispatchRegressionViolations += "$file (PRODUCTION_REPO_TOKEN inlined in run: line — leak risk)"
            continue
        }
        if ($hasToken -and $line -notmatch $tokenEnvAssignmentPattern) {
            $dispatchRegressionViolations += "$file (PRODUCTION_REPO_TOKEN referenced outside env: assignment — leak risk)"
        }
    }
}

if ($dispatchRegressionViolations.Count -eq 0) {
    Write-Host '    PASS Production dispatch jobs are Ubuntu/bash and never inline PRODUCTION_REPO_TOKEN'
}
else {
    Write-Host "    FAIL Production dispatch regression issues found in: $($dispatchRegressionViolations -join ', ')" -ForegroundColor Red
    $guardrailFailures += 'production-dispatch-runner-token-regression'
}

# Test 21: Public Linux publication/deployment jobs must remain explicitly
# GitHub-hosted, audit-aligned, and free of private-runner requirements.
Write-Host '  Test 21: Validate public Linux runner routing contracts...'
$publicLinuxRoutingViolations = @()

if ($null -eq $auditJson) {
    $auditJson = & pwsh -NoProfile -File $runnerAuditScriptPath -OutputFormat json | ConvertFrom-Json
}
$runnerContractData = Get-Content $runnerContractPolicyPath -Raw | ConvertFrom-Json
$runnerContracts = @($runnerContractData.contracts)
$expectedPublicContracts = @(
    @{ Workflow = 'audit-environment-drift.yml'; Job = 'audit'; RequiredCapabilities = @('public-internet') },
    @{ Workflow = 'close-production-issues.yml'; Job = 'close-issues'; RequiredCapabilities = @('public-api-dispatch') },
    @{ Workflow = 'docs-production.yml'; Job = 'dispatch-production-docs'; RequiredCapabilities = @('public-api-dispatch') },
    @{ Workflow = 'docs.yml'; Job = 'deploy'; RequiredCapabilities = @('oidc', 'public-pages-deploy') },
    @{ Workflow = 'extension-deploy.yml'; Job = 'build-push'; RequiredCapabilities = @('public-registry-publish') },
    @{ Workflow = 'extension-deploy.yml'; Job = 'deploy'; RequiredCapabilities = @('credential-auth', 'public-cloud-deploy') },
    @{ Workflow = 'mcp-build.yml'; Job = 'build'; RequiredCapabilities = @('public-build') },
    @{ Workflow = 'mcp-deploy.yml'; Job = 'build-push'; RequiredCapabilities = @('public-registry-publish') },
    @{ Workflow = 'mcp-deploy.yml'; Job = 'deploy'; RequiredCapabilities = @('credential-auth', 'public-cloud-deploy') },
    @{ Workflow = 'package-basecoat.yml'; Job = 'release'; RequiredCapabilities = @('public-release-publish') },
    @{ Workflow = 'portal-deploy.yml'; Job = 'deploy'; RequiredCapabilities = @('credential-auth', 'oidc', 'public-cloud-deploy') },
    @{ Workflow = 'publish-to-production.yml'; Job = 'publish'; RequiredCapabilities = @('public-release-publish') },
    @{ Workflow = 'release.yml'; Job = 'release'; RequiredCapabilities = @('public-release-publish') }
)

if ($runnerContractData.version -ne 2) {
    $publicLinuxRoutingViolations += "contract schema version is '$($runnerContractData.version)' (expected 2)"
}

$contractKeys = @()
foreach ($contract in $runnerContracts) {
    $contractKey = "$($contract.workflow)|$($contract.job)"
    $contractKeys += $contractKey
    foreach ($requiredField in @(
        'workflow',
        'job',
        'allowed_runner_classes',
        'required_capabilities',
        'forbidden_capabilities',
        'max_timeout_minutes'
    )) {
        if ($contract.PSObject.Properties.Name -notcontains $requiredField) {
            $publicLinuxRoutingViolations += "$contractKey (missing v2 field '$requiredField')"
        }
    }

    if (@($contract.allowed_runner_classes).Count -eq 0) {
        $publicLinuxRoutingViolations += "$contractKey (allowed_runner_classes must not be empty)"
    }
    if (@($contract.required_capabilities).Count -eq 0) {
        $publicLinuxRoutingViolations += "$contractKey (required_capabilities must not be empty)"
    }
    if (@($contract.forbidden_capabilities).Count -eq 0) {
        $publicLinuxRoutingViolations += "$contractKey (forbidden_capabilities must not be empty)"
    }
    if ($null -eq $contract.max_timeout_minutes -or [int]$contract.max_timeout_minutes -le 0) {
        $publicLinuxRoutingViolations += "$contractKey (max_timeout_minutes must be positive)"
    }
}

foreach ($duplicateKey in @($contractKeys | Group-Object | Where-Object { $_.Count -gt 1 })) {
    $publicLinuxRoutingViolations += "$($duplicateKey.Name) (duplicate routing contract)"
}

$expectedPublicContractKeys = @(
    $expectedPublicContracts |
        ForEach-Object { "$($_.Workflow)|$($_.Job)" } |
        Sort-Object
)
$publicLinuxContractKeys = @(
    $runnerContracts |
        Where-Object {
            $allowedClasses = @($_.allowed_runner_classes)
            $allowedClasses.Count -eq 1 -and
                $allowedClasses[0] -eq 'github-hosted-linux'
        } |
        ForEach-Object { "$($_.workflow)|$($_.job)" } |
        Sort-Object
)
if (($publicLinuxContractKeys -join ',') -ne ($expectedPublicContractKeys -join ',')) {
    $publicLinuxRoutingViolations += "public Linux contract set changed (actual: '$($publicLinuxContractKeys -join ', ')')"
}

foreach ($expectedContract in $expectedPublicContracts) {
    $workflow = $expectedContract.Workflow
    $job = $expectedContract.Job
    $expectedKey = "$workflow|$job"
    $matchingContracts = @($runnerContracts | Where-Object {
        $_.workflow -eq $workflow -and $_.job -eq $job
    })
    if ($matchingContracts.Count -ne 1) {
        $publicLinuxRoutingViolations += "$expectedKey (expected one routing contract, found $($matchingContracts.Count))"
        continue
    }
    $target = $matchingContracts[0]
    $actualRequiredCapabilities = @($target.required_capabilities | Sort-Object)
    $expectedRequiredCapabilities = @($expectedContract.RequiredCapabilities | Sort-Object)
    if (($actualRequiredCapabilities -join ',') -ne ($expectedRequiredCapabilities -join ',')) {
        $publicLinuxRoutingViolations += "$expectedKey (required_capabilities changed: '$($actualRequiredCapabilities -join ', ')')"
    }
    $expectedForbiddenCapabilities = @('private-network', 'runner-managed-identity')
    if ($expectedKey -in @('extension-deploy.yml|deploy', 'mcp-deploy.yml|deploy')) {
        $expectedForbiddenCapabilities += 'oidc'
    }
    $actualForbiddenCapabilities = @($target.forbidden_capabilities | Sort-Object)
    $expectedForbiddenCapabilities = @($expectedForbiddenCapabilities | Sort-Object)
    if (($actualForbiddenCapabilities -join ',') -ne ($expectedForbiddenCapabilities -join ',')) {
        $publicLinuxRoutingViolations += "$expectedKey (forbidden_capabilities changed: '$($actualForbiddenCapabilities -join ', ')')"
    }

    $auditRow = @($auditJson.jobs | Where-Object {
        $_.Workflow -eq $workflow -and $_.Job -eq $job
    })
    if ($auditRow.Count -ne 1) {
        $publicLinuxRoutingViolations += "$workflow/$job (expected one audit row, found $($auditRow.Count))"
        continue
    }

    $row = $auditRow[0]
    if ($row.RunsOn -ne 'ubuntu-latest' -or
        $row.ActualRunnerClass -ne 'github-hosted-linux' -or
        $row.RecommendedRunnerClass -ne 'github-hosted-linux' -or
        $row.Status -ne 'aligned') {
        $publicLinuxRoutingViolations += "$workflow/$job (audit routing is $($row.RecommendedRunnerClass)/$($row.ActualRunnerClass)/$($row.Status))"
    }
    $rowCapabilities = @($row.RequiredCapabilities -split ',' | ForEach-Object { $_.Trim() })
    foreach ($capability in @($target.required_capabilities)) {
        if ($rowCapabilities -notcontains $capability) {
            $publicLinuxRoutingViolations += "$workflow/$job (missing capability '$capability')"
        }
    }
    foreach ($capability in @($target.forbidden_capabilities)) {
        if ($rowCapabilities -contains $capability) {
            $publicLinuxRoutingViolations += "$workflow/$job (forbidden capability '$capability')"
        }
    }

    $allowedClasses = @($target.allowed_runner_classes)
    if ($allowedClasses.Count -ne 1 -or $allowedClasses[0] -ne 'github-hosted-linux') {
        $publicLinuxRoutingViolations += "$workflow/$job (contract must allow only github-hosted-linux)"
    }
    $forbiddenCapabilities = @($target.forbidden_capabilities)
    foreach ($requiredForbiddenCapability in @('private-network', 'runner-managed-identity')) {
        if ($forbiddenCapabilities -notcontains $requiredForbiddenCapability) {
            $publicLinuxRoutingViolations += "$workflow/$job (contract must forbid '$requiredForbiddenCapability')"
        }
    }
}

if ($publicLinuxRoutingViolations.Count -eq 0) {
    Write-Host '    PASS Public Linux jobs are pinned, audit-aligned, and contract-restricted'
}
else {
    Write-Host "    FAIL Public Linux runner routing issues found in: $($publicLinuxRoutingViolations -join ', ')" -ForegroundColor Red
    $guardrailFailures += 'public-linux-runner-routing'
}

# Test 22: Authentication mode, permission inheritance, and private workload
# evidence must remain independent from the assigned runner.
Write-Host '  Test 22: Validate authentication and private capability inference...'
$runnerFixtureDir = Join-Path $repoRoot 'tests\fixtures\workflow-runner-capabilities'
$runnerFixtureContractPath = Join-Path $runnerFixtureDir 'contracts.json'
$malformedClassPath = Join-Path $runnerFixtureDir 'malformed-classes.json'
$emptyClassPath = Join-Path $runnerFixtureDir 'empty-classes.json'
$runnerFixtureAudit = & pwsh -NoProfile -File $runnerAuditScriptPath `
    -OutputFormat json `
    -WorkflowDirectory $runnerFixtureDir `
    -ContractPath $runnerFixtureContractPath | ConvertFrom-Json
$runnerSeparationViolations = @()

$runnerHealthScriptPath = Join-Path $repoRoot 'scripts\report-runner-health.ps1'
if (-not (Test-Path $runnerHealthScriptPath)) {
    $runnerSeparationViolations += 'runner health contract filtering (script missing)'
}
else {
    $runnerHealthSource = Get-Content $runnerHealthScriptPath -Raw
    if ($runnerHealthSource -notmatch 'workflow-runner-routing-contracts\.json' -or
        $runnerHealthSource -notmatch 'Test-IsContractedGithubHostedJob' -or
        $runnerHealthSource -notmatch 'Get-GithubHostedRunnerClass' -or
        $runnerHealthSource -notmatch 'Test-HasGithubHostedContract' -or
        $runnerHealthSource -notmatch '\$hasGithubHostedContract') {
        $runnerSeparationViolations += 'runner health contract filtering (contracted public failures still treated as wrong-runner evidence)'
    }

    $runnerHealthTestRoot = Join-Path $repoRoot "tests\.runner-health-test-$([guid]::NewGuid().ToString('N'))"
    $runnerHealthFakeBin = Join-Path $runnerHealthTestRoot 'bin'
    $runnerHealthContractPath = Join-Path $runnerHealthTestRoot 'contracts.json'
    $originalPath = $env:PATH
    $originalRunnerLabels = $env:BASECOAT_TEST_RUNNER_LABELS
    $originalRunnerJobName = $env:BASECOAT_TEST_RUNNER_JOB_NAME
    try {
        New-Item -ItemType Directory -Path $runnerHealthFakeBin -Force | Out-Null
        @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
$endpoint = ($Arguments -join ' ')
$now = (Get-Date).ToUniversalTime()
if ($endpoint -match 'actions/workflows/release\.yml/runs') {
    [pscustomobject]@{
        workflow_runs = @(
            [pscustomobject]@{
                id = 42
                created_at = $now.AddMinutes(-10).ToString('o')
                run_started_at = $now.AddMinutes(-9).ToString('o')
                updated_at = $now.AddMinutes(-1).ToString('o')
                conclusion = 'failure'
                html_url = 'https://example.test/runs/42'
                run_attempt = 1
            }
        )
    } | ConvertTo-Json -Depth 8 -Compress
}
elseif ($endpoint -match 'actions/runs/42/jobs') {
    [pscustomobject]@{
        jobs = @(
            [pscustomobject]@{
                name = if ($env:BASECOAT_TEST_RUNNER_JOB_NAME) { $env:BASECOAT_TEST_RUNNER_JOB_NAME } else { 'release' }
                conclusion = 'failure'
                runner_name = 'GitHub Actions 1'
                started_at = $now.AddMinutes(-9).ToString('o')
                labels = @($env:BASECOAT_TEST_RUNNER_LABELS -split ',')
            }
        )
    } | ConvertTo-Json -Depth 8 -Compress
}
elseif ($endpoint -match 'actions/runners') {
    [pscustomobject]@{ runners = @() } | ConvertTo-Json -Depth 4 -Compress
}
else {
    [pscustomobject]@{ workflow_runs = @() } | ConvertTo-Json -Depth 4 -Compress
}
'@ | Set-Content -Path (Join-Path $runnerHealthFakeBin 'fake-gh.ps1')
        Set-Content -Path (Join-Path $runnerHealthFakeBin 'gh.cmd') -Value '@pwsh -NoProfile -File "%~dp0fake-gh.ps1" %*'
        @'
#!/usr/bin/env bash
exec pwsh -NoProfile -File "$(dirname "$0")/fake-gh.ps1" "$@"
'@ | Set-Content -Path (Join-Path $runnerHealthFakeBin 'gh') -NoNewline
        if (-not $IsWindows) {
            chmod +x (Join-Path $runnerHealthFakeBin 'gh')
        }
        @{
            version = 2
            contracts = @(
                @{
                    workflow = 'release.yml'
                    job = 'release'
                    allowed_runner_classes = @('github-hosted-linux')
                    required_capabilities = @('public-release-publish')
                    forbidden_capabilities = @('private-network')
                    max_timeout_minutes = 20
                }
            )
        } | ConvertTo-Json -Depth 8 | Set-Content -Path $runnerHealthContractPath
        $env:PATH = "$runnerHealthFakeBin$([IO.Path]::PathSeparator)$originalPath"

        $env:BASECOAT_TEST_RUNNER_JOB_NAME = 'release'
        $env:BASECOAT_TEST_RUNNER_LABELS = 'ubuntu-latest'
        $approvedLinuxReport = & pwsh -NoProfile -File $runnerHealthScriptPath `
            -Repository 'example/repo' `
            -LookbackDays 1 `
            -OutputFormat json `
            -ContractPath $runnerHealthContractPath | ConvertFrom-Json
        if ($approvedLinuxReport.summary.potential_wrong_runner_patterns -ne 0) {
            $runnerSeparationViolations += 'runner health exact class filtering (approved Linux failure was flagged)'
        }

        $env:BASECOAT_TEST_RUNNER_JOB_NAME = 'release'
        $env:BASECOAT_TEST_RUNNER_LABELS = 'windows-latest'
        $disallowedWindowsReport = & pwsh -NoProfile -File $runnerHealthScriptPath `
            -Repository 'example/repo' `
            -LookbackDays 1 `
            -OutputFormat json `
            -ContractPath $runnerHealthContractPath | ConvertFrom-Json
        if ($disallowedWindowsReport.summary.potential_wrong_runner_patterns -ne 1) {
            $runnerSeparationViolations += 'runner health exact class filtering (disallowed Windows failure was suppressed)'
        }

        $env:BASECOAT_TEST_RUNNER_JOB_NAME = 'release'
        $env:BASECOAT_TEST_RUNNER_LABELS = 'self-hosted,ubuntu-latest'
        $selfHostedLinuxReport = & pwsh -NoProfile -File $runnerHealthScriptPath `
            -Repository 'example/repo' `
            -LookbackDays 1 `
            -OutputFormat json `
            -ContractPath $runnerHealthContractPath | ConvertFrom-Json
        if ($selfHostedLinuxReport.summary.potential_wrong_runner_patterns -ne 1) {
            $runnerSeparationViolations += 'runner health hosted class filtering (self-hosted label set was suppressed)'
        }
        elseif ($selfHostedLinuxReport.wrong_runner_patterns[0].pattern_description -ne
            'contracted-public-job-failed-on-self-hosted-runner') {
            $runnerSeparationViolations += 'runner health hosted class filtering (self-hosted pattern was mislabeled)'
        }

        $env:BASECOAT_TEST_RUNNER_JOB_NAME = 'package'
        $env:BASECOAT_TEST_RUNNER_LABELS = 'ubuntu-latest'
        $uncontractedHostedReport = & pwsh -NoProfile -File $runnerHealthScriptPath `
            -Repository 'example/repo' `
            -LookbackDays 1 `
            -OutputFormat json `
            -ContractPath $runnerHealthContractPath | ConvertFrom-Json
        if ($uncontractedHostedReport.summary.potential_wrong_runner_patterns -ne 0) {
            $runnerSeparationViolations += 'runner health contract scope (uncontracted hosted failure was flagged)'
        }

        $env:BASECOAT_TEST_RUNNER_JOB_NAME = 'production-token-preflight / Validate token is configured'
        $env:BASECOAT_TEST_RUNNER_LABELS = 'ubuntu-latest'
        $delegatedHostedReport = & pwsh -NoProfile -File $runnerHealthScriptPath `
            -Repository 'example/repo' `
            -LookbackDays 1 `
            -OutputFormat json `
            -ContractPath $runnerHealthContractPath | ConvertFrom-Json
        if ($delegatedHostedReport.summary.potential_wrong_runner_patterns -ne 0) {
            $runnerSeparationViolations += 'runner health delegated filtering (reusable hosted child was flagged)'
        }
    }
    finally {
        $env:PATH = $originalPath
        $env:BASECOAT_TEST_RUNNER_LABELS = $originalRunnerLabels
        $env:BASECOAT_TEST_RUNNER_JOB_NAME = $originalRunnerJobName
        if (Test-Path $runnerHealthTestRoot) {
            Remove-Item -Path $runnerHealthTestRoot -Recurse -Force
        }
    }
}

$malformedClassOutput = ''
$malformedClassRejected = $false
try {
    & $runnerAuditScriptPath `
        -OutputFormat json `
        -WorkflowDirectory $runnerFixtureDir `
        -ClassPath $malformedClassPath `
        -ContractPath $runnerFixtureContractPath | Out-Null
}
catch {
    $malformedClassRejected = $true
    $malformedClassOutput = $_.Exception.Message
}
$missingMalformedClassDiagnostics = @(
    'fractional-priority',
    'text-priority',
    'text-recommendation-flag',
    'capabilities must contain only non-empty strings',
    'scalar-required-all',
    'scalar-required-any'
) | Where-Object { $malformedClassOutput -notmatch [regex]::Escape($_) }
if (-not $malformedClassRejected -or $missingMalformedClassDiagnostics.Count -gt 0) {
    $missingSummary = if ($missingMalformedClassDiagnostics.Count -gt 0) {
        "; missing diagnostics: $($missingMalformedClassDiagnostics -join ', ')"
    }
    else { '' }
    $runnerSeparationViolations += "malformed runner class fixture (invalid class catalog field accepted$missingSummary)"
}

$emptyClassOutput = (& pwsh -NoProfile -File $runnerAuditScriptPath `
    -OutputFormat json `
    -WorkflowDirectory $runnerFixtureDir `
    -ClassPath $emptyClassPath `
    -ContractPath $runnerFixtureContractPath 2>&1) -join "`n"
if ($LASTEXITCODE -eq 0 -or $emptyClassOutput -notmatch 'classes must be a non-empty array') {
    $runnerSeparationViolations += 'empty runner class fixture (empty catalog accepted)'
}

$fixtureRows = @($runnerFixtureAudit.jobs)
if ($runnerFixtureAudit.summary.mismatches -ne 3) {
    $runnerSeparationViolations += "fixture audit (expected three unnecessary-runner mismatches, found $($runnerFixtureAudit.summary.mismatches))"
}

$publicOidcRow = @($runnerFixtureAudit.jobs | Where-Object {
    $_.Workflow -eq 'public-oidc-deploy.yml' -and $_.Job -eq 'deploy'
})
if ($publicOidcRow.Count -ne 1) {
    $runnerSeparationViolations += 'public OIDC fixture (missing audit row)'
}
else {
    $publicCaps = @($publicOidcRow[0].RequiredCapabilities -split ',' | ForEach-Object { $_.Trim() })
    if ($publicOidcRow[0].RecommendedRunnerClass -ne 'github-hosted-linux' -or
        $publicOidcRow[0].Status -ne 'aligned' -or
        $publicCaps -notcontains 'oidc' -or
        $publicCaps -contains 'credential-auth' -or
        $publicCaps -contains 'private-network' -or
        $publicCaps -contains 'runner-managed-identity') {
        $runnerSeparationViolations += 'public OIDC fixture (incorrectly requires private runner)'
    }
}

$publicCredentialRow = @($fixtureRows | Where-Object {
    $_.Workflow -eq 'public-credential-deploy.yml' -and $_.Job -eq 'deploy'
})
if ($publicCredentialRow.Count -ne 1) {
    $runnerSeparationViolations += 'public credential fixture (missing audit row)'
}
else {
    $credentialCaps = @($publicCredentialRow[0].RequiredCapabilities -split ',' | ForEach-Object { $_.Trim() })
    if ($publicCredentialRow[0].RecommendedRunnerClass -ne 'github-hosted-linux' -or
        $publicCredentialRow[0].Status -ne 'aligned' -or
        $credentialCaps -notcontains 'credential-auth' -or
        $credentialCaps -contains 'oidc') {
        $runnerSeparationViolations += 'public credential fixture (credential login misclassified as OIDC)'
    }
}

$commentedLoginInputsRow = @($fixtureRows | Where-Object {
    $_.Workflow -eq 'commented-login-inputs.yml' -and $_.Job -eq 'deploy'
})
if ($commentedLoginInputsRow.Count -ne 1) {
    $runnerSeparationViolations += 'commented Azure Login inputs fixture (missing audit row)'
}
else {
    $commentedLoginCaps = @($commentedLoginInputsRow[0].RequiredCapabilities -split ',' | ForEach-Object { $_.Trim() })
    if ($commentedLoginInputsRow[0].RecommendedRunnerClass -ne 'github-hosted-linux' -or
        $commentedLoginInputsRow[0].Status -ne 'aligned' -or
        $commentedLoginCaps -contains 'oidc' -or
        $commentedLoginCaps -contains 'credential-auth') {
        $runnerSeparationViolations += 'commented Azure Login inputs fixture (placeholder treated as authentication evidence)'
    }
}

$commentedPermissionRow = @($fixtureRows | Where-Object {
    $_.Workflow -eq 'commented-oidc-permission.yml' -and $_.Job -eq 'deploy'
})
if ($commentedPermissionRow.Count -ne 1) {
    $runnerSeparationViolations += 'commented OIDC permission fixture (missing audit row)'
}
else {
    $commentedPermissionCaps = @($commentedPermissionRow[0].RequiredCapabilities -split ',' | ForEach-Object { $_.Trim() })
    if ($commentedPermissionCaps -contains 'oidc') {
        $runnerSeparationViolations += 'commented OIDC permission fixture (disabled permission inferred as capability evidence)'
    }
}

$siblingPermissionRow = @($fixtureRows | Where-Object {
    $_.Workflow -eq 'sibling-permission-isolation.yml' -and $_.Job -eq 'deploy'
})
if ($siblingPermissionRow.Count -ne 1) {
    $runnerSeparationViolations += 'sibling permission fixture (missing deploy audit row)'
}
else {
    $siblingCaps = @($siblingPermissionRow[0].RequiredCapabilities -split ',' | ForEach-Object { $_.Trim() })
    if ($siblingCaps -contains 'oidc') {
        $runnerSeparationViolations += 'sibling permission fixture (job-level OIDC permission leaked across jobs)'
    }
}

$unnecessarySelfHostedRow = @($fixtureRows | Where-Object {
    $_.Workflow -eq 'unnecessary-self-hosted-public.yml' -and $_.Job -eq 'public-job'
})
if ($unnecessarySelfHostedRow.Count -ne 1) {
    $runnerSeparationViolations += 'unnecessary self-hosted fixture (missing audit row)'
}
else {
    $unnecessaryCaps = @($unnecessarySelfHostedRow[0].RequiredCapabilities -split ',' | ForEach-Object { $_.Trim() })
    if ($unnecessarySelfHostedRow[0].ActualRunnerClass -ne 'self-hosted-linux' -or
        $unnecessarySelfHostedRow[0].RecommendedRunnerClass -ne 'github-hosted-linux' -or
        $unnecessarySelfHostedRow[0].Status -ne 'mismatch' -or
        $unnecessaryCaps -contains 'private-network') {
        $runnerSeparationViolations += 'unnecessary self-hosted fixture (runner assignment became circular capability evidence)'
    }
}

$markerTextRow = @($fixtureRows | Where-Object {
    $_.Workflow -eq 'marker-text-is-not-evidence.yml' -and $_.Job -eq 'public-job'
})
if ($markerTextRow.Count -ne 1) {
    $runnerSeparationViolations += 'marker text fixture (missing audit row)'
}
else {
    $markerTextCapabilities = @($markerTextRow[0].RequiredCapabilities -split ',' | ForEach-Object { $_.Trim() })
    if ($markerTextCapabilities -contains 'private-network' -or
        $markerTextCapabilities -contains 'oidc' -or
        $markerTextCapabilities -contains 'public-cloud-deploy' -or
        $markerTextCapabilities -contains 'public-registry-publish' -or
        $markerTextCapabilities -contains 'public-build' -or
        $markerTextCapabilities -contains 'public-release-publish' -or
        $markerTextRow[0].RecommendedRunnerClass -ne 'github-hosted-linux' -or
        $markerTextRow[0].Status -ne 'mismatch') {
        $runnerSeparationViolations += 'marker text fixture (block-scalar command text inferred as capability evidence)'
    }
}

$privateNetworkRow = @($fixtureRows | Where-Object {
    $_.Workflow -eq 'private-network-deploy.yml' -and $_.Job -eq 'deploy'
})
if ($privateNetworkRow.Count -ne 1) {
    $runnerSeparationViolations += 'private network fixture (missing audit row)'
}
else {
    $privateNetworkCaps = @($privateNetworkRow[0].RequiredCapabilities -split ',' | ForEach-Object { $_.Trim() })
    if ($privateNetworkRow[0].RecommendedRunnerClass -ne 'self-hosted-linux' -or
        $privateNetworkRow[0].Status -ne 'aligned' -or
        $privateNetworkCaps -notcontains 'private-network') {
        $runnerSeparationViolations += 'private network fixture (explicit workload marker was not honored)'
    }
}

$privateIdentityRow = @($runnerFixtureAudit.jobs | Where-Object {
    $_.Workflow -eq 'private-identity-deploy.yml' -and $_.Job -eq 'deploy'
})
if ($privateIdentityRow.Count -ne 1) {
    $runnerSeparationViolations += 'private identity fixture (missing audit row)'
}
else {
    $privateCaps = @($privateIdentityRow[0].RequiredCapabilities -split ',' | ForEach-Object { $_.Trim() })
    if ($privateIdentityRow[0].RecommendedRunnerClass -ne 'self-hosted-linux' -or
        $privateIdentityRow[0].Status -ne 'aligned' -or
        $privateCaps -notcontains 'runner-managed-identity' -or
        $privateCaps -contains 'oidc') {
        $runnerSeparationViolations += 'private identity fixture (private requirements were masked)'
    }
}

$multilineIdentityRows = @($runnerFixtureAudit.jobs | Where-Object {
    $_.Workflow -eq 'multiline-runner-identity.yml'
})
if ($multilineIdentityRows.Count -ne 13 -or
    @($multilineIdentityRows | Where-Object {
        $_.RecommendedRunnerClass -ne 'self-hosted-linux' -or
        $_.Status -ne 'aligned' -or
        @($_.RequiredCapabilities -split ',\s*') -notcontains 'runner-managed-identity'
    }).Count -gt 0) {
    $runnerSeparationViolations += 'multiline runner identity fixture (executable identity flow not detected)'
}

$identityTextRow = @($runnerFixtureAudit.jobs | Where-Object {
    $_.Workflow -eq 'identity-text-is-not-evidence.yml' -and $_.Job -eq 'public-job'
})
if ($identityTextRow.Count -ne 1) {
    $runnerSeparationViolations += 'identity text fixture (missing audit row)'
}
else {
    $identityTextCapabilities = @($identityTextRow[0].RequiredCapabilities -split ',' | ForEach-Object { $_.Trim() })
    if ($identityTextCapabilities -contains 'runner-managed-identity' -or
        $identityTextRow[0].RecommendedRunnerClass -ne 'github-hosted-linux' -or
        $identityTextRow[0].Status -ne 'mismatch') {
        $runnerSeparationViolations += 'identity text fixture (comment, string, or heredoc inferred as executable evidence)'
    }
}

$contractReportFixtureDir = Join-Path $repoRoot 'tests\fixtures\workflow-runner-contract-report'
$violatingContractPath = Join-Path $contractReportFixtureDir 'contracts.json'
$violationMarkdown = (& pwsh -NoProfile -File $runnerAuditScriptPath `
    -OutputFormat markdown `
    -WorkflowDirectory $contractReportFixtureDir `
    -ContractPath $violatingContractPath) -join "`n"
if ($violationMarkdown -notmatch '## Runner Contract Violations' -or
    $violationMarkdown -notmatch 'forbidden-capability' -or
    $violationMarkdown -match '## Mismatch Details') {
    $runnerSeparationViolations += 'contract violation report (details missing when mismatches are zero)'
}

$malformedContractPath = Join-Path $contractReportFixtureDir 'malformed-contracts.json'
$malformedContractAudit = & pwsh -NoProfile -File $runnerAuditScriptPath `
    -OutputFormat json `
    -WorkflowDirectory $contractReportFixtureDir `
    -ContractPath $malformedContractPath | ConvertFrom-Json
$malformedRules = @($malformedContractAudit.contract_violations.Rule)
if (@($malformedRules | Where-Object { $_ -eq 'contract-nonempty-array' }).Count -ne 3 -or
    @($malformedRules | Where-Object { $_ -eq 'contract-positive-integer-timeout' }).Count -ne 3 -or
    @($malformedRules | Where-Object { $_ -eq 'contract-array-field' }).Count -ne 3 -or
    @($malformedRules | Where-Object { $_ -eq 'known-runner-class' }).Count -ne 1 -or
    @($malformedRules | Where-Object { $_ -eq 'known-capability' }).Count -ne 1) {
    $runnerSeparationViolations += 'malformed contract fixture (shape, timeout, runner class, or capability accepted)'
}
& pwsh -NoProfile -File $runnerAuditScriptPath `
    -OutputFormat json `
    -WorkflowDirectory $contractReportFixtureDir `
    -ContractPath $malformedContractPath `
    -FailOnContractViolation *> $null
if ($LASTEXITCODE -eq 0) {
    $runnerSeparationViolations += 'malformed contract fixture (-FailOnContractViolation did not fail)'
}

foreach ($invalidContractCollection in @('missing-contracts.json', 'scalar-contracts.json')) {
    $invalidContractCollectionPath = Join-Path $contractReportFixtureDir $invalidContractCollection
    $invalidContractCollectionAudit = & pwsh -NoProfile -File $runnerAuditScriptPath `
        -OutputFormat json `
        -WorkflowDirectory $contractReportFixtureDir `
        -ContractPath $invalidContractCollectionPath | ConvertFrom-Json
    if (@($invalidContractCollectionAudit.contract_violations.Rule | Where-Object {
        $_ -eq 'contract-collection'
    }).Count -ne 1) {
        $runnerSeparationViolations += "$invalidContractCollection (invalid top-level contracts shape accepted)"
    }
    & pwsh -NoProfile -File $runnerAuditScriptPath `
        -OutputFormat json `
        -WorkflowDirectory $contractReportFixtureDir `
        -ContractPath $invalidContractCollectionPath `
        -FailOnContractViolation *> $null
    if ($LASTEXITCODE -eq 0) {
        $runnerSeparationViolations += "$invalidContractCollection (-FailOnContractViolation did not fail)"
    }
}

if ($runnerSeparationViolations.Count -eq 0) {
    Write-Host '    PASS Authentication, permissions, workload needs, and runner assignment remain distinct'
}
else {
    Write-Host "    FAIL Runner capability separation issues found in: $($runnerSeparationViolations -join ', ')" -ForegroundColor Red
    $guardrailFailures += 'runner-capability-separation'
}

if ($guardrailFailures.Count -gt 0) {
    Write-Host "Workflow guardrails failed: $($guardrailFailures -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host 'All workflow guardrails tests completed'
exit 0
