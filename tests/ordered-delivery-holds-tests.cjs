'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  admissionOperationKey,
  evaluateHold,
  itemKey,
  planAdmission,
  reconcileAdmission
} = require('../.github/base-coat/scripts/ordered-delivery-holds.cjs');

const scope = { repositoryId: 1, targetRef: 'main', id: 'wave-5', version: 1 };
const writer = { controlsAllEntryPaths: true };
const item = (prNumber, issueNumber, createdAt, overrides = {}) => ({
  prNumber,
  headSha: String(prNumber).padStart(40, '0'),
  sources: [{ issueNumber, createdAt }],
  ready: true,
  eligible: true,
  holdLabel: false,
  ...overrides
});
const hold = (overrides = {}) => ({
  scope, pr: 3, owner: 'lane-a', reason: 'staging', revision: 2,
  createdAt: '2026-10-01T00:00:00Z', reviewAt: '2026-10-05T00:00:00Z', ...overrides
});

test('independent ready items are admitted by recorded source age, not arrival order', () => {
  const items = [item(30, 300, '2026-10-03T00:00:00Z'), item(10, 100, '2026-10-01T00:00:00Z'), item(20, 200, '2026-10-02T00:00:00Z')];
  assert.deepEqual(planAdmission({ scope, items, writer }).prNumber, 10);
  items[1].admitted = true;
  assert.equal(planAdmission({ scope, items, writer }).prNumber, 20);
});

test('multi-source items use the oldest included source and missing sources block', () => {
  assert.equal(itemKey(item(5, 50, '2026-10-05T00:00:00Z', { sources: [{ issueNumber: 9, createdAt: '2026-10-09T00:00:00Z' }, { issueNumber: 4, createdAt: '2026-10-04T00:00:00Z' }] })).issue, 4);
  for (const createdAt of [0, '2026-02-31T00:00:00Z']) assert.equal(itemKey(item(5, 50, '2026-10-05', { sources: [{ issueNumber: 9, createdAt }] })), null);
  const plan = planAdmission({ scope, items: [item(1, 1, '2026-10-02T00:00:00Z', { sources: [] }), item(2, 2, '2026-10-03T00:00:00Z')], writer });
  assert.deepEqual([plan.action, plan.waiting[0].blockers], ['wait', ['missing or ambiguous primary source']]);
  const dependentSourceless = [item(1, 1, '', { sources: [] }), item(2, 2, '2026-10-03T00:00:00Z'), item(3, 3, '2026-10-04T00:00:00Z', { ready: false })];
  assert.equal(planAdmission({ scope, items: dependentSourceless, dependencies: [{ dependent: 1, prerequisite: 3, validated: true, reason: 'r', revision: 1 }], writer }).blockedBy, 1);
});

test('validated younger prerequisite precedes older dependent with a recorded reason', () => {
  const items = [item(1, 1, '2026-10-01T00:00:00Z'), item(2, 2, '2026-10-02T00:00:00Z')];
  const dependencies = [{ dependent: 1, prerequisite: 2, validated: true, reason: 'shared schema', revision: 4 }];
  const plan = planAdmission({ scope, items, dependencies, writer });
  assert.deepEqual([plan.prNumber, plan.precedence], [2, [{ dependent: 1, prerequisite: 2, reason: 'shared schema', revision: 4 }]]);
  for (const bad of [{ revision: null }, { reason: 1 }, { reason: undefined }, { prerequisite: undefined }]) {
    assert.equal(planAdmission({ scope, items, dependencies: [{ ...dependencies[0], ...bad }], writer }).reason, 'malformed dependency evidence');
  }
  assert.equal(planAdmission({ scope, items, dependencies: [{ ...dependencies[0], validated: false }], writer }).prNumber, 1);
  assert.deepEqual([[], [9]].map(outside => planAdmission({ scope, items, dependencies: [{ ...dependencies[0], prerequisite: 9 }], deliveredOutsideScope: outside, writer }).action), ['blocked', 'admit']);
  const chained = planAdmission({ scope, items: [...items, item(3, 3, '2026-10-01T12:00:00Z')], dependencies: [...dependencies, { ...dependencies[0], dependent: 2, prerequisite: 3 }], writer });
  assert.deepEqual([chained.prNumber, chained.precedence.map(edge => [edge.dependent, edge.prerequisite])], [3, [[2, 3], [1, 2]]]);
  assert.equal(planAdmission({ scope, items, dependencies: [...dependencies, { ...dependencies[0], dependent: 2, prerequisite: 1 }], writer }).reason, 'dependency cycle');
  const crossing = (ready, exceptions = []) => planAdmission({ scope, items: [...items, item(3, 3, '2026-10-03T00:00:00Z', { ready })], dependencies: [{ ...dependencies[0], prerequisite: 3 }], exceptions, writer });
  assert.equal(crossing(false, [{ skippedPr: 1, successorPr: 2, ownerVerified: true, repositoryId: 1, targetRef: 'main', scopeId: 'wave-5', scopeVersion: 1, reason: 'owner exception' }]).prNumber, 2);
  assert.deepEqual([true, false].map(ready => [crossing(ready).action, crossing(ready).prNumber || crossing(ready).blockedBy]), [['admit', 3], ['wait', 3]]);
});

