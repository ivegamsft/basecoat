'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  assertCanActivateWindow,
  assertStateTransition,
  canonicalJson,
  createWindowKey,
  recordDigest
} = require('../scripts/release-owner-state.cjs');

const sha = character => character.repeat(40);
const digest = character => character.repeat(64);

function inventory(overrides = {}) {
  return {
    repositoryId: 12345,
    baselineTag: 'v4.6.2',
    baselineSha: sha('a'),
    candidateSha: sha('b'),
    candidateTreeSha: sha('c'),
    authorizations: [
      { issue: 10, commentId: '100', receiptDigest: digest('d') },
      { issue: 11, commentId: '101', receiptDigest: digest('e') }
    ],
    pullRequests: [
      { number: 20, mergeSha: sha('f'), disposition: 'included' },
      { number: 21, mergeSha: sha('1'), disposition: 'excluded:release-opt-out' }
    ],
    generation: 1,
    ...overrides
  };
}

function windowRecord(overrides = {}) {
  const key = createWindowKey(inventory());
  return {
    repositoryId: 12345,
    windowKey: key,
    generation: 1,
    revision: 1,
    state: 'CANDIDATE',
    baselineTag: 'v4.6.2',
    baselineSha: sha('a'),
    candidateSha: sha('b'),
    candidateTreeSha: sha('c'),
    authorizations: inventory().authorizations,
    pullRequests: inventory().pullRequests,
    version: '4.7.0',
    ...overrides
  };
}

function nextRecord(current, overrides = {}) {
  return {
    ...current,
    revision: current.revision + 1,
    previousRecordDigest: recordDigest(current),
    ...overrides
  };
}

test('canonical JSON sorts object keys recursively and rejects non-JSON values', () => {
  assert.equal(canonicalJson({ z: 1, nested: { b: 2, a: 1 } }),
    '{"nested":{"a":1,"b":2},"z":1}');
  assert.throws(() => canonicalJson({ value: undefined }), /undefined/);
  assert.throws(() => canonicalJson({ value: Number.NaN }), /non-finite/);
});

test('window key is stable across input ordering and binds dispositions and generation', () => {
  const original = inventory();
  const reordered = inventory({
    authorizations: [...original.authorizations].reverse(),
    pullRequests: [...original.pullRequests].reverse()
  });
  assert.equal(createWindowKey(original), createWindowKey(reordered));
  assert.notEqual(createWindowKey(original), createWindowKey(inventory({
    pullRequests: [
      { number: 20, mergeSha: sha('f'), disposition: 'included' },
      { number: 21, mergeSha: sha('1'), disposition: 'included' }
    ]
  })));
  assert.notEqual(createWindowKey(original), createWindowKey(inventory({ generation: 2 })));
});

test('window key rejects incomplete, ambiguous, or malformed inventory tuples', () => {
  assert.throws(() => createWindowKey(inventory({ candidateSha: 'short' })), /full hexadecimal SHA/);
  assert.throws(() => createWindowKey(inventory({
    pullRequests: [
      { number: 20, mergeSha: sha('f'), disposition: 'included' },
      { number: 20, mergeSha: sha('1'), disposition: 'included' }
    ]
  })), /duplicate numbers/);
  assert.throws(() => createWindowKey(inventory({
    pullRequests: [{ number: 21, mergeSha: sha('1'), disposition: 'excluded' }]
  })), /reason code/);
});

test('state transitions bind the prior digest and preserve window identity', () => {
  const current = windowRecord();
  const merged = {
    state: 'METADATA_MERGED',
    metadataPrNumber: 123,
    metadataMergeSha: sha('2'),
    intendedTag: 'v4.7.0',
    intendedSha: sha('2')
  };
  assert.equal(assertStateTransition(current, nextRecord(current, merged)), true);
  assert.throws(() => assertStateTransition(current, nextRecord(current, {
    ...merged,
    intendedTag: undefined,
    intendedSha: undefined
  })), /METADATA_MERGED requires the immutable SemVer tag/);
  assert.throws(() => assertStateTransition(current, nextRecord(current, {
    state: 'TAGGED'
  })), /Illegal release-window transition/);
  assert.throws(() => assertStateTransition(current, nextRecord(current, {
    state: 'BLOCKED',
    previousRecordDigest: digest('0')
  })), /does not bind/);
  assert.throws(() => assertStateTransition(current, nextRecord(current, {
    state: 'BLOCKED',
    candidateSha: sha('3')
  })), /identity field cannot change/);
});

test('version and release targets cannot be retargeted within a window', () => {
  const candidate = windowRecord();
  assert.throws(() => assertStateTransition(candidate, nextRecord(candidate, {
    state: 'CANDIDATE',
    version: '4.8.0'
  })), /Selected version is immutable/);

  const tagged = windowRecord({
    revision: 2,
    state: 'TAGGED',
    intendedTag: 'v4.7.0',
    intendedSha: sha('2'),
    mirrorTarget: sha('3'),
    mirrorTargetTreeSha: sha('4'),
    metadataPrNumber: 123,
    metadataMergeSha: sha('2')
  });
  assert.throws(() => assertStateTransition(tagged, nextRecord(tagged, {
    state: 'PARTIAL',
    intendedSha: sha('5')
  })), /target is immutable: intendedSha/);
  assert.throws(() => assertStateTransition(tagged, nextRecord(tagged, {
    state: 'PARTIAL',
    metadataMergeSha: sha('5')
  })), /Merged metadata field cannot change/);
});

