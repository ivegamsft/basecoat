[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$workflowPath = Join-Path $repoRoot '.github\workflows\pr-auto-merge-executor.yml'
$templatePath = Join-Path $repoRoot '.github\base-coat\workflows\pr-auto-merge-executor.yml'
$humanBoundaryPath = Join-Path $repoRoot '.github\governance\human-approval-boundaries.json'

if (-not (Test-Path $workflowPath)) {
    throw "Missing workflow file: $workflowPath"
}
if (-not (Test-Path $templatePath)) {
    throw "Missing template workflow file: $templatePath"
}
if (-not (Test-Path $humanBoundaryPath)) {
    throw "Missing human approval boundary file: $humanBoundaryPath"
}

$workflow = Get-Content -Path $workflowPath -Raw
$template = Get-Content -Path $templatePath -Raw

if ($workflow -ne $template) {
    throw 'Workflow template mismatch: .github/workflows and .github/base-coat/workflows copies must be identical.'
}

if ($workflow -notmatch '(?m)^name:\s*"?BaseCoat - PR Auto Merge Executor"?\s*$') {
    throw 'Workflow must declare the expected name.'
}
if ($workflow -notmatch '(?m)^on:\s*$') {
    throw "Workflow must define triggers under 'on:'."
}
if ($workflow -notmatch '(?ms)pull_request_target:\s*\r?\n\s*branches:\s*\r?\n\s*-\s*main') {
    throw 'Workflow must trigger on pull_request_target events targeting main.'
}
if ($workflow -notmatch '(?m)pull_request_review:') {
    throw 'Workflow must retrigger on pull request reviews.'
}
if ($workflow -notmatch '(?m)check_suite:') {
    throw 'Workflow must retrigger on check suite completion to reevaluate pending required checks.'
}
if ($workflow -notmatch '(?m)workflow_dispatch:') {
    throw 'Workflow must support workflow_dispatch for replay/manual operation.'
}
if ($workflow -notmatch '(?m)^permissions:\s*\r?\n\s*checks:\s*read\s*\r?\n\s*contents:\s*write\s*\r?\n\s*pull-requests:\s*write\s*\r?\n\s*issues:\s*write\s*\r?\n\s*statuses:\s*read') {
    throw 'Workflow permissions must include checks/statuses read plus contents/pull-requests/issues write.'
}
if ($workflow -notmatch 'github\.event\.pull_request\.number \|\| github\.event\.pull_request_review\.pull_request\.number \|\| inputs\.pr_number \|\| github\.ref') {
    throw 'Workflow concurrency group must scope by PR number with fallback for manual dispatch.'
}
if ($workflow -notmatch 'pr-auto-merge-executor:v1') {
    throw 'Workflow must include the stable marker for idempotent status comments.'
}
if ($workflow -notmatch 'gh pr merge "\$\{PR_NUMBER\}" --repo "\$\{REPOSITORY\}" --auto --squash --delete-branch') {
    throw 'Workflow must use gh pr merge with --auto --squash --delete-branch.'
}
if ($workflow -notmatch 'policy-packs\.json') {
    throw 'Workflow must load governance policy packs from .github/governance/policy-packs.json.'
}
if ($workflow -notmatch 'human-approval-boundaries\.json') {
    throw 'Workflow must load human approval boundaries from .github/governance/human-approval-boundaries.json.'
}
if ($workflow -notmatch 'getContent') {
    throw 'Workflow must read governance policy from the trusted default branch.'
}
if ($workflow -notmatch 'required_checks') {
    throw 'Workflow must evaluate required checks from policy packs.'
}
if ($workflow -notmatch 'merge_queue_posture') {
    throw 'Workflow must enforce merge_queue_posture policy.'
}
if ($workflow -notmatch "merge_queue_posture required: auto-merge executor defers to repository merge queue policy") {
    throw 'Workflow must block auto-merge when merge_queue_posture is required.'
}
if ($workflow -notmatch "Unknown policy pack") {
    throw 'Workflow must fail closed for invalid BASECOAT_POLICY_PACK values.'
}
if ($workflow -notmatch 'always_human_required') {
    throw 'Workflow must consume always_human_required boundaries.'
}
if ($workflow -notmatch 'latestReviewByUser') {
    throw 'Workflow must reduce reviews to each reviewer''s latest state before counting approvals.'
}
if ($workflow -notmatch 'github\.paginate\(github\.rest\.checks\.listForRef') {
    throw 'Workflow must paginate check runs when evaluating required checks.'
}
if ($workflow -notmatch 'if \(!statusSucceeded && !checkSucceeded\)') {
    throw 'Workflow must treat pending or missing required checks as unsatisfied.'
}
if ($workflow -notmatch "pr\.base\?\.ref !== 'main'") {
    throw 'Workflow must block manual dispatches targeting a non-main base branch.'
}
if ($workflow -match 'rulesets') {
    throw 'Workflow must not rely on the rulesets API for merge-queue posture.'
}

Write-Host 'PR auto-merge executor workflow tests passed.'
