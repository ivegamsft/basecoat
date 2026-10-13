'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { candidateCoverage, evaluateCompletion, receiptMatchesCurrent, retryAllowed } = require('../.github/base-coat/scripts/completion-readiness.cjs');

const sha = char => char.repeat(40), through = '2026-10-05T00:00:00Z';
const complete = (overrides = {}) => ({
  repositoryId: 1, repository: 'org/repo',
  source: { issue: 3669, directiveId: 77, approved: true, permissionCurrent: true, authorityRevision: 1, createdAt: '2026-10-01T00:00:00Z' },
  spec: { path: 'docs/spec/x.spec.md', sha: sha('5'), digest: 'digest' },
  task: { trusted: true, id: 'task-1' },
  pr: { number: 10, headRepository: 'org/repo', headRef: 'feat/x', headSha: sha('a'), baseRef: 'main', baseSha: sha('b'), draft: true, bodyDigest: 'body' },
  generation: 1, policyRevision: 'p1', unresolvedDependencies: [], reconciledAt: through,
  candidates: {
    digest: 'c1', revision: 1, sourceHorizon: '2026-10-01T00:00:00Z', overlapping: [], observedThrough: through,
    collections: [{ name: 'open-prs', pages: 1, terminal: true, observedThrough: through }, { name: 'closed-since-horizon', pages: 1, terminal: true, since: '2026-09-30T00:00:00Z', observedThrough: through },
      { name: 'retained-index', pages: 1, terminal: true, fromInception: true, indexRevision: 'idx-1', observedThrough: through }]
  },
  files: ['a.cjs'], inventory: { complete: true, treeDigest: 'tree' }, scopeAcceptance: { verified: true, digest: 's1', sourceIssue: 3669, specDigest: 'digest', workId: 'task-1', headSha: sha('a') },
  completion: { state: 'completed', headSha: sha('a'), workId: 'task-1', runId: 7, producerAppId: 15368, generation: 1 },
  template: { passed: true, headSha: sha('a'), baseSha: sha('b'), treeDigest: 'tree', bodyDigest: 'body', digest: 't1' },
  decomposition: { passed: true, headSha: sha('a'), baseSha: sha('b'), treeDigest: 'tree', bodyDigest: 'body', digest: 'd1' },
  requiredChecks: [{ context: 'tests', state: 'success', headSha: sha('a'), baseSha: sha('b'), producerAppId: 15368, runId: 1 }],
  trustedValidationProducers: { tests: 15368 }, trustedCompletionProducerAppId: 15368, requiredContexts: ['tests'],
  policy: { humanApprovalRequiredSizes: ['XXL'], minimumQualifiedApprovalsForHumanSize: 1 },
  sizeLabel: 'XL', riskTier: 'high', downstreamReceiptGate: true,
  ...overrides
});
const review = (reviewer, id, qualified = true) => ({ reviewer, id, submittedAt: `2026-10-0${id}T00:00:00Z`, qualified, commitId: sha('a') });

test('authorized complete exact-head work is promoted once and never closes the source', () => {
  const first = evaluateCompletion(complete());
  assert.deepEqual([first.disposition, first.promote, first.closeSource], ['ready', true, false]);
  const duplicate = evaluateCompletion(complete({ pr: { ...complete().pr, draft: false } }));
  assert.deepEqual([duplicate.disposition, duplicate.promote], ['already-ready', false]);
});

test('unrelated green runs or completion for another head stay incomplete', () => {
  for (const bad of [{ headSha: sha('c') }, { workId: 'other' }, { state: 'started' }, { producerAppId: 1 }, { producerAppId: 0 }, { generation: 0 }]) {
    assert.equal(evaluateCompletion(complete({ completion: { ...complete().completion, ...bad }, trustedCompletionProducerAppId: bad.producerAppId === 0 ? 0 : 15368 })).disposition, 'incomplete');
  }
});

