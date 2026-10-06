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

Assert-Match $workflow 'isAuthError\(error\) \|\| error\.status === 404' `
    'repos.get 404 on a hidden private repo must short-circuit as inaccessible, not missing files.'

Assert-Match $workflow 'repository metadata unavailable \(\$\{errorDetail\(error\)\}\)' `
    'Hidden-repo short-circuit must record HTTP status in the inaccessible detail.'

Assert-Match $workflow 'if \(isAuthError\(error\) \|\| error\.status === 404\) \{\s*rulesetsInaccessible = true' `
    'getRepoRulesets 404 must be inaccessible, not rulesets=0 drift.'

Assert-Match $workflow 'const probeFile = async' `
    'Drift loop must probe files with inaccessible vs missing outcomes.'

Assert-Match $workflow 'if \(error\.status === 404\) \{\s*return \{ exists: false, inaccessible: false, unknown: false \}' `
    'A 404 file probe must remain a measured missing file, distinct from other API errors.'

Assert-Match $workflow 'return \{ exists: false, inaccessible: false, unknown: true, detail: errorDetail\(error\) \}' `
    'Non-404 file probe errors must be unknown, not measured drift.'

Assert-Match $workflow "const status = inaccessible \? 'inaccessible' : 'unknown'" `
    'Drift loop must emit inaccessible surface status for token-scoped failures.'

Assert-Match $workflow 'POST_ONBOARDING_DRIFT_READ_TOKEN' `
    'Drift loop must support the optional downstream read-only token.'

Assert-Match $workflow 'const downstreamGithub = process\.env\.DOWNSTREAM_READ_TOKEN[\s\S]*?: github;' `
    'Downstream API reads must use the optional credential without replacing source-repo writes.'

Assert-Match $workflow 'unknownCount' `
    'Drift loop must report unknown surfaces separately from measured drift.'

Assert-Match $workflow 'trendFor\(row, previous\)' `
    'Drift trends must not call an unreadable surface stable or clean.'

Assert-Match $workflow 'if \(!canCloseRemediation\(row\)\)' `
    'Remediation issues must remain open until all surfaces are measured and resolved.'

if ($workflow -match "pullDataUnavailable \? 'drift'") {
    throw 'Reviewer-routing must not treat pull-list auth failures as drift.'
}

$contractTestsPath = Join-Path $PSScriptRoot 'post-onboarding-drift-loop-contract.test.js'
& node $contractTestsPath
if ($LASTEXITCODE -ne 0) {
    throw 'Post-onboarding drift contract fixture tests failed.'
}

Write-Host 'PASS post-onboarding-drift-loop inaccessible, unknown, drift, trend, and closure contract.'
