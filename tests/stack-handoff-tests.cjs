'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { evaluateFinalization, invalidateDescendants, nextAdvancement, planDescendantSync, reconcileLayerOperation, stackOperationKey, validateStack } = require('../.github/base-coat/scripts/stack-handoff.cjs');

const sha = char => char.repeat(40);
const stack = { repositoryId: 1, repository: 'org/repo', id: 'stack-1', revision: 1, integrationRef: 'feature/lane-a', integrationTip: sha('9') }, tipD = { ...stack, integrationTip: sha('d') };
const protections = { 'feature/lane-a': { protected: true }, 'layer/1': { protected: true }, 'layer/2': { protected: true } };
const layer = (prNumber, parentPr, baseRef, headSha, overrides = {}) => ({
  prNumber, parentPr, baseRef, headSha, headRef: `layer/${prNumber}`, headRepository: 'org/repo',
  baseSha: sha('0'), state: 'open', scopeAuthorized: true, authorityIdentity: 'task-1', treeDigest: 'tree', readinessIdentity: 'r', decompositionDigest: 'd', ...overrides
});
const threeLayers = () => [
  layer(1, null, 'feature/lane-a', sha('a'), { baseSha: sha('9') }),
  layer(2, 1, 'layer/1', sha('b'), { baseSha: sha('a') }),
  layer(3, 2, 'layer/2', sha('c'), { baseSha: sha('b') })
];
const gate = { policyRevision: 'p', trustedProducerAppId: 7 };
const fresh = { authorityIdentity: 'task-1', repositoryId: 1, stackId: 'stack-1', stackRevision: 1, readinessIdentity: 'r', decompositionDigest: 'd', state: 'success', ready: true, decompositionPassed: true, treeDigest: 'tree', policyRevision: 'p', producerAppId: 7 };
const ancestry = [{ ancestor: sha('9'), descendant: sha('a') }, { ancestor: sha('a'), descendant: sha('b') }, { ancestor: sha('b'), descendant: sha('c') }];
const mergedChain = () => threeLayers().map((entry, i) => ({ ...entry, merged: true, state: 'closed', baseRef: 'feature/lane-a', baseSha: sha(i ? String(i) : '9'), integratedCommit: sha(i === 2 ? '9' : String(i + 1)) })), mergedAncestry = [ancestry[0], { ancestor: sha('1'), descendant: sha('b') }, { ancestor: sha('2'), descendant: sha('c') }];

test('three-layer chain with observed ancestry advances bottom-up only with exact validation', () => {
  const layers = threeLayers();
  assert.deepEqual(validateStack({ stack, layers, ancestry, protections }).ordered, [1, 2, 3]);
  assert.deepEqual(nextAdvancement({ stack, layers, ancestry, protections, ...gate }), { action: 'validate', prNumber: 1 });
  layers[0].validation = { ...fresh, prNumber: 1, headSha: sha('a'), baseSha: sha('9'), headRef: 'layer/1', baseRef: 'feature/lane-a' };
  for (const stale of [{ policyRevision: 'old' }, { producerAppId: 8 }, { treeDigest: 'old' }, { ready: false }, { prNumber: 999 }, { stackRevision: 2 }, { decompositionDigest: 'old' }, { baseRef: 'feature/old' }, { headRef: 'layer/9' }, { authorityIdentity: 'task-2' }]) {
    assert.equal(nextAdvancement({ stack, layers: [{ ...layers[0], validation: { ...layers[0].validation, ...stale } }, ...layers.slice(1)], ancestry, protections, ...gate }).action, 'validate');
  }
  assert.equal(nextAdvancement({ stack, layers: [{ ...layers[0], baseSha: sha('0'), validation: { ...layers[0].validation, baseSha: sha('0') } }, ...layers.slice(1)], ancestry, protections }).action, 'blocked');
  assert.equal(nextAdvancement({ stack, layers, ancestry, protections, ...gate }).action, 'advance');
  layers[0].validation.headSha = sha('f');
  assert.equal(nextAdvancement({ stack, layers, ancestry, protections, ...gate }).action, 'validate');
});

test('label dependency without Git ancestry is rejected and freezes descendants', () => {
  const result = validateStack({ stack, layers: threeLayers().map(entry => ({ ...entry, dependencyLabel: 'depends-on-1' })), ancestry: [ancestry[0], ancestry[2]], protections });
  assert.deepEqual([result.valid, result.frozen], [false, [2, 3]]);
  assert.match(result.blockers[2].join(' '), /not an observed ancestor/);
});

