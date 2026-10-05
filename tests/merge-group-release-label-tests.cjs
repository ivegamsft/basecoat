'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const {
  evaluatePullRequestLabels,
  isReleaseLabel,
  selectCurrentMergeGroupPullRequests
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

test('merge-group membership requires current open heads targeting the event base', () => {
  const pullRequests = [
    { number: 10, state: 'open', base: { ref: 'main' }, head: { sha: 'head-a' } },
    { number: 11, state: 'open', base: { ref: 'main' }, head: { sha: 'head-b' } },
    { number: 12, state: 'open', base: { ref: 'main' }, head: { sha: 'stale-head' } },
    { number: 13, state: 'closed', base: { ref: 'main' }, head: { sha: 'head-c' } },
    { number: 14, state: 'open', base: { ref: 'release' }, head: { sha: 'head-d' } }
  ];

  assert.deepEqual(
    selectCurrentMergeGroupPullRequests({
      baseRef: 'main',
      commitShas: ['base', 'head-a', 'head-b'],
      pullRequests
    }).map(pullRequest => pullRequest.number),
    [10, 11]
  );
});

test('unresolvable, stale, or duplicate membership fails closed', () => {
  assert.throws(
    () => selectCurrentMergeGroupPullRequests({
      baseRef: 'main',
      commitShas: ['stale-head'],
      pullRequests: [
        { number: 10, state: 'open', base: { ref: 'main' }, head: { sha: 'current-head' } }
      ]
    }),
    /No open main-targeting pull request/
  );
  assert.throws(
    () => selectCurrentMergeGroupPullRequests({
      baseRef: 'main',
      commitShas: [],
      pullRequests: null
    }),
    /data is incomplete/
  );
  assert.throws(
    () => selectCurrentMergeGroupPullRequests({
      baseRef: 'main',
      commitShas: ['head-a'],
      pullRequests: [
        { number: 10, state: 'open', base: { ref: 'main' }, head: { sha: 'head-a' } },
        { number: 10, state: 'open', base: { ref: 'main' }, head: { sha: 'head-a' } }
      ]
    }),
    /identities are ambiguous/
  );
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
  assert.match(helper, /No open \$\{baseRef\}-targeting pull request/);
});
