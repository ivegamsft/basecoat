#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Contract tests for guidance audit gating and validation workflow routing.

.DESCRIPTION
    Ensures the package workflow reuses merge-group validation, while the Linux
    full-suite job preserves its guidance-audit failure policy.
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running validate-basecoat gating contract tests...'

$failures = @()

$packageWorkflowPath = Join-Path $repoRoot '.github\workflows\package-basecoat.yml'
$validateWorkflowPath = Join-Path $repoRoot '.github\workflows\validate-basecoat.yml'
$ciWorkflowPath = Join-Path $repoRoot '.github\workflows\ci.yml'

if (-not (Test-Path $packageWorkflowPath)) {
    throw "Missing workflow file: $packageWorkflowPath"
}

if (-not (Test-Path $validateWorkflowPath)) {
    throw "Missing workflow file: $validateWorkflowPath"
}

$packageContent = Get-Content $packageWorkflowPath -Raw
$validateContent = Get-Content $validateWorkflowPath -Raw
$ciContent = Get-Content $ciWorkflowPath -Raw
$runnerContent = Get-Content (Join-Path $repoRoot 'tests\run-tests.ps1') -Raw

# Contract 1: package workflow must not invoke a second full validation run.
if ($packageContent -match 'uses:\s*\./\.github/workflows/validate-basecoat\.yml' -or
    $packageContent -notmatch 'find-merge-group-validation:') {
    $failures += 'package-basecoat must reuse a successful merge-group validation instead of rerunning validate-basecoat'
}

# Contract 2: keep the reusable workflow input compatible for existing callers.
if ($validateContent -notmatch 'fail_on_guidance_audit_errors:') {
    $failures += 'validate-basecoat is missing fail_on_guidance_audit_errors input definition'
}
if ($validateContent -notmatch 'fail_on_guidance_audit_errors:[\s\S]*?default:\s*true') {
    $failures += 'validate-basecoat fail_on_guidance_audit_errors input must default to true'
}

# Contract 3: Linux full-suite CI must propagate the event-specific audit policy.
if (-not $ciContent.Contains('pwsh tests/run-tests.ps1 -GuidanceAuditFailOnError:$failOnGuidanceAuditErrors') -or
    -not $ciContent.Contains('$failOnGuidanceAuditErrors = ''${{ github.event_name }}'' -ne ''pull_request''') -or
    -not $runnerContent.Contains('[bool]$GuidanceAuditFailOnError = $true')) {
    $failures += 'CI must pass its guidance-audit policy to the Linux full-suite runner.'
}

