'use strict';

// Stage 1 shadow evaluator for docs/spec/protected-main-eligibility-barrier.spec.md.
// Pure decision logic only: it performs no API writes, never enqueues, and is not
// a required-status producer until enforcementActivation() reports every prerequisite.
const { canonicalJson, sha256 } = require('./pr-decomposition-evaluator.cjs');
const { resolveApprovalRequirements } = require('./merge-eligibility-policy.cjs');

const SHA_PATTERN = /^[0-9a-f]{40}$/;
const MAX_EVALUATIONS_PER_IDENTITY = 3;
const ENFORCEMENT_PREREQUISITES = ['producerSelected', 'groupMembershipProven',
  'revocationFenceProven', 'hostedFixturesPassed', 'ownerGoDecision'];

const digest = value => sha256(canonicalJson(value));
const present = value => value !== undefined && value !== null && value !== '';

function prIdentity(input) {
  return {
    repositoryId: input.repositoryId,
    prId: input.prId,
    headRepository: input.head?.repository,
    headRef: input.head?.ref,
    headSha: input.head?.sha,
    baseRef: input.base?.ref,
    baseSha: input.base?.sha,
    treeDigest: input.treeDigest,
    readinessIdentity: input.readinessIdentity,
    sourceIssue: input.authority?.sourceIssue,
    specDigest: input.authority?.specDigest,
    taskId: input.authority?.taskId,
    policyRevision: input.policyRevision,
    decompositionDigest: input.decomposition?.digest,
    holdRevision: input.holdRevision,
    // Classification, authority, approvals and validation evidence are bound so any change
    // invalidates prior green output for the same head.
    sizeLabel: input.sizeLabel,
    riskTier: input.riskTier,
    authorityApproved: input.authority?.approved === true,
    permissionCurrent: input.authority?.permissionCurrent === true,
    approvalsDigest: digest((input.approvals || []).map(review => [review.id ?? null, review.qualified === true, review.commitId ?? null])),
    validationDigest: digest((input.requiredChecks || []).map(check => [check.context, check.state, check.headSha, check.producerAppId ?? null])),
    evidenceRevision: Number(input.evidenceRevision || 0)
  };
}

function decision(stage, identity, reasons, input) {
  const unique = [...new Set(reasons)];
  return {
    stage,
    state: unique.length === 0 ? 'success' : 'failure',
    identity,
    identityDigest: digest(identity),
    evidenceRevision: Number(input.evidenceRevision || 0),
    reasons: unique,
    producer: { appId: input.producer?.appId ?? null, runId: input.producer?.runId ?? null }
  };
}

function prBlockers(input, identity) {
  const blockers = Object.entries(identity)
    .filter(([, value]) => !present(value))
    .map(([field]) => `Missing evidence: ${field}.`);
  if (present(identity.headSha) && !SHA_PATTERN.test(identity.headSha)) blockers.push('Invalid head SHA.');
  if (input.evidenceError) blockers.push(`Evidence unavailable: ${input.evidenceError}.`);
  if (input.ready !== true) blockers.push('PR is not ready; readiness is evaluated separately.');
  if (identity.baseRef !== (input.protectedRef || 'main')) blockers.push('Destination is not the protected ref.');
  if (input.decomposition?.passed !== true) blockers.push('Decomposition evidence is missing or failed.');
  if (input.authority?.approved !== true || input.authority?.permissionCurrent !== true) {
    blockers.push('Approved source/spec authority with current permission is missing.');
  }
  if (!Array.isArray(input.activeHolds)) blockers.push('Hold state is unknown.');
  else if (input.activeHolds.length > 0) blockers.push(`Active delivery hold: ${input.activeHolds.join(', ')}.`);
  if (!Array.isArray(input.unresolvedDependencies)) blockers.push('Dependency state is unknown.');
  else if (input.unresolvedDependencies.length > 0) blockers.push('Unresolved dependencies remain.');
  const checks = Array.isArray(input.requiredChecks) ? input.requiredChecks : [];
  if (checks.length === 0) blockers.push('Required validation evidence is missing.');
  for (const check of checks) {
    if (check.headSha !== identity.headSha) blockers.push(`Stale validation reused: ${check.context}.`);
    else if (check.state !== 'success') blockers.push(`Required validation not successful: ${check.context}.`);
    else if (!present(check.producerAppId) || check.producerAppId !== input.trustedValidationProducers?.[check.context]) {
      blockers.push(`Untrusted validation producer: ${check.context}.`);
    }
  }
  const { requiredApprovals } = resolveApprovalRequirements({ ...input.policy, riskTier: input.riskTier, sizeLabel: input.sizeLabel });
  const qualified = (input.approvals || []).filter(review => review.qualified === true && review.commitId === identity.headSha);
  if (qualified.length < requiredApprovals) {
    blockers.push(`Qualified current-head approval required (${qualified.length}/${requiredApprovals}).`);
  }
  if (input.stackFinalization) {
    const manifest = input.stackManifest;
    if (manifest?.authorized !== true || manifest.treeDigest !== identity.treeDigest) {
      blockers.push('Stack finalization requires an authorized aggregate manifest for the exact tree.');
    }
  }
  return blockers;
}