test('failed checks, missing intake and failed decomposition keep the draft with reasons', () => {
  assert.deepEqual(evaluateCompletion(complete({ requiredChecks: [{ ...complete().requiredChecks[0], state: 'failure' }] })).reasons, ['tests: failure']);
  assert.equal(evaluateCompletion(complete({ template: { passed: false } })).promote, false);
  assert.equal(evaluateCompletion(complete({ decomposition: undefined })).disposition, 'blocked');
  for (const stale of [{ treeDigest: 'old' }, { headSha: sha('9') }, { bodyDigest: 'old' }, { digest: '' }]) {
    assert.equal(evaluateCompletion(complete({ decomposition: { ...complete().decomposition, ...stale } })).disposition, 'blocked');
  }
  const stale = complete({ requiredChecks: [{ ...complete().requiredChecks[0], baseSha: sha('e') }] });
  assert.match(evaluateCompletion(stale).reasons[0], /not for current head\/base/);
  const producerless = complete({ requiredChecks: [{ ...complete().requiredChecks[0], producerAppId: undefined }] });
  assert.deepEqual(evaluateCompletion(producerless).reasons, ['tests: untrusted producer']);
});

test('forks, revoked directives, unpinned specs and missing identities fail closed', () => {
  assert.equal(evaluateCompletion(complete({ pr: { ...complete().pr, headRepository: 'fork/repo' } })).disposition, 'blocked');
  assert.equal(evaluateCompletion(complete({ source: { ...complete().source, revoked: true } })).disposition, 'blocked');
  assert.equal(evaluateCompletion(complete({ spec: { path: 'docs/spec/x.spec.md' } })).disposition, 'blocked');
  assert.equal(evaluateCompletion(complete({ task: { id: 'task-1' } })).disposition, 'blocked');
  assert.equal(evaluateCompletion(complete({ evidenceError: 'timeout' })).disposition, 'blocked');
  for (const bad of [{ repositoryId: undefined }, { generation: undefined }, { policyRevision: undefined }, { pr: { ...complete().pr, baseSha: undefined } },
    { sizeLabel: undefined }, { sizeLabel: 'XXL', policy: undefined }, { sizeLabel: 'XXL', riskTier: 'unknown', policy: {} }, { policy: { ...complete().policy, requiredApprovalsByRiskTier: { high: 'x' } } }, { policy: { ...complete().policy, requiredApprovalsByRiskTier: { high: -1 } } }, { policy: { ...complete().policy, requiredApprovalsByRiskTier: 1 } }, { policy: { ...complete().policy, humanApprovalRequiredSizes: ['XL '] } }, { task: { trusted: true, id: ' ' } }, { task: { trusted: true, id: -1 } }, { policy: { ...complete().policy, approvalRequiredByRisk: 'yes' } }, { localWork: { id: 'l', verified: true } },
    { repository: undefined, pr: { ...complete().pr, headRepository: undefined } }, { inventory: { complete: false, treeDigest: 'tree' } },
    { requiredChecks: [{ ...complete().requiredChecks[0], runId: undefined }] }, { pr: { ...complete().pr, draft: undefined } }, { candidates: { ...complete().candidates, overlapping: undefined } },
    { requiredContexts: ['tests', 'lint'] }, { requiredContexts: [] }, { approvals: [{ reviewer: 'r1', qualified: true, commitId: sha('a') }] }, { requiredChecks: [complete().requiredChecks[0], complete().requiredChecks[0]] },
    { repositoryId: 0 }, { generation: -1 }, { source: { ...complete().source, issue: -1 } }, { source: { ...complete().source, directiveId: null } }, { source: { ...complete().source, authorityRevision: undefined } }, { requiredChecks: [null] }, { sizeLabel: 'XXL', policy: { humanApprovalRequiredSizes: 'XXL' } },
    { trustedValidationProducers: { tests: 0 }, requiredChecks: [{ ...complete().requiredChecks[0], producerAppId: 0 }] }, { policy: { humanApprovalRequiredSizes: ['XL'], minimumQualifiedApprovalsForHumanSize: -1 } }, { sizeLabel: 'XXL', approvals: [{ ...review('r1', 1), reviewer: '', id: 0 }] }, { scopeAcceptance: undefined }, { scopeAcceptance: { ...complete().scopeAcceptance, headSha: sha('c') } }, { scopeAcceptance: { ...complete().scopeAcceptance, specDigest: 'old' } }]) {
    assert.equal(evaluateCompletion(complete(bad)).disposition, 'blocked');
  }
});