test('failed windows resume once or retire only with a remediation receipt', () => {
  const failed = windowRecord({
    revision: 3,
    state: 'FAILED',
    metadataPrNumber: 123,
    metadataMergeSha: sha('2'),
    intendedTag: 'v4.7.0',
    intendedSha: sha('2')
  });
  const receipt = (action, commentId) => ({ action, tag: 'v4.7.0', commentId, receiptDigest: digest('7') });
  const resumed = nextRecord(failed, { state: 'PARTIAL', remediations: [receipt('retry', '900')] });
  assert.equal(assertStateTransition(failed, resumed), true);
  assert.equal(assertStateTransition(failed, nextRecord(failed, {
    state: 'RETIRED',
    remediations: [receipt('retire', '901')]
  })), true);
  assert.throws(() => assertStateTransition(failed, nextRecord(failed, { state: 'PARTIAL' })),
    /requires exactly one \/release-retry/);
  assert.throws(() => assertStateTransition(failed, nextRecord(failed, { state: 'RETIRED' })),
    /requires exactly one \/release-retire/);
  assert.throws(() => assertStateTransition(failed, nextRecord(failed, {
    state: 'PARTIAL',
    remediations: [{ ...receipt('retry', '900'), tag: 'v4.8.0' }]
  })), /must be a \/release-retry for v4.7.0/);

  const failedAgain = { ...resumed, revision: 5, state: 'FAILED' };
  assert.throws(() => assertStateTransition(failedAgain, nextRecord(failedAgain, {
    state: 'PARTIAL',
    remediations: [...resumed.remediations, receipt('retry', '902')]
  })), /at most once per window/);
  assert.throws(() => assertStateTransition(failedAgain, nextRecord(failedAgain, {
    state: 'RETIRED',
    remediations: [...resumed.remediations, receipt('retire', '900')]
  })), /consumed at most once/);
  assert.throws(() => assertStateTransition(failedAgain, nextRecord(failedAgain, {
    state: 'RETIRED',
    remediations: [receipt('retire', '903')]
  })), /append-only/);
  assert.throws(() => assertStateTransition(failed, nextRecord(failed, {
    state: 'TAGGED'
  })), /Illegal release-window transition/);
  const retired = { ...failed, revision: 4, state: 'RETIRED' };
  assert.throws(() => assertStateTransition(retired, nextRecord(retired, {
    state: 'PARTIAL'
  })), /Illegal release-window transition/);
});

test('post-tag windows cannot be superseded, and activation requires a resolvable pointer', () => {
  const candidate = windowRecord();
  const next = windowRecord({
    windowKey: createWindowKey(inventory({ generation: 2 })),
    generation: 2,
    revision: 1,
    previousRecordDigest: null
  });
  const activate = (overrides = {}) => assertCanActivateWindow({
    currentKey: candidate.windowKey,
    currentRecord: candidate,
    newRecord: next,
    priorGenerations: [],
    ...overrides
  });
  assert.equal(activate(), true);
  for (const state of ['TAGGED', 'PARTIAL', 'FAILED']) {
    assert.throws(() => activate({ currentRecord: { ...candidate, state } }),
      new RegExp(`Cannot supersede a current window in ${state}`));
  }
  assert.throws(() => activate({ currentKey: digest('8') }), /does not resolve/);
  assert.throws(() => activate({ newRecord: candidate }), /generation must be 2/);
  assert.throws(() => activate({ newRecord: { ...next, windowKey: digest('9') } }), /recomputed/);
  assert.throws(() => activate({ priorGenerations: [2] }), /generation must be 3/);
  assert.throws(() => activate({ priorGenerations: undefined }), /prior generations/);
  assert.throws(() => assertCanActivateWindow({
    currentKey: null,
    currentRecord: null,
    newRecord: { ...next, revision: 2 },
    priorGenerations: [1]
  }), /revision 1/);
});

test('the window after a retired or verified tag must select a higher version', () => {
  const fresh = inventory({ candidateSha: sha('6') });
  const next = windowRecord({
    candidateSha: sha('6'),
    windowKey: createWindowKey(fresh),
    version: '4.7.0'
  });
  for (const state of ['RETIRED', 'VERIFIED']) {
    const current = windowRecord({ state, version: '4.7.0' });
    const activate = newRecord => assertCanActivateWindow({
      currentKey: current.windowKey,
      currentRecord: current,
      newRecord,
      priorGenerations: []
    });
    assert.throws(() => activate(next), new RegExp(`after ${state} must select a higher version`));
    assert.throws(() => activate({ ...next, version: '4.6.9' }), /higher version/);
    assert.equal(activate({ ...next, version: '4.7.1' }), true);
  }
  const huge = windowRecord({ state: 'RETIRED', version: '9007199254740992.0.0' });
  assert.equal(assertCanActivateWindow({
    currentKey: huge.windowKey,
    currentRecord: huge,
    newRecord: { ...next, version: '9007199254740993.0.0' },
    priorGenerations: []
  }), true);
});
