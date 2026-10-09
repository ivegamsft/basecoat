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

module.exports = { isOnlyHumanReviewHold, resolveApprovalRequirements };
