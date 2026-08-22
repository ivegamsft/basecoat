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
if ($workflow -match '/usr/local/bin/copilot') {
    throw 'issue-triage lock must not invoke /usr/local/bin/copilot directly.'
}

if ($workflow -notmatch 'compiler_version":"v0\.86\.2"') {
    throw 'issue-triage lock must align compiler_version to v0.86.2.'
}
if ($workflow -notmatch 'github/gh-aw-actions/setup@6aab9e5b5c91c615506061f09bedd81a23babe3c') {
    throw 'issue-triage lock must align setup action SHA to gh-aw v0.86.2.'
}
if ($workflow -notmatch 'GH_AW_INFO_CLI_VERSION: "v0\.86\.2"') {
    throw 'issue-triage lock must align GH_AW_INFO_CLI_VERSION to v0.86.2.'
}
if ($workflow -notmatch 'ghcr\.io/github/gh-aw-mcpg:v0\.4\.9@sha256:e5a1569aeaf41820fa7bdee3e94468cae448133cdbf00119ad24f5b74db1ab9f') {
    throw 'issue-triage lock must pin gh-aw-mcpg v0.4.9 to its compiled digest.'
}
if ($workflow -notmatch '"\$\{RUNNER_TEMP\}/gh-aw/actions/copilot_harness\.cjs"\s*"\$\{RUNNER_TEMP\}/gh-aw/bin/copilot"') {
    throw 'issue-triage lock must invoke the harness with the staged ${RUNNER_TEMP}/gh-aw/bin/copilot binary.'
}
$copilotPermissionPattern = '(?m)^\s*copilot-requests:\s*write\s*$'
$copilotPermissionCount = [regex]::Matches($workflow, $copilotPermissionPattern).Count
if ($copilotPermissionCount -ne 2) {
    throw "issue-triage lock must grant copilot-requests: write to agent and detection jobs (found $copilotPermissionCount)."
}
$actionsTokenPattern = '(?m)^\s*COPILOT_GITHUB_TOKEN:\s*\$\{\{\s*github\.token\s*\}\}\s*$'
$actionsTokenCount = [regex]::Matches($workflow, $actionsTokenPattern).Count
if ($actionsTokenCount -ne 2) {
    throw "issue-triage lock must use the short-lived GitHub Actions token for both Copilot phases (found $actionsTokenCount)."
}
if ($workflow -match 'name:\s*Validate COPILOT_GITHUB_TOKEN secret') {
    throw 'issue-triage lock must not retain the expiring PAT validation gate.'
}

Write-Host 'Issue triage lock refresh tests passed.'
