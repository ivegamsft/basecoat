'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { buildDeliveryReceipt, deriveReleaseDisposition, planReceiptAppend } = require('../scripts/release-owner-receipt.cjs');
const { deriveWindowReport } = require('../scripts/release-owner-report.cjs');

const sha = character => character.repeat(40);
const hex64 = character => character.repeat(64);

function fields(overrides = {}) {
  return {
    issue: '10', comment: '100', 'comment-created': '2025-01-01T00:00:00Z', 'comment-updated': '2025-01-01T00:00:00Z',
    'body-sha256': hex64('a'), 'body-edited': 'none', 'comment-sha256': hex64('b'),
    approver: 'octocat', permission: 'admin', 'auth-run': '555',
    'auth-cutoff': '2025-01-01T00:01:00Z', 'spec-blob': sha('c'), pr: 20, head: sha('d'),
    size: 'M', 'xxl-review': 'none', release: 'eligible', ...overrides
  };
}

test('builds a canonical receipt bound to its PR head and digest path', () => {
  const built = buildDeliveryReceipt(fields());
  assert.match(built.text, /^delivery-receipt:v1;issue:10;comment:100;/);
  assert.match(built.text, /;pr:20;head:d{40};size:M;xxl-review:none;release:eligible$/);
  assert.equal(built.path, `receipts/20/${sha('d')}/${built.digest}`);
  assert.equal(buildDeliveryReceipt(fields()).digest, built.digest);

  const report = deriveWindowReport({
    repositoryId: 1, tags: [{ name: 'v1.0.0', sha: sha('1'), verified: true }],
    candidateSha: sha('4'), candidateTreeSha: sha('5'), baselineIsAncestor: true,
    inventoryComplete: true, pullRequests: [{ number: 20, mergeSha: sha('6'), headSha: sha('d') }],
    reachableMergeShas: [sha('6')], receipts: { 20: [{ text: built.text, digest: built.digest }] }
  });
  assert.equal(report.state, 'CANDIDATE');
  assert.deepEqual(report.pullRequests.map(pr => pr.disposition), ['included']);
});

test('rejects unknown, missing, separator-bearing, and contract-violating fields', () => {
  assert.throws(() => buildDeliveryReceipt(fields({ extra: '1' })), /Unknown receipt field: extra/);
  const missing = fields();
  delete missing.head;
  assert.throws(() => buildDeliveryReceipt(missing), /Missing receipt field: head/);
  assert.throws(() => buildDeliveryReceipt(fields({ approver: 'a;b' })), /wrong field count/);
  assert.throws(() => buildDeliveryReceipt(fields({ 'delivery-receipt': 'v2' })), /delivery-receipt is invalid/);
  assert.throws(() => buildDeliveryReceipt(fields({ pr: 1.5 })), /string or safe integer/);
  assert.throws(() => buildDeliveryReceipt(fields({ size: 'XXL' })), /lacks a qualified review/);
  assert.throws(() => buildDeliveryReceipt(fields({ 'auth-cutoff': '2024-12-31T00:00:00Z' })), /chronologically/);
  assert.throws(() => buildDeliveryReceipt(null), /plain object/);
});

function evidence(reviews, overrides = {}) {
  return {
    reviews, head: sha('d'), prAuthor: 'author',
    permissions: { alice: { permission: 'write' }, bob: { permission: 'read' }, dave: { permission: 'maintain' }, author: { permission: 'admin' } },
    ...overrides
  };
}

function review(id, login, overrides = {}) {
  return {
    id, user: { login, type: 'User' }, state: 'APPROVED', commit_id: sha('d'),
    submitted_at: `2025-01-01T00:00:${String(id % 60).padStart(2, '0')}Z`, ...overrides
  };
}

