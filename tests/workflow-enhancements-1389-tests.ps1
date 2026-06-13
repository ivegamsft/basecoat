$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running workflow enhancements (#1389) tests...'

$workflows = @(
    '.github/workflows/dependency-audit.yml',
    '.github/workflows/stale-management.yml',
    '.github/workflows/release-changelog-generation.yml',
    '.github/workflows/cross-repo-sync-validation.yml',
    '.github/workflows/docs-link-checker.yml',
    '.github/workflows/skill-coverage-report.yml',
    '.github/workflows/repo-health-check.yml',
    '.github/workflows/pr-size-labeler.yml',
    '.github/workflows/dependency-graph-pages.yml',
    '.github/workflows/reviewer-autoassign.yml'
)

$failures = @()

foreach ($workflow in $workflows) {
    if (-not (Test-Path $workflow)) {
        $failures += "Missing workflow: $workflow"
        continue
    }

    $content = Get-Content $workflow -Raw

    if ($content -notmatch '(?m)^\s{2}workflow_dispatch:\s*$') {
        $failures += "$workflow missing workflow_dispatch trigger"
    }

    if ($content -notmatch '(?m)^\s{2}group:\s*\$\{\{\s*github\.workflow') {
        $failures += "$workflow missing workflow-based concurrency group"
    }

    if ($content -notmatch 'timeout-minutes:') {
        $failures += "$workflow missing timeout-minutes"
    }

    $lines = $content -split "`n"
    foreach ($line in $lines) {
        if ($line -match 'uses:\s*([^@\s]+)@(.+)') {
            $action = $matches[1]
            $ref = $matches[2].Trim()
            if ($action -match '^\.\/' -or $action -match 'docker://') {
                continue
            }
            if ($ref -notmatch '^[a-f0-9]{40}$') {
                $failures += "$workflow uses non-SHA action reference: $action@$ref"
            }
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'Workflow enhancement test failures:' -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'Workflow enhancements (#1389) tests passed' -ForegroundColor Green
exit 0
