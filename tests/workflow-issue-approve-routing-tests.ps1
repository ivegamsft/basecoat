[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$workflowPath = Join-Path $repoRoot '.github\workflows\issue-approve.yml'
$templatePath = Join-Path $repoRoot '.github\base-coat\workflows\issue-approve.yml'

if (-not (Test-Path $workflowPath)) {
    throw "Missing workflow file: $workflowPath"
}
if (-not (Test-Path $templatePath)) {
    throw "Missing template workflow file: $templatePath"
}

$files = @(
    @{ Name = '.github/workflows/issue-approve.yml'; Content = (Get-Content -Path $workflowPath -Raw) },
    @{ Name = '.github/base-coat/workflows/issue-approve.yml'; Content = (Get-Content -Path $templatePath -Raw) }
)

foreach ($entry in $files) {
    $name = $entry.Name
    $content = $entry.Content

    if ($content -notmatch '(?ms)route-pr-approve:\s*\r?\n\s*if:\s*\|\s*\r?\n\s*github\.event\.issue\.pull_request') {
        throw "$name must include route-pr-approve job for PR comment routing."
    }
    if ($content -notmatch '(?m)pull-requests:\s*read') {
        throw "$name must grant pull-requests read access for PR routing."
    }
    if ($content -notmatch 'contains\(github\.event\.comment\.body,\s*''/approve''\)') {
        throw "$name must gate routing and approval jobs on '/approve' comments."
    }
    if ($content -notmatch 'getCollaboratorPermissionLevel') {
        throw "$name must verify the original commenter can approve issues."
    }
    if ($content -notmatch 'copilot-agent') {
        throw "$name must still apply approved/copilot-agent labels."
    }
    if ($content -notmatch 'Processed /approve') {
        throw "$name must document direct /approve processing in the PR response."
    }
    if ($content -match '⚠️|✅|⛔') {
        throw "$name must not use emoji in user-facing comments."
    }
}

Write-Host 'Issue-approve routing workflow tests passed.'
