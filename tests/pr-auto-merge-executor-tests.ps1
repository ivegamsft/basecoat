[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$workflowPath = Join-Path $repoRoot '.github\workflows\pr-auto-merge-executor.yml'
$templatePath = Join-Path $repoRoot '.github\base-coat\workflows\pr-auto-merge-executor.yml'
$humanBoundaryPath = Join-Path $repoRoot '.github\governance\human-approval-boundaries.json'
$prValidationPath = Join-Path $repoRoot '.github\workflows\pr-validation.yml'
$decompositionEvaluatorPath = Join-Path $repoRoot '.github\base-coat\scripts\pr-decomposition-evaluator.cjs'
$rootPrTemplatePath = Join-Path $repoRoot '.github\PULL_REQUEST_TEMPLATE.md'
$managedPrTemplatePath = Join-Path $repoRoot 'templates\intake\PULL_REQUEST_TEMPLATE.md'
$reviewReconcilePath = Join-Path $repoRoot '.github\workflows\merge-eligibility-human-review-reconcile.yml'
$reviewReconcileTemplatePath = Join-Path $repoRoot '.github\base-coat\workflows\merge-eligibility-human-review-reconcile.yml'
$sizeLabelerPath = Join-Path $repoRoot '.github\workflows\pr-size-labeler.yml'

if (-not (Test-Path $workflowPath)) {
    throw "Missing workflow file: $workflowPath"
}
if (-not (Test-Path $templatePath)) {
    throw "Missing template workflow file: $templatePath"
}
if (-not (Test-Path $humanBoundaryPath)) {
    throw "Missing human approval boundary file: $humanBoundaryPath"
}
if (-not (Test-Path $prValidationPath)) {
    throw "Missing PR validation workflow file: $prValidationPath"
}
foreach ($path in @(
    $decompositionEvaluatorPath,
    $rootPrTemplatePath,
    $managedPrTemplatePath,
    $reviewReconcilePath,
    $reviewReconcileTemplatePath,
    $sizeLabelerPath
)) {
    if (-not (Test-Path $path)) {
        throw "Missing decomposition enforcement dependency: $path"
    }
}

$workflow = Get-Content -Path $workflowPath -Raw
$template = Get-Content -Path $templatePath -Raw
$prValidation = Get-Content -Path $prValidationPath -Raw
$reviewReconcile = Get-Content -Path $reviewReconcilePath -Raw
$reviewReconcileTemplate = Get-Content -Path $reviewReconcileTemplatePath -Raw
$sizeLabeler = Get-Content -Path $sizeLabelerPath -Raw
$rootPrTemplate = Get-Content -Path $rootPrTemplatePath -Raw
$managedPrTemplate = Get-Content -Path $managedPrTemplatePath -Raw

foreach ($scopeField in @(
    'Change scope: TBD',
    'Source issues: TBD',
    'Independently deliverable units: TBD',
    'Expected changed lines (additions + deletions): TBD',
    'Classification rationale: TBD',
    'Mechanical batch exception evidence: none',
    'Batch exception: <40-character-head-sha> <64-character-evidence-sha256>'
)) {
    if (
        $rootPrTemplate -notmatch [regex]::Escape($scopeField) -or
        $managedPrTemplate -notmatch [regex]::Escape($scopeField)
    ) {
        throw "Root and downstream PR templates must keep the batch-scope contract in parity: $scopeField"
    }
}

if ($workflow -ne $template) {
    throw 'Workflow template mismatch: .github/workflows and .github/base-coat/workflows copies must be identical.'
}
if ($workflow -notmatch "\.github/base-coat/scripts/pr-decomposition-evaluator\.cjs") {
    throw 'Merge eligibility must invoke the distributed decomposition evaluator from the trusted default-branch checkout.'
}
if ($workflow -notmatch '(?s)Checkout repository.*?ref:\s*\$\{\{\s*github\.event\.repository\.default_branch\s*\|\|\s*''main''\s*\}\}') {
    throw 'Privileged evaluation must load trusted code from the default branch, never the pull request head.'
}
foreach ($requiredDecompositionText in @(
    'changedFiles: pr.changed_files',
    'additions: pr.additions',
    'deletions: pr.deletions',
    'files,',
    'decomposition.reviewPending',
    'initialSnapshot',
    'finalSnapshot',
    'PR metadata changed during evaluation',
    'pre-merge-snapshot:',
    'needs: [evaluate, pre-merge-snapshot]',
    'EXPECTED_BASE_SHA',
    'EXPECTED_DECOMPOSITION_DIGEST',
    'EXPECTED_EXCEPTION_REVIEW_ID',
    'EXPECTED_REVIEW_DIGEST',
    'approvalsStillSatisfied',
    'reviewSnapshotDigest',
    'github.paginate(github.rest.pulls.listFiles',
    'decomposition.decision === ''pass''',
    'humanApprovalSizes',
    'requiresHumanApprovalBySize',
    'requiredApprovals = Math.max'
)) {
    if ($workflow -notmatch [regex]::Escape($requiredDecompositionText)) {
        throw "Merge eligibility is missing decomposition or snapshot validation: $requiredDecompositionText"
    }
}
foreach ($unchangedSizeBoundary in @(
    'max: 20',
    'max: 100',
    'max: 300',
    'max: 800',
    'max: 2000',
    "label: 'size:XXL'"
)) {
    if ($sizeLabeler -notmatch [regex]::Escape($unchangedSizeBoundary)) {
        throw "PR size-label boundaries must remain unchanged: $unchangedSizeBoundary"
    }
}
foreach ($requiredReleaseLabelPollingText in @(
    'max_label_poll_attempts=10',
    'for attempt in $(seq 1 "$max_label_poll_attempts"); do',
    'Waiting for asynchronous PR labeling',
    'Release label gate passed on label poll'
)) {
    if ($prValidation -notmatch [regex]::Escape($requiredReleaseLabelPollingText)) {
        throw "PR validation must wait for asynchronous release labeling: $requiredReleaseLabelPollingText"
    }
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
if ($workflow -notmatch '(?ms)workflow_run:\s*\r?\n\s*workflows:\s*\r?\n\s*-\s*"BaseCoat - CI"\s*\r?\n\s*types:\s*\r?\n\s*-\s*completed') {
    throw 'Workflow must reroute successful BaseCoat CI completion events to merge eligibility evaluation.'
}
foreach ($requiredCiCompletionRoutingText in @(
    'route-ci-completion',
    "github.event.workflow_run.conclusion == 'success'",
    "github.event.workflow_run.event == 'pull_request'",
    'github.event.workflow_run.head_repository.full_name == github.repository',
    'github.paginate(',
    'github.rest.repos.listPullRequestsAssociatedWithCommit',
    'per_page: 100',
    'Queued post-CI merge eligibility reevaluation for PR #${pullRequest.number}.',
    "github.event_name != 'workflow_run'"
)) {
    if ($workflow -notmatch [regex]::Escape($requiredCiCompletionRoutingText)) {
        throw "Workflow is missing trusted CI-completion routing: $requiredCiCompletionRoutingText"
    }
}
foreach ($concurrencyNamespace in @("format('workflow-run-{0}'", "format('issue-{0}'", "format('comment-{0}'", "format('pr-{0}'")) {
    if ($workflow -notmatch [regex]::Escape($concurrencyNamespace)) {
        throw "Workflow must namespace concurrency routing: $concurrencyNamespace"
    }
}
if ($workflow -notmatch '(?ms)pull_request_review:\s*\r?\n\s*types:\s*\r?\n\s*-\s*dismissed') {
    throw 'Workflow must re-evaluate review dismissal without directly accepting untrusted submitted reviews.'
}
$reviewTrigger = [regex]::Match(
    $workflow,
    '(?ms)^\s{2}pull_request_review:\s*\r?\n(?<block>.*?)(?=^\s{2}[a-z_]+:\s*$|^permissions:\s*$)'
)
if (-not $reviewTrigger.Success) {
    throw 'Workflow must define the pull_request_review dismissal trigger.'
}
if ($reviewTrigger.Groups['block'].Value -match '(?m)(?:\[\s*submitted\s*\]|^\s*-\s*submitted\s*$)') {
    throw 'Workflow must not run directly on submitted pull request reviews; the Copilot reviewer app has no repository permission and GitHub blocks those runs before any job can execute.'
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
if ($workflow -notmatch 'mergeStateStatus' -or
    $workflow -notmatch 'pulls/\$\{PR_NUMBER\}/update-branch') {
    throw 'Workflow must update an eligible auto-merge PR when strict protection reports it behind main.'
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
foreach ($requiredBootstrapPolicyText in @(
    'readJsonFromDefaultBranchOptional',
    'readJsonFromPullRequestHeadOptional',
    'normalizeProductionDigestPolicy',
    'Number(error?.status) === 404',
    'BaseCoat governance policy ${path} is not yet present on ${defaultBranch}.',
    "const trustedPolicy = await readJsonFromDefaultBranchOptional('.github/governance/policy-packs.json');",
    "const pullRequestPolicy = await readJsonFromPullRequestHeadOptional(",
    'Pull request governance policy may update production workflow digests only',
    "const humanBoundaries = await readJsonFromDefaultBranchOptional('.github/governance/human-approval-boundaries.json');",
    'BaseCoat governance policy is not yet installed on ${defaultBranch}; skipping merge evaluation.'
)) {
    if (-not $workflow.Contains($requiredBootstrapPolicyText)) {
        throw "Workflow must handle absent default-branch policy as a neutral bootstrap skip: $requiredBootstrapPolicyText"
    }
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
if ($workflow -notmatch 'const requiresHumanReviewByBoundary\s*=\s*\r?\n\s*requiresHumanReviewByRisk \|\| requiresHumanApprovalBySize;') {
    throw 'Workflow must define the reported human review boundary from risk and size policy.'
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
if ($workflow -notmatch [regex]::Escape('if (existing && existing.startedAt > startedAt) continue;')) {
    throw 'Workflow must keep only the most recently started check run per name so a stale cancelled/failed rerun cannot clobber a newer passing result.'
}
if ($workflow -notmatch 'if \(!statusSucceeded && !checkSucceeded\)') {
    throw 'Workflow must treat pending or missing required checks as unsatisfied.'
}
if ($workflow -notmatch 'waitingForRequiredChecks' -or
    $workflow -notmatch 'waitingForExternalProgress' -or
    $workflow -notmatch [regex]::Escape('Waiting for required status checks to complete.')) {
    throw 'Workflow must keep merge eligibility pending while required checks are still running.'
}
if ($workflow -notmatch [regex]::Escape('contains(fromJSON(''["opened","reopened","synchronize"]''), github.event.action)')) {
    throw 'Workflow must cancel in-progress eligibility only when the pull request head changes.'
}
if ($workflow -match '(?m)^\s*cancel-in-progress:\s*true\s*$') {
    throw 'Workflow must not cancel in-progress eligibility on label or edit storms.'
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
const fs = require('node:fs');
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

$decompositionHarnessPath = Join-Path $scratchRoot 'decomposition-contract.cjs'
try {
    New-Item -Path $scratchRoot -ItemType Directory -Force | Out-Null
    $installedConsumerRoot = Join-Path $scratchRoot 'installed-consumer'
    $installedScripts = Join-Path $installedConsumerRoot '.github\base-coat\scripts'
    $installedWorkflows = Join-Path $installedConsumerRoot '.github\workflows'
    New-Item -Path $installedScripts, $installedWorkflows -ItemType Directory -Force | Out-Null
    Copy-Item -LiteralPath $decompositionEvaluatorPath -Destination $installedScripts
    $installedExecutorPath = Join-Path $installedWorkflows 'basecoat-pr-auto-merge-executor.yml'
    Copy-Item -LiteralPath $templatePath -Destination $installedExecutorPath
    $previousGitHubWorkspace = $env:GITHUB_WORKSPACE
    $env:GITHUB_WORKSPACE = $installedConsumerRoot
    $env:INSTALLED_EXECUTOR_PATH = $installedExecutorPath
    $decompositionHarness = @'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const installedWorkflow = fs.readFileSync(process.env.INSTALLED_EXECUTOR_PATH, 'utf8');
const evaluatorPaths = Array.from(
  installedWorkflow.matchAll(/require\(\s*require\('node:path'\)\.join\(process\.env\.GITHUB_WORKSPACE,\s*'([^']+)'\)\s*\)/g),
  match => match[1]
);
assert.deepEqual(
  evaluatorPaths,
  [
    '.github/base-coat/scripts/pr-decomposition-evaluator.cjs',
    '.github/base-coat/scripts/pr-decomposition-evaluator.cjs'
  ],
  'the installed executor jobs must load the evaluator from the managed runtime payload'
);
const installedEvaluator = require(path.join(process.env.GITHUB_WORKSPACE, evaluatorPaths[0]));
assert.equal(installedEvaluator.MAX_FILES, 15, 'the installed evaluator dependency must load successfully');
const {
  MAX_FILES,
  MAX_LINES,
  evaluateDecomposition,
  reviewSnapshotDigest
} = require(process.env.DECOMPOSITION_EVALUATOR);

const headSha = 'a'.repeat(40);
const baseSha = 'b'.repeat(40);
const inputRevision = 'c'.repeat(40);
const permissionByLogin = {
  maintainer: { role_name: 'maintain' },
  writer: { permission: 'write' },
  reader: { permission: 'read' },
  'reviewer[bot]': { permission: 'admin' }
};
const resolvePermission = async login => permissionByLogin[login] || null;
const makeFiles = (count, prefix = 'docs/generated') =>
  Array.from({ length: count }, (_, index) => ({
    filename: `${prefix}/file-${String(index).padStart(2, '0')}.md`,
    status: 'modified'
  }));
const makeBody = ({
  scope = 'batch',
  units = 2,
  unitInventory = 'work unit A; work unit B',
  rationale = 'independently deployable work units.',
  issues = [3475],
  exception = null,
  scopeLines = ''
} = {}) => [
  '## Intake Contract',
  '',
  '### Design',
  '',
  `Change scope: ${scope}`,
  scopeLines,
  `Source issues: ${issues.map(issue => `#${issue}`).join(', ')}`,
  `Independently deliverable units: ${units}`,
  `Unit inventory: ${unitInventory}`,
  'Expected files: 16',
  'Expected changed lines (additions + deletions): 301',
  `Classification rationale: ${rationale}`,
  `Mechanical batch exception evidence: ${exception ? 'proposed' : 'none'}`,
  ...(exception ? ['```json', JSON.stringify(exception, null, 2), '```'] : []),
  '',
  '### Debate',
  '',
  'Alternatives were considered.'
].filter(Boolean).join('\n');
const makeException = (files, updates = {}) => ({
  command: 'generator --source input.json',
  tool_version: 'generator 1.2.3',
  input_revision: inputRevision,
  file_inventory: files.map(file => ({
    path: file.filename,
    status: file.status,
    previous_path: file.previous_filename || ''
  })),
  smaller_batches_not_viable: 'All outputs are generated from one atomic source snapshot.',
  reproduction_diff_evidence: 'Re-running the declared generator produces an identical diff.',
  validation_command: 'generator --check',
  validation_result: 'Passed with no diff.',
  rollback_procedure: 'Revert the generated-output commit.',
  source_issues: [3475],
  head_sha: headSha,
  base_sha: baseSha,
  ...updates
});
const makeReview = (digest, updates = {}) => ({
  id: 42,
  user: { login: 'maintainer', type: 'User' },
  state: 'APPROVED',
  commit_id: headSha,
  body: `Reviewed evidence.\nBatch exception: ${headSha} ${digest}`,
  submitted_at: '2026-10-04T01:00:00Z',
  ...updates
});
const evaluate = async ({
  body,
  exception = null,
  files = makeFiles(16),
  changedFiles = files.length,
  additions = 150,
  deletions = 151,
  reviews = [],
  authorLogin = 'author',
  ...extra
} = {}) => evaluateDecomposition({
  body: body || makeBody({ exception }),
  changedFiles,
  additions,
  deletions,
  files,
  headSha,
  baseSha,
  reviews,
  authorLogin,
  resolvePermission,
  ...extra
});

(async () => {
  assert.equal(MAX_FILES, 15);
  assert.equal(MAX_LINES, 300);
  const sizeLabelerText = fs.readFileSync(process.env.SIZE_LABELER_PATH, 'utf8');
  const thresholdBlock = sizeLabelerText.match(/const thresholds = \[([\s\S]*?)\n\s*\];/)?.[1];
  assert.ok(thresholdBlock, 'the existing deterministic size-label thresholds must remain present');
  const sizeThresholds = Array.from(
    thresholdBlock.matchAll(/\{\s*label:\s*'([^']+)',\s*max:\s*(\d+|Number\.MAX_SAFE_INTEGER)/g),
    match => ({ label: match[1], max: match[2] === 'Number.MAX_SAFE_INTEGER' ? Number.MAX_SAFE_INTEGER : Number(match[2]) })
  );
  const sizeFor = lines => sizeThresholds.find(threshold => lines <= threshold.max)?.label;
  for (const [lines, expected] of [
    [20, 'size:XS'], [21, 'size:S'],
    [100, 'size:S'], [101, 'size:M'],
    [300, 'size:M'], [301, 'size:L'],
    [800, 'size:L'], [801, 'size:XL'],
    [2000, 'size:XL'], [2001, 'size:XXL']
  ]) {
    assert.equal(sizeFor(lines), expected, `the existing ${lines}-line size boundary is unchanged`);
  }
  assert.equal((await evaluate({
    files: makeFiles(15),
    changedFiles: 15,
    additions: 150,
    deletions: 150
  })).decision, 'pass', '15 files and 300 total changed lines are inclusive');
  assert.equal((await evaluate({
    files: makeFiles(14),
    changedFiles: 14,
    additions: 150,
    deletions: 149
  })).decision, 'pass', 'batches below both thresholds pass');
  assert.equal((await evaluate({
    files: makeFiles(16),
    changedFiles: 16,
    additions: 300,
    deletions: 0
  })).decision, 'block', '16 files block even at the inclusive line limit');
  assert.equal((await evaluate({
    files: makeFiles(15),
    changedFiles: 15,
    additions: 150,
    deletions: 151
  })).decision, 'block', '301 lines block even at the inclusive file limit');
  assert.equal((await evaluate({
    files: makeFiles(16),
    changedFiles: 16,
    additions: 150,
    deletions: 151
  })).decision, 'block', 'overflow of both limits requires decomposition');
  assert.equal((await evaluate({
    body: makeBody({
      scope: 'individual',
      units: 1,
      unitInventory: 'one cohesive feature'
    }),
    files: makeFiles(16),
    changedFiles: 16,
    additions: 300,
    deletions: 1
  })).decision, 'pass', 'a cohesive individual feature has no batch cap');
  assert.equal((await evaluate({
    files: makeFiles(73),
    changedFiles: 73,
    additions: 3000,
    deletions: 3169
  })).decision, 'block', 'the 73-file/6169-line batch blocks without an exception');

  const batchFiles = makeFiles(16);
  const exception = makeException(batchFiles);
  const proposal = await evaluate({ files: batchFiles, exception });
  assert.equal(proposal.decision, 'pending', `an exception proposal is not authorization: ${proposal.reason}`);
  assert.match(proposal.evidenceDigest, /^[0-9a-f]{64}$/);
  const validApproval = makeReview(proposal.evidenceDigest);
  const approvedException = await evaluate({
    files: batchFiles,
    exception,
    reviews: [validApproval]
  });
  assert.equal(approvedException.decision, 'pass');
  assert.equal(approvedException.reviewId, validApproval.id);

  const mixedBehaviorFiles = makeFiles(16);
  mixedBehaviorFiles[0].filename = 'scripts/authentication-check.ps1';
  assert.equal((await evaluate({
    files: mixedBehaviorFiles,
    exception: makeException(mixedBehaviorFiles),
    reviews: [validApproval]
  })).decision, 'block', 'sensitive auth changes cannot ride a mechanical exception');

  assert.equal((await evaluate({
    body: '## Intake Contract\n### Design\n\nChange scope: batch',
    files: makeFiles(16),
    changedFiles: 16
  })).decision, 'block', 'missing scope metadata fails closed');
  assert.equal((await evaluate({
    body: makeBody({ scopeLines: 'Change scope: batch' }),
    files: makeFiles(16),
    changedFiles: 16
  })).decision, 'block', 'duplicate scope metadata fails closed');
  assert.equal((await evaluate({
    body: makeBody({
      scope: 'individual',
      units: 2,
      unitInventory: 'work unit A; work unit B'
    }),
    files: makeFiles(16),
    changedFiles: 16
  })).decision, 'block', 'individual scope contradicting multiple deliverables fails closed');
  for (const placeholder of ['TBD', 'TODO', 'N/A', '<unit description>']) {
    assert.equal((await evaluate({
      body: makeBody({
        scope: 'individual',
        units: 1,
        unitInventory: placeholder
      }),
      files: makeFiles(1),
      changedFiles: 1,
      additions: 1,
      deletions: 0
    })).decision, 'block', `individual scope rejects placeholder unit inventory '${placeholder}'`);
    assert.equal((await evaluate({
      body: makeBody({
        scope: 'individual',
        units: 1,
        unitInventory: 'one cohesive feature',
        rationale: placeholder
      }),
      files: makeFiles(1),
      changedFiles: 1,
      additions: 1,
      deletions: 0
    })).decision, 'block', `individual scope rejects placeholder rationale '${placeholder}'`);
  }
  assert.equal((await evaluate({
    changedFiles: undefined
  })).decision, 'block', 'missing authoritative counts do not become zero');
  assert.equal((await evaluate({
    additions: -1
  })).decision, 'block', 'negative authoritative counts fail closed');
  assert.equal((await evaluate({
    files: makeFiles(15),
    changedFiles: 16
  })).decision, 'block', 'incomplete GitHub file inventory fails closed');

  const editedException = makeException(batchFiles, {
    command: 'generator --source changed.json'
  });
  const changedEvidence = await evaluate({
    files: batchFiles,
    exception: editedException,
    reviews: [validApproval]
  });
  assert.equal(changedEvidence.decision, 'pending');
  assert.notEqual(changedEvidence.evidenceDigest, proposal.evidenceDigest);
  const changedBase = await evaluate({
    files: batchFiles,
    exception: makeException(batchFiles, { base_sha: 'e'.repeat(40) })
  });
  assert.equal(changedBase.decision, 'block', 'exception evidence must bind the current base SHA');
  const duplicateJsonBody = makeBody({ exception }).replace(
    '"command": "generator --source input.json",',
    '"command": "generator --source input.json",\n  "command": "generator --source altered.json",'
  );
  assert.equal((await evaluate({
    files: batchFiles,
    body: duplicateJsonBody
  })).decision, 'block', 'duplicate JSON keys cannot create ambiguous evidence');

  const unqualified = await evaluate({
    files: batchFiles,
    exception,
    reviews: [makeReview(proposal.evidenceDigest, {
      user: { login: 'reader', type: 'User' }
    })]
  });
  assert.equal(unqualified.decision, 'pending', 'read-only reviewers cannot authorize exceptions');
  const botReview = await evaluate({
    files: batchFiles,
    exception,
    reviews: [makeReview(proposal.evidenceDigest, {
      user: { login: 'reviewer[bot]', type: 'Bot' }
    })]
  });
  assert.equal(botReview.decision, 'pending', 'bot reviews cannot authorize exceptions');
  const authorReview = await evaluate({
    files: batchFiles,
    exception,
    reviews: [validApproval],
    authorLogin: 'maintainer'
  });
  assert.equal(authorReview.decision, 'pending', 'the PR author cannot authorize an exception');
  const staleReview = await evaluate({
    files: batchFiles,
    exception,
    reviews: [makeReview(proposal.evidenceDigest, { commit_id: 'd'.repeat(40) })]
  });
  assert.equal(staleReview.decision, 'pending', 'reviews on an earlier head cannot authorize an exception');
  const changedReview = await evaluate({
    files: batchFiles,
    exception,
    reviews: [
      validApproval,
      makeReview(proposal.evidenceDigest, {
        id: 43,
        state: 'CHANGES_REQUESTED',
        submitted_at: '2026-10-04T02:00:00Z'
      })
    ]
  });
  assert.equal(changedReview.decision, 'pending', 'a later non-approval revokes the earlier approval');
  assert.notEqual(
    reviewSnapshotDigest([validApproval]),
    reviewSnapshotDigest([{
      ...validApproval,
      body: `${validApproval.body}\nEdited after evaluation`
    }]),
    'the pre-merge snapshot changes when review evidence is edited'
  );
  const editedAnnotation = await evaluate({
    files: batchFiles,
    exception,
    reviews: [makeReview(proposal.evidenceDigest, {
      body: 'Reviewed evidence.\nBatch exception: edited'
    })]
  });
  assert.equal(editedAnnotation.decision, 'pending', 'edited annotation invalidates the review binding');
  const duplicateAnnotation = await evaluate({
    files: batchFiles,
    exception,
    reviews: [makeReview(proposal.evidenceDigest, {
      body: `Batch exception: ${headSha} ${proposal.evidenceDigest}\nBatch exception: ${headSha} ${proposal.evidenceDigest}`
    })]
  });
  assert.equal(duplicateAnnotation.decision, 'pending', 'annotation must appear exactly once');

  const spoofedLabel = await evaluate({
    files: makeFiles(16),
    changedFiles: 16,
    additions: 300,
    deletions: 0,
    labels: ['size:S']
  });
  assert.equal(spoofedLabel.decision, 'block', 'size labels do not authorize oversized batches');
  const unknownPermission = await evaluate({
    files: batchFiles,
    exception,
    reviews: [makeReview(proposal.evidenceDigest)],
    resolvePermission: async () => { throw new Error('permission API unavailable'); }
  });
  assert.equal(unknownPermission.decision, 'pending', 'permission API failures deny exception authorization');
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
'@
    Set-Content -Path $decompositionHarnessPath -Value $decompositionHarness -Encoding UTF8
    $env:DECOMPOSITION_EVALUATOR = $decompositionEvaluatorPath
    $env:SIZE_LABELER_PATH = $sizeLabelerPath
    & node $decompositionHarnessPath
    if ($LASTEXITCODE -ne 0) {
        throw 'PR decomposition evaluator behavioral contract tests failed.'
    }
} finally {
    if ($null -eq $previousGitHubWorkspace) {
        Remove-Item Env:\GITHUB_WORKSPACE -ErrorAction SilentlyContinue
    } else {
        $env:GITHUB_WORKSPACE = $previousGitHubWorkspace
    }
    Remove-Item Env:\INSTALLED_EXECUTOR_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:\DECOMPOSITION_EVALUATOR -ErrorAction SilentlyContinue
    Remove-Item Env:\SIZE_LABELER_PATH -ErrorAction SilentlyContinue
    if (Test-Path $scratchRoot) {
        Remove-Item -Path $scratchRoot -Recurse -Force
    }
}

Write-Host 'PR auto-merge executor workflow tests passed.'
