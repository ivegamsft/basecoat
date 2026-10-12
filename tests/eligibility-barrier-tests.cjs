'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  acceptBarrierStatus,
  enforcementActivation,
  evaluateGroupBarrier,
  evaluatePrBarrier,
  retryAllowed,
  selectCurrentDecision
} = require('../.github/base-coat/scripts/eligibility-barrier.cjs');

const headSha = 'a'.repeat(40);
const soloDev = { requiredApprovalsByRiskTier: {}, humanApprovalRequiredSizes: ['XXL'], minimumQualifiedApprovalsForHumanSize: 1, approvalRequiredByRisk: {} };
const pr = (overrides = {}) => ({
  repositoryId: 1, prId: 10, treeDigest: 'tree-1', readinessIdentity: 'ready-1', ready: true,
  head: { repository: 'org/repo', ref: 'fix/10', sha: headSha },
  base: { ref: 'main', sha: 'b'.repeat(40) },
  authority: { approved: true, permissionCurrent: true, sourceIssue: 3672, specDigest: 'spec', taskId: 'task' },
  policyRevision: 'policy-1', decomposition: { passed: true, digest: 'decomp' },
  holdRevision: 'hold-0', activeHolds: [], unresolvedDependencies: [],
  requiredChecks: [{ context: 'tests', state: 'success', headSha, producerAppId: 15368 }],
  trustedValidationProducers: { tests: 15368 },
  policy: soloDev, riskTier: 'high', sizeLabel: 'XL', approvals: [],
  producer: { appId: 99, runId: 1 },
  ...overrides
});
const group = (members, overrides = {}) => ({
  repositoryId: 1,
  policyRevision: 'policy-1',
  group: { id: 'g1', ref: 'gh-readonly-queue/main/pr-10', headSha: 'c'.repeat(40), baseSha: 'b'.repeat(40), treeDigest: 'gtree' },
  membershipComplete: true,
  constituents: members.map(current => ({ current, queuedHeadSha: current.head.sha })),
  producer: { appId: 99, runId: 2 },
  ...overrides
});

test('authorized solo-dev XL is eligible with zero routine reviews', () => {
  const result = evaluatePrBarrier(pr());
  assert.equal(result.state, 'success');
  assert.deepEqual(result.reasons, []);
});

test('XXL without qualified current-head approval fails; stale approval does not pass', () => {
  assert.equal(evaluatePrBarrier(pr({ sizeLabel: 'XXL' })).state, 'failure');
  const stale = evaluatePrBarrier(pr({ sizeLabel: 'XXL', approvals: [{ qualified: true, commitId: 'd'.repeat(40) }] }));
  assert.match(stale.reasons.join(' '), /current-head approval required \(0\/1\)/);
  assert.equal(evaluatePrBarrier(pr({ sizeLabel: 'XXL', approvals: [{ qualified: true, commitId: headSha }] })).state, 'success');
});

test('missing evidence, holds, draft readiness and non-main destinations fail closed', () => {
  assert.equal(evaluatePrBarrier(pr({ authority: undefined })).state, 'failure');
  assert.equal(evaluatePrBarrier(pr({ activeHolds: undefined })).state, 'failure');
  assert.equal(evaluatePrBarrier(pr({ evidenceError: 'rate limited' })).state, 'failure');
  assert.equal(evaluatePrBarrier(pr({ requiredChecks: [] })).state, 'failure');
  assert.match(evaluatePrBarrier(pr({ activeHolds: ['delivery-hold'] })).reasons.join(' '), /Active delivery hold/);
  assert.equal(evaluatePrBarrier(pr({ ready: false })).state, 'failure');
  assert.equal(evaluatePrBarrier(pr({ base: { ref: 'feature/x', sha: 'b'.repeat(40) } })).state, 'failure');
});

