'use strict';

// Stage 1 read-only stack observer for docs/spec/dependent-stack-handoff.spec.md.
// Pure decision logic: it never merges, retargets, rewrites or deletes refs. Dependency
// labels and branch names are never treated as Git ancestry.
const { canonicalJson, sha256 } = require('./pr-decomposition-evaluator.cjs');
const { evaluatePrBarrier } = require('./eligibility-barrier.cjs');

const MAX_ATTEMPTS_PER_REVISION = 3;
const isSha = value => /^[0-9a-f]{40}$/.test(value || '');

const isAncestor = (ancestry, ancestor, descendant) =>
  (ancestry || []).some(edge => edge.ancestor === ancestor && edge.descendant === descendant);

// Ordered bottom-up layers from the explicit stack record; returns null on missing parent or cycle.
function orderLayers(layers) {
  const ordered = [];
  let current = layers.filter(layer => layer.parentPr === null || layer.parentPr === undefined);
  if (current.length !== 1) return null;
  while (current.length === 1 && ordered.length <= layers.length) {
    ordered.push(current[0]);
    current = layers.filter(layer => layer.parentPr === current[0].prNumber);
  }
  return current.length > 1 || ordered.length !== layers.length ? null : ordered;
}

function validateStack({ stack, layers = [], ancestry = [], protections = {} }) {
  const blockers = new Map();
  const block = (pr, reason) => blockers.set(pr, [...(blockers.get(pr) || []), reason]);
  if (!stack?.id || !stack.repositoryId || !stack.repository || !Number.isInteger(stack.revision) || !isSha(stack.integrationTip) || !/^feature\/.+/.test(stack.integrationRef || '')) {
    return { valid: false, reason: 'stack identity, repository or feature/* integration ref is missing', ordered: [], blockers: {} };
  }
  if (!Array.isArray(layers) || !Array.isArray(ancestry) || layers.some(layer => !layer || typeof layer !== 'object' || !['open', 'closed'].includes(layer.state) || !Number.isInteger(layer.prNumber) || !layer.headRef || !layer.baseRef || !isSha(layer.headSha) || !isSha(layer.baseSha))) {
    return { valid: false, reason: 'layer state, PR, ref or SHA identity is incomplete', ordered: [], blockers: {} };
  }
  const ordered = orderLayers(layers);
  if (!ordered) return { valid: false, reason: 'stack has a missing parent, fork or cycle', ordered: [], blockers: {} };
  ordered.forEach((layer, index) => {
    const liveParent = ordered.slice(0, index).reverse().find(entry => entry.merged !== true);
    const expectedBase = liveParent ? liveParent.headRef : stack.integrationRef;
    if (layer.headRepository !== stack.repository) block(layer.prNumber, 'head is from an untrusted repository');
    if (layer.scopeAuthorized !== true || !layer.authorityIdentity) block(layer.prNumber, 'layer scope or source/spec/task authority is not current');
    if (layer.baseRef !== expectedBase) block(layer.prNumber, `base must be ${expectedBase}`);
    if (protections[layer.baseRef]?.protected !== true) block(layer.prNumber, `destination ${layer.baseRef} is not protected`);
    if ((layer.state === 'closed') !== (layer.merged === true)) block(layer.prNumber, layer.merged === true ? 'layer marked merged but still open' : 'layer closed without merge'); else if (layer.merged === true && !isSha(layer.integratedCommit)) block(layer.prNumber, 'merged layer lacks integration provenance');
    if (layer.merged !== true && ordered.slice(index + 1).some(entry => entry.merged === true)) block(layer.prNumber, 'a descendant merged before this layer');
    // Fail closed: every layer, merged or not, descends from the live parent head, nearest merged integrated commit, or (merged root) its recorded base or the integration tip.
    const mergedParent = ordered.slice(0, index).reverse().find(entry => entry.merged === true);
    const anchor = liveParent ? liveParent.headSha : (mergedParent ? mergedParent.integratedCommit : (layer.merged === true ? layer.baseSha : stack.integrationTip));
    const evidence = layer.reconstruction;
    const reconstructed = evidence?.approved === true && evidence.repositoryId === stack.repositoryId && evidence.stackId === stack.id && evidence.stackRevision === stack.revision
      && evidence.headSha === layer.headSha && evidence.baseSha === layer.baseSha && evidence.anchor === anchor && Boolean(layer.authorityIdentity) && evidence.authorityIdentity === layer.authorityIdentity;
    if (layer.baseSha !== anchor) block(layer.prNumber, 'base sha is not the recorded parent head, integrated commit or integration tip');
    if ((!anchor || !isAncestor(ancestry, anchor, layer.headSha)) && !reconstructed) block(layer.prNumber, 'recorded base or parent head is not an observed ancestor');
  });
  // The latest merged layer must be the stack's current integration tip; a blocked layer freezes itself and every descendant.
  const lastMerged = [...ordered].reverse().find(layer => layer.merged === true); if (lastMerged && lastMerged.integratedCommit !== stack.integrationTip) block(lastMerged.prNumber, 'latest merged layer is not the current integration tip');
  const firstBlocked = ordered.findIndex(layer => blockers.has(layer.prNumber)), frozen = firstBlocked < 0 ? [] : ordered.slice(firstBlocked).map(layer => layer.prNumber);
  return { valid: blockers.size === 0, ordered: ordered.map(layer => layer.prNumber), frozen, blockers: Object.fromEntries(blockers) };
}