test('zero-file work is no-op or superseded and competition blocks without an owner disposition', () => {
  const sup = { verified: true, prNumber: 11, sourceIssue: 3669, candidatesDigest: 'c1', candidatesRevision: 1 }, overlap = { candidates: { ...complete().candidates, overlapping: [{ number: 11 }] } };
  assert.deepEqual([{}, { supersededBy: sup }, { ...overlap }, { ...overlap, supersededBy: '#11' }, { ...overlap, supersededBy: sup }, { ...overlap, supersededBy: { ...sup, candidatesDigest: 'old' } }, { ...overlap, supersededBy: sup, files: ['a.cjs'] }, { completion: { state: 'failed', headSha: sha('a'), workId: 'task-1' } }].map(extra => evaluateCompletion(complete({ files: [], ...extra })).disposition), ['no-op', 'no-op', 'competition', 'competition', 'superseded', 'competition', 'competition', 'incomplete']);
  const competing = complete({ candidates: { ...complete().candidates, overlapping: [{ number: 11 }] } }); assert.equal(evaluateCompletion(competing).disposition, 'competition');
  const owner = { verified: true, winner: 10, sourceIssue: 3669, candidatesDigest: 'c1', candidatesRevision: 1 }; assert.equal(evaluateCompletion({ ...competing, ownerDisposition: owner }).disposition, 'ready');
  for (const bad of [{ verified: false }, { candidatesRevision: 0 }, { candidatesDigest: 'old' }, { sourceIssue: 1 }]) {
    assert.equal(evaluateCompletion({ ...competing, ownerDisposition: { ...owner, ...bad } }).disposition, 'competition');
  }
});

test('local work requires verified provenance instead of a fabricated agent task', () => {
  assert.equal(evaluateCompletion(complete({ task: undefined, localWork: { id: 'local-1' } })).disposition, 'blocked');
  const local = complete({ task: undefined, localWork: { id: 'local-1', verified: true }, completion: { ...complete().completion, workId: 'local-1' }, scopeAcceptance: { ...complete().scopeAcceptance, workId: 'local-1' } });
  assert.equal(evaluateCompletion(local).disposition, 'ready');
});

test('page bounds, missing collections, horizon or index evidence are unknown and block promotion', () => {
  const base = complete().candidates;
  const withClosed = collection => base.collections.map(entry => entry.name === 'closed-since-horizon' ? { ...entry, ...collection } : entry);
  const variants = [{ pages: 100 }, { pages: 0 }, { pages: -1 }, { terminal: false, cursor: 'p4' }, { inaccessible: true }, { indexGap: true }, { since: '2026-10-02T00:00:00Z' }, { since: 'not-a-date' }, { since: undefined }, { observedThrough: '2026-10-06T00:00:00Z' }]
    .map(collection => ({ ...base, collections: withClosed(collection) }));
  variants.push({ ...base, collections: base.collections.slice(0, 2) }, { ...base, sourceHorizon: undefined }, { ...base, sourceHorizon: '2026-10-02T00:00:00Z' }, { ...base, observedThrough: undefined }, { ...base, observedThrough: '2026-10-04T00:00:00Z', collections: base.collections.map(entry => ({ ...entry, observedThrough: '2026-10-04T00:00:00Z' })) }, { ...base, collections: [null, ...base.collections] }, { ...base, overlapping: [null] }, { ...base, overlapping: [{ number: -1 }] }, { ...base, overlapping: [{ number: 0 }] },
    { ...base, collections: [...base.collections.slice(0, 2), { ...base.collections[2], fromInception: false }] }, { ...base, revision: 0 });
  assert.deepEqual([[undefined, through], ['2026-10-01T00:00:00Z', through], ['2026-10-06T00:00:00Z', through], ['2026-10-01T00:00:00Z', '2026-10-04T00:00:00Z'], ['2026-10-01T00:00:00Z', undefined]].map(([created, now]) => candidateCoverage(base, created, now).complete), [false, true, false, false, false]);
  for (const candidates of variants) {
    assert.equal(candidateCoverage(candidates, '2026-10-01T00:00:00Z', through).complete, false);
    assert.equal(evaluateCompletion(complete({ candidates })).disposition, 'blocked');
  }
});
test('feature-only completion and XXL without qualified review do not cross the boundary', () => {
  const layerTarget = { verified: true, ref: 'feature/lane', stackId: 's1' }, onLayer = extra => evaluateCompletion(complete({ pr: { ...complete().pr, baseRef: 'feature/lane' }, ...extra })).disposition; assert.deepEqual([{ layerTarget }, {}, { layerTarget: { ...layerTarget, ref: 'release/1' } }].map(onLayer), ['complete-feature-only', 'blocked', 'blocked']);
  assert.deepEqual([[], [review('r1', 1)]].map(approvals => evaluateCompletion(complete({ sizeLabel: 'XXL', approvals })).disposition), ['blocked', 'ready']);
  assert.equal(evaluateCompletion(complete({ sizeLabel: 'XXL', approvals: [review('r1', 2, false), review('r1', 1)] })).disposition, 'blocked');
  const twoRequired = { humanApprovalRequiredSizes: [], minimumQualifiedApprovalsForHumanSize: 1, requiredApprovalsByRiskTier: { high: 2 } }, sameReviewer = [review('r1', 1), review('r1', 2)], caseVariant = [review('Alice', 1), review('alice', 2)];
  assert.deepEqual([sameReviewer, caseVariant, [...sameReviewer, review('r2', 3)]].map(approvals => evaluateCompletion(complete({ policy: twoRequired, approvals })).disposition), ['blocked', 'blocked', 'ready']);
  assert.equal(evaluateCompletion(complete({ downstreamReceiptGate: false })).promote, false);
  assert.deepEqual([[], [review('r1', 1)]].map(approvals => evaluateCompletion(complete({ policy: { ...complete().policy, approvalRequiredByRisk: { high: true } }, approvals })).disposition), ['blocked', 'ready']);
});

