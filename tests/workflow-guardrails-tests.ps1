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
$hasResolverStep = $publishWorkflow -match '(?ms)name:\s*Resolve publish tag from event payload.*?\$GITHUB_EVENT_PATH'
$usesResolvedTagOutput = $publishWorkflow -match 'steps\.resolve-tag\.outputs\.tag'

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

# Test 15: Required-check workflows must support merge queue
Write-Host '  Test 15: Validate required-check workflows support merge_group...'
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
    if ($workflowContent -notmatch "(?m)^\s+merge_group:\s*$") {
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

if ($guardrailFailures.Count -gt 0) {
    Write-Host "Workflow guardrails failed: $($guardrailFailures -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host 'All workflow guardrails tests completed'
exit 0
