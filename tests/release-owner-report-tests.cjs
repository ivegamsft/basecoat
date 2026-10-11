'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  deriveWindowReport,
  parseReceipt,
  receiptDigest,
  selectBaseline
} = require('../scripts/release-owner-report.cjs');

const sha = character => character.repeat(40);
const hex64 = character => character.repeat(64);

function receipt(overrides = {}) {
  const fields = {
    'delivery-receipt': 'v1', issue: '10', comment: '100',
    'comment-created': '2025-01-01T00:00:00Z', 'comment-updated': '2025-01-01T00:00:00Z',
    'body-sha256': hex64('a'), 'body-edited': 'none', 'comment-sha256': hex64('b'),
    approver: 'octocat', permission: 'admin', 'auth-run': '555',
    'auth-cutoff': '2025-01-01T00:01:00Z', 'spec-blob': sha('c'), pr: '20', head: sha('d'),
    size: 'M', 'xxl-review': 'none', release: 'eligible', ...overrides
  };
  const text = Object.entries(fields).map(([key, value]) => `${key}:${value}`).join(';');
  return { text, digest: receiptDigest(text) };
}

function inventory(overrides = {}) {
  return {
    repositoryId: 12345,
    tags: [
      { name: 'v4.9.0', sha: sha('1'), verified: true },
      { name: 'v4.10.0', sha: sha('2'), verified: true },
      { name: 'v9.0.0', sha: sha('3'), verified: false }
    ],
    candidateSha: sha('4'),
    candidateTreeSha: sha('5'),
    baselineIsAncestor: true,
    inventoryComplete: true,
    pullRequests: [
      { number: 20, mergeSha: sha('6'), headSha: sha('d') },
      { number: 21, mergeSha: sha('7'), headSha: sha('e') }
    ],
    reachableMergeShas: [sha('6'), sha('7')],
    receipts: { 20: [receipt()] },
    ...overrides
  };
}

test('parses the delivery receipt grammar and rejects malformed or inconsistent receipts', () => {
  assert.equal(parseReceipt(receipt().text)['auth-cutoff'], '2025-01-01T00:01:00Z');
  assert.throws(() => parseReceipt(receipt({ permission: 'triage' }).text), /permission/);
  assert.throws(() => parseReceipt(receipt({ head: 'abc' }).text), /head/);
  assert.throws(() => parseReceipt(`${receipt().text};extra:1`), /field count/);
  assert.throws(() => parseReceipt(receipt({ 'xxl-review': '9' }).text), /non-XXL/);
  assert.throws(() => parseReceipt(receipt({ size: 'XXL' }).text), /qualified review/);
  assert.equal(parseReceipt(receipt({ size: 'XXL', 'xxl-review': '9' }).text).size, 'XXL');
  for (const overrides of [
    { 'comment-updated': '2024-12-31T23:59:59Z' },
    { 'auth-cutoff': '2025-01-01T00:00:00Z' },
    { 'body-edited': '2025-01-01T00:00:30Z' }
  ]) {
    assert.throws(() => parseReceipt(receipt(overrides).text), /chronologically/);
  }
  assert.equal(parseReceipt(receipt({ 'body-edited': '2024-12-31T00:00:00Z' }).text)['body-edited'],
    '2024-12-31T00:00:00Z');
  assert.throws(() => parseReceipt(receipt({ 'auth-cutoff': '2025-02-30T00:00:00Z' }).text), /auth-cutoff/);
  assert.throws(() => parseReceipt(receipt({ 'comment-created': '2025-01-01T24:00:00Z' }).text),
    /comment-created/);
  assert.equal(parseReceipt(receipt({ 'comment-created': '2024-02-29T00:00:00Z',
    'comment-updated': '2024-02-29T00:00:00Z', 'auth-cutoff': '2024-02-29T23:59:59.5Z' }).text)['auth-cutoff'],
    '2024-02-29T23:59:59.5Z');
});

