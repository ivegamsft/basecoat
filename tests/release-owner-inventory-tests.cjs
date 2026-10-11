'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  assembleInventory,
  groupReceiptBlobs,
  parseTagRefs,
  searchMergedPulls
} = require('../scripts/release-owner-inventory.cjs');
const { deriveWindowReport, receiptDigest } = require('../scripts/release-owner-report.cjs');

const sha = character => character.repeat(40);
const hex64 = character => character.repeat(64);

function receiptText(pr, head) {
  return [
    'delivery-receipt:v1', 'issue:10', 'comment:100', 'comment-created:2025-01-01T00:00:00Z',
    'comment-updated:2025-01-01T00:00:00Z', `body-sha256:${hex64('a')}`, 'body-edited:none',
    `comment-sha256:${hex64('b')}`, 'approver:octocat', 'permission:admin', 'auth-run:555',
    'auth-cutoff:2025-01-01T00:01:00Z', `spec-blob:${sha('c')}`, `pr:${pr}`, `head:${head}`,
    'size:M', 'xxl-review:none', 'release:eligible'
  ].join(';');
}

function blob(pr, head, text = receiptText(pr, head)) {
  return { path: `receipts/${pr}/${head}/${receiptDigest(text)}`, text };
}

function raw(overrides = {}) {
  return {
    repositoryId: 1,
    tags: [{ name: 'v1.0.0', sha: sha('1'), verified: true }],
    candidateSha: sha('4'),
    candidateTreeSha: sha('5'),
    baselineIsAncestor: true,
    windowCommits: [sha('6'), sha('7')],
    searchComplete: true,
    searchPulls: [
      { number: 20, mergeSha: sha('6'), headSha: sha('d'), position: 'window' },
      { number: 21, mergeSha: sha('7'), headSha: sha('e'), position: 'window' },
      { number: 19, mergeSha: sha('0'), headSha: sha('f'), position: 'before-baseline' },
      { number: 22, mergeSha: sha('8'), headSha: sha('9'), position: 'after-candidate' }
    ],
    receiptBlobs: null,
    ...overrides
  };
}

const report = overrides => deriveWindowReport(assembleInventory(raw(overrides)));

test('parses annotated and lightweight commit tags and skips non-commit tags', () => {
  const lines = [
    `v1.0.0\ttag\t${sha('a')}\tcommit\t${sha('b')}`,
    `v1.0.1\tcommit\t${sha('c')}\t\t`,
    `tree-tag\ttree\t${sha('d')}\t\t`,
    `tag-of-tree\ttag\t${sha('e')}\ttree\t${sha('f')}`
  ].join('\n');
  assert.deepEqual(parseTagRefs(lines), [{ name: 'v1.0.0', sha: sha('b') }, { name: 'v1.0.1', sha: sha('c') }]);
});

test('reconciles the window and reports NO_RELEASE when the receipts ref is absent', () => {
  const result = report();
  assert.equal(result.state, 'NO_RELEASE');
  assert.deepEqual(result.pullRequests.map(pr => [pr.number, pr.disposition]),
    [[20, 'excluded:missing-receipt'], [21, 'excluded:missing-receipt']]);
});

test('blocks on direct pushes, anomalous PRs, and incomplete search', () => {
  const direct = report({ windowCommits: [sha('6'), sha('7'), sha('3')] });
  assert.equal(direct.state, 'BLOCKED');
  assert.deepEqual(direct.missingFromApi, [sha('3')]);

  const anomaly = report({
    searchPulls: [...raw().searchPulls, { number: 23, mergeSha: sha('2'), headSha: sha('c'), position: 'anomaly' }]
  });
  assert.deepEqual(anomaly.missingFromGit, [sha('2')]);
  assert.deepEqual(report({ searchComplete: false }).reasons, ['incomplete-inventory']);
});

test('groups stored receipts by PR and fails closed on bad paths or rebound heads', () => {
  const included = report({ receiptBlobs: [blob(20, sha('d'))] });
  assert.equal(included.state, 'CANDIDATE');
  assert.equal(included.pullRequests[0].disposition, 'included');

  const rebound = blob(20, sha('d'));
  rebound.path = `receipts/20/${sha('e')}/${receiptDigest(rebound.text)}`;
  assert.deepEqual(groupReceiptBlobs([rebound]), { 20: [{ text: null, digest: receiptDigest(rebound.text) }] });
  assert.equal(report({ receiptBlobs: [rebound] }).pullRequests[0].disposition, 'excluded:receipt-digest-mismatch');

  assert.deepEqual(report({ receiptBlobs: [{ path: 'receipts/README', text: '' }] }).reasons,
    ['invalid-receipt-inventory']);
  assert.equal(report({ receiptBlobs: [{ path: `receipts/20/${sha('d')}/${hex64('0')}`, text: 'bad' }] })
    .pullRequests[0].disposition, 'excluded:receipt-digest-mismatch');

  const trailing = blob(20, sha('d'));
  trailing.text += '\n';
  assert.equal(report({ receiptBlobs: [trailing] }).pullRequests[0].disposition, 'excluded:receipt-digest-mismatch');
});

function pager(pages) {
  const calls = [];
  const fetchPage = (q, after) => {
    calls.push(after);
    return pages[calls.length - 1];
  };
  return { calls, fetchPage };
}

const node = number => ({ number, mergedAt: '2025-01-01T00:00:00Z', headRefOid: sha('d'), mergeCommit: { oid: sha('6') } });

test('paginates merged-PR search and fails closed when the inventory is incomplete', () => {
  const pages = [
    { issueCount: 3, pageInfo: { hasNextPage: true, endCursor: 'c1' }, nodes: [node(1), node(2)] },
    { issueCount: 3, pageInfo: { hasNextPage: false, endCursor: 'c2' }, nodes: [node(3)] }
  ];
  const full = pager(pages);
  const result = searchMergedPulls('o/r', 'main', '2025-01-01', full.fetchPage);
  assert.deepEqual(full.calls, [null, 'c1']);
  assert.equal(result.complete, true);
  assert.deepEqual(result.pulls.map(pr => pr.number), [1, 2, 3]);
  assert.deepEqual(result.pulls[0], { number: 1, mergedAt: '2025-01-01T00:00:00Z', headSha: sha('d'), mergeSha: sha('6') });

  const overLimit = pager([{ issueCount: 1001, pageInfo: { hasNextPage: false }, nodes: [node(1)] }]);
  assert.equal(searchMergedPulls('o/r', 'main', '2025-01-01', overLimit.fetchPage).complete, false);

  const short = pager([{ issueCount: 2, pageInfo: { hasNextPage: false }, nodes: [node(1)] }]);
  assert.equal(searchMergedPulls('o/r', 'main', '2025-01-01', short.fetchPage).complete, false);

  const stuck = pager([
    { issueCount: 4, pageInfo: { hasNextPage: true, endCursor: 'c1' }, nodes: [node(1)] },
    { issueCount: 4, pageInfo: { hasNextPage: true, endCursor: 'c1' }, nodes: [node(2)] }
  ]);
  assert.equal(searchMergedPulls('o/r', 'main', '2025-01-01', stuck.fetchPage).complete, false);
  assert.deepEqual(stuck.calls, [null, 'c1']);
});
