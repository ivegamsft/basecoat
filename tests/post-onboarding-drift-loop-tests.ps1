$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$workflowPath = Join-Path $repoRoot '.github\workflows\post-onboarding-drift-loop.yml'

if (-not (Test-Path $workflowPath)) {
    throw "Missing workflow file: $workflowPath"
}

function Assert-Match {
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$Message
    )

    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

$workflow = Get-Content $workflowPath -Raw

Assert-Match $workflow 'const isAuthError = error => error && \(error\.status === 401 \|\| error\.status === 403\)' `
    'Drift loop must classify 401/403 as auth errors, not missing files.'

Assert-Match $workflow 'const probeFile = async' `
    'Drift loop must probe files with inaccessible vs missing outcomes.'

Assert-Match $workflow "status: 'inaccessible'" `
    'Drift loop must emit inaccessible surface status for token-scoped failures.'

Assert-Match $workflow 'filter\(surface => surface\.status === ''drift''\)' `
    'driftCount must count only drift, not inaccessible surfaces.'

if ($workflow -match "pullDataUnavailable \? 'drift'") {
    throw 'Reviewer-routing must not treat pull-list auth failures as drift.'
}

if ($workflow -match 'return false;\s*\n\s*\}\s*;\s*\n\s*const getMergeableState') {
    throw 'contentExists boolean helper must not treat 403 as a missing file.'
}

Write-Host 'PASS post-onboarding-drift-loop inaccessible vs drift contract.'
