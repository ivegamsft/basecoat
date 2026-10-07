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
    if ($content -notmatch '(?m)actions:\s*write' -or
        $content -notmatch '(?m)statuses:\s*write') {
        throw "$name must grant actions/status permissions for linked PR reevaluation."
    }
    if ($content -notmatch 'contains\(github\.event\.comment\.body,\s*''/approve''\)') {
        throw "$name must gate routing and approval jobs on '/approve' comments."
    }
    if ($content -match 'contains\(github\.event\.comment\.body,\s*''/spec-2-prod''\)') {
        throw "$name must not route /spec-2-prod through issue approval or cloud assignment."
    }
    if ($content -match '/approve''\)\s*\|\|[\s\S]{0,120}/spec-2-prod') {
        throw "$name must keep /spec-2-prod under ship-it intent dispatch only."
    }
    if ($content -match 'comment `/approve` or `/spec-2-prod`') {
        throw "$name must describe only /approve as the issue approval retry command."
    }
    if ($content -notmatch 'approval\.validateIssue' -or
        $content -notmatch 'approval\.qualifiedDirective' -or
        $content -notmatch 'approval\.forwardReceipt') {
        throw "$name must use the shared issue contract and original qualified directive before assignment."
    }
    if ($content -notmatch 'Open a ready-for-review implementation PR \(not a draft\)' -or
        $content -notmatch 'Closes #') {
        throw "$name must require a ready, issue-closing implementation PR from the coding agent."
    }
    if ($content -notmatch 'approval\.findApproval') {
        throw "$name must revalidate real authority before linked PR reevaluation."
    }

    if ($files[0].Content -ne $files[1].Content) {
        throw 'Issue-approve workflow and template must remain byte-identical.'
    }
    if ($content -notmatch 'copilot-agent') {
        throw "$name must still apply approved/copilot-agent labels."
    }
    if ($content -notmatch 'Processed /approve') {
        throw "$name must document direct /approve processing in the PR response."
    }
    foreach ($requiredRoutingText in @(
        'reevaluate-linked-prs',
        'Linked issue approval was finalized.',
        'listRepoWorkflows',
        'createWorkflowDispatch',
        'pr-auto-merge-executor.yml',
        'skipping optional linked PR reevaluation'
    )) {
        if ($content -notmatch [regex]::Escape($requiredRoutingText)) {
            throw "$name must route finalized issue approval to linked PRs: $requiredRoutingText"
        }
        if ($content -match "throw new Error\('Unable to find the installed PR auto-merge executor workflow") {
            throw "$name must remain independently installable when the optional executor is absent."
        }
    }
    if ($content -match '⚠️|✅|⛔') {
        throw "$name must not use emoji in user-facing comments."
    }
}

Write-Host 'Issue-approve routing workflow tests passed.'