// Only the lowest incomplete layer may advance, and only with validation for its exact head/base.
function nextAdvancement(input) {
  const result = validateStack(input);
  if (!result.ordered.length) return { action: 'blocked', reason: result.reason };
  const byPr = new Map(input.layers.map(layer => [layer.prNumber, layer]));
  const lowest = result.ordered.map(pr => byPr.get(pr)).find(layer => layer.merged !== true);
  if (!lowest) return result.valid ? { action: 'finalize' } : { action: 'blocked', reasons: Object.values(result.blockers).flat() };
  if (result.frozen.includes(lowest.prNumber)) return { action: 'blocked', prNumber: lowest.prNumber, reasons: result.blockers[lowest.prNumber] || ['ancestor frozen'] };
  const validation = lowest.validation;
  // Validation counts only when bound to this stack revision, PR, head/base, tree, readiness, decomposition, policy and producer.
  const fresh = validation?.state === 'success' && validation.headSha === lowest.headSha && validation.baseSha === lowest.baseSha && Boolean(lowest.treeDigest)
    && validation.treeDigest === lowest.treeDigest && validation.ready === true && validation.decompositionPassed === true && Boolean(input.policyRevision)
    && validation.policyRevision === input.policyRevision && Number.isInteger(validation.producerAppId) && validation.producerAppId === input.trustedProducerAppId
    && validation.repositoryId === input.stack.repositoryId && validation.stackId === input.stack.id && validation.stackRevision === input.stack.revision
    && validation.prNumber === lowest.prNumber && validation.headRef === lowest.headRef && validation.baseRef === lowest.baseRef && Boolean(lowest.readinessIdentity) && validation.readinessIdentity === lowest.readinessIdentity
    && Boolean(lowest.decompositionDigest) && validation.decompositionDigest === lowest.decompositionDigest && validation.authorityIdentity === lowest.authorityIdentity;
  if (!fresh) return { action: 'validate', prNumber: lowest.prNumber };
  return { action: 'advance', prNumber: lowest.prNumber, headSha: lowest.headSha, baseSha: lowest.baseSha };
}

// A parent edit invalidates validation for every transitive descendant.
function invalidateDescendants(layers, changedPr) {
  const invalid = [];
  for (let frontier = [changedPr]; frontier.length > 0;) {
    const children = layers.filter(layer => frontier.includes(layer.parentPr)).map(layer => layer.prNumber);
    frontier = children.filter(pr => pr !== changedPr && !invalid.includes(pr));
    invalid.push(...frontier);
  }
  return invalid;
}

// Squash-aware synchronization plan: the old parent head is not assumed to be an ancestor of
// the squash commit; the child's unique delta is replayed from the recorded boundary.
function planDescendantSync({ parent, child, ancestry = [], stack, protections = {} }) {
  if ((parent.state === 'closed') !== (parent.merged === true)) return { action: 'freeze', reason: 'parent merge flag contradicts its PR state' };
  if (parent.merged !== true) return { action: 'wait' };
  if (!isSha(parent.integratedCommit) || parent.integratedCommit !== stack?.integrationTip || !isSha(parent.originalHeadSha) || parent.originalHeadSha !== parent.headSha) return { action: 'freeze', reason: 'integrated commit is not the current integration tip or original boundary missing' };
  // Ancestry proves the range exists; the delta receipt must be bound to this stack revision and the child's current authority, repository and protected current and retarget destinations.
  const delta = child.uniqueDelta, provenDelta = delta?.verified === true && delta.baseSha === parent.originalHeadSha && delta.headSha === child.headSha && Boolean(child.treeDigest) && delta.treeDigest === child.treeDigest && Boolean(stack?.repositoryId) && Boolean(stack.repository) && Boolean(stack.id) && Number.isInteger(stack.revision) && isSha(child.headSha) && protections[child.baseRef]?.protected === true && delta.repositoryId === stack.repositoryId && delta.stackId === stack.id && delta.stackRevision === stack.revision && Boolean(child.authorityIdentity) && delta.authorityIdentity === child.authorityIdentity && child.scopeAuthorized === true && child.headRepository === stack?.repository && protections[parent.baseRef]?.protected === true && child.parentPr === parent.prNumber && child.baseRef === parent.headRef && parent.baseRef === stack?.integrationRef;
  if (child.state !== 'open' || child.merged === true || child.baseSha !== parent.originalHeadSha || !isAncestor(ancestry, parent.originalHeadSha, child.headSha) || !provenDelta) return { action: 'freeze', reason: 'child delta boundary is ambiguous or unverified' };
  return { action: 'reconstruct', onto: parent.integratedCommit, range: `${parent.originalHeadSha}..${child.headSha}`, retargetTo: parent.baseRef, requiresFreshValidation: true };
}

