$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running publish-to-production dispatch tag tests...'

$workflowPath = Join-Path $repoRoot '.github\workflows\publish-to-production.yml'
if (-not (Test-Path $workflowPath)) {
    throw "Missing workflow file: $workflowPath"
}

$content = Get-Content $workflowPath -Raw

if ($content -notmatch '(?m)^\s{2}workflow_dispatch:\s*$') {
    throw 'publish-to-production.yml is missing workflow_dispatch trigger'
}

if ($content -match '(?m)^\s{8}default:\s*"v\d+\.\d+\.\d+"\s*$') {
    throw 'publish-to-production.yml still contains a hard-coded semver default for workflow_dispatch tag input'
}

if ($content -notmatch '(?m)^\s{8}required:\s*false\s*$') {
    throw 'publish-to-production.yml should make workflow_dispatch tag input optional to allow latest-tag resolution'
}

if ($content -notmatch '(?m)^\s{6}- name:\s*Resolve publish tag\s*$') {
    throw 'publish-to-production.yml is missing "Resolve publish tag" step'
}

if ($content -notmatch '(?m)^\s{8}id:\s*resolve_tag\s*$') {
    throw 'publish-to-production.yml is missing resolve_tag step id'
}

if ($content -notmatch "git tag --list 'v\[0-9\]\*\.\[0-9\]\*\.\[0-9\]\*' --sort=-v:refname") {
    throw 'publish-to-production.yml does not resolve latest semver tag when input is empty'
}

if ($content -notmatch '(?m)^\s{10}ref:\s*refs/tags/\$\{\{\s*steps\.resolve_tag\.outputs\.tag\s*\}\}\s*$') {
    throw 'publish-to-production.yml checkout step is not pinned to resolved publish tag'
}

if ($content -match 'TAG:\s*\$\{\{\s*inputs\.tag\s*\|\|\s*github\.ref_name\s*\}\}') {
    throw 'publish-to-production.yml still uses legacy TAG fallback expression'
}

if ($content -notmatch 'TAG:\s*\$\{\{\s*steps\.resolve_tag\.outputs\.tag\s*\}\}') {
    throw 'publish-to-production.yml does not propagate resolved tag into publish steps'
}

# Regression (#2713): the internal-link rewrite must exclude tests/, or test fixtures
# that embed the internal repo URL get mutated and break the external mirror's CI.
if ($content -notmatch "(?m)\|\s*grep -v '\^tests/'") {
    throw 'publish-to-production.yml link-rewrite must exclude tests/ (grep -v ''^tests/'') to avoid mutating test fixtures'
}

Write-Host 'Publish-to-production dispatch tag tests passed' -ForegroundColor Green
exit 0
