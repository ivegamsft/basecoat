'use strict';

const { createHash } = require('node:crypto');

const STATES = Object.freeze([
  'NO_RELEASE',
  'BLOCKED',
  'CANDIDATE',
  'METADATA_MERGED',
  'TAGGED',
  'PARTIAL',
  'FAILED',
  'RETIRED',
  'VERIFIED'
]);

const TRANSITIONS = Object.freeze({
  NO_RELEASE: [],
  BLOCKED: [],
  CANDIDATE: ['CANDIDATE', 'METADATA_MERGED', 'BLOCKED'],
  METADATA_MERGED: ['TAGGED', 'BLOCKED'],
  TAGGED: ['PARTIAL', 'FAILED', 'VERIFIED'],
  PARTIAL: ['PARTIAL', 'FAILED', 'VERIFIED'],
  FAILED: ['PARTIAL', 'RETIRED'],
  RETIRED: [],
  VERIFIED: []
});

const POST_TAG_STATES = new Set(['TAGGED', 'PARTIAL', 'FAILED']);
const SHA40 = /^[0-9a-f]{40}$/i;
const SHA64 = /^[0-9a-f]{64}$/i;
const SEMVER_TAG = /^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
const SEMVER = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
const REMEDIATION_ACTIONS = Object.freeze({ PARTIAL: 'retry', RETIRED: 'retire' });

function parseVersion(value, name) {
  const match = typeof value === 'string' ? SEMVER.exec(value) : null;
  if (!match) throw new Error(`${name} must be a canonical MAJOR.MINOR.PATCH version.`);
  return match.slice(1).map(BigInt);
}

function compareVersions(left, right) {
  const a = parseVersion(left, 'version');
  const b = parseVersion(right, 'version');
  for (let index = 0; index < 3; index += 1) {
    if (a[index] !== b[index]) return a[index] < b[index] ? -1 : 1;
  }
  return 0;
}

function canonicalValue(value) {
  if (Array.isArray(value)) return value.map(canonicalValue);
  if (value && typeof value === 'object') {
    const prototype = Object.getPrototypeOf(value);
    if (prototype !== Object.prototype && prototype !== null) {
      throw new Error('Canonical JSON accepts only plain objects.');
    }
    return Object.fromEntries(Object.keys(value).sort().map(key => {
      if (value[key] === undefined) throw new Error('Canonical JSON does not accept undefined values.');
      return [key, canonicalValue(value[key])];
    }));
  }
  if (typeof value === 'number' && !Number.isFinite(value)) {
    throw new Error('Canonical JSON does not accept non-finite numbers.');
  }
  if (typeof value === 'undefined' || typeof value === 'function' || typeof value === 'symbol' ||
      typeof value === 'bigint') {
    throw new Error('Canonical JSON contains an unsupported value.');
  }
  return value;
}

function canonicalJson(value) {
  return JSON.stringify(canonicalValue(value));
}

function requirePositiveInteger(value, name) {
  if (!Number.isSafeInteger(value) || value < 1) {
    throw new Error(`${name} must be a positive safe integer.`);
  }
}

function requireSha(value, pattern, name) {
  if (typeof value !== 'string' || !pattern.test(value)) {
    throw new Error(`${name} must be a full hexadecimal SHA.`);
  }
  return value.toLowerCase();
}

function createWindowKey({
  repositoryId,
  baselineTag,
  baselineSha,
  candidateSha,
  candidateTreeSha,
  authorizations,
  pullRequests,
  generation
}) {
  requirePositiveInteger(repositoryId, 'repositoryId');
  requirePositiveInteger(generation, 'generation');
  if (typeof baselineTag !== 'string' || !SEMVER_TAG.test(baselineTag)) {
    throw new Error('baselineTag must be a canonical vMAJOR.MINOR.PATCH tag.');
  }
  if (!Array.isArray(authorizations) || !Array.isArray(pullRequests)) {
    throw new Error('Complete authorization and pull-request inventories are required.');
  }

  const normalizedAuthorizations = authorizations.map(item => {
    if (!item || typeof item !== 'object') throw new Error('Authorization tuple is incomplete.');
    requirePositiveInteger(item.issue, 'authorization issue');
    if (typeof item.commentId !== 'string' || !/^[1-9]\d*$/.test(item.commentId)) {
      throw new Error('Authorization commentId must be a positive decimal string.');
    }
    return [
      item.issue,
      item.commentId,
      requireSha(item.receiptDigest, SHA64, 'receiptDigest')
    ];
  }).sort((left, right) =>
    left[0] - right[0] || left[1].localeCompare(right[1]) || left[2].localeCompare(right[2])
  );

  const seenPullRequests = new Set();
  const normalizedPullRequests = pullRequests.map(item => {
    if (!item || typeof item !== 'object') throw new Error('Pull-request tuple is incomplete.');
    requirePositiveInteger(item.number, 'pull-request number');
    if (seenPullRequests.has(item.number)) throw new Error('Pull-request inventory has duplicate numbers.');
    seenPullRequests.add(item.number);
    if (typeof item.disposition !== 'string' ||
        !(item.disposition === 'included' || /^excluded:[a-z][a-z0-9-]*$/.test(item.disposition))) {
      throw new Error('Pull-request disposition must be included or an excluded reason code.');
    }
    return [
      item.number,
      requireSha(item.mergeSha, SHA40, 'mergeSha'),
      item.disposition
    ];
  }).sort((left, right) => left[0] - right[0]);

  const identity = {
    repositoryId,
    baselineTag,
    baselineSha: requireSha(baselineSha, SHA40, 'baselineSha'),
    candidateSha: requireSha(candidateSha, SHA40, 'candidateSha'),
    candidateTreeSha: requireSha(candidateTreeSha, SHA40, 'candidateTreeSha'),
    authorizations: normalizedAuthorizations,
    pullRequests: normalizedPullRequests,
    generation
  };
  return createHash('sha256').update(canonicalJson(identity)).digest('hex');
}

