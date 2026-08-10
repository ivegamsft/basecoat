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
if ($workflow -match '(?m)check_suite:') {
    throw 'Workflow must not rely on suppressed GitHub Actions check_suite completion events.'
}
if ($workflow -notmatch '(?m)^\s*timeout-minutes:\s*20\s*$') {
    throw 'Workflow must allow enough time to wait for repository-required checks.'
}
if ($workflow -notmatch '(?m)workflow_dispatch:') {
    throw 'Workflow must support workflow_dispatch for replay/manual operation.'
}
if ($workflow -notmatch '(?m)^permissions:\s*\r?\n\s*checks:\s*read\s*\r?\n\s*contents:\s*write\s*\r?\n\s*pull-requests:\s*write\s*\r?\n\s*issues:\s*write\s*\r?\n\s*statuses:\s*write') {
    throw 'Workflow permissions must include checks read plus contents/pull-requests/issues/statuses write.'
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
if ($workflow -match '(?m)gh pr merge .+--admin') {
    throw 'Workflow must never use administrator bypass for auto-merge.'
}
if ($workflow -notmatch 'core\.setFailed\(`Merge eligibility gate blocked:') {
    throw 'Workflow must fail its status check when merge policy is not satisfied.'
}
if ($workflow -notmatch "eligibilityStatusContext = 'BaseCoat merge eligibility'") {
    throw 'Workflow must use the stable PR-head eligibility status context.'
}
if ($workflow -notmatch 'github\.rest\.repos\.createCommitStatus') {
    throw 'Workflow must publish merge eligibility as a commit status.'
}
if ($workflow -notmatch 'sha:\s*headSha') {
    throw 'Workflow must publish merge eligibility against the pull request head SHA.'
}
if ($workflow -notmatch 'githubActionsIntegrationId\s*=\s*15368') {
    throw 'Workflow must identify the trusted GitHub Actions integration.'
}
if (-not $workflow.Contains("publishEligibilityStatus('pending', 'Evaluating BaseCoat merge policy.')")) {
    throw 'Workflow must replace any prior eligibility result with pending before policy loading.'
}
if (-not $workflow.Contains("publishEligibilityStatus('failure', 'BaseCoat merge policy evaluation failed.')")) {
    throw 'Workflow must fail closed when policy evaluation throws.'
}
if ($workflow -notmatch 'policy\.production_release_paths') {
    throw 'Workflow must consume explicit production release paths from policy.'
}
if ($workflow -notmatch '\[file\.filename, file\.previous_filename\]') {
    throw 'Workflow must classify both source and destination paths for renamed files.'
}
if ($workflow -notmatch "production_environment_approval: production release path requires explicit human approval") {
    throw 'Workflow must preserve independent approval for configured production release paths.'
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
if ($workflow -notmatch 'github\.rest\.repos\.getCollaboratorPermissionLevel') {
    throw 'Workflow must verify repository permission before counting an approval.'
}
if ($workflow -notmatch "new Set\(\['admin', 'maintain', 'write'\]\)") {
    throw 'Workflow must restrict qualified approvers to write, maintain, or admin permission.'
}
if ($workflow -notmatch 'new Set\(qualifiedApprovers\.filter\(Boolean\)\)') {
    throw 'Workflow approval counts must use only permission-qualified reviewers.'
}
if ($workflow -notmatch 'github\.rest\.checks\.listForRef' -or
    $workflow -notmatch 'pageRuns\.length < 100') {
    throw 'Workflow must explicitly paginate check runs when evaluating required checks.'
}
if ($workflow -notmatch '\[headSha, pr\.merge_commit_sha\]') {
    throw 'Workflow must inspect both the PR head and synthetic merge commit for required checks.'
}
if ($workflow -notmatch "status\.creator\?\.login !== 'github-actions\[bot\]'" -or
    $workflow -notmatch "check\.app\?\.id === githubActionsIntegrationId") {
    throw 'Workflow must accept required-check evidence only from the trusted GitHub Actions integration.'
}
if ($workflow -notmatch 'maxCheckPollAttempts\s*=\s*60' -or
    $workflow -notmatch 'checkPollIntervalMs\s*=\s*15000' -or
    $workflow -notmatch 'await new Promise\(resolve => setTimeout\(resolve, checkPollIntervalMs\)\)') {
    throw 'Workflow must wait for pending required checks before publishing a terminal eligibility result.'
}
if ($workflow -notmatch 'if \(!statusSucceeded && !checkSucceeded\)') {
    throw 'Workflow must treat pending or missing required checks as unsatisfied.'
}
if ($workflow -notmatch "pr\.base\?\.ref !== 'main'") {
    throw 'Workflow must block manual dispatches targeting a non-main base branch.'
}
if ($workflow -match "mergeable_state \|\| ''\)\.toLowerCase\(\) === 'blocked'") {
    throw 'Workflow must not self-block on mergeable_state=blocked while its own required status is pending.'
}
if ($workflow -match 'rulesets') {
    throw 'Workflow must not rely on the rulesets API for merge-queue posture.'
}

Write-Host 'PR auto-merge executor workflow tests passed.'
