'use strict';

// Stage 1 shadow reconciler for docs/spec/coding-agent-completion-readiness.spec.md.
// Pure decision logic: no draft/ready mutation, enqueue, merge or issue closure. A green
// workflow run, workflow approval or task start never implies completion.
const { canonicalJson, sha256 } = require('./pr-decomposition-evaluator.cjs');
const { resolveApprovalRequirements } = require('./merge-eligibility-policy.cjs');

const SHA_PATTERN = /^[0-9a-f]{40}$/;
const MAX_PAGES_PER_COLLECTION = 100;
const MAX_ATTEMPTS_PER_IDENTITY = 3;
const RETRY_WINDOW_MS = 24 * 60 * 60 * 1000, RETRY_BACKOFF_MS = [0, 15 * 60 * 1000, 60 * 60 * 1000], MAX_SCAN_AGE_MS = 5 * 60 * 1000;
const SIZE_LABELS = ['XS', 'S', 'M', 'L', 'XL', 'XXL'], RISK_TIERS = ['low', 'medium', 'high', 'critical'];
const positive = value => Number.isInteger(value) && value > 0, validId = id => (typeof id === 'string' && id.trim() !== '') || positive(id), record = value => value === undefined || (value !== null && typeof value === 'object' && !Array.isArray(value));
// Malformed check entries collapse to an empty set, which the authoritative context comparison then blocks.
const checkList = input => (Array.isArray(input.requiredChecks) && input.requiredChecks.every(check => check && typeof check === 'object') ? input.requiredChecks : []);

function workIdentity(input) {
  if (input.task && input.localWork) return null;
  return input.task?.trusted === true && validId(input.task.id) ? { kind: 'agent-task', id: input.task.id }
    : input.localWork?.verified === true && validId(input.localWork.id) ? { kind: 'local-work', id: input.localWork.id } : null;
}

// Latest review per case-insensitive login by submittedAt then id, never by array position; null when any review is unordered.
function latestReviews(approvals = []) {
  if (!Array.isArray(approvals) || approvals.some(review => typeof review?.reviewer !== 'string' || !review.reviewer.trim() || Number.isNaN(Date.parse(review.submittedAt)) || !positive(review.id))) return null;
  const ordered = [...approvals].sort((a, b) => Date.parse(a.submittedAt) - Date.parse(b.submittedAt) || a.id - b.id);
  return [...new Map(ordered.map(({ reviewer, id, qualified, commitId }) => [reviewer.toLowerCase(), { reviewer: reviewer.toLowerCase(), id, qualified, commitId }])).values()].sort((a, b) => a.reviewer.localeCompare(b.reviewer));
}

// Full canonical tuple; generation alone is never globally unique.
function completionOperationKey(input) {
  return sha256(canonicalJson({
    repositoryId: input.repositoryId, source: { issue: input.source?.issue, directiveId: input.source?.directiveId, createdAt: input.source?.createdAt, authority: { revision: input.source?.authorityRevision, approved: input.source?.approved, permissionCurrent: input.source?.permissionCurrent, revoked: input.source?.revoked === true } },
    spec: { path: input.spec?.path, sha: input.spec?.sha, digest: input.spec?.digest }, work: workIdentity(input),
    generation: input.generation, pr: input.pr?.number,
    head: { repository: input.pr?.headRepository, ref: input.pr?.headRef, sha: input.pr?.headSha }, base: { ref: input.pr?.baseRef, sha: input.pr?.baseSha },
    policyRevision: input.policyRevision, requiredContexts: Array.isArray(input.requiredContexts) ? [...input.requiredContexts].sort() : null,
    tree: input.inventory?.treeDigest, body: input.pr?.bodyDigest, template: input.template?.digest, decomposition: input.decomposition?.digest,
    classification: { size: input.sizeLabel, risk: input.riskTier }, reviews: latestReviews(input.approvals),
    checks: checkList(input).map(({ context, runId, producerAppId, state, headSha, baseSha }) => ({ context, runId, producerAppId, state, headSha, baseSha }))
      .sort((a, b) => String(a.context).localeCompare(String(b.context)) || String(a.runId).localeCompare(String(b.runId))),
    completion: { runId: input.completion?.runId, producerAppId: input.completion?.producerAppId }, scopeAcceptance: input.scopeAcceptance?.digest,
    candidates: { digest: input.candidates?.digest, revision: input.candidates?.revision, sourceHorizon: input.candidates?.sourceHorizon, overlapping: Array.isArray(input.candidates?.overlapping) ? [...input.candidates.overlapping].sort((a, b) => (a?.number ?? 0) - (b?.number ?? 0)) : null }
  }));
}

