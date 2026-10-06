'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const { reviewSnapshotDigest, sha256 } = require('../.github/base-coat/scripts/pr-decomposition-evaluator.cjs');
const root = path.resolve(__dirname, '..');
const workflow = name => fs.readFileSync(path.join(root, '.github', 'workflows', name), 'utf8').replace(/\r\n/g, '\n');
const executor = workflow('pr-auto-merge-executor.yml');
const validation = workflow('pr-validation.yml');
const spec = workflow('prd-spec-gate.yml');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const checks = executor.slice(executor.indexOf('            const readRequiredCheckState = async () => {'),
  executor.indexOf('            const unsatisfiedChecks = requiredCheckState'));
const guard = executor.slice(executor.indexOf('            const { data: finalPr }'),
  executor.indexOf('            const eligible = blockers.length === 0;'));
const snapshot = executor.slice(executor.indexOf('            const metadataDigest ='),
  executor.indexOf('            const publishEligibilityStatus ='));
const routing = executor.split('  route-ci-completion:')[1].split('  route-pr-acknowledgement:')[0]
  .split('          script: |\n')[1].split('\n').map(line => line.replace(/^ {12}/, '')).join('\n');
const requiredChecks = ['ci', 'windows', 'unix', 'validation', 'spec'];
const pr = () => ({
  number: 3577, head: { sha: 'a'.repeat(40) }, base: { sha: 'b'.repeat(40), ref: 'main' },
  state: 'open', draft: false, title: 'Title', body: 'Body', labels: [],
  changed_files: 1, additions: 1, deletions: 0
});
const review = () => ({ id: 1, state: 'APPROVED', commit_id: 'a'.repeat(40), user: { login: 'maintainer' } });
const checkRuns = () => requiredChecks.map((name, id) => ({
  name, id, app: { id: 15368 }, status: 'completed', conclusion: 'success',
  started_at: '2026-10-06T00:00:00Z', completed_at: '2026-10-06T00:01:00Z'
}));

// A controlled scheduler fixture: notifications every second, a 100ms policy
// service, and GitHub's one-running/one-replaceable-pending concurrency contract.
const burst = ['labeled', 'unlabeled', 'edited', ...requiredChecks.map(name => `completed:${name}`)];
function replay(waitSeconds) {
  let freeAt = 0;
  let pending;
  let replaced = 0;
  const evaluations = [];
  const readTimes = [];
  for (const [time, event] of burst.entries()) {
    if (time >= freeAt) {
      if (pending !== undefined) {
        evaluations.push(pending);
        readTimes.push(freeAt + waitSeconds);
        freeAt += waitSeconds + 0.1;
        pending = undefined;
      }
      if (time >= freeAt) {
        evaluations.push(event);
        readTimes.push(time + waitSeconds);
        freeAt = time + waitSeconds + 0.1;
        continue;
      }
    }
    if (pending !== undefined) replaced++;
    pending = event;
  }
  if (pending !== undefined) {
    evaluations.push(pending);
    readTimes.push(freeAt + waitSeconds);
  }
  return { evaluations, readTimes, replaced };
}

function evidenceAt(time) {
  const current = pr();
  const runs = checkRuns().map(check => ({ ...check, status: 'in_progress', conclusion: null }));
  for (const [index, event] of burst.entries()) {
    if (index > time) break;
    if (event === 'labeled') current.labels = [{ name: 'delivery-hold' }];
    else if (event === 'unlabeled') current.labels = [];
    else if (event === 'edited') current.body = 'Final body';
    else Object.assign(runs.find(check => check.name === event.split(':')[1]),
      { status: 'completed', conclusion: 'success' });
  }
  return { current, runs };
}

function replayCodeValidation(metadataLane) {
  const active = new Map();
  let codeRequests = 0;
  let codeCancellations = 0;
  for (const [time, action] of ['opened', 'labeled', 'unlabeled'].entries()) {
    const lane = metadataLane && action !== 'opened' ? 'metadata' : 'code';
    if (lane === 'code') {
      codeRequests++;
      if ((active.get(lane) || 0) > time) codeCancellations++;
    }
    active.set(lane, time + 10);
  }
  return { codeRequests, codeCancellations };
}

