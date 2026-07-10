[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$workflowPath = Join-Path $repoRoot '.github\workflows\issue-triage.lock.yml'
$templatePath = Join-Path $repoRoot '.github\base-coat\workflows\issue-triage.lock.yml'

if (-not (Test-Path $workflowPath)) {
    throw "Missing workflow lock file: $workflowPath"
}
if (-not (Test-Path $templatePath)) {
    throw "Missing template lock file: $templatePath"
}

$workflow = Get-Content -Path $workflowPath -Raw
$template = Get-Content -Path $templatePath -Raw

if ($workflow -ne $template) {
    throw 'issue-triage lock workflow and base-coat template must be identical.'
}

if ($workflow -match 'v0\.71\.5') {
    throw 'issue-triage lock must not retain stale compiler/runtime version v0.71.5.'
}
if ($workflow -match '0\.25\.40') {
    throw 'issue-triage lock must not retain stale firewall version 0.25.40.'
}
if ($workflow -match 'v1\.0\.3') {
    throw 'issue-triage lock must not retain stale github-mcp-server version v1.0.3.'
}
if ($workflow -match 'v0\.3\.6') {
    throw 'issue-triage lock must not retain stale gh-aw-mcpg version v0.3.6.'
}
if ($workflow -match '8c7d04ebf1ece56cd381446125da3e0f6896294a' -or $workflow -match 'b8068426813005612b960b5ab0b8bd2c27142323') {
    throw 'issue-triage lock must not retain stale gh-aw-actions/setup SHAs.'
}

if ($workflow -notmatch 'compiler_version":"v0\.74\.4"') {
    throw 'issue-triage lock must align compiler_version to v0.74.4.'
}
if ($workflow -notmatch 'github/gh-aw-actions/setup@d3abfe96a194bce3a523ed2093ddedd5704cdf62') {
    throw 'issue-triage lock must align setup action SHA to d3abfe96a194bce3a523ed2093ddedd5704cdf62.'
}
if ($workflow -notmatch 'GH_AW_INFO_CLI_VERSION: "v0\.74\.4"') {
    throw 'issue-triage lock must align GH_AW_INFO_CLI_VERSION to v0.74.4.'
}
if ($workflow -notmatch 'ghcr\.io/github/gh-aw-mcpg:v0\.3\.9@sha256:64828b42a4482f58fab16509d7f8f495a6d97c972a98a68aff20543531ac0388') {
    throw 'issue-triage lock must pin gh-aw-mcpg v0.3.9 to sha256:64828b42...'
}
if ($workflow -notmatch 'COPILOT_GITHUB_TOKEN:\s*\$\{\{\s*secrets\.COPILOT_GITHUB_TOKEN\s*\}\}') {
    throw 'issue-triage lock must pass the real Copilot token to the agent phase.'
}
if ($workflow -notmatch 'COPILOT_GITHUB_TOKEN:\s*placeholder-token-for-credential-isolation') {
    throw 'issue-triage lock must pass placeholder token value to the detection phase for credential isolation.'
}

Write-Host 'Issue triage lock refresh tests passed.'