function recordDigest(record) {
  if (!record || typeof record !== 'object') throw new Error('Window record is required.');
  return createHash('sha256').update(canonicalJson(record)).digest('hex');
}

function assertReleaseTarget(record, state) {
  if (!SEMVER_TAG.test(record.intendedTag || '') ||
      record.intendedTag !== `v${record.version}` ||
      !SHA40.test(record.intendedSha || '') ||
      record.intendedSha !== record.metadataMergeSha) {
    throw new Error(`${state} requires the immutable SemVer tag to target the metadata merge SHA.`);
  }
  if (record.mirrorTarget !== undefined && !SHA40.test(record.mirrorTarget)) {
    throw new Error('mirrorTarget must be a full hexadecimal SHA.');
  }
  if (record.mirrorTargetTreeSha !== undefined && !SHA40.test(record.mirrorTargetTreeSha)) {
    throw new Error('mirrorTargetTreeSha must be a full hexadecimal SHA.');
  }
}

function assertStateTransition(current, next) {
  if (!current || !next || typeof current !== 'object' || typeof next !== 'object') {
    throw new Error('Current and next window records are required.');
  }
  if (!STATES.includes(current.state) || !STATES.includes(next.state)) {
    throw new Error('Window record has an unknown state.');
  }
  if (!SHA64.test(current.windowKey || '') || !SHA64.test(next.windowKey || '')) {
    throw new Error('Window key must be a full SHA-256 digest.');
  }
  if (current.windowKey !== next.windowKey) {
    throw new Error('A state transition cannot change the window key.');
  }
  if (!Number.isSafeInteger(current.revision) || next.revision !== current.revision + 1) {
    throw new Error('Next window revision must increment exactly once.');
  }
  if (next.previousRecordDigest !== recordDigest(current)) {
    throw new Error('Next window record does not bind the current record digest.');
  }
  if (!TRANSITIONS[current.state].includes(next.state)) {
    throw new Error(`Illegal release-window transition: ${current.state} -> ${next.state}.`);
  }
  if (next.state === 'METADATA_MERGED') {
    requirePositiveInteger(next.metadataPrNumber, 'metadataPrNumber');
    requireSha(next.metadataMergeSha, SHA40, 'metadataMergeSha');
  }
  for (const field of [
    'repositoryId',
    'generation',
    'baselineTag',
    'baselineSha',
    'candidateSha',
    'candidateTreeSha',
    'authorizations',
    'pullRequests'
  ]) {
    if (canonicalJson(current[field]) !== canonicalJson(next[field])) {
      throw new Error(`Release-window identity field cannot change: ${field}.`);
    }
  }

  if (current.version !== undefined && current.version !== next.version) {
    throw new Error('Selected version is immutable under the same window key.');
  }
  if (current.state === 'METADATA_MERGED' || POST_TAG_STATES.has(current.state) ||
      current.state === 'VERIFIED' || current.state === 'RETIRED') {
    for (const field of ['metadataPrNumber', 'metadataMergeSha']) {
      if (canonicalJson(current[field]) !== canonicalJson(next[field])) {
        throw new Error(`Merged metadata field cannot change: ${field}.`);
      }
    }
  }
  for (const field of ['intendedTag', 'intendedSha', 'mirrorTarget', 'mirrorTargetTreeSha']) {
    if (current[field] !== undefined && current[field] !== next[field]) {
      throw new Error(`Persisted release target is immutable: ${field}.`);
    }
  }
  if (next.state === 'METADATA_MERGED' || POST_TAG_STATES.has(next.state) ||
      next.state === 'VERIFIED' || next.state === 'RETIRED') {
    assertReleaseTarget(next, next.state);
  }
  assertRemediation(current, next);
  return true;
}

