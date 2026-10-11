'use strict';

function resolveApprovalRequirements({
  riskTier,
  sizeLabel,
  requiredApprovalsByRiskTier,
  humanApprovalRequiredSizes,
  minimumQualifiedApprovalsForHumanSize,
  approvalRequiredByRisk
}) {
  const requiresHumanApprovalBySize = new Set(
    (humanApprovalRequiredSizes || []).map(size => String(size || '').toUpperCase())
  ).has(String(sizeLabel || '').toUpperCase());
  const requiresHumanReviewByRisk = Boolean(approvalRequiredByRisk?.[riskTier]);
  const requiredApprovals = Math.max(
    Number(requiredApprovalsByRiskTier?.[riskTier] || 0),
    requiresHumanApprovalBySize
      ? Number(minimumQualifiedApprovalsForHumanSize || 1)
      : 0
  );

  return {
    requiredApprovals,
    requiresHumanApprovalBySize,
    requiresHumanReviewByRisk
  };
}

function isOnlyHumanReviewHold({
  blockers,
  humanReviewBlockers,
  requiredChecksBlocker,
  hasPendingChecks,
  hasFailedChecks
}) {
  if (
    !Array.isArray(blockers) ||
    !Array.isArray(humanReviewBlockers) ||
    blockers.length === 0 ||
    humanReviewBlockers.length === 0 ||
    humanReviewBlockers.some(reason => !blockers.includes(reason))
  ) return false;

  const humanReasons = new Set(humanReviewBlockers);
  return blockers.every(reason =>
    humanReasons.has(reason) ||
    (
      Boolean(requiredChecksBlocker) &&
      reason === requiredChecksBlocker &&
      hasPendingChecks === true &&
      hasFailedChecks !== true
    )
  );
}

// Outdated threads anchor to superseded diffs; only current, unresolved threads block.
// Any read failure or incomplete page set fails closed.
function summarizeReviewThreads({ threads, complete, error }) {
  if (error || complete !== true || !Array.isArray(threads)) {
    const detail = error ? `: ${error instanceof Error ? error.message : String(error)}` : '';
    return {
      readable: false,
      unresolved: [],
      summary: 'unreadable',
      blocker: `Review thread state could not be read; eligibility fails closed${detail}.`
    };
  }
  const unresolved = threads
    .filter(thread => thread && thread.isResolved !== true && thread.isOutdated !== true)
    .map(thread => ({
      path: String(thread.path || ''),
      url: String(thread.comments?.nodes?.[0]?.url || ''),
      author: String(thread.comments?.nodes?.[0]?.author?.login || '')
    }));
  return {
    readable: true,
    unresolved,
    summary: unresolved.length === 0 ? 'clear' : `unresolved:${unresolved.length}`,
    blocker: unresolved.length === 0
      ? ''
      : `Unresolved review threads: ${unresolved.length}; resolve them before merge: ` +
        unresolved.map(thread => thread.url || thread.path || 'thread').join(', ')
  };
}

module.exports = { isOnlyHumanReviewHold, resolveApprovalRequirements, summarizeReviewThreads };
