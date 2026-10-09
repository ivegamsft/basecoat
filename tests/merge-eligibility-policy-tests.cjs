'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');
const {
  isOnlyHumanReviewHold,
  resolveApprovalRequirements
} = require('../.github/base-coat/scripts/merge-eligibility-policy.cjs');

const approvalHold = 'Insufficient approvals for risk tier high (0/1).';
const requiredChecksBlocker = 'Required checks not satisfied: tests pending.';
const soloDev = {
  requiredApprovalsByRiskTier: { low: 0, medium: 0, high: 0, critical: 0 },
  humanApprovalRequiredSizes: ['XXL'],
  minimumQualifiedApprovalsForHumanSize: 1,
  approvalRequiredByRisk: { low: false, medium: false, high: false, critical: false }
};
const teamDev = {
  requiredApprovalsByRiskTier: { low: 0, medium: 1, high: 1, critical: 1 },
  humanApprovalRequiredSizes: [],
  minimumQualifiedApprovalsForHumanSize: 1,
  approvalRequiredByRisk: { low: false, medium: true, high: true, critical: true }
};

test('solo-dev XL remains zero-review even at high risk', () => {
  assert.deepEqual(resolveApprovalRequirements({
    ...soloDev,
    riskTier: 'high',
    sizeLabel: 'XL'
  }), {
    requiredApprovals: 0,
    requiresHumanApprovalBySize: false,
    requiresHumanReviewByRisk: false
  });
});

test('solo-dev XXL requires exactly one qualified approval', () => {
  assert.deepEqual(resolveApprovalRequirements({
    ...soloDev,
    riskTier: 'high',
    sizeLabel: 'XXL'
  }), {
    requiredApprovals: 1,
    requiresHumanApprovalBySize: true,
    requiresHumanReviewByRisk: false
  });
});

test('team-dev medium risk keeps its configured qualified approval requirement', () => {
  assert.deepEqual(resolveApprovalRequirements({
    ...teamDev,
    riskTier: 'medium',
    sizeLabel: 'M'
  }), {
    requiredApprovals: 1,
    requiresHumanApprovalBySize: false,
    requiresHumanReviewByRisk: true
  });
});

test('classifies a pure qualified-human approval requirement as an external hold', () => {
  assert.equal(isOnlyHumanReviewHold({
    blockers: [approvalHold],
    humanReviewBlockers: [approvalHold],
    requiredChecksBlocker: '',
    hasPendingChecks: false,
    hasFailedChecks: false
  }), true);
});

test('keeps a human approval hold pending while required checks are still running', () => {
  assert.equal(isOnlyHumanReviewHold({
    blockers: [approvalHold, requiredChecksBlocker],
    humanReviewBlockers: [approvalHold],
    requiredChecksBlocker,
    hasPendingChecks: true,
    hasFailedChecks: false
  }), true);
});

test('does not mask a failed required check as a human-review hold', () => {
  assert.equal(isOnlyHumanReviewHold({
    blockers: [approvalHold, requiredChecksBlocker],
    humanReviewBlockers: [approvalHold],
    requiredChecksBlocker,
    hasPendingChecks: true,
    hasFailedChecks: true
  }), false);
});

test('does not mask unrelated policy failures alongside a human-review hold', () => {
  assert.equal(isOnlyHumanReviewHold({
    blockers: [approvalHold, 'PR is missing a canonical size label.'],
    humanReviewBlockers: [approvalHold],
    requiredChecksBlocker: '',
    hasPendingChecks: false,
    hasFailedChecks: false
  }), false);
});

test('does not classify an empty blocker set as a human-review hold', () => {
  assert.equal(isOnlyHumanReviewHold({
    blockers: [],
    humanReviewBlockers: [approvalHold],
    requiredChecksBlocker: '',
    hasPendingChecks: false,
    hasFailedChecks: false
  }), false);
});

test('does not accept human-review reasons absent from the evaluated blocker set', () => {
  assert.equal(isOnlyHumanReviewHold({
    blockers: ['Required checks not satisfied: tests pending.'],
    humanReviewBlockers: [approvalHold],
    requiredChecksBlocker,
    hasPendingChecks: true,
    hasFailedChecks: false
  }), false);
});

test('wires structured human-hold state to both trusted executor copies', () => {
  const root = path.resolve(__dirname, '..');
  for (const workflow of [
    '.github/workflows/pr-auto-merge-executor.yml',
    '.github/base-coat/workflows/pr-auto-merge-executor.yml'
  ]) {
    const content = fs.readFileSync(path.join(root, workflow), 'utf8');
    assert.match(content, /merge-eligibility-policy\.cjs/);
    assert.match(content, /waitingForHumanReview/);
    assert.match(content, /human_review_hold/);
    assert.match(content, /human_review_hold: \$\{\{ steps\.policy\.outputs\.human_review_hold \}\}/);
    assert.match(content, /eligibility_state: \$\{\{ steps\.policy\.outputs\.eligibility_state \}\}/);
    assert.match(content, /Waiting for qualified human review/);
  }
});
