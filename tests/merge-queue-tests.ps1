#!/usr/bin/env pwsh

<#
.SYNOPSIS
Test merge queue enforcement configuration

.DESCRIPTION
Validates that merge queue configuration meets Sprint 36 acceptance criteria

.EXAMPLE
.\merge-queue-tests.ps1
#>

$ErrorActionPreference = 'Stop'
$testResults = @()

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

    $testResults += $result

    if ($Pass) {
        Write-Host "✓ $TestName" -ForegroundColor Green
    } else {
        Write-Host "✗ $TestName" -ForegroundColor Red
        if ($Details) {
            Write-Host "  └─ $Details" -ForegroundColor Yellow
        }
    }
}

# Test 1: Documentation exists
Write-Host 'Running merge queue enforcement tests...' -ForegroundColor Blue
Write-Host ''

$docPath = 'docs/operations/merge-queue-enforcement.md'
Test-Result 'Merge queue documentation exists' `
    (Test-Path $docPath) `
    "Expected: $docPath"

# Test 2: Documentation contains required sections
if (Test-Path $docPath) {
    $docContent = Get-Content -Path $docPath -Raw

    Test-Result 'Documentation contains Configuration section' `
        ($docContent -match '## Configuration') `
        'Missing: ## Configuration'

    Test-Result 'Documentation contains merge queue parameters' `
        ($docContent -match 'grouping_strategy|max_entries_to_build|merge_method') `
        'Missing: merge queue parameters'

    Test-Result 'Documentation contains required status checks' `
        ($docContent -match 'validate-commit-messages|validate-unix|validate-windows') `
        'Missing: required status checks list'

    Test-Result 'Documentation contains acceptance criteria' `
        ($docContent -match '## Acceptance Criteria') `
        'Missing: ## Acceptance Criteria'
}

# Test 3: Deployment scripts exist
Test-Result 'Bash deployment script exists' `
    (Test-Path 'scripts/deploy-merge-queue.sh') `
    'Expected: scripts/deploy-merge-queue.sh'

Test-Result 'PowerShell deployment script exists' `
    (Test-Path 'scripts/deploy-merge-queue.ps1') `
    'Expected: scripts/deploy-merge-queue.ps1'

# Test 4: Scripts have proper headers
$bashScript = Get-Content -Path 'scripts/deploy-merge-queue.sh' -Raw -ErrorAction SilentlyContinue
if ($bashScript) {
    Test-Result 'Bash script has proper shebang' `
        ($bashScript -match '^#!/usr/bin/env bash') `
        'Missing: #!/usr/bin/env bash'

    Test-Result 'Bash script has usage documentation' `
        ($bashScript -match '# Usage:') `
        'Missing: Usage documentation'

    Test-Result 'Bash script has error handling' `
        ($bashScript -match 'set -euo pipefail') `
        'Missing: error handling'
}

$psScript = Get-Content -Path 'scripts/deploy-merge-queue.ps1' -Raw -ErrorAction SilentlyContinue
if ($psScript) {
    Test-Result 'PowerShell script has help' `
        ($psScript -match '\<#' -and $psScript -match 'SYNOPSIS') `
        'Missing: PowerShell help'

    Test-Result 'PowerShell script has DryRun parameter' `
        ($psScript -match 'param\(.*DryRun') `
        'Missing: DryRun parameter'

    Test-Result 'PowerShell script has prerequisite validation' `
        ($psScript -match 'Test-Prerequisites|Test-GitHubAuth') `
        'Missing: prerequisite validation functions'
}

# Test 5: Validate JSON ruleset structure
$docContent = Get-Content -Path $docPath -Raw -ErrorAction SilentlyContinue
if ($docContent) {
    # Extract JSON from code block
    $jsonMatch = $docContent -match '```json\s(.*?)```'
    if ($jsonMatch) {
        $jsonContent = $Matches[1]
        try {
            $ruleset = $jsonContent | ConvertFrom-Json
            Test-Result 'Ruleset JSON is valid' $true ''
            
            Test-Result 'Ruleset has merge_queue rule' `
                ($ruleset.rules | Where-Object { $_.type -eq 'merge_queue' } | Measure-Object).Count -gt 0 `
                'Missing: merge_queue rule'

            Test-Result 'Ruleset has required_status_checks' `
                ($ruleset.rules | Where-Object { $_.type -eq 'required_status_checks' } | Measure-Object).Count -gt 0 `
                'Missing: required_status_checks rule'

            Test-Result 'Ruleset has pull_request rule' `
                ($ruleset.rules | Where-Object { $_.type -eq 'pull_request' } | Measure-Object).Count -gt 0 `
                'Missing: pull_request rule'
        } catch {
            Test-Result 'Ruleset JSON is valid' $false "JSON parse error: $_"
        }
    }
}

# Summary
Write-Host ''
Write-Host '=== Test Summary ===' -ForegroundColor Blue
$passed = ($testResults | Where-Object { $_.Status -eq 'PASS' } | Measure-Object).Count
$failed = ($testResults | Where-Object { $_.Status -eq 'FAIL' } | Measure-Object).Count
$total = $testResults.Count

Write-Host "Passed: $passed/$total" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "Failed: $failed/$total" -ForegroundColor Red
}

# Exit with appropriate code
if ($failed -eq 0) {
    Write-Host ''
    Write-Host 'All tests passed! ✓' -ForegroundColor Green
    exit 0
} else {
    Write-Host ''
    Write-Host "Test failures detected. Fix above issues before proceeding." -ForegroundColor Red
    exit 1
}