test('selects the highest verified canonical tag numerically', () => {
  assert.deepEqual(selectBaseline(inventory().tags), { name: 'v4.10.0', sha: sha('2') });
  assert.equal(selectBaseline([{ name: 'v1.0.0-rc.1', sha: sha('1'), verified: true }]), null);
});

test('derives a candidate that includes only PRs with a current eligible receipt', () => {
  const report = deriveWindowReport(inventory());
  assert.equal(report.mode, 'report-only');
  assert.equal(report.state, 'CANDIDATE');
  assert.equal(report.liveRevalidation, 'not-evaluated');
  assert.deepEqual(report.baseline, { name: 'v4.10.0', sha: sha('2') });
  assert.deepEqual(report.pullRequests.map(pr => pr.disposition), ['included', 'excluded:missing-receipt']);
  assert.equal(report.candidateTreeSha, sha('5'));
  assert.deepEqual(report.authorizations, [{ issue: 10, commentId: '100', receiptDigest: receipt().digest }]);
  assert.match(report.windowKey, /^[0-9a-f]{64}$/);
  assert.equal(deriveWindowReport(inventory()).windowKey, report.windowKey);
});

test('blocks on missing baseline, ancestry, incomplete pages, or API and git disagreement', () => {
  assert.deepEqual(deriveWindowReport(inventory({ tags: [] })).reasons, ['no-verified-baseline']);
  assert.deepEqual(deriveWindowReport(inventory({ baselineIsAncestor: false })).reasons,
    ['baseline-not-ancestor']);
  assert.deepEqual(deriveWindowReport(inventory({ inventoryComplete: false })).reasons,
    ['incomplete-inventory']);
  const mismatch = deriveWindowReport(inventory({ reachableMergeShas: [sha('6'), sha('8')] }));
  assert.equal(mismatch.state, 'BLOCKED');
  assert.deepEqual(mismatch.missingFromGit, [sha('7')]);
  assert.deepEqual(mismatch.missingFromApi, [sha('8')]);
  const duplicate = inventory();
  duplicate.pullRequests[1].number = 20;
  assert.deepEqual(deriveWindowReport(duplicate).reasons, ['invalid-pull-request-inventory']);
  for (const overrides of [{ candidateSha: 'abc' }, { candidateTreeSha: undefined }, { repositoryId: 0 },
    { candidateSha: [sha('4')] }]) {
    assert.deepEqual(deriveWindowReport(inventory({ receipts: {}, ...overrides })).reasons, ['invalid-candidate']);
  }
  for (const reachableMergeShas of [[sha('6'), 'abc'], [sha('6'), sha('7'), sha('7')], [sha('6'), [sha('7')]]]) {
    assert.deepEqual(deriveWindowReport(inventory({ reachableMergeShas })).reasons, ['incomplete-inventory']);
  }
});

