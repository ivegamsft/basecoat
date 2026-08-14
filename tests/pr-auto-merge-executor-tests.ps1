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
if ($workflow -notmatch '(?ms)pull_request_target:.*?types:.*?-\s*edited') {
    throw 'Workflow must reevaluate when PR title/body edits change linked issue evidence.'
}
foreach ($concurrencyNamespace in @("format('issue-{0}'", "format('comment-{0}'", "format('pr-{0}'")) {
    if ($workflow -notmatch [regex]::Escape($concurrencyNamespace)) {
        throw "Workflow must namespace concurrency routing: $concurrencyNamespace"
    }
}
if ($workflow -notmatch '(?m)pull_request_review:') {
    throw 'Workflow must retrigger on pull request reviews.'
}
if ($workflow -notmatch '(?ms)issue_comment:\s*\r?\n\s*types:\s*\r?\n\s*-\s*created\s*\r?\n\s*-\s*edited\s*\r?\n\s*-\s*deleted') {
    throw 'Workflow must retrigger when a PR acknowledgement comment is created, edited, or deleted.'
}
foreach ($requiredPrRoutingText in @(
    'route-pr-acknowledgement',
    'acknowledgementAdded',
    'acknowledgementRevoked',
    'acknowledgementReplaced',
    'previousSha !== currentSha',
    'Ignoring acknowledgement addition from bot',
    'Ignoring acknowledgement addition from unqualified user',
    'Ignoring acknowledgement for stale SHA',
    'Solo-dev maintainer acknowledgement evidence changed.'
)) {
    if ($workflow -notmatch [regex]::Escape($requiredPrRoutingText)) {
        throw "Workflow is missing authorized PR acknowledgement routing: $requiredPrRoutingText"
    }
}
foreach ($requiredLinkedIssueRoutingText in @(
    'route-linked-issue-evidence',
    "github.event_name == 'issues'",
    "github.event.label.name == 'approved'",
    'exactIssueApproval',
    'github.rest.actions.createWorkflowDispatch',
    'github.workflow_ref',
    'Linked issue #${issueNumber} acknowledgement evidence changed.',
    'issue-approve will route after finalizing the label'
)) {
    if ($workflow -notmatch [regex]::Escape($requiredLinkedIssueRoutingText)) {
        throw "Workflow is missing linked issue evidence routing: $requiredLinkedIssueRoutingText"
    }
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
if ($workflow -notmatch '(?m)^permissions:\s*\r?\n\s*actions:\s*write\s*\r?\n\s*checks:\s*read\s*\r?\n\s*contents:\s*write\s*\r?\n\s*deployments:\s*read\s*\r?\n\s*pull-requests:\s*write\s*\r?\n\s*issues:\s*write\s*\r?\n\s*statuses:\s*write') {
    throw 'Workflow permissions must support linked-evidence dispatch plus merge evaluation.'
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
if ($workflow -match "production_environment_approval: production release path requires explicit human approval") {
    throw 'Workflow must not model production environment approval as an independent PR approval.'
}
foreach ($requiredProductionContractText in @(
    'production_environment_contract',
    "environmentContract.enforcement !== 'github_environment'",
    'environmentContract.minimum_required_reviewers',
    'environmentContract.deployment_workflow_binding_verification',
    'pr_head_digest_and_environment_against_trusted_policy',
    "environmentContract.pr_approval_is_equivalent !== false",
    'environmentContract.solo_dev_prevent_self_review',
    'policyEnvironment.workflow_bindings',
    'productionWorkflowPathsToVerify',
    'readTextFromPullRequestHead',
    'readWorkflowJobEnvironments',
    'observedEnvironments.length !== 1',
    'expected_job_environment',
    'expected_workflow_sha256',
    "require('crypto')",
    "createHash('sha256')",
    'does not match its trusted full-workflow digest',
    'governed production workflow renamed outside inventory',
    'does not retain its trusted production environment binding',
    'github.rest.repos.getEnvironment',
    'liveEnvironment.protection_rules',
    'liveEnvironment.deployment_branch_policy',
    'github.rest.repos.listDeploymentBranchPolicies',
    "branchPolicy.name === 'main'",
    'reviewerRule?.prevent_self_review !== false',
    'production_environment_approval contract invalid'
)) {
    if ($workflow -notmatch [regex]::Escape($requiredProductionContractText)) {
        throw "Workflow is missing production environment contract enforcement: $requiredProductionContractText"
    }
    if ($workflow -notmatch "issue\.state !== 'open'") {
        throw 'Workflow must reject closed historical issues as acknowledgement evidence.'
    }
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
foreach ($requiredAutomatedReviewText in @(
    'profile.main?.automated_review',
    'automatedReviewerLogins',
    'acceptedAutomatedReviewStates',
    'review.commit_id === headSha',
    'Automated review required for current head',
    'required-missing-current-head'
)) {
    if ($workflow -notmatch [regex]::Escape($requiredAutomatedReviewText)) {
        throw "Workflow is missing current-head automated review enforcement: $requiredAutomatedReviewText"
    }
}
if ($workflow -notmatch "review\.state === 'APPROVED' && review\.commit_id === headSha") {
    throw 'Workflow must count only independent approvals for the current head SHA.'
}
if ($workflow -notmatch 'isBotActor\(review\.user\)') {
    throw 'Workflow must not count bot-authored PR approvals.'
}
if ($workflow -notmatch 'github\.rest\.repos\.getCollaboratorPermissionLevel') {
    throw 'Workflow must verify repository permission before counting an approval.'
}
if ($workflow -notmatch "new Set\(\['admin', 'maintain', 'write'\]\)") {
    throw 'Workflow must restrict qualified approvers to write, maintain, or admin permission.'
}
foreach ($requiredAcknowledgementText in @(
    '/acknowledge-critical',
    'evaluateMaintainerAcknowledgement',
    'maintainer_acknowledgement_required_by_risk',
    'maintainer_acknowledgement_satisfies_boundaries',
    'required_maintainer_acknowledgement_by_risk_tier',
    'linked-approved-issue',
    'stale-sha',
    'stale-time',
    "user?.type === 'Bot'",
    'issueLabels.includes(''approved'')',
    'isExactIssueApproval'
)) {
    if ($workflow -notmatch [regex]::Escape($requiredAcknowledgementText)) {
        throw "Workflow is missing acknowledgement contract behavior: $requiredAcknowledgementText"
    }
    foreach ($requiredHeadObservationText in @(
        'pr-auto-merge-head:v1',
        'context.payload.pull_request?.updated_at',
        "['opened', 'reopened', 'synchronize']",
        'headObservedAt: headObservation?.observedAt'
    )) {
        if ($workflow -notmatch [regex]::Escape($requiredHeadObservationText)) {
            throw "Workflow is missing latest-push observation behavior: $requiredHeadObservationText"
        }
    }
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

$helperMatch = [regex]::Match(
    $workflow,
    '(?s)// BEGIN SOLO-DEV ACKNOWLEDGEMENT CONTRACT\r?\n(?<helper>.*?)\r?\n\s*// END SOLO-DEV ACKNOWLEDGEMENT CONTRACT'
)
if (-not $helperMatch.Success) {
    throw 'Workflow must expose the acknowledgement helper contract for behavioral tests.'
}

$scratchRoot = Join-Path $repoRoot 'test-results\pr-auto-merge-executor-contract'
$harnessPath = Join-Path $scratchRoot 'acknowledgement-contract.cjs'
try {
    if (Test-Path $scratchRoot) {
        Remove-Item -Path $scratchRoot -Recurse -Force
    }
    New-Item -Path $scratchRoot -ItemType Directory -Force | Out-Null

    $harness = @"
const assert = require('node:assert/strict');
$($helperMatch.Groups['helper'].Value)

const currentSha = 'a'.repeat(40);
const staleSha = 'b'.repeat(40);
const pushTime = '2026-08-11T10:00:00Z';
const afterPush = '2026-08-11T10:01:00Z';
const beforePush = '2026-08-11T09:59:00Z';
const permissions = {
  author: { permission: 'admin' },
  maintainer: { role_name: 'maintain' },
  writer: { permission: 'write' },
  reader: { permission: 'read' },
  'automation[bot]': { permission: 'admin' }
};
const resolvePermission = async login => permissions[login] || null;
const prComment = (login, body, createdAt = afterPush, type = 'User') => ({
  user: { login, type },
  body,
  created_at: createdAt
});
const evaluate = ({ comments = [], issues = [] } = {}) =>
  evaluateMaintainerAcknowledgement({
    headSha: currentSha,
    headObservedAt: pushTime,
    prComments: comments,
    linkedIssues: issues,
    resolvePermission
  });

(async () => {
  const author = await evaluate({
    comments: [prComment('author', '/acknowledge-critical ' + currentSha)]
  });
  assert.equal(author.satisfied, true, 'PR author with admin permission must be allowed to acknowledge');
  assert.equal(author.actor, 'author');

  const nonAuthor = await evaluate({
    comments: [prComment('maintainer', '/acknowledge-critical ' + currentSha)]
  });
  assert.equal(nonAuthor.satisfied, true, 'non-author maintainer must be allowed to acknowledge');

  const writer = await evaluate({
    comments: [prComment('writer', '/acknowledge-critical ' + currentSha)]
  });
  assert.equal(writer.satisfied, true, 'write permission must satisfy acknowledgement');

  const bot = await evaluate({
    comments: [prComment('automation[bot]', '/acknowledge-critical ' + currentSha, afterPush, 'Bot')]
  });
  assert.equal(bot.satisfied, false, 'bot acknowledgement must be rejected');
  assert.ok(bot.rejected.includes('bot:automation[bot]'));

  const arbitrary = await evaluate({
    comments: [prComment('reader', '/acknowledge-critical ' + currentSha)]
  });
  assert.equal(arbitrary.satisfied, false, 'read-only commenter must be rejected');

  const staleHead = await evaluate({
    comments: [prComment('author', '/acknowledge-critical ' + staleSha)]
  });
  assert.equal(staleHead.satisfied, false, 'acknowledgement for an earlier head SHA must be rejected');
  assert.ok(staleHead.rejected.includes('stale-sha:author'));

  const staleTime = await evaluate({
    comments: [prComment('author', '/acknowledge-critical ' + currentSha, beforePush)]
  });
  assert.equal(staleTime.satisfied, false, 'PR acknowledgement before the latest commit must be rejected');
  assert.ok(staleTime.rejected.includes('stale-time:author'));

  const linkedIssue = await evaluate({
    issues: [{
      number: 2809,
      approved: true,
      comments: [prComment('maintainer', '/approve')]
    }]
  });
  assert.equal(linkedIssue.satisfied, true, 'qualified /approve on a linked approved issue must satisfy acknowledgement');
  assert.equal(linkedIssue.source, 'linked-approved-issue');

  const unlabeledIssue = await evaluate({
    issues: [{
      number: 2809,
      approved: false,
      comments: [prComment('maintainer', '/approve')]
    }]
  });
  assert.equal(unlabeledIssue.satisfied, false, 'linked issue must also carry the approved label');

  assert.deepEqual(collectLinkedIssueNumbers('Fixes #2809\nCloses #42'), [2809, 42]);
  assert.equal(parseCriticalAcknowledgement('/acknowledge-critical ' + currentSha), currentSha);
  assert.equal(parseCriticalAcknowledgement('note\n/acknowledge-critical ' + currentSha), '');
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
"@
    Set-Content -Path $harnessPath -Value $harness -Encoding UTF8
    & node $harnessPath
    if ($LASTEXITCODE -ne 0) {
        throw 'Solo-dev maintainer acknowledgement behavioral contract tests failed.'
    }
} finally {
    if (Test-Path $scratchRoot) {
        Remove-Item -Path $scratchRoot -Recurse -Force
    }
}

Write-Host 'PR auto-merge executor workflow tests passed.'