$laneRunnerContent = Get-Content (Join-Path $repoRoot 'scripts\run-windows-validation-lane.ps1') -Raw
foreach ($requiredText in @(
    '  validate-windows:',
    'runs-on: windows-latest',
    'Run isolated Windows validation lanes',
    '& pwsh -NoProfile -File scripts/run-windows-validation-lane.ps1 -LaneName core',
    '-LaneName sync',
    'scripts/run-windows-validation-lane.ps1',
    'exit $LASTEXITCODE',
    "Name = 'core'",
    "Name = 'sync'",
    'Start-Process -FilePath pwsh',
    'Wait-Process -Id ($processes.Process.Id)',
    'Windows validation failed:',
    'name: windows-validation-failure-attempt-${{ github.run_attempt }}',
    'exit 1'
)) {
    if (-not $validateContent.Contains($requiredText)) {
        $failures += "Windows sharding must preserve fail-closed coverage: $requiredText"
    }
}
if ($validateContent.Contains('  windows-core:') -or $validateContent.Contains('  windows-sync:')) {
    $failures += 'Windows validation must not depend on extra Windows jobs that can be abandoned before runner acquisition.'
}
if (-not $runnerContent.Contains('& pwsh -NoProfile -File ./scripts/validate-basecoat.ps1 -Strict') -or
    -not $runnerContent.Contains('if ($LASTEXITCODE -ne 0)') -or
    -not $runnerContent.Contains("Write-Host 'Running sync process tests...'")) {
    $failures += 'The Linux full test suite must propagate strict BaseCoat validation failures and retain the sync suite.'
}
$dispatchValidationJob = [regex]::Match($validateContent, '(?ms)^  validate-powershell:\s*\r?\n(.*?)(?=^  [a-z0-9_-]+:|\z)')
if (-not $dispatchValidationJob.Success -or
    $dispatchValidationJob.Groups[1].Value -notmatch "if:\s*github\.event_name == 'workflow_dispatch' \|\| github\.event_name == 'workflow_call'" -or
    $dispatchValidationJob.Groups[1].Value -notmatch 'FAIL_ON_GUIDANCE_AUDIT_ERRORS:\s*\$\{\{\s*inputs\.fail_on_guidance_audit_errors\s*\}\}' -or
    -not $dispatchValidationJob.Groups[1].Value.Contains('$failOnGuidanceAuditErrors = $true') -or
    -not $dispatchValidationJob.Groups[1].Value.Contains('$env:GITHUB_EVENT_NAME -eq ''workflow_dispatch''') -or
    -not $dispatchValidationJob.Groups[1].Value.Contains('$env:GITHUB_REF -ne ''refs/heads/main''') -or
    -not $dispatchValidationJob.Groups[1].Value.Contains('$env:FAIL_ON_GUIDANCE_AUDIT_ERRORS -eq ''true''') -or
    $dispatchValidationJob.Groups[1].Value -notmatch 'Run strict PowerShell test suite[\s\S]*?pwsh tests/run-tests\.ps1 -GuidanceAuditFailOnError:\$failOnGuidanceAuditErrors[\s\S]*?check-coherence\.ps1 -Strict -Category conflicts') {
    $failures += 'workflow_dispatch must preserve advisory guidance audits off main, while workflow_call honors its input and both retain strict validation.'
}
if ($ciContent -notmatch 'ci-merge-group-validation-\$\{\{\s*steps\.source\.outputs\.tree\s*\}\}' -or
    $ciContent -notmatch 'Validate strict coherence conflicts[\s\S]*?Write CI validated tree marker[\s\S]*?Record successful merge-group CI validation[\s\S]*?overwrite:\s*true') {
    $failures += 'CI must publish a merge-group tree marker only after the strict PowerShell suite and coherence gate pass.'
}
foreach ($requiredText in @(
    '& pwsh -NoProfile -File tests\aidl-incident-routing-verification-tests.ps1',
    '& pwsh -NoProfile -File tests\dogfood-install-tests.ps1',
    '& pwsh -NoProfile -File tests\portable-skill-export-preview-tests.ps1',
    '& $powershell51.Source -NoProfile -ExecutionPolicy Bypass -File tests\bootstrap-pr-counter-tests.ps1',
    '& pwsh -NoProfile -File tests\guidance-lock-tests.ps1',
    '& pwsh -NoProfile -File tests\sync-tests.ps1',
    '$failure.Output | ForEach-Object { "$_" }',
    'exit $result.ExitCode'
)) {
    if (-not $laneRunnerContent.Contains($requiredText)) {
        $failures += "Windows lane runner must preserve platform-specific coverage: $requiredText"
    }
}
if ($laneRunnerContent.Contains('tests\run-tests.ps1') -or
    $laneRunnerContent.Contains('validate-basecoat.ps1')) {
    $failures += 'Windows lanes must not repeat the Linux validation suite.'
}
if ($ciContent -notmatch 'scripts/check-coherence\.ps1 -Strict -Category conflicts') {
    $failures += 'The strict coherence-conflict gate must remain on the Linux CI path.'
}

if ($failures.Count -gt 0) {
    Write-Host 'validate-basecoat gating contract FAILED.' -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'validate-basecoat gating contract passed.' -ForegroundColor Green
exit 0