// Bounded exhaustive lookup over the expected collections; any gap or missing horizon/index evidence is unknown, never "no competition"; the horizon may not postdate trusted source creation.
const REQUIRED_COLLECTIONS = ['open-prs', 'closed-since-horizon', 'retained-index'];

function candidateCoverage(candidates, sourceCreatedAt, reconciledAt) {
  const raw = Array.isArray(candidates?.collections) ? candidates.collections : [];
  const collections = raw.filter(entry => typeof entry?.name === 'string'), gaps = [];
  if (collections.length !== raw.length) gaps.push('malformed collection entry');
  for (const name of REQUIRED_COLLECTIONS) {
    if (collections.filter(entry => entry.name === name).length !== 1) gaps.push(`${name}: collection missing or duplicated`);
  }
  for (const entry of collections) {
    if (!REQUIRED_COLLECTIONS.includes(entry.name)) gaps.push(`${entry.name}: unexpected collection`);
    // Reaching the ceiling is unknown coverage, so a complete scan must stop strictly below it.
    if (!Number.isInteger(entry.pages) || entry.pages < 1 || entry.pages >= MAX_PAGES_PER_COLLECTION) gaps.push(`${entry.name}: page bound reached or unknown`);
    if (entry.terminal !== true) gaps.push(`${entry.name}: pagination not exhausted (cursor ${entry.cursor ?? 'none'})`);
    if (entry.inaccessible === true) gaps.push(`${entry.name}: inaccessible page`);
    if (entry.indexGap === true) gaps.push(`${entry.name}: retained index gap`);
  }
  const horizon = Date.parse(candidates?.sourceHorizon), closed = collections.find(entry => entry.name === 'closed-since-horizon');
  const since = Date.parse(closed?.since), created = Date.parse(sourceCreatedAt);
  if ([horizon, since, created].some(Number.isNaN) || horizon > created || since > horizon) gaps.push('closed/merged lookup does not cover the source horizon');
  // Every scan is fenced by one upper boundary between trusted source creation and the trusted reconciliation time, so no PR moves between collections unseen.
  if (Number.isNaN(Date.parse(candidates?.observedThrough)) || Date.parse(candidates.observedThrough) < created || Date.parse(candidates.observedThrough) !== Date.parse(reconciledAt) || collections.some(entry => entry.observedThrough !== candidates.observedThrough)) gaps.push('collections lack a common observed-through boundary');
  const index = collections.find(entry => entry.name === 'retained-index');
  if (!index || index.fromInception !== true || !index.indexRevision) gaps.push('retained index does not cover inception');
  if (!Array.isArray(candidates?.overlapping) || candidates.overlapping.some(candidate => !positive(candidate?.number))) gaps.push('overlap inventory unavailable or malformed');
  if (!candidates?.digest || !Number.isInteger(candidates?.revision) || candidates.revision < 1) gaps.push('candidate snapshot digest/revision missing');
  return { complete: gaps.length === 0, gaps };
}

function result(disposition, reasons, input) {
  return { disposition, reasons, promote: disposition === 'ready', closeSource: false, operationKey: completionOperationKey(input), coverageKey: sha256(canonicalJson({ observedThrough: input.candidates?.observedThrough, collections: Array.isArray(input.candidates?.collections) ? [...input.candidates.collections].sort((a, b) => String(a?.name).localeCompare(String(b?.name))) : null })) };
}

