$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$workflowPath = Join-Path $repoRoot '.github\workflows\downstream-reviewer-routing-audit.yml'

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

Assert-Match $workflow 'error\.status === 401 \|\| error\.status === 403 \|\| error\.status === 404' `
    'Reviewer-routing audit must classify 401/403/404 as inaccessible, not a hard failure.'

Assert-Match $workflow "!String\(row\.state\)\.includes\('inaccessible'\)" `
    'Inaccessible sibling repos must not count toward escalation_count.'

Assert-Match $workflow 'does not count as an escalation' `
    'Scorecard must document inaccessible as informational, not an escalation.'

if ($workflow -match "const escalations = scoreRows\.filter\(row => row\.state !== 'healthy'\);") {
    throw 'Escalations must exclude inaccessible rows, not treat every non-healthy state as an escalation.'
}

Write-Host 'PASS downstream-reviewer-routing-audit inaccessible vs escalation contract.'