test('root and reconstructed layers need ancestry or evidence bound to this stack revision', () => {
  assert.deepEqual(validateStack({ stack, layers: threeLayers(), ancestry: ancestry.slice(1), protections }).frozen, [1, 2, 3]);
  const evidence = { approved: true, repositoryId: 1, stackId: 'stack-1', stackRevision: 1, headSha: sha('a'), baseSha: sha('9'), anchor: sha('9'), authorityIdentity: 'task-1' };
  const layers = threeLayers(); layers[0].reconstruction = evidence;
  assert.equal(validateStack({ stack, layers, ancestry: ancestry.slice(1), protections }).valid, true);
  for (const bad of [{ stackRevision: 0 }, { stackId: 'other' }, { repositoryId: 2 }, { authorityIdentity: 'task-2' }]) {
    assert.equal(validateStack({ stack, layers: [{ ...layers[0], reconstruction: { ...evidence, ...bad } }, ...layers.slice(1)], ancestry: ancestry.slice(1), protections }).valid, false);
  }
});

test('unprotected destinations, unauthorized scope, foreign heads and cycles fail closed', () => {
  assert.match(validateStack({ stack, layers: threeLayers(), ancestry, protections: {} }).blockers[1].join(' '), /not protected/);
  assert.deepEqual(validateStack({ stack, layers: threeLayers().map((entry, i) => (i === 2 ? { ...entry, scopeAuthorized: false } : entry)), ancestry, protections }).frozen, [3]);
  assert.deepEqual(nextAdvancement({ stack, layers: threeLayers().map((entry, i) => (i === 0 ? { ...entry, headRepository: 'fork/repo' } : entry)), ancestry, protections, ...gate }).action, 'blocked');
  assert.equal(validateStack({ stack, layers: threeLayers().map((entry, i) => (i === 0 ? { ...entry, parentPr: 3 } : entry)), ancestry, protections }).valid, false);
  for (const [index, field] of [[0, 'prNumber'], [1, 'headRef'], [2, 'headSha'], [0, 'state'], [1, 'authorityIdentity']]) {
    assert.equal(validateStack({ stack, layers: threeLayers().map((entry, i) => i === index ? { ...entry, [field]: undefined } : entry), ancestry, protections }).valid, false);
  }
  for (const bad of [{ integrationRef: 'main' }, { repository: undefined }, { repositoryId: undefined }]) {
    assert.equal(validateStack({ stack: { ...stack, ...bad }, layers: threeLayers().map(entry => ({ ...entry, headRepository: undefined })), ancestry, protections }).valid, false);
  }
});

test('parent edits invalidate every transitive descendant', () => {
  assert.deepEqual([1, 3].map(pr => invalidateDescendants(threeLayers(), pr)), [[2, 3], []]);
});

test('squash parent merge replays the unique child delta without assuming old parent ancestry', () => {
  const parent = { ...threeLayers()[0], merged: true, state: 'closed', originalHeadSha: sha('a'), integratedCommit: sha('d') };
  const child = { ...threeLayers()[1], uniqueDelta: { verified: true, baseSha: sha('a'), headSha: sha('b'), treeDigest: 'tree', repositoryId: 1, stackId: 'stack-1', stackRevision: 1, authorityIdentity: 'task-1' } };
  assert.deepEqual(planDescendantSync({ stack: tipD, protections, parent, child, ancestry }), {
    action: 'reconstruct', onto: sha('d'), range: `${sha('a')}..${sha('b')}`, retargetTo: 'feature/lane-a', requiresFreshValidation: true
  });
  assert.deepEqual([[], ancestry].map((a, i) => planDescendantSync({ stack: tipD, protections: i ? {} : protections, parent, child, ancestry: a }).action), ['freeze', 'freeze']);
  for (const bad of [{ baseSha: sha('9') }, { state: 'closed', merged: true }, { uniqueDelta: undefined }, { uniqueDelta: { ...child.uniqueDelta, treeDigest: 'old' } }, { scopeAuthorized: false }, { headRepository: 'fork/repo' }, { uniqueDelta: { ...child.uniqueDelta, stackRevision: 2 } }, { uniqueDelta: { ...child.uniqueDelta, repositoryId: 2 } }, { headRepository: undefined }, { headSha: 'x', uniqueDelta: { ...child.uniqueDelta, headSha: 'x' } }, { authorityIdentity: 'task-2' }, { baseRef: 'unrelated' }, { parentPr: 3 }]) assert.equal(planDescendantSync({ stack: tipD, protections, parent, child: { ...child, ...bad }, ancestry }).action, 'freeze');
  for (const bad of [{ integratedCommit: undefined }, { baseRef: 'release' }]) assert.equal(planDescendantSync({ stack: tipD, protections: { ...protections, release: { protected: true } }, parent: { ...parent, ...bad }, child, ancestry }).action, 'freeze'); for (const [s, p] of [[{ repository: undefined, repositoryId: undefined }, protections], [{ id: undefined, revision: undefined }, protections], [{}, { ...protections, 'layer/1': undefined }]]) assert.equal(planDescendantSync({ stack: { ...tipD, ...s }, protections: p, parent, child: { ...child, ...('repository' in s ? { headRepository: undefined } : {}), uniqueDelta: { ...child.uniqueDelta, ...('repositoryId' in s ? { repositoryId: undefined } : {}), ...('id' in s ? { stackId: undefined, stackRevision: undefined } : {}) } }, ancestry }).action, 'freeze');
  assert.equal(planDescendantSync({ stack, protections, parent, child, ancestry }).action, 'freeze'); assert.equal(planDescendantSync({ stack: tipD, protections, parent: { ...parent, originalHeadSha: sha('9') }, child: { ...child, baseSha: sha('9') }, ancestry }).action, 'freeze');
});