function remediationList(record) {
  if (record.remediations === undefined) return [];
  if (!Array.isArray(record.remediations)) throw new Error('remediations must be an array.');
  return record.remediations;
}

function assertRemediation(current, next) {
  const before = remediationList(current);
  const after = remediationList(next);
  if (after.length < before.length ||
      canonicalJson(after.slice(0, before.length)) !== canonicalJson(before)) {
    throw new Error('Recorded remediation receipts are append-only.');
  }
  const appended = after.slice(before.length);
  const action = current.state === 'FAILED' ? REMEDIATION_ACTIONS[next.state] : undefined;
  if (!action) {
    if (appended.length !== 0) throw new Error('Remediation receipts are recorded only when leaving FAILED.');
    return;
  }
  if (appended.length !== 1) {
    throw new Error(`FAILED -> ${next.state} requires exactly one /release-${action} remediation receipt.`);
  }
  const [receipt] = appended;
  if (!receipt || typeof receipt !== 'object' || receipt.action !== action ||
      receipt.tag !== next.intendedTag ||
      typeof receipt.commentId !== 'string' || !/^[1-9]\d*$/.test(receipt.commentId)) {
    throw new Error(`Remediation receipt must be a /release-${action} for ${next.intendedTag}.`);
  }
  requireSha(receipt.receiptDigest, SHA64, 'remediation receiptDigest');
  if (before.some(item => item.commentId === receipt.commentId)) {
    throw new Error('Remediation comment IDs are consumed at most once.');
  }
  if (action === 'retry' && before.some(item => item.action === 'retry')) {
    throw new Error('/release-retry resets the retry budget at most once per window.');
  }
}

function sameKeyMaterial(left, right) {
  return createWindowKey({ ...left, generation: 1 }) === createWindowKey({ ...right, generation: 1 });
}

function assertCanActivateWindow({ currentKey, currentRecord, newRecord, priorGenerations }) {
  if (!newRecord || typeof newRecord !== 'object' || !STATES.includes(newRecord.state)) {
    throw new Error('New release window record is incomplete.');
  }
  requirePositiveInteger(newRecord.repositoryId, 'repositoryId');
  requirePositiveInteger(newRecord.generation, 'generation');
  if (newRecord.windowKey !== createWindowKey(newRecord)) {
    throw new Error('Window key must be recomputed from the record key material.');
  }
  if (!Array.isArray(priorGenerations)) {
    throw new Error('Authoritative prior generations for identical key material are required.');
  }
  const generations = [...priorGenerations];
  if (currentRecord && sameKeyMaterial(currentRecord, newRecord)) generations.push(currentRecord.generation);
  generations.forEach(value => requirePositiveInteger(value, 'prior generation'));
  const expectedGeneration = generations.length === 0 ? 1 : Math.max(...generations) + 1;
  if (newRecord.generation !== expectedGeneration) {
    throw new Error(`Window generation must be ${expectedGeneration} for this key material.`);
  }
  parseVersion(newRecord.version, 'version');
  if (newRecord.revision !== 1 ||
      (newRecord.previousRecordDigest !== undefined && newRecord.previousRecordDigest !== null)) {
    throw new Error('A new release window must have a digest key, revision 1, and no predecessor digest.');
  }
  if (!['NO_RELEASE', 'BLOCKED', 'CANDIDATE'].includes(newRecord.state)) {
    throw new Error('A newly activated window must start before metadata merge.');
  }
  if (currentKey === null || currentKey === undefined) {
    if (currentRecord !== null && currentRecord !== undefined) {
      throw new Error('Current window record exists without a current-window pointer.');
    }
    return true;
  }
  if (!currentRecord || currentRecord.windowKey !== currentKey) {
    throw new Error('Current-window pointer does not resolve to its authoritative record.');
  }
  if (currentRecord.repositoryId !== newRecord.repositoryId) {
    throw new Error('Release windows cannot cross repository boundaries.');
  }
  if (newRecord.windowKey === currentKey) {
    throw new Error('Existing window must resume instead of creating a duplicate record.');
  }
  if (POST_TAG_STATES.has(currentRecord.state)) {
    throw new Error(`Cannot supersede a current window in ${currentRecord.state}.`);
  }
  if ((currentRecord.state === 'RETIRED' || currentRecord.state === 'VERIFIED') &&
      compareVersions(newRecord.version, currentRecord.version) <= 0) {
    throw new Error(`The window after ${currentRecord.state} must select a higher version.`);
  }
  return true;
}

module.exports = {
  STATES,
  TRANSITIONS,
  canonicalJson,
  createWindowKey,
  recordDigest,
  assertStateTransition,
  assertCanActivateWindow
};