// One feature/* -> main finalization: every layer integrated, manifest bound to the exact
// tree and layers, and the aggregate PR evaluated by the protected-main barrier.
function evaluateFinalization({ stack, layers = [], manifest, finalization, ancestry = [], protections = {} }) {
  const reasons = [];
  if (!validateStack({ stack, layers, ancestry, protections }).valid) reasons.push('stack does not validate against current evidence');
  if (!stack?.repositoryId || !stack.repository || !stack.id || !Number.isInteger(stack.revision)) reasons.push('stack identity is incomplete');
  if (layers.length === 0 || !layers.every(layer => Number.isInteger(layer.prNumber)) || new Set(layers.map(layer => layer.prNumber)).size !== layers.length) reasons.push('layer inventory is empty, duplicated or malformed');
  if (layers.some(layer => layer.merged !== true || layer.state !== 'closed')) reasons.push('incomplete layers remain');
  const entries = Array.isArray(manifest?.layers) && manifest.layers.every(entry => Number.isInteger(entry?.prNumber) && isSha(entry.integratedCommit)) ? manifest.layers : null;
  if (!entries) reasons.push('manifest layers are missing or malformed');
  const included = new Map((entries || []).map(entry => [entry.prNumber, entry.integratedCommit]));
  const bound = manifest?.repositoryId === stack?.repositoryId && manifest?.stackId === stack?.id && manifest?.revision === stack?.revision && Boolean(manifest?.decompositionDigest)
    && manifest.decompositionDigest === finalization?.decomposition?.digest && Array.isArray(manifest.tasks) && manifest.tasks.length > 0 && new Set(manifest.tasks).size === manifest.tasks.length
    && Array.isArray(manifest.exclusions) && manifest.exclusions.every(entry => typeof entry?.reason === 'string' && entry.reason.trim()) && [...manifest.tasks].sort().join('\n') === [...new Set(layers.map(layer => layer.authorityIdentity))].sort().join('\n');
  if (!bound) reasons.push('manifest is not bound to this stack revision, task/exclusion inventory and aggregate decomposition');
  if (layers.length !== included.size || (entries || []).length !== included.size || layers.some(layer => !isSha(layer.integratedCommit) || included.get(layer.prNumber) !== layer.integratedCommit) || layers.some(layer => layer.integratedCommit !== stack?.integrationTip && !isAncestor(ancestry, layer.integratedCommit, stack?.integrationTip))) reasons.push('manifest layers or integration provenance differ from stack or are not observed in the integration tip history');
  const head = finalization?.head;
  if (finalization?.repositoryId !== stack?.repositoryId || head?.repository !== stack?.repository || head?.ref !== stack?.integrationRef || !isSha(head?.sha) || head.sha !== stack?.integrationTip || (orderLayers(layers) || []).at(-1)?.integratedCommit !== stack?.integrationTip) reasons.push('finalization head is not the recorded integration tip of this stack or its terminal integrated layer');
  const barrier = evaluatePrBarrier({ ...finalization, stackFinalization: true, stackManifest: manifest, protectedRef: 'main' });
  return { state: reasons.length || barrier.state !== 'success' ? 'failure' : 'success', reasons: [...reasons, ...barrier.reasons] };
}

function stackOperationKey({ stack, prNumber, headSha, baseSha, targetTip, policyRevision } = {}) {
  if (!stack?.repositoryId || !stack.id || !Number.isInteger(stack.revision) || !Number.isInteger(prNumber)
    || ![headSha, baseSha, targetTip].every(isSha) || !policyRevision) return null;
  return sha256(canonicalJson({ repositoryId: stack.repositoryId, stackId: stack.id, revision: stack.revision, prNumber, headSha, baseSha, targetTip, policyRevision }));
}

// Duplicate or post-crash events read actual state; ambiguous effects are never repeated.
function reconcileLayerOperation({ intent, observed, current, attempts = 0 }) {
  if (!intent) return observed?.applied === true ? { action: 'paused', reason: 'untracked effect: no recorded intent' } : { action: 'plan' };
  const key = stackOperationKey(current);
  if (!key || key !== intent.operationKey) return { action: 'paused', reason: 'operation identity changed after decision' };
  if ((observed?.applied === true || observed?.known === true) && stackOperationKey(observed) !== key) return { action: 'paused', reason: 'observed state does not match the intended identity' };
  if (observed?.applied === true) return { action: 'already-applied' };
  if (attempts >= MAX_ATTEMPTS_PER_REVISION) return { action: 'paused', reason: 'retry budget exhausted' };
  return observed?.known !== true ? { action: 'inspect', reason: 'ambiguous effect' } : { action: 'retry' };
}

module.exports = { evaluateFinalization, invalidateDescendants, nextAdvancement, planDescendantSync, reconcileLayerOperation, stackOperationKey, validateStack };
