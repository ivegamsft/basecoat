'use strict';

// Stage 1 shadow scheduler for docs/spec/ordered-delivery-holds.spec.md.
// Pure decision logic: no labels, drafts, queue requests or other writes. Readiness,
// scheduling holds, eligibility and admission stay four independent inputs/outputs.
const { canonicalJson, sha256 } = require('./pr-decomposition-evaluator.cjs');

const MAX_ATTEMPTS_PER_IDENTITY = 3;
const text = value => typeof value === 'string' && value.trim().length > 0;
const isoUtc = value => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$/.test(value) && !Number.isNaN(Date.parse(value))
  && new Date(value).toISOString().slice(0, 19) === value.slice(0, 19); // Reject calendar values Date.parse silently normalizes.
const validHoldRecord = record => Boolean(record) && text(record.owner) && text(record.reason) && Number.isInteger(record.revision) && record.revision > 0
  && isoUtc(record.createdAt) && isoUtc(record.reviewAt);

// Immutable ordering key: oldest primary source created_at (UTC), then issue, then PR.
function itemKey(item) {
  const sources = Array.isArray(item?.sources) ? item.sources : [];
  if (sources.length === 0 || !Number.isInteger(item.prNumber)) return null;
  const parsed = sources.map(source => ({ at: Date.parse(source.createdAt), issue: source.issueNumber }));
  if (sources.some(source => !isoUtc(source.createdAt)) || parsed.some(source => !Number.isInteger(source.issue))) return null;
  parsed.sort((a, b) => a.at - b.at || a.issue - b.issue);
  return { at: parsed[0].at, issue: parsed[0].issue, pr: item.prNumber };
}

const compareKeys = (a, b) => a.at - b.at || a.issue - b.issue || a.pr - b.pr;

// Expiry marks review overdue but never releases a hold; removal needs resume evidence
// on a complete record bound to this exact scope and PR.
const SCOPE_FIELDS = ['repositoryId', 'targetRef', 'id', 'version'];
const present = value => value !== undefined && value !== null && value !== '';
const sameScope = (a, b) => Boolean(a && b) && SCOPE_FIELDS.every(field => present(a[field]) && a[field] === b[field]);

function evaluateHold({ labelPresent, record, scope, prNumber, now = Date.now() }) {
  if (!labelPresent && !record) return { held: false, state: 'none' };
  const valid = validHoldRecord(record) && sameScope(record.scope, scope) && record.pr === prNumber;
  if (!valid) return { held: true, state: labelPresent ? 'invalid-record' : 'unexplained-removal' };
  const resume = record.resumeEvidence;
  if (!labelPresent) {
    if (resume?.authorized === true && resume.revision === record.revision) return { held: false, state: 'released' };
    return { held: true, state: 'unexplained-removal' };
  }
  return { held: true, state: now >= Date.parse(record.reviewAt) ? 'overdue' : 'active' };
}

function findCycle(ids, edges) {
  const visiting = new Set(), done = new Set();
  const visit = id => {
    if (done.has(id)) return false;
    if (visiting.has(id)) return true;
    visiting.add(id);
    const cyclic = edges.filter(edge => edge.dependent === id).some(edge => visit(edge.prerequisite));
    visiting.delete(id);
    done.add(id);
    return cyclic;
  };
  return ids.some(visit);
}

const NEXT_ACTION = {
  'missing or ambiguous primary source': 'record the primary source issue',
  'not ready': 'complete readiness', 'not eligible': 'resolve eligibility blockers', 'delivery hold': 'hold owner reviews or resumes', 'awaiting prerequisite': 'deliver validated prerequisites first'
};

function itemBlockers(item, scope, now) {
  const blockers = [];
  if (!itemKey(item)) blockers.push('missing or ambiguous primary source');
  if (item.ready !== true) blockers.push('not ready');
  if (item.eligible !== true) blockers.push('not eligible');
  if (evaluateHold({ labelPresent: item.holdLabel === true, record: item.hold, scope, prNumber: item.prNumber, now }).held) blockers.push('delivery hold');
  return blockers;
}

