'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { execFileSync } = require('node:child_process');
const test = require('node:test');
const {
  classifyPullRequestLabels,
  evaluatePullRequestLabels,
  evaluateReleaseCoverage,
  isReleaseLabel,
  parseReleaseCommits,
  runReleaseCoverage,
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
  assert.throws(() => evaluatePullRequestLabels({ labels: [{ name: '' }] }), /nonempty name/);
});

test('one classifier yields the same per-PR result at every stage', () => {
  const cases = [
    [['WAVE:5'], 'release-label'], [['Sprint-2026-10'], 'release-label'],
    [['wave/sprint', 'dependencies'], 'release-label'],
    [['Skip-Release-Label-Gate'], 'explicit-exemption'], [['dependencies'], 'dependency-exemption'],
    [['size:S'], 'uncovered'], [[], 'uncovered']
  ];
  cases.forEach(([labels, reason], index) => {
    const fork = { number: index + 1, labels, head: { repo: { fork: true } } };
    const classified = classifyPullRequestLabels(fork);
    assert.equal(classified.reason, reason, labels.join(','));
    assert.equal(evaluatePullRequestLabels(fork).valid, classified.covered);
    assert.deepEqual(evaluateReleaseCoverage([fork]).results[0], { number: index + 1, ...classified });
  });
});

const window = (covered, uncovered, exempt = 0) => [
  ...Array.from({ length: covered }, (_, i) => ({ number: i + 1, labels: ['sprint:1'] })),
  ...Array.from({ length: exempt }, (_, i) => ({ number: 100 + i, labels: [{ name: 'dependencies' }] })),
  ...Array.from({ length: uncovered }, (_, i) => ({ number: 200 + i, labels: [] }))
];

test('release coverage counts exemptions as covered and enforces the 10% boundary', () => {
  assert.equal(evaluateReleaseCoverage([]).status, 'empty');
  assert.equal(evaluateReleaseCoverage(window(10, 0)).status, 'pass');
  const exact = evaluateReleaseCoverage(window(9, 1));
  assert.equal(exact.status, 'partial');
  assert.deepEqual(exact.uncoveredNumbers, [200]);
  assert.equal(evaluateReleaseCoverage(window(8, 2)).status, 'fail');
  const mixed = evaluateReleaseCoverage(window(2, 1, 7));
  assert.deepEqual(
    [mixed.status, mixed.total, mixed.releaseLabelCovered, mixed.exemptCovered, mixed.uncovered],
    ['partial', 10, 2, 7, 1]
  );
  assert.equal(evaluateReleaseCoverage(window(0, 0, 3)).status, 'pass');
});

test('release coverage rejects malformed or duplicate inventory', () => {
  assert.throws(() => evaluateReleaseCoverage(null), /inventory is incomplete/);
  assert.throws(() => evaluateReleaseCoverage([{ number: 0, labels: [] }]), /malformed PR number/);
  assert.throws(() => evaluateReleaseCoverage([{ number: 1, labels: [] }, { number: 1, labels: [] }]), /duplicate PR #1/);
  assert.throws(() => evaluateReleaseCoverage([{ number: 1 }]), /label data is incomplete/);
});

test('release membership comes from the exact range and fails closed', () => {
  const [prev, tag, c7, c8] = ['1', '2', '7', '8'].map(digit => digit.repeat(40));
  assert.deepEqual(
    parseReleaseCommits([`${c7}\tfix: a (#3808) (#7)`, `${c8}\tMerge pull request #8 from x/y`]),
    [{ sha: c7, number: 7 }, { sha: c8, number: 8 }]
  );
  assert.throws(() => parseReleaseCommits([`${c7}\tchore: direct push`]), /no pull-request association/);
  const labels = { 7: ['sprint:1'], 8: ['skip-release-label-gate'] };
  const runCommand = (cmd, args) => {
    if (args[0] === 'rev-parse') return args[1].startsWith('v1') ? prev : tag;
    if (args[0] === 'merge-base') return '';
    if (args[0] === 'log') return `${c7}\tfeat: x (#7)\n${c8}\tci: y (#8)`;
    const number = Number(args[1].split('/').pop());
    return JSON.stringify({ number, merged: true, mergeCommitSha: number === 8 ? c8 : c7, labels: labels[number] || [] });
  };
  const run = command => runReleaseCoverage({ repository: 'o/r', previousTag: 'v1.0.0', tag: 'v2.0.0', runCommand: command, log: () => {} });
  const result = run(runCommand);
  assert.deepEqual([result.status, result.previousSha, result.tagSha, result.exemptCovered], ['pass', prev, tag, 1]);
  assert.throws(() => run((cmd, args) => {
    if (args[0] === 'merge-base') throw new Error('exit 1');
    return runCommand(cmd, args);
  }), /not an ancestor/);
  assert.throws(() => run((cmd, args) => (args[0] === 'log' ? `${c8}\tborrowed (#9)` : runCommand(cmd, args))), /did not produce release range commit/);
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
