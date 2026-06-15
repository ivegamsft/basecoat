$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running governance metadata drift tests...'

$scriptPath = Join-Path $repoRoot 'scripts\governance-metadata-drift.ps1'
$auditWorkflowPath = Join-Path $repoRoot '.github\workflows\governance-audit.yml'
$enforceWorkflowPath = Join-Path $repoRoot '.github\workflows\governance-enforce.yml'

if (-not (Test-Path $scriptPath)) {
    throw "Missing script: $scriptPath"
}

if (-not (Test-Path $auditWorkflowPath)) {
    throw "Missing workflow: $auditWorkflowPath"
}

if (-not (Test-Path $enforceWorkflowPath)) {
    throw "Missing workflow: $enforceWorkflowPath"
}

$auditWorkflow = Get-Content $auditWorkflowPath -Raw
$enforceWorkflow = Get-Content $enforceWorkflowPath -Raw

if ($auditWorkflow -notmatch '(?m)^name:\s*BaseCoat - Governance Metadata Drift Audit\s*$') {
    throw 'governance-audit.yml name was not updated to metadata drift audit'
}

if ($enforceWorkflow -notmatch '(?m)^name:\s*BaseCoat - Governance Metadata Drift Enforcement\s*$') {
    throw 'governance-enforce.yml name was not updated to metadata drift enforcement'
}

if ($auditWorkflow -notmatch '(?m)^\s{2}schedule:\s*$') {
    throw 'governance-audit.yml must include a schedule trigger'
}

if ($auditWorkflow -notmatch 'governance-metadata-drift\.ps1\s+-Mode\s+audit') {
    throw 'governance-audit.yml does not execute governance-metadata-drift.ps1 in audit mode'
}

if ($enforceWorkflow -notmatch 'governance-metadata-drift\.ps1\s+-Mode\s+enforce') {
    throw 'governance-enforce.yml does not execute governance-metadata-drift.ps1 in enforce mode'
}

if ($auditWorkflow -notmatch 'governance-metadata-drift-report') {
    throw 'governance-audit.yml missing governance drift report artifact upload'
}

if ($enforceWorkflow -notmatch 'governance-metadata-drift-report') {
    throw 'governance-enforce.yml missing governance drift report artifact upload'
}

if ($auditWorkflow -notmatch '@[a-f0-9]{40}') {
    throw 'governance-audit.yml contains unpinned action references'
}

if ($enforceWorkflow -notmatch '@[a-f0-9]{40}') {
    throw 'governance-enforce.yml contains unpinned action references'
}

Write-Host '  Running script in enforce mode against current repository...'
& pwsh -NoProfile -File $scriptPath -Mode enforce
if ($LASTEXITCODE -ne 0) {
    throw 'governance-metadata-drift.ps1 reported drift in current repository state'
}

Write-Host 'Governance metadata drift tests passed' -ForegroundColor Green
exit 0