function evaluateCompletion(input) {
  const pr = input.pr || {};
  const authority = [];
  if (input.source?.approved !== true || input.source?.permissionCurrent !== true || input.source?.revoked === true || !positive(input.source?.authorityRevision)) {
    authority.push('qualified source directive is missing, revoked or lacks current permission');
  }
  if (!input.spec?.path || !SHA_PATTERN.test(input.spec?.sha || '') || !input.spec?.digest) authority.push('approved spec is not pinned');
  if (!workIdentity(input)) authority.push('trusted task or verified local-work identity is missing');
  if (![input.repositoryId, input.source?.issue, input.source?.directiveId, pr.number].every(positive) || !Number.isInteger(input.generation) || input.generation < 0
    || !pr.headRef || !pr.baseRef || !SHA_PATTERN.test(pr.baseSha || '') || !input.policyRevision) authority.push('operation identity is incomplete');
  if (!Array.isArray(input.unresolvedDependencies) || input.unresolvedDependencies.length > 0) authority.push('dependencies unresolved or unknown');
  if (input.evidenceError) authority.push(`evidence unavailable: ${input.evidenceError}`);
  if (!input.repository || pr.headRepository !== input.repository || !SHA_PATTERN.test(pr.headSha || '')) authority.push('fork or unidentified head; metadata-only rejection');
  if (authority.length > 0) return result('blocked', authority, input);

  const coverage = candidateCoverage(input.candidates, input.source?.createdAt, input.reconciledAt);
  if (!coverage.complete) return result('blocked', ['candidate set unknown', ...coverage.gaps], input);
  const competitors = (input.candidates.overlapping || []).filter(candidate => candidate.number !== pr.number); // Supersession (zero-file only) must name a PR in this exhaustive snapshot.
  const owner = input.ownerDisposition;
  const ownerDecided = owner?.verified === true && owner.winner === pr.number && owner.sourceIssue === input.source?.issue
    && owner.candidatesDigest === input.candidates.digest && owner.candidatesRevision === input.candidates.revision;
  const sup = input.supersededBy, superseded = sup?.verified === true && Array.isArray(input.files) && input.files.length === 0 && competitors.some(candidate => candidate.number === sup.prNumber) && sup.sourceIssue === input.source?.issue && sup.candidatesDigest === input.candidates.digest && sup.candidatesRevision === input.candidates.revision;
  if (competitors.length > 0 && !ownerDecided && !superseded) {
    return result('competition', competitors.map(candidate => `competing PR #${candidate.number}`), input);
  }
  const completion = input.completion || {};
  // Completion counts only from the trusted completion producer for this run, task and exact head.
  if (completion.state !== 'completed' || completion.headSha !== pr.headSha || completion.workId !== workIdentity(input).id || completion.generation !== input.generation
    || !positive(completion.runId) || !positive(completion.producerAppId) || completion.producerAppId !== input.trustedCompletionProducerAppId) {
    return result('incomplete', ['no trusted completion evidence for this task and exact head'], input);
  }
  if (!Array.isArray(input.files) || input.inventory?.complete !== true || !input.inventory.treeDigest) return result('blocked', ['complete diff inventory unavailable'], input);
  if (input.files.length === 0) return result(superseded ? 'superseded' : 'no-op', [superseded ? `superseded by #${sup.prNumber}` : 'zero-file completion'], input);
  const blockers = [];
  // Intake and decomposition results count only for the current body, head, base and tree.
  const currentEvidence = check => check?.passed === true && check.headSha === pr.headSha && check.baseSha === pr.baseSha
    && Boolean(check.treeDigest) && check.treeDigest === input.inventory.treeDigest && Boolean(pr.bodyDigest) && check.bodyDigest === pr.bodyDigest && Boolean(check.digest);
  if (!currentEvidence(input.template)) blockers.push('intake template validation failed or stale');
  if (!currentEvidence(input.decomposition)) blockers.push('decomposition validation failed or stale');
  const scope = input.scopeAcceptance; if (!(scope?.verified === true && Boolean(scope.digest) && scope.sourceIssue === input.source?.issue && scope.specDigest === input.spec?.digest && scope.workId === workIdentity(input).id && scope.headSha === pr.headSha)) blockers.push('trusted scope acceptance missing or not bound to the current source/spec/work/head');
  const checks = checkList(input);
  // The authoritative policy context set (profile.main.required_checks) must be met exactly once each.
  const expected = Array.isArray(input.requiredContexts) ? input.requiredContexts : [];
  if (expected.length === 0 || new Set(expected).size !== expected.length || checks.length !== expected.length
    || expected.some(context => checks.filter(check => check.context === context).length !== 1)) blockers.push('required check set incomplete or not authoritative');
  for (const check of checks) {
    if (check.headSha !== pr.headSha || check.baseSha !== pr.baseSha) blockers.push(`${check.context}: not for current head/base`);
    else if (check.state !== 'success') blockers.push(`${check.context}: ${check.state}`);
    else if (typeof check.context !== 'string' || !check.context.trim() || !positive(check.runId) || !positive(check.producerAppId) || check.producerAppId !== input.trustedValidationProducers?.[check.context]) blockers.push(`${check.context}: untrusted producer`);
  }
  const policyValid = SIZE_LABELS.includes(input.sizeLabel) && RISK_TIERS.includes(input.riskTier) && Array.isArray(input.policy?.humanApprovalRequiredSizes) && input.policy.humanApprovalRequiredSizes.every(size => SIZE_LABELS.includes(size)) && record(input.policy.requiredApprovalsByRiskTier) && record(input.policy.approvalRequiredByRisk) && Object.values(input.policy.approvalRequiredByRisk ?? {}).every(flag => typeof flag === 'boolean') && [...Object.values(input.policy.requiredApprovalsByRiskTier ?? {}), input.policy.minimumQualifiedApprovalsForHumanSize ?? 0].every(count => Number.isInteger(count) && count >= 0);
  if (!policyValid) blockers.push('classification or approval policy evidence missing');
  // The resolver runs only on well-shaped policy; otherwise an invalid count keeps the result blocked.
  const { requiredApprovals: resolved, requiresHumanReviewByRisk, requiresHumanApprovalBySize } = policyValid ? resolveApprovalRequirements({ ...input.policy, riskTier: input.riskTier, sizeLabel: input.sizeLabel }) : { requiredApprovals: NaN };
  const reviews = latestReviews(input.approvals), requiredApprovals = (requiresHumanReviewByRisk || requiresHumanApprovalBySize || input.sizeLabel === 'XXL') && resolved < 1 ? 1 : resolved;
  if (!reviews) blockers.push('review evidence is unordered or incomplete');
  const qualified = (reviews || []).filter(review => review.qualified === true && review.commitId === pr.headSha).length;
  if (!Number.isInteger(requiredApprovals) || requiredApprovals < 0) blockers.push('approval policy resolves to an invalid count');
  if (qualified < requiredApprovals) blockers.push(`qualified current-head approval required (${qualified}/${requiredApprovals})`);
  if (blockers.length > 0) return result('blocked', blockers, input);
  if (pr.baseRef !== 'main') return input.layerTarget?.verified === true && input.layerTarget.ref === pr.baseRef && Boolean(input.layerTarget.stackId) ? result('complete-feature-only', ['feature-only completion stays draft'], input) : result('blocked', ['non-main destination is not a verified stack layer target'], input);
  if (input.downstreamReceiptGate !== true) return result('blocked', ['downstream receipt gate is not enforceable; promotion disabled'], input);
  if (typeof pr.draft !== 'boolean') return result('blocked', ['draft state unavailable; re-fetch before promotion'], input);
  return result(pr.draft === false ? 'already-ready' : 'ready', [], input);
}