test('derives release disposition from scope opt-out and the XXL boundary', () => {
  const xxl = (reviews, extra = {}) => deriveReleaseDisposition({
    size: 'XXL', scopeOptsOut: false, xxlReview: evidence(reviews, extra)
  });
  assert.deepEqual(deriveReleaseDisposition({ size: 'XL', scopeOptsOut: false }),
    { release: 'eligible', 'xxl-review': 'none' });
  assert.deepEqual(deriveReleaseDisposition({ size: 'S', scopeOptsOut: true }),
    { release: 'excluded', 'xxl-review': 'none' });
  assert.deepEqual(xxl([review(7, 'alice')]), { release: 'eligible', 'xxl-review': '7' });
  assert.deepEqual(deriveReleaseDisposition({ size: 'XXL', scopeOptsOut: true, xxlReview: evidence([review(7, 'alice')]) }),
    { release: 'excluded', 'xxl-review': '7' });

  const excluded = { release: 'excluded', 'xxl-review': 'none' };
  assert.deepEqual(xxl([]), excluded);
  assert.deepEqual(xxl([review(7, 'alice', { commit_id: sha('e') })]), excluded, 'stale head');
  assert.deepEqual(xxl([review(7, 'alice', { state: 'COMMENTED' })]), excluded, 'not approved');
  assert.deepEqual(xxl([review(7, 'bob')]), excluded, 'read permission');
  assert.deepEqual(xxl([review(7, 'carol')]), excluded, 'unknown permission');
  assert.deepEqual(xxl([review(7, 'author')]), excluded, 'self review');
  assert.deepEqual(xxl([review(7, 'ci[bot]')], { permissions: { 'ci[bot]': { permission: 'admin' } } }),
    excluded, 'bot review');
  assert.deepEqual(xxl([review(7, 'alice'), review(8, 'alice', { state: 'CHANGES_REQUESTED' })]), excluded,
    'superseded approval');
  assert.deepEqual(xxl([review(8, 'alice', { state: 'CHANGES_REQUESTED' }), review(9, 'alice')]),
    { release: 'eligible', 'xxl-review': '9' });
  assert.deepEqual(xxl([review(7, 'alice'), review(8, 'alice', { state: 'CHANGES_REQUESTED', submitted_at: null,
    created_at: '2025-01-01T00:01:00Z' })]), excluded, 'created_at fallback supersedes approval');
  assert.deepEqual(xxl([review(7, 'Author')]), excluded, 'case-variant self review');
  assert.deepEqual(xxl([review(7, 'alice'), review(8, 'Alice', { state: 'CHANGES_REQUESTED' })]), excluded);
  assert.deepEqual(xxl([review(9, 'alice'), review(8, 'dave', { state: 'CHANGES_REQUESTED' })]), excluded, 'blocker');
  assert.deepEqual(xxl([review(9, 'alice'), review(8, 'erin', { state: 'CHANGES_REQUESTED' })]), excluded, 'unresolved');
  assert.deepEqual(xxl([review(9, 'alice'), review(8, 'dave', { state: 'CHANGES_REQUESTED' })],
    { permissions: { alice: { permission: 'write' }, dave: null } }), excluded, 'null permission lookup');
  assert.deepEqual(xxl([review(68, 'alice'), review(8, 'alice', { state: 'CHANGES_REQUESTED' }), review(69, 'alice')]),
    { release: 'eligible', 'xxl-review': '69' }, 'superseded same-time conflict');
  assert.deepEqual(xxl([review(9, 'ALICE')]), { release: 'eligible', 'xxl-review': '9' });
  assert.throws(() => xxl([review(7, 'alice')], { permissions: { alice: { permission: 'write' }, Alice: { permission: 'read' } } }),
    /repeat a login/);

  assert.throws(() => deriveReleaseDisposition({ size: 'XXL', scopeOptsOut: false }), /review evidence/);
  assert.throws(() => xxl([review(7, 'alice', { submitted_at: 'not-a-date' })]), /valid dates/);
  assert.throws(() => xxl([review(7, 'alice', { submitted_at: null })]), /valid dates/, 'undated review');
  assert.throws(() => xxl([review(68, 'alice'), review(8, 'alice', { state: 'CHANGES_REQUESTED' })]), /same-time/);
  assert.throws(() => xxl([review(0, 'alice')]), /positive integers/);
  assert.throws(() => deriveReleaseDisposition({ size: 'M', scopeOptsOut: false, xxlReview: evidence([]) }), /Only XXL/);
  assert.throws(() => deriveReleaseDisposition({ size: 'XXXL', scopeOptsOut: false }), /Size/);
  assert.throws(() => deriveReleaseDisposition({ size: 'M', scopeOptsOut: 'no' }), /boolean/);

  for (const input of [
    { size: 'XXL', scopeOptsOut: false, xxlReview: evidence([review(7, 'alice')]) },
    { size: 'XXL', scopeOptsOut: false, xxlReview: evidence([]) },
    { size: 'L', scopeOptsOut: true }
  ]) {
    assert.doesNotThrow(() => buildDeliveryReceipt(fields({ size: input.size, ...deriveReleaseDisposition(input) })));
  }
});