test('older held or blocked work stops advancement unless a verified scoped exception is recorded', () => {
  const now = Date.parse('2026-10-03T00:00:00Z');
  const items = [item(1, 1, '2026-10-01T00:00:00Z', { holdLabel: true, hold: hold({ pr: 1 }) }), item(2, 2, '2026-10-02T00:00:00Z', { ready: false }), item(3, 3, '2026-10-02T12:00:00Z')];
  const waiting = planAdmission({ scope, items, writer, now });
  assert.deepEqual([waiting.action, waiting.waiting.map(entry => [entry.prNumber, entry.blockers[0], entry.ageMs > 0, Boolean(entry.nextAction)])],
    ['wait', [[1, 'delivery hold', true, true], [2, 'not ready', true, true]]]);
  assert.equal(items[0].ready, true);
  const exception = pr => ({ skippedPr: pr, successorPr: 3, ownerVerified: true, repositoryId: 1, targetRef: 'main', scopeId: 'wave-5', scopeVersion: 1, reason: 'owner exception' });
  for (const bad of [{ scopeVersion: 0 }, { ownerVerified: false }, { scopeId: 'other' }, { targetRef: 'dev' }, { reason: {} }, { reason: ' ' }]) {
    assert.equal(planAdmission({ scope, items, writer, now, exceptions: [{ ...exception(1), ...bad }, exception(2)] }).action, 'wait');
  }
  assert.equal(planAdmission({ scope, items, writer, now, exceptions: [{ ...exception(1), successorPr: 9 }, exception(2)] }).blockedBy, 1);
  const skipped = planAdmission({ scope, items, writer, now, exceptions: [exception(1), exception(2)] });
  assert.equal(skipped.prNumber, 3);
  assert.deepEqual(skipped.skipped.map(entry => entry.prNumber), [1, 2]);
  assert.equal(planAdmission({ scope, items: items.slice(0, 2), writer, now, exceptions: [exception(1), exception(2)] }).action, 'wait');
});
test('metadata repair on newer work does not admit it ahead of older eligible work', () => {
  const items = [item(1, 1, '2026-10-01T00:00:00Z', { eligible: false }), item(2, 2, '2026-10-02T00:00:00Z')];
  assert.equal(planAdmission({ scope, items, writer }).action, 'wait');
  items[0].eligible = true;
  assert.equal(planAdmission({ scope, items, writer }).prNumber, 1);
});