test('burst retains a final evaluation without caching any authorization decision', async () => {
  assert.match(executor, /format\('pr-\{0\}', github.event.pull_request.number \|\| inputs.pr_number/);
  assert.match(executor, /cancel-in-progress: false/);
  assert.match(executor, /name: Coalesce eligibility notifications\n\s+shell: bash\n\s+run: sleep 10/);
  const baseline = replay(0);
  const coalesced = replay(10);
  assert.equal(baseline.evaluations.length, 8);
  assert.equal(coalesced.evaluations.length, 2);
  assert.equal(coalesced.evaluations.at(-1), burst.at(-1));
  let lookupCalls = 0;
  let dispatchCalls = 0;
  for (const name of requiredChecks) {
    await new AsyncFunction('github', 'context', 'core', 'process', routing)({
      paginate: async () => { lookupCalls++; return [pr()]; },
      rest: { repos: { listPullRequestsAssociatedWithCommit() {} },
        actions: { createWorkflowDispatch: async () => { dispatchCalls++; } } }
    }, { repo: { owner: 'owner', repo: 'repo' }, payload: {
      workflow_run: { head_sha: pr().head.sha, name }, repository: { default_branch: 'main' }
    } }, { info() {} }, { env: { WORKFLOW_REF: 'owner/repo/.github/workflows/pr-auto-merge-executor.yml@main' } });
  }
  assert.equal(lookupCalls, 5);
  assert.equal(dispatchCalls, 5);
  let calls = 0;
  const read = async time => {
    const { current, runs } = evidenceAt(time);
    const result = await new AsyncFunction('github', 'core', 'owner', 'repo', 'headSha', 'pr',
    'requiredChecks', 'githubActionsIntegrationId', checks + '\nreturn requiredCheckState;')({
    rest: {
      repos: { getCombinedStatusForRef: async () => { calls++; return { data: { statuses: [] } }; } },
      checks: { listForRef: async () => { calls++; return { data: { check_runs: runs } }; } }
    }
    }, { info() {} }, 'owner', 'repo', current.head.sha, current, requiredChecks, 15368);
    return { current, result };
  };
  const baselineResults = [];
  for (const time of baseline.readTimes) baselineResults.push(await read(time));
  assert.equal(baselineResults[0].result.unsatisfiedChecks.length, 5);
  assert.equal(baselineResults.at(-1).result.unsatisfiedChecks.length, 0);
  const baselineCalls = calls;
  calls = 0;
  for (const time of coalesced.readTimes) {
    const { current, result } = await read(time);
    assert.equal(current.body, 'Final body');
    assert.deepEqual(current.labels, []);
    assert.equal(result.unsatisfiedChecks.length, 0);
    assert.equal(result.evidence, (await read(time + 0.1)).result.evidence);
  }
  assert.equal(baselineCalls, 16);
  assert.equal(calls, 8);
  console.log(JSON.stringify({ fixture: '8 notifications / 7 seconds / 100ms policy service',
    baselineEvaluations: 8, coalescedEvaluations: 2, baselineCheckCalls: baselineCalls,
    coalescedCheckCalls: calls, lookupCalls, dispatchCalls, replacedPending: coalesced.replaced }));
});

test('PRD/spec gate re-fetches metadata instead of accepting an obsolete skip label or body', async () => {
  const script = spec.split('          script: |\n')[1].split('\n')
    .map(line => line.replace(/^ {12}/, '')).join('\n');
  let reads = 0;
  const failures = [];
  await new AsyncFunction('github', 'context', 'core', script)({
    rest: { pulls: { get: async () => {
      reads++;
      return { data: { ...pr(), changed_files: 12, additions: 500, body: '', user: { login: 'contributor' } } };
    } } }
  }, { repo: { owner: 'owner', repo: 'repo' }, payload: {
    pull_request: { ...pr(), body: 'PRD: link\nSpec: link', labels: [{ name: 'skip-prd-spec-check' }] }
  } }, { notice() {}, warning() {}, setFailed: failure => failures.push(failure) });
  assert.equal(reads, 1);
  assert.equal(failures.length, 1);
});

test('metadata lane cannot cancel code validation; merge-group/manual code validation remains', () => {
  assert.match(validation, /github.ref.*'metadata' \|\| 'code'/);
  assert.match(validation, /cancel-in-progress:.*!contains/);
  const jobs = validation.split('\njobs:\n')[1];
  for (const name of ['main-branch-protection-readiness', 'forbidden-internal-identifier-gate',
    'markdown-lint', 'gitleaks-scan', 'validate-agent-files', 'sync-dry-run']) {
    const job = jobs.split(`  ${name}:`)[1].split(/\n  [a-z]/)[0];
    assert.match(job, /if:.*!contains\(fromJSON\('\["labeled","unlabeled"\]'\), github.event.action\)/);
  }
  assert.match(jobs.split('  release-label-gate:')[1], /pulls.get/);
  assert.match(validation, /merge_group:\n\s+types:\n\s+- checks_requested/);
  assert.match(spec, /merge_group:\n\s+types:\n\s+- checks_requested/);
  assert.match(spec, /cancel-in-progress: false/);
  assert.match(spec, /const \{ data: pr \} = await github.rest.pulls.get/);
  const baseline = replayCodeValidation(false);
  const coalesced = replayCodeValidation(true);
  assert.deepEqual(baseline, { codeRequests: 3, codeCancellations: 2 });
  assert.deepEqual(coalesced, { codeRequests: 1, codeCancellations: 0 });
  console.log(JSON.stringify({ fixture: 'opened+labeled+unlabeled / 10s code service', baseline, coalesced }));
});

for (const [name, mutate] of [
  ['equivalent evidence', () => {}],
  ['head', state => { state.pr.head.sha = 'c'.repeat(40); }],
  ['base', state => { state.pr.base.sha = 'c'.repeat(40); }],
  ['metadata', state => { state.pr.body = 'Changed'; }],
  ['title', state => { state.pr.title = 'Changed'; }],
  ['hold added', state => { state.pr.labels.push({ name: 'delivery-hold' }); }],
  ['hold removed', state => { state.pr.labels = []; }],
  ['approval dismissal', state => { state.reviews[0].state = 'DISMISSED'; }],
  ['approval added', state => { state.reviews.push({ ...review(), id: 2 }); }],
  ['check failure', state => { state.checks[0].conclusion = 'failure'; }],
  ['check rerun', state => { state.checks[0].id = 100; }],
  ['check pending', state => { state.checks[0].status = 'in_progress'; state.checks[0].conclusion = null; }],
  ['check disappeared', state => { state.checks = []; }]
]) {
  test(`fresh final authorization guard: ${name}`, async () => {
    const state = { pr: pr(), reviews: [review()], checks: checkRuns() };
    if (name === 'hold removed') state.pr.labels = [{ name: 'delivery-hold' }];
    const originalReviews = structuredClone(state.reviews);
    let reads = 0;
    let dispatches = 0;
    const statuses = [];
    const outputs = {};
    const github = { rest: {
      pulls: { get: async () => ({ data: state.pr }), listReviews() {} },
      repos: {
        getCombinedStatusForRef: async () => ({ data: { statuses: [] } }),
        createCommitStatus: async value => statuses.push(value)
      },
      checks: { listForRef: async () => {
        const result = structuredClone(state.checks);
        if (++reads === 1) mutate(state);
        return { data: { check_runs: result } };
      } },
      actions: { createWorkflowDispatch: async () => { dispatches++; } }
    }, paginate: async () => state.reviews };
    await new AsyncFunction('github', 'core', 'process', 'owner', 'repo', 'prNumber', 'pr', 'baseSha',
      'headSha', 'requiredChecks', 'githubActionsIntegrationId', 'sha256', 'reviewSnapshotDigest',
      'reviews', 'workflowUrl', 'eligibilityStatusContext', 'defaultBranch',
      snapshot + '\ninitialSnapshot.reviewDigest = reviewSnapshotDigest(reviews);\n' + checks + guard)(
      github, { info() {}, setFailed() {}, setOutput: (key, value) => { outputs[key] = value; } },
      { env: { WORKFLOW_REF: 'owner/repo/.github/workflows/pr-auto-merge-executor.yml@main' } },
      'owner', 'repo', 3577, structuredClone(state.pr), state.pr.base.sha, state.pr.head.sha,
      requiredChecks, 15368, sha256, reviewSnapshotDigest, originalReviews, 'run-url',
      'BaseCoat merge eligibility', 'main');
    assert.equal(reads, 2);
    assert.equal(dispatches, name === 'equivalent evidence' ? 0 : 1);
    if (dispatches) {
      assert.equal(outputs.eligible, 'false');
      assert.equal(statuses[0].state, 'pending');
      assert.equal(statuses[0].sha, state.pr.head.sha);
    }
  });
}