test('excludes tampered, mismatched, opted-out, and ambiguous receipts with a reason', () => {
  const cases = [
    [[{ ...receipt(), digest: hex64('f') }], 'excluded:receipt-digest-mismatch'],
    [[receipt({ release: 'maybe' })], 'excluded:receipt-malformed'],
    [[receipt({ pr: '99' })], 'excluded:receipt-pr-mismatch'],
    [[receipt({ head: sha('9') })], 'excluded:head-mismatch'],
    [[receipt({ release: 'excluded' })], 'excluded:release-opt-out']
  ];
  for (const [entries, expected] of cases) {
    const report = deriveWindowReport(inventory({ receipts: { 20: entries } }));
    assert.equal(report.state, 'NO_RELEASE', expected);
    assert.equal(report.pullRequests[0].disposition, expected);
    assert.equal(report.windowKey, undefined);
  }
  const other = receipt({ pr: '21', head: sha('e'), issue: '11' });
  const ambiguous = deriveWindowReport(inventory({
    receipts: { 20: [receipt(), receipt({ comment: '101' })], 21: [other] }
  }));
  assert.equal(ambiguous.state, 'BLOCKED');
  assert.deepEqual(ambiguous.reasons, ['ambiguous-authorization']);
  assert.deepEqual(ambiguous.pullRequests.map(pr => pr.disposition), ['excluded:ambiguous-receipt', 'included']);
  assert.equal(ambiguous.windowKey, undefined);
  for (const receipts of [null, [], { 20: receipt() }, { 20: null }]) {
    assert.deepEqual(deriveWindowReport(inventory({ receipts })).reasons, ['invalid-receipt-inventory']);
  }
  assert.deepEqual(deriveWindowReport(inventory({ tags: 'v1.0.0' })).reasons, ['invalid-tag-inventory']);
  for (const bad of [{ name: 'v9.0.0', sha: 'abc', verified: true }, { name: 'v9.0.0', sha: sha('9') }, null]) {
    const tags = [...inventory().tags, bad];
    assert.deepEqual(deriveWindowReport(inventory({ tags })).reasons, ['invalid-tag-inventory']);
  }
  const conflicting = [{ name: 'v5.0.0', sha: sha('1'), verified: true }, { name: 'v5.0.0', sha: sha('2'), verified: true }];
  for (const tags of [conflicting, [...conflicting].reverse(),
    [conflicting[0], { ...conflicting[1], verified: false }],
    [conflicting[0], { ...conflicting[0], verified: false }]]) {
    assert.deepEqual(deriveWindowReport(inventory({ tags })).reasons, ['ambiguous-tag-inventory']);
  }
  const sharedSha = inventory({ reachableMergeShas: [sha('6')] });
  sharedSha.pullRequests[1].mergeSha = sha('6');
  assert.deepEqual(deriveWindowReport(sharedSha).reasons, ['invalid-pull-request-inventory']);
  const tampered = { ...receipt(), digest: hex64('f') };
  const malformed = receipt({ release: 'maybe' });
  for (const entries of [[tampered, malformed, receipt()], [receipt(), malformed, tampered]]) {
    assert.equal(deriveWindowReport(inventory({ receipts: { 20: entries } })).pullRequests[0].disposition,
      'excluded:receipt-digest-mismatch');
  }
  assert.throws(() => parseReceipt(receipt({ issue: '9007199254740993' }).text), /issue/);
  assert.throws(() => parseReceipt(receipt({ pr: '9007199254740993' }).text), /pr/);
});

test('opted-out receipts bind their authorization into the window key', () => {
  const optOut = extra => receipt({ pr: '21', head: sha('e'), issue: '11', release: 'excluded', ...extra });
  const first = deriveWindowReport(inventory({ receipts: { 20: [receipt()], 21: [optOut()] } }));
  assert.equal(first.state, 'CANDIDATE');
  assert.equal(first.pullRequests[1].disposition, 'excluded:release-opt-out');
  assert.equal(first.authorizations.length, 2);
  const renewed = deriveWindowReport(inventory({
    receipts: { 20: [receipt()], 21: [optOut({ comment: '200' })] }
  }));
  assert.notEqual(renewed.windowKey, first.windowKey);
  const only = deriveWindowReport(inventory({ receipts: { 21: [optOut()] } }));
  assert.equal(only.state, 'NO_RELEASE');
  assert.equal(only.authorizations.length, 1);
});

test('the latest auth-cutoff receipt wins over earlier renewals for the same head', () => {
  const earlier = receipt({ release: 'excluded' });
  const renewed = receipt({ comment: '101', 'auth-cutoff': '2025-01-02T00:00:00Z' });
  const report = deriveWindowReport(inventory({ receipts: { 20: [earlier, renewed] } }));
  assert.equal(report.state, 'CANDIDATE');
  assert.equal(report.pullRequests[0].disposition, 'included');
  const obsoleteHead = receipt({ head: sha('9'), comment: '102', 'auth-cutoff': '2025-01-03T00:00:00Z' });
  const merged = deriveWindowReport(inventory({ receipts: { 20: [renewed, obsoleteHead] } }));
  assert.equal(merged.pullRequests[0].disposition, 'included');
});