test('hold expiry, mismatched records and unexplained label removal never release a hold', () => {
  const now = Date.parse('2026-10-10T00:00:00Z');
  const at = { scope, prNumber: 3, now };
  assert.deepEqual(evaluateHold({ labelPresent: true, record: hold(), ...at }), { held: true, state: 'overdue' });
  assert.equal(evaluateHold({ labelPresent: true, record: hold(), ...at, now: Date.parse('2026-10-05T00:00:00Z') }).state, 'overdue');
  assert.equal(evaluateHold({ labelPresent: true, record: { pr: 3 }, ...at }).state, 'invalid-record');
  assert.equal(evaluateHold({ labelPresent: true, record: hold(), ...at, scope: { ...scope, version: 2 } }).state, 'invalid-record');
  assert.equal(evaluateHold({ labelPresent: false, record: hold(), ...at }).state, 'unexplained-removal');
  const resumed = hold({ resumeEvidence: { authorized: true, revision: 2 } });
  assert.equal(evaluateHold({ labelPresent: false, record: hold({ resumeEvidence: { authorized: true, revision: 1 } }), ...at }).held, true);
  for (const bad of [{ owner: '' }, { reason: '  ' }, { revision: null, resumeEvidence: { authorized: true, revision: null } }, { reviewAt: 'never' }, { createdAt: 0, reviewAt: 1 }]) {
    assert.equal(evaluateHold({ labelPresent: false, record: { ...resumed, ...bad }, ...at }).held, true);
  }
  assert.equal(evaluateHold({ labelPresent: true, record: hold({ reviewAt: 'never' }), ...at }).state, 'invalid-record');
  assert.equal(evaluateHold({ labelPresent: false, record: resumed, ...at, prNumber: 4 }).held, true);
  const blank = { repositoryId: null, targetRef: null, id: null, version: null };
  assert.equal(evaluateHold({ labelPresent: false, record: { ...resumed, scope: blank }, ...at, scope: blank }).held, true);
  assert.equal(admissionOperationKey({ scope: blank, prNumber: 1, headSha: 'a'.repeat(40), baseSha: 'b'.repeat(40), decisionRevision: 1 }), null);
  assert.equal(evaluateHold({ labelPresent: false, record: resumed, ...at }).held, false);
});
test('uncontrolled writers degrade to best-effort and untracked admissions pause', () => {
  const items = [item(1, 1, '2026-10-01T00:00:00Z')];
  assert.equal(planAdmission({ scope, items }).orderGuaranteed, false);
  assert.equal(planAdmission({ scope, items, writer, untrackedAdmissions: [9] }).action, 'paused');
  assert.equal(planAdmission({ scope: { ...scope, version: undefined }, items, writer }).action, 'blocked');
});

test('duplicate events, stale heads and ambiguous requests reconcile without repeated effects', () => {
  const current = { scope, prNumber: 1, headSha: 'a'.repeat(40), baseSha: 'c'.repeat(40), decisionRevision: 1 };
  const intent = { operationKey: admissionOperationKey(current), requested: true };
  assert.equal(reconcileAdmission({ intent, observed: { queued: true, headSha: current.headSha }, current }).action, 'already-admitted');
  for (const changed of [{ headSha: 'b'.repeat(40) }, { baseSha: 'd'.repeat(40) }, { decisionRevision: 2 }]) {
    assert.equal(reconcileAdmission({ intent, observed: {}, current: { ...current, ...changed } }).action, 'paused');
  }
  assert.equal(reconcileAdmission({ intent, observed: {}, current }).action, 'inspect');
  assert.equal(reconcileAdmission({ intent, observed: {}, current, attempts: 3 }).reason, 'retry budget exhausted');
  assert.equal(reconcileAdmission({ intent: { ...intent, requested: false }, observed: { queued: true, headSha: current.headSha }, current }).action, 'paused');
  assert.equal(admissionOperationKey({ ...current, baseSha: undefined }), null);
  assert.equal(reconcileAdmission({ intent: { ...intent, operationKey: null }, observed: {}, current: { ...current, decisionRevision: undefined } }).action, 'paused');
  assert.equal(reconcileAdmission({ intent: { ...intent, requested: false }, observed: { known: true }, current }).action, 'retry');
  assert.equal(reconcileAdmission({ intent: null, observed: { queued: true }, current }).action, 'paused');
});