test('parent closed without merge freezes descendants with a resumable blocker', () => {
  const layers = threeLayers();
  layers[0].state = 'closed';
  assert.equal(planDescendantSync({ stack: tipD, protections, parent: layers[0], child: layers[1], ancestry }).action, 'freeze');
  const outOfOrder = threeLayers().map((layer, i) => (i === 1 ? { ...layer, merged: true, state: 'closed', integratedCommit: sha('d') } : layer));
  assert.deepEqual(validateStack({ stack, layers: outOfOrder, ancestry, protections }).frozen, [1, 2, 3]);
  const closed = validateStack({ stack, layers, ancestry, protections });
  assert.deepEqual([closed.blockers[1].join(' ').includes('closed without merge'), closed.frozen], [true, [1, 2, 3]]);
  assert.equal(nextAdvancement({ stack, layers, ancestry, protections }).action, 'blocked');
  assert.equal(validateStack({ stack: { ...stack, integrationTip: 'tip' }, layers, ancestry, protections }).valid, false);
});

test('retargeted child after a merged parent is validated against the integration ref', () => {
  const layers = threeLayers();
  Object.assign(layers[0], { merged: true, state: 'closed', integratedCommit: sha('d') });
  Object.assign(layers[1], { baseRef: 'feature/lane-a', baseSha: sha('d'), validation: { ...fresh, prNumber: 2, headSha: sha('b'), baseSha: sha('d'), headRef: 'layer/2', baseRef: 'feature/lane-a' } });
  const current = { ...stack, integrationTip: sha('d') }, retargeted = [...ancestry, { ancestor: sha('d'), descendant: sha('b') }];
  assert.deepEqual([nextAdvancement({ stack: current, layers, ancestry, protections, ...gate }).action, nextAdvancement({ stack, layers, ancestry: retargeted, protections, ...gate }).action], ['blocked', 'blocked']); assert.deepEqual(nextAdvancement({ stack: current, layers, ancestry: retargeted, protections, ...gate }).prNumber, 2);
  for (const bad of [[null], 'x']) assert.deepEqual([validateStack({ stack, layers: bad, ancestry, protections }).valid, nextAdvancement({ stack, layers: bad, ancestry, protections }).action], [false, 'blocked']);
  for (const bad of [{ state: 'closed' }, { state: 'open', baseRef: 'feature/lane-a' }]) assert.equal(nextAdvancement({ stack, layers: layers.map(entry => ({ ...entry, merged: true, ...bad })), ancestry, protections, ...gate }).action, 'blocked');
  const merged = mergedChain();
  assert.deepEqual([[protections, merged], [{}, merged], [protections, merged.map((entry, i) => (i === 2 ? { ...entry, integratedCommit: undefined } : entry))]].map(([p, l]) => nextAdvancement({ stack, layers: l, ancestry: mergedAncestry, protections: p, ...gate }).action), ['finalize', 'blocked', 'blocked']);
});