// An exception is honored only with verified owner authority, the full scope identity
// and the exact successor it allows to pass the skipped item.
function exceptionFor(exceptions, scope, prNumber) {
  return exceptions.find(entry => entry.skippedPr === prNumber && entry.ownerVerified === true && text(entry.reason)
    && Number.isInteger(entry.successorPr) && entry.repositoryId === scope.repositoryId && entry.targetRef === scope.targetRef
    && entry.scopeId === scope.id && entry.scopeVersion === scope.version);
}
// Select the next admission for one scope. Older blocked/held work stops advancement unless
// a scoped scheduling exception names it for this scope version; the exception never
// bypasses delivery-policy blockers of the successor.
function planAdmission({ scope, items = [], dependencies = [], exceptions = [], writer = {}, untrackedAdmissions = [], deliveredOutsideScope = [], now = Date.now() }) {
  if (!scope?.repositoryId || !scope.targetRef || !scope.id || !Number.isInteger(scope.version)) {
    return { action: 'blocked', reason: 'scope record is incomplete' };
  }
  if (untrackedAdmissions.length > 0) {
    return { action: 'paused', reason: `untracked admission detected: ${untrackedAdmissions.join(', ')}` };
  }
  const orderGuaranteed = writer.controlsAllEntryPaths === true;
  const byId = new Map(items.map(item => [item.prNumber, item]));
  const edges = dependencies.filter(edge => edge.validated === true);
  if (edges.some(edge => !Number.isInteger(edge.dependent) || !Number.isInteger(edge.prerequisite) || typeof edge.reason !== 'string' || !edge.reason.trim() || !Number.isInteger(edge.revision) || edge.revision < 1)) {
    return { action: 'blocked', reason: 'malformed dependency evidence' };
  }
  if (edges.some(edge => !byId.has(edge.dependent) || (!byId.has(edge.prerequisite) && !deliveredOutsideScope.includes(edge.prerequisite)))) {
    return { action: 'blocked', reason: 'dependency references an item outside the scope' };
  }
  if (findCycle([...byId.keys()], edges)) return { action: 'blocked', reason: 'dependency cycle' };
  // Only inventories decide delivery: the scope inventory, or the authoritative delivered-outside-scope inventory.
  const delivered = id => (byId.has(id) ? byId.get(id).delivered === true : deliveredOutsideScope.includes(id));
  const requires = (id, out = new Set()) => { // Transitive validated prerequisites: the only work allowed to pass a dependency-blocked item.
    for (let frontier = [id]; frontier.length > 0;) frontier = edges.filter(edge => frontier.includes(edge.dependent) && !out.has(edge.prerequisite)).map(edge => out.add(edge.prerequisite) && edge.prerequisite); return [...out]; };
  const pending = items.filter(item => item.delivered !== true && item.admitted !== true)
    .sort((a, b) => compareKeys(itemKey(a) || { at: -Infinity, issue: 0, pr: a.prNumber }, itemKey(b) || { at: -Infinity, issue: 0, pr: b.prNumber }));
  const skipped = [], waiting = [], awaiting = [];
  for (const item of pending) {
    const own = itemBlockers(item, scope, now), key = itemKey(item);
    const blockers = own.length > 0 || !edges.some(edge => edge.dependent === item.prNumber && !delivered(edge.prerequisite)) ? own : ['awaiting prerequisite'];
    const report = { prNumber: item.prNumber, blockers, ageMs: key ? now - key.at : null, nextAction: NEXT_ACTION[blockers[0]] };
    if (blockers.length > 0) { // Dependency waits honor the same exact-successor exception; the dependent itself is never admitted.
      const exception = exceptionFor(exceptions, scope, item.prNumber);
      if (exception) skipped.push({ ...report, reason: exception.reason, successorPr: exception.successorPr });
      else if (own.length > 0) waiting.push(report); else awaiting.push({ ...report, requires: requires(item.prNumber) });
      continue;
    }
    const first = waiting[0] || skipped.find(entry => entry.successorPr !== item.prNumber);
    if (first) return { action: 'wait', blockedBy: first.prNumber, waiting: waiting.length ? waiting : [first], orderGuaranteed, skipped };
    if (awaiting.length > 0 && !awaiting[0].requires.includes(item.prNumber)) continue; // Only the oldest dependent's prerequisite path may pass it.
    // The transitive dependency chain is the audit evidence for every older dependent this item displaces.
    const chain = [];
    for (let frontier = [item.prNumber]; frontier.length > 0;) {
      const next = edges.filter(edge => frontier.includes(edge.prerequisite) && !chain.includes(edge));
      chain.push(...next);
      frontier = next.map(edge => edge.dependent);
    }
    const displaces = chain.some(edge => itemKey(byId.get(edge.dependent)) && compareKeys(itemKey(byId.get(edge.dependent)), itemKey(item)) < 0);
    const precedence = displaces ? chain.map(edge => ({ dependent: edge.dependent, prerequisite: edge.prerequisite, reason: edge.reason, revision: edge.revision })) : [];
    return { action: 'admit', prNumber: item.prNumber, headSha: item.headSha, orderGuaranteed, skipped, precedence };
  }
  // Excepted items whose named successor is not admissible still keep the scope waiting.
  const left = [waiting, skipped, awaiting].find(list => list.length > 0) || [];
  if (left.length > 0) return { action: 'wait', blockedBy: left[0].prNumber, waiting: left, orderGuaranteed, skipped };
  return { action: 'idle', orderGuaranteed, skipped };
}

// Returns null for incomplete identities so an unbound intent can never be reconciled.
function admissionOperationKey({ scope, prNumber, headSha, baseSha, decisionRevision } = {}) {
  const sha = value => /^[0-9a-f]{40}$/.test(value || '');
  if (!SCOPE_FIELDS.every(field => present(scope?.[field])) || !Number.isInteger(prNumber)
    || !sha(headSha) || !sha(baseSha) || !Number.isInteger(decisionRevision)) return null;
  return sha256(canonicalJson({
    repositoryId: scope.repositoryId, targetRef: scope.targetRef, scopeId: scope.id,
    scopeVersion: scope.version, prNumber, headSha, baseSha, decisionRevision
  }));
}
// Recovery after duplicate events, timeouts or crashes: inspect observed state first and
// never treat an ambiguous request as failure or as permission to repeat it.
function reconcileAdmission({ intent, observed, current, attempts = 0 }) {
  if (!intent) return observed?.queued === true ? { action: 'paused', reason: 'untracked admission: no recorded intent' } : { action: 'plan' };
  const key = admissionOperationKey(current);
  if (!key || key !== intent.operationKey) return { action: 'paused', reason: 'operation identity changed after decision' };
  if (observed?.queued === true) {
    if (intent.requested !== true) return { action: 'paused', reason: 'untracked admission: no recorded request' };
    return observed.headSha === current.headSha ? { action: 'already-admitted' } : { action: 'paused', reason: 'queued head differs from intent' };
  }
  if (attempts >= MAX_ATTEMPTS_PER_IDENTITY) return { action: 'paused', reason: 'retry budget exhausted' };
  if (intent.requested === true && observed?.known !== true) return { action: 'inspect', reason: 'ambiguous admission result' };
  return { action: 'retry' };
}
module.exports = { MAX_ATTEMPTS_PER_IDENTITY, admissionOperationKey, evaluateHold, itemKey, planAdmission, reconcileAdmission };