test('plans appendReceipt with absent-or-exact semantics frozen at merge', () => {
  const first = buildDeliveryReceipt(fields());
  const base = { text: first.text, pr: 20, head: sha('d'), merged: false };

  assert.deepEqual(planReceiptAppend({ ...base, existing: {} }),
    { action: 'create', path: first.path, digest: first.digest, content: first.text });
  assert.deepEqual(planReceiptAppend({ ...base, existing: { [first.path]: first.text } }),
    { action: 'noop', path: first.path, digest: first.digest });
  assert.deepEqual(planReceiptAppend({ ...base, existing: { [first.path]: `${first.text} ` } }),
    { action: 'reject', reason: 'path-conflict' });

  const renewed = buildDeliveryReceipt(fields({ comment: '101', 'auth-cutoff': '2025-01-01T00:02:00Z' }));
  const plan = planReceiptAppend({ ...base, text: renewed.text, existing: { [first.path]: first.text } });
  assert.equal(plan.action, 'create');
  assert.notEqual(plan.path, first.path);

  assert.deepEqual(planReceiptAppend({ ...base, merged: true, existing: {} }),
    { action: 'reject', reason: 'pr-merged' });
  assert.equal(planReceiptAppend({ ...base, merged: 'false', existing: {} }).reason, 'invalid-merge-state');
  assert.equal(planReceiptAppend({ ...base, existing: [] }).reason, 'invalid-existing-inventory');
  assert.equal(planReceiptAppend({ ...base, existing: { x: 1 } }).reason, 'invalid-existing-inventory');
  assert.equal(planReceiptAppend({ ...base, existing: { x: first.text } }).reason, 'invalid-existing-inventory');
  const otherHead = `receipts/20/${sha('e')}/${first.digest}`;
  assert.equal(planReceiptAppend({ ...base, existing: { [otherHead]: first.text } }).reason,
    'invalid-existing-inventory');
  const tampered = { [renewed.path]: `${renewed.text}\n` };
  assert.equal(planReceiptAppend({ ...base, existing: tampered }).reason, 'invalid-existing-inventory');
  assert.equal(planReceiptAppend({ ...base, existing: { ...tampered, [first.path]: 'other' } }).reason,
    'path-conflict');
  assert.equal(planReceiptAppend({ ...base, text: 'bogus', existing: {} }).reason, 'receipt-malformed');
  assert.equal(planReceiptAppend({ ...base, pr: 21, existing: {} }).reason, 'pr-mismatch');
  assert.equal(planReceiptAppend({ ...base, pr: '20', existing: {} }).reason, 'pr-mismatch');
  assert.equal(planReceiptAppend({ ...base, head: sha('e'), existing: {} }).reason, 'head-mismatch');
});