test('finalization needs every layer, the exact manifest and the protected-main barrier', () => {
  const layers = mergedChain();
  const finalization = {
    repositoryId: 1, prId: 9, head: { repository: 'org/repo', ref: 'feature/lane-a', sha: sha('9') },
    base: { ref: 'main', sha: sha('0') }, treeDigest: 'tree', readinessIdentity: 'r', ready: true,
    authority: { approved: true, permissionCurrent: true, sourceIssue: 3670, specDigest: 's', taskId: 't' },
    policyRevision: 'p', decomposition: { passed: true, digest: 'd' }, holdRevision: 'h', activeHolds: [], unresolvedDependencies: [],
    requiredChecks: [{ context: 'tests', state: 'success', headSha: sha('9'), producerAppId: 1 }], trustedValidationProducers: { tests: 1 },
    policy: { humanApprovalRequiredSizes: ['XXL'], minimumQualifiedApprovalsForHumanSize: 1 }, sizeLabel: 'XL', riskTier: 'low'
  };
  const manifest = { repositoryId: 1, stackId: 'stack-1', revision: 1, authorized: true, treeDigest: 'tree', decompositionDigest: 'd', tasks: ['task-1'], exclusions: [{ reason: 'out of scope' }], layers: layers.map(({ prNumber, integratedCommit }) => ({ prNumber, integratedCommit })) };
  const finalize = (overrides = {}) => evaluateFinalization({ stack, layers, manifest, finalization, ancestry: [...mergedAncestry, ...['1', '2'].map(c => ({ ancestor: sha(c), descendant: sha('9') }))], protections, ...overrides });
  assert.deepEqual([finalize().reasons, finalize({ protections: {} }).state, finalize({ finalization: { ...finalization, sizeLabel: 'XXL' } }).state, finalize({ ancestry: [ancestry[0], ...['1', '2'].map(c => ({ ancestor: sha(c), descendant: sha('9') }))] }).state], [[], 'failure', 'failure', 'failure']);
  const off = layers.map(entry => ({ ...entry, integratedCommit: sha(String(entry.prNumber)) })), offManifest = { ...manifest, layers: off.map(({ prNumber, integratedCommit }) => ({ prNumber, integratedCommit })) }; assert.match(finalize({ layers: off, manifest: offManifest }).reasons.join(' '), /recorded integration tip of this stack or its terminal integrated layer/);
  for (const bad of [{ layers: manifest.layers.slice(0, 2) }, { revision: 2 }, { layers: [...manifest.layers.slice(0, 2), { prNumber: 3, integratedCommit: sha('f') }] }, { layers: 'x' }, { layers: [null, ...manifest.layers] },
    { tasks: [] }, { tasks: ['task-2'] }, { tasks: ['task-1', 'task-1'] }, { tasks: ['task-1', 'task-2'] }, { exclusions: [{}] }, { decompositionDigest: 'old' }]) {
    assert.equal(finalize({ manifest: { ...manifest, ...bad } }).state, 'failure');
  }
  for (const bad of [{ head: { ...finalization.head, repository: 'fork/repo' } }, { head: { ...finalization.head, sha: sha('e') } }, { base: { ...finalization.base, ref: 'release' }, protectedRef: 'release' }]) assert.equal(finalize({ finalization: { ...finalization, ...bad } }).state, 'failure');
  assert.equal(evaluateFinalization({ stack, layers: threeLayers(), manifest, finalization }).state, 'failure');
  assert.match(evaluateFinalization({ stack, layers: [], manifest: { ...manifest, layers: [] }, finalization }).reasons.join(' '), /inventory is empty/);
  const anonymous = { ...stack, repositoryId: undefined, repository: undefined };
  assert.equal(evaluateFinalization({ stack: anonymous, layers, manifest: { ...manifest, repositoryId: undefined }, finalization: { ...finalization, repositoryId: undefined, head: { ...finalization.head, repository: undefined } } }).state, 'failure');
});

test('duplicate events after a crash read actual state and never repeat ambiguous effects', () => {
  const current = { stack, prNumber: 1, headSha: sha('a'), baseSha: sha('0'), targetTip: sha('1'), policyRevision: 'p' };
  const intent = { operationKey: stackOperationKey(current) };
  assert.deepEqual([current, { ...current, targetTip: sha('2') }].map(seen => reconcileLayerOperation({ intent, observed: { applied: true, ...seen }, current }).action), ['already-applied', 'paused']);
  assert.deepEqual([0, 3].map(attempts => reconcileLayerOperation({ intent, observed: {}, current, attempts }).action), ['inspect', 'paused']);
  assert.deepEqual([current, { ...current, headSha: sha('e') }].map(seen => reconcileLayerOperation({ intent, observed: { known: true, ...seen }, current }).action), ['retry', 'paused']);
  assert.equal(reconcileLayerOperation({ intent: null, observed: { applied: true }, current }).action, 'paused');
  assert.equal(reconcileLayerOperation({ intent, observed: { applied: true }, current: { ...current, stack: { ...stack, revision: 2 } } }).action, 'paused');
  for (const bad of [{ targetTip: sha('2') }, { policyRevision: undefined }, { targetTip: undefined }, { stack: { ...stack, repositoryId: undefined } }]) {
    assert.notEqual(stackOperationKey({ ...current, ...bad }), intent.operationKey);
  }
  assert.equal(stackOperationKey({ ...current, policyRevision: undefined }), null);
});
