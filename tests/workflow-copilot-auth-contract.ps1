#!/usr/bin/env pwsh

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$bootstrapPath = Join-Path $repoRoot 'scripts/bootstrap.ps1'
$validationWorkflowPath = Join-Path $repoRoot '.github/workflows/validate-basecoat.yml'
$workflowNames = @(
    'code-review-agent',
    'issue-triage',
    'release-impact-advisor',
    'retro-facilitator',
    'security-analyst',
    'self-healing-ci'
)
$failures = @()

$bootstrap = Get-Content $bootstrapPath -Raw
foreach ($legacySecret in @('COPILOT_GITHUB_TOKEN', 'GH_AW_GITHUB_TOKEN')) {
    if ($bootstrap -match "Name\s*=\s*'$legacySecret'") {
        $failures += "Bootstrap must not require legacy agentic auth secret $legacySecret."
    }
}

$validationWorkflow = Get-Content $validationWorkflowPath -Raw
foreach ($actionlintCompatibilityPattern in @(
    'unknown permission scope \"copilot-requests\"',
    'unexpected key \"queue\" for \"concurrency\" section'
)) {
    if ($validationWorkflow -notmatch [regex]::Escape($actionlintCompatibilityPattern)) {
        $failures += "Workflow syntax validation must ignore known actionlint lag: $actionlintCompatibilityPattern"
    }
}

foreach ($name in $workflowNames) {
    $sourcePath = Join-Path $repoRoot ".github/workflows/$name.md"
    $runtimePath = Join-Path $repoRoot ".github/workflows/$name.lock.yml"
    $templatePath = Join-Path $repoRoot ".github/base-coat/workflows/$name.lock.yml"

    foreach ($path in @($sourcePath, $runtimePath, $templatePath)) {
        if (-not (Test-Path $path)) {
            $failures += "Missing workflow auth contract file: $path"
        }
    }
    if ($failures.Count -gt 0 -and
        (-not (Test-Path $sourcePath) -or -not (Test-Path $runtimePath) -or -not (Test-Path $templatePath))) {
        continue
    }

    $source = Get-Content $sourcePath -Raw
    $runtime = Get-Content $runtimePath -Raw
    $template = Get-Content $templatePath -Raw

    if ($source -notmatch '(?m)^\s*copilot-requests:\s*write\s*$') {
        $failures += "$name source must request organization-backed Copilot authentication."
    }
    if ($runtime -ne $template) {
        $failures += "$name runtime and distributed lock files must be identical."
    }

    $permissionCount = [regex]::Matches(
        $runtime,
        '(?m)^\s*copilot-requests:\s*write\s*$'
    ).Count
    if ($permissionCount -ne 2) {
        $failures += "$name lock must grant copilot-requests: write to agent and detection jobs (found $permissionCount)."
    }

    $actionsTokenCount = [regex]::Matches(
        $runtime,
        '(?m)^\s*COPILOT_GITHUB_TOKEN:\s*\$\{\{\s*github\.token\s*\}\}\s*$'
    ).Count
    if ($actionsTokenCount -ne 2) {
        $failures += "$name lock must bind github.token for both Copilot phases (found $actionsTokenCount)."
    }

    if ($runtime -match 'name:\s*Validate COPILOT_GITHUB_TOKEN secret') {
        $failures += "$name lock must not depend on the expiring Copilot PAT validation gate."
    }
}

# Lock files are generated artifacts, so a value that differs between them means
# they were produced by different compiler versions. That drift surfaces later as
# an unrelated diff in an unrelated pull request, which is how it was first found.
$expiryByWorkflow = @{}
foreach ($name in $workflowNames) {
    $runtimePath = Join-Path $repoRoot ".github/workflows/$name.lock.yml"
    if (-not (Test-Path $runtimePath)) { continue }
    $match = [regex]::Match(
        (Get-Content $runtimePath -Raw),
        'GH_AW_ACTION_FAILURE_ISSUE_EXPIRES_HOURS:\s*"([^"]*)"'
    )
    if ($match.Success) {
        $expiryByWorkflow[$name] = $match.Groups[1].Value
    }
}
$distinctExpiry = @($expiryByWorkflow.Values | Sort-Object -Unique)
if ($distinctExpiry.Count -gt 1) {
    $detail = ($expiryByWorkflow.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '
    $failures += "gh-aw lock files disagree on GH_AW_ACTION_FAILURE_ISSUE_EXPIRES_HOURS ($detail); recompile all with 'gh aw compile'."
}

if ($failures.Count -gt 0) {
    Write-Host 'Copilot authentication workflow contract FAILED.' -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'Copilot authentication workflow contract passed.' -ForegroundColor Green
