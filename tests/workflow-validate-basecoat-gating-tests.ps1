#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Contract tests for package/validate guidance audit gating behavior.

.DESCRIPTION
    Ensures package-basecoat disables guidance-audit hard failures when calling
    validate-basecoat, and validate-basecoat correctly propagates that input to
    tests/run-tests.ps1 for workflow_call executions.
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running validate-basecoat gating contract tests...'

$failures = @()

$packageWorkflowPath = Join-Path $repoRoot '.github\workflows\package-basecoat.yml'
$validateWorkflowPath = Join-Path $repoRoot '.github\workflows\validate-basecoat.yml'

if (-not (Test-Path $packageWorkflowPath)) {
    throw "Missing workflow file: $packageWorkflowPath"
}

if (-not (Test-Path $validateWorkflowPath)) {
    throw "Missing workflow file: $validateWorkflowPath"
}

$packageContent = Get-Content $packageWorkflowPath -Raw
$validateContent = Get-Content $validateWorkflowPath -Raw

# Contract 1: package workflow explicitly disables guidance audit failures.
if ($packageContent -notmatch 'fail_on_guidance_audit_errors:\s*false') {
    $failures += 'package-basecoat must set fail_on_guidance_audit_errors: false when calling validate-basecoat'
}

# Contract 2: validate workflow defines the toggle input with default true.
if ($validateContent -notmatch 'fail_on_guidance_audit_errors:') {
    $failures += 'validate-basecoat is missing fail_on_guidance_audit_errors input definition'
}
if ($validateContent -notmatch 'fail_on_guidance_audit_errors:[\s\S]*?default:\s*true') {
    $failures += 'validate-basecoat fail_on_guidance_audit_errors input must default to true'
}

# Contract 3: run-tests step must pass GuidanceAuditFailOnError explicitly.
if ($validateContent -notmatch 'GuidanceAuditFailOnError:\$failOnGuidanceAuditErrors') {
    $failures += 'validate-basecoat run-tests step must pass -GuidanceAuditFailOnError using workflow input'
}

# Contract 4: workflow_call path must branch on github.event_name.
if ($validateContent -notmatch "if \('\$\{\{ github\.event_name \}\}' -eq 'workflow_call'\)") {
    $failures += 'validate-basecoat must branch workflow_call behavior for guidance audit gating'
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
