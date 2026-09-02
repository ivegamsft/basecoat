$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$workflowPath = Join-Path $repoRoot '.github\workflows\docs-link-checker.yml'

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

Assert-Match $workflow "github\.com/YOUR-ORG" `
    'Docs link checker must skip YOUR-ORG template placeholders.'

Assert-Match $workflow 'packagefeedproxy\.microsoft\.io' `
    'Docs link checker must skip the corp npm proxy that returns 405 to HEAD/GET.'

Assert-Match $workflow 'token\.actions\.githubusercontent\.com' `
    'Docs link checker must skip the Actions OIDC token endpoint (POST-only, 404 to HEAD/GET).'

Assert-Match $workflow 'code in \(403, 405, 501\)' `
    'HEAD 403/405/501 must retry GET before classifying a link as broken.'

Write-Host 'PASS docs-link-checker placeholder and method-retry contract.'