test('receipts bind exact identity; new pushes, competitors and other work invalidate them', () => {
  const input = complete(), receipt = evaluateCompletion(input), at = Date.parse(through) + 60000;
  assert.deepEqual([input, { ...input, candidates: { ...input.candidates, collections: [...input.candidates.collections].reverse() } }].map(current => receiptMatchesCurrent({ at, receipt, current })), [true, true]);
  for (const changed of [{ pr: { ...input.pr, headSha: sha('d') } }, { candidates: { ...input.candidates, digest: 'c2', revision: 2 } }, { task: { trusted: true, id: 'task-2' } },
    { source: { ...input.source, revoked: true } }, { source: { ...input.source, authorityRevision: 2 } }, { downstreamReceiptGate: false }, { sizeLabel: 'XXL', approvals: [review('r1', 1)] }, { requiredChecks: [{ ...input.requiredChecks[0], runId: 2 }] }, { candidates: { ...input.candidates, collections: input.candidates.collections.map(entry => ({ ...entry, pages: 2 })) } }, { candidates: { ...input.candidates, sourceHorizon: '2026-09-30T00:00:00Z' } }]) {
    assert.equal(receiptMatchesCurrent({ at, receipt, current: complete(changed) }), false);
  }
  assert.equal(receiptMatchesCurrent({ at, receipt: evaluateCompletion(complete({ files: [] })), current: input }), false);
  const now = Date.parse('2026-10-02T00:00:00Z');
  const later = '2026-10-06T00:00:00Z', rescan = complete({ reconciledAt: later, candidates: { ...input.candidates, observedThrough: later, collections: input.candidates.collections.map(entry => ({ ...entry, observedThrough: later })) } }); assert.deepEqual([evaluateCompletion(rescan).operationKey === receipt.operationKey, receiptMatchesCurrent({ at: Date.parse(later), receipt, current: rescan })], [true, false]);
  assert.deepEqual([undefined, at + 3600000, Date.parse(through) - 1].map(clock => receiptMatchesCurrent({ at: clock, receipt, current: input })), [false, false, false]);
  const first = '2026-10-01T01:00:00Z', h = n => new Date(now - n * 3600000).toISOString(); assert.deepEqual([retryAllowed(0), retryAllowed(2, first, now, h(2)), retryAllowed(2, first, now, h(0.5)), retryAllowed(1, first, now, h(0.1)), retryAllowed(1, first, now, h(0.3)), retryAllowed(2, first, now), retryAllowed(2, '2026-10-01T00:00:00Z', now, h(2)), retryAllowed(2), retryAllowed(3)], [true, true, false, false, true, false, false, false, false]);
  assert.equal(retryAllowed(-1) || retryAllowed(1.5) || retryAllowed('x'), false);
});