// Pre-admission barrier. It never consults queue membership or group status, so a
// group-only context can never be a prerequisite of admission (no circular wait).
function evaluatePrBarrier(input) {
  const identity = prIdentity(input);
  return decision('pr', identity, prBlockers(input, identity), input);
}

// Fresh group-scoped decision on the synthetic head. PR-head statuses are never copied;
// every constituent is re-evaluated from current evidence.
function evaluateGroupBarrier(input) {
  const group = input.group || {};
  const constituents = Array.isArray(input.constituents) ? input.constituents : [];
  const reasons = [];
  for (const field of ['id', 'ref', 'headSha', 'baseSha', 'treeDigest']) {
    if (!present(group[field])) reasons.push(`Missing group evidence: ${field}.`);
  }
  if (input.membershipComplete !== true) reasons.push('Group membership enumeration is not proven complete.');
  if (constituents.length === 0) reasons.push('Group has no constituents.');
  const members = constituents.map(member => {
    const evaluated = evaluatePrBarrier({ ...member.current, evidenceRevision: input.evidenceRevision, producer: input.producer });
    if (member.queuedHeadSha !== evaluated.identity.headSha) reasons.push(`Constituent ${member.current?.prId} head changed after admission.`);
    if (evaluated.identity.baseRef !== (input.protectedRef || 'main')) reasons.push(`Constituent ${member.current?.prId} targets another base.`);
    for (const reason of evaluated.reasons) reasons.push(`Constituent ${member.current?.prId}: ${reason}`);
    return { prId: evaluated.identity.prId, headSha: evaluated.identity.headSha, identityDigest: evaluated.identityDigest };
  });
  const identity = { repositoryId: input.repositoryId, policyRevision: input.policyRevision, group, members };
  return decision('group', identity, reasons, input);
}

// Accept only a success produced by the trusted installed producer for this exact identity.
function acceptBarrierStatus({ status, trustedProducerAppId, stage, identityDigest }) {
  return Boolean(status) && status.state === 'success' && status.stage === stage &&
    present(trustedProducerAppId) && status.producer?.appId === trustedProducerAppId &&
    status.identityDigest === identityDigest;
}

// Writer fencing: newer evidence revisions win; on equal revision a failure is never
// replaced by success, so stale or out-of-order workers cannot republish green.
function selectCurrentDecision(current, incoming) {
  if (!current) return incoming;
  if (!incoming) return current;
  if (incoming.evidenceRevision !== current.evidenceRevision) {
    return incoming.evidenceRevision > current.evidenceRevision ? incoming : current;
  }
  return current.state === 'failure' ? current : incoming;
}

function retryAllowed(attemptsForIdentity) {
  return Number(attemptsForIdentity || 0) < MAX_EVALUATIONS_PER_IDENTITY;
}

// Default-off: enforcement stays inactive until every activation prerequisite is proven.
function enforcementActivation(evidence = {}) {
  const missing = ENFORCEMENT_PREREQUISITES.filter(key => evidence[key] !== true);
  return { active: missing.length === 0, missing };
}

module.exports = {
  ENFORCEMENT_PREREQUISITES,
  MAX_EVALUATIONS_PER_IDENTITY,
  acceptBarrierStatus,
  enforcementActivation,
  evaluateGroupBarrier,
  evaluatePrBarrier,
  retryAllowed,
  selectCurrentDecision
};
