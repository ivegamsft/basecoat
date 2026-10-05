'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { execFileSync } = require('node:child_process');
const test = require('node:test');
const {
  evaluatePullRequestLabels,
  isReleaseLabel,
  selectCurrentMergeGroupPullRequests,
  verifyCurrentSquashMergeTree
} = require('../scripts/merge-group-release-labels.cjs');

test('release-label matcher accepts only documented formats', () => {
  for (const label of ['wave:1', 'sprint:40', 'wave-1', 'sprint-2026-05', 'wave/sprint']) {
    assert.equal(isReleaseLabel(label), true, label);
  }
  for (const label of ['wave', 'sprint', 'size:S', 'needs-triage']) {
    assert.equal(isReleaseLabel(label), false, label);
  }
});

test('explicit supported exemptions are checked on each pull request', () => {
  assert.deepEqual(
    evaluatePullRequestLabels({ labels: [{ name: 'skip-release-label-gate' }] }),
    { valid: true, reason: 'skip-release-label-gate label' }
  );
  assert.deepEqual(
    evaluatePullRequestLabels({ labels: [{ name: 'dependencies' }] }),
    { valid: true, reason: 'dependencies label' }
  );
  assert.deepEqual(
    evaluatePullRequestLabels({ labels: [] }),
    { valid: false, reason: 'missing release label' }
  );
  assert.throws(() => evaluatePullRequestLabels(null), /label data is incomplete/);
});

const groupHeadSha = 'a'.repeat(40);
const queueEntry = () => ({
  state: 'AWAITING_CHECKS',
  headCommit: { oid: groupHeadSha },
  pullRequest: { number: 3496, state: 'OPEN', baseRefName: 'main', headRefOid: 'b'.repeat(40) }
});

test('squash membership comes from live queue identity, not original head ancestry', () => {
  assert.deepEqual(
    selectCurrentMergeGroupPullRequests({
      baseRef: 'main',
      groupHeadSha,
      queueEntries: [queueEntry()]
    }).map(pullRequest => pullRequest.number),
    [3496]
  );
});

test('unresolvable, stale, or duplicate membership fails closed', () => {
  for (const entries of [[], [queueEntry(), queueEntry()]]) {
    assert.throws(() => selectCurrentMergeGroupPullRequests({
      baseRef: 'main', groupHeadSha, queueEntries: entries
    }), /exactly one live queue entry/);
  }
  for (const mutate of [
    entry => { entry.pullRequest.state = 'CLOSED'; },
    entry => { entry.pullRequest.baseRefName = 'release'; },
    entry => { entry.pullRequest.headRefOid = ''; },
    entry => { entry.state = 'QUEUED'; }
  ]) {
    const entry = queueEntry();
    mutate(entry);
    assert.throws(() => selectCurrentMergeGroupPullRequests({
      baseRef: 'main', groupHeadSha, queueEntries: [entry]
    }), /stale or incomplete/);
  }
  assert.throws(() => selectCurrentMergeGroupPullRequests({
    baseRef: 'main', groupHeadSha, queueEntries: null
  }), /data is incomplete/);
});

test('real synthetic squash tree verifies current source head and rejects changed heads/base', () => {
  const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'basecoat-queue-tree-'));
  const git = args => execFileSync('git', args, {
    cwd: fixture, encoding: 'utf8',
    env: { ...process.env, GIT_AUTHOR_NAME: 'Test', GIT_AUTHOR_EMAIL: 'test@example.invalid',
      GIT_COMMITTER_NAME: 'Test', GIT_COMMITTER_EMAIL: 'test@example.invalid' }
  }).trim();
  try {
    git(['init', '--quiet']);
    fs.writeFileSync(path.join(fixture, 'base.txt'), 'base');
    git(['add', '.']);
    git(['commit', '--quiet', '-m', 'base']);
    const baseSha = git(['rev-parse', 'HEAD']);
    fs.writeFileSync(path.join(fixture, 'feature.txt'), 'feature');
    git(['add', '.']);
    git(['commit', '--quiet', '-m', 'feature']);
    const sourceHead = git(['rev-parse', 'HEAD']);
    const tree = git(['rev-parse', 'HEAD^{tree}']);
    const squashSha = git(['commit-tree', tree, '-p', baseSha, '-m', 'synthetic queue squash']);
    const runGit = args => args[0] === 'fetch' ? '' : git(args);
    verifyCurrentSquashMergeTree({ baseSha, groupHeadSha: squashSha, pullRequestHeadSha: sourceHead, runGit });
    fs.writeFileSync(path.join(fixture, 'feature.txt'), 'changed head');
    git(['add', '.']);
    git(['commit', '--quiet', '-m', 'changed']);
    const changedHead = git(['rev-parse', 'HEAD']);
    assert.throws(() => verifyCurrentSquashMergeTree({
      baseSha, groupHeadSha: squashSha, pullRequestHeadSha: changedHead, runGit
    }), /refusing stale membership/);
    assert.throws(() => verifyCurrentSquashMergeTree({
      baseSha: sourceHead, groupHeadSha: squashSha, pullRequestHeadSha: sourceHead, runGit
    }), /refusing stale membership/);
  } finally {
    fs.rmSync(fixture, { recursive: true, force: true });
  }
});

test('every selected constituent must independently satisfy the release-label gate', () => {
  const constituents = [
    { number: 10, labels: [{ name: 'wave:1' }] },
    { number: 11, labels: [{ name: 'skip-release-label-gate' }] },
    { number: 12, labels: [] }
  ];

  assert.equal(evaluatePullRequestLabels(constituents[0]).valid, true);
  assert.equal(evaluatePullRequestLabels(constituents[1]).valid, true);
  assert.equal(evaluatePullRequestLabels(constituents[2]).valid, false);
});

test('required workflows are wired to merge-group validation without a silent skip', () => {
  const root = path.join(__dirname, '..');
  const ci = fs.readFileSync(path.join(root, '.github/workflows/ci.yml'), 'utf8');
  const agentMerge = fs.readFileSync(path.join(root, '.github/workflows/agent-merge.yml'), 'utf8');
  const prValidation = fs.readFileSync(path.join(root, '.github/workflows/pr-validation.yml'), 'utf8');
  const helper = fs.readFileSync(path.join(root, 'scripts/merge-group-release-labels.cjs'), 'utf8');

  for (const [name, workflow] of [['CI', ci], ['Agent Merge', agentMerge], ['PR Validation', prValidation]]) {
    assert.match(workflow, /merge_group:\s*\r?\n\s+types:\s*\r?\n\s+- checks_requested/, `${name} trigger`);
  }
  assert.match(prValidation, /selectCurrentMergeGroupPullRequests/);
  assert.match(prValidation, /currentPullRequest\.head\.sha !== candidate\.head\.sha/);
  assert.match(prValidation, /refusing to validate stale membership/);
  assert.match(prValidation, /baseRef !== 'main'/);
  assert.match(prValidation, /github\.graphql/);
  assert.match(prValidation, /verifyCurrentSquashMergeTree/);
  assert.match(helper, /exactly one live queue entry/);
});