test('stale green from an old head or a wrong producer is not reused', () => {
  const moved = evaluatePrBarrier(pr({ head: { repository: 'org/repo', ref: 'fix/10', sha: 'e'.repeat(40) } }));
  assert.match(moved.reasons.join(' '), /Stale validation reused/);
  const spoofed = pr({ requiredChecks: [{ context: 'tests', state: 'success', headSha, producerAppId: 1 }] });
  assert.match(evaluatePrBarrier(spoofed).reasons.join(' '), /Untrusted validation producer/);
});

test('barrier status is accepted only from the trusted producer for the exact identity', () => {
  const result = evaluatePrBarrier(pr());
  const accept = status => acceptBarrierStatus({ status, trustedProducerAppId: 99, stage: 'pr', identityDigest: result.identityDigest });
  assert.equal(accept(result), true);
  assert.equal(accept({ ...result, producer: { appId: 15368 } }), false);
  assert.equal(accept({ ...result, stage: 'group' }), false);
  for (const changed of [{ policyRevision: 'policy-2' }, { sizeLabel: 'XXL' }, { authority: { ...pr().authority, permissionCurrent: false } },
    { approvals: [{ id: 1, qualified: true, commitId: headSha }] }, { requiredChecks: [{ ...pr().requiredChecks[0], producerAppId: 7 }] }]) {
    assert.equal(acceptBarrierStatus({ status: result, trustedProducerAppId: 99, stage: 'pr', identityDigest: evaluatePrBarrier(pr(changed)).identityDigest }), false);
  }
});

test('group barrier re-evaluates constituents instead of copying PR status', () => {
  assert.equal(evaluateGroupBarrier(group([pr()])).state, 'success');
  const held = evaluateGroupBarrier(group([pr({ activeHolds: ['delivery-hold'] })]));
  assert.match(held.reasons.join(' '), /Constituent 10: Active delivery hold/);
  const incomplete = evaluateGroupBarrier(group([pr()], { membershipComplete: false }));
  assert.equal(incomplete.state, 'failure');
  const changed = group([pr()]);
  changed.constituents[0].queuedHeadSha = 'f'.repeat(40);
  assert.match(evaluateGroupBarrier(changed).reasons.join(' '), /head changed after admission/);
  const multi = evaluateGroupBarrier(group([pr(), pr({ prId: 11 })]));
  assert.equal(multi.state, 'success');
  assert.deepEqual(multi.identity.members.map(member => member.prId), [10, 11]);
});

test('stack finalization requires an authorized aggregate manifest for the exact tree', () => {
  assert.equal(evaluatePrBarrier(pr({ stackFinalization: true })).state, 'failure');
  assert.equal(evaluatePrBarrier(pr({ stackFinalization: true, stackManifest: { authorized: true, treeDigest: 'other' } })).state, 'failure');
  assert.equal(evaluatePrBarrier(pr({ stackFinalization: true, stackManifest: { authorized: true, treeDigest: 'tree-1' } })).state, 'success');
});

test('stale or out-of-order workers cannot replace a current failure with success', () => {
  const failure = { ...evaluatePrBarrier(pr({ activeHolds: ['delivery-hold'], evidenceRevision: 2 })) };
  const staleGreen = evaluatePrBarrier(pr({ evidenceRevision: 1 }));
  assert.equal(selectCurrentDecision(failure, staleGreen), failure);
  assert.equal(selectCurrentDecision(failure, evaluatePrBarrier(pr({ evidenceRevision: 2 }))), failure);
  const fresh = evaluatePrBarrier(pr({ evidenceRevision: 3 }));
  assert.equal(selectCurrentDecision(failure, fresh), fresh);
});

test('enforcement stays default-off and retries are bounded', () => {
  assert.equal(enforcementActivation().active, false);
  assert.equal(enforcementActivation({ producerSelected: true }).missing.includes('revocationFenceProven'), true);
  assert.equal(retryAllowed(2), true);
  assert.equal(retryAllowed(3), false);
});