// Downstream gate: a receipt is valid only while the current input still evaluates to a
// promotable disposition for the identical identity. New pushes, competitors, revoked
// authority, a disabled gate or a fresh scan (coverageKey, kept out of the retry key) invalidate it. `at` is the trusted gate clock; the scan must be at most MAX_SCAN_AGE_MS old.
function receiptMatchesCurrent({ receipt, current, at }) {
  const now = evaluateCompletion(current), age = at - Date.parse(current?.reconciledAt);
  return Boolean(receipt) && Number.isFinite(at) && age >= 0 && age <= MAX_SCAN_AGE_MS && ['ready', 'already-ready'].includes(receipt.disposition) &&
    ['ready', 'already-ready'].includes(now.disposition) && receipt.operationKey === now.operationKey && receipt.coverageKey === now.coverageKey;
}
// Pauses after three attempts or 24 hours from the first attempt; each retry waits the backoff after the last attempt.
function retryAllowed(attemptsForIdentity, firstAttemptAt, now = Date.now(), lastAttemptAt) {
  const attempts = attemptsForIdentity ?? 0, first = Date.parse(firstAttemptAt), last = Date.parse(lastAttemptAt); if (!Number.isInteger(attempts) || attempts < 0 || attempts >= MAX_ATTEMPTS_PER_IDENTITY) return false;
  return attempts === 0 || (now - first >= 0 && now - first < RETRY_WINDOW_MS && last >= first && last <= now && now - last >= RETRY_BACKOFF_MS[attempts]);
}

module.exports = { MAX_PAGES_PER_COLLECTION, candidateCoverage, completionOperationKey, evaluateCompletion, receiptMatchesCurrent, retryAllowed };
