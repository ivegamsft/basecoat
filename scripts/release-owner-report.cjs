'use strict';

// Report-only release-window derivation (#3594 rollout step 1). Pure: it
// consumes a pre-collected inventory and never writes refs, tags, or releases.

const { createHash } = require('node:crypto');
const fs = require('node:fs');
const { createWindowKey } = require('./release-owner-state.cjs');

const SHA40 = /^[0-9a-f]{40}$/;
const SHA64 = /^[0-9a-f]{64}$/;
const SEMVER_TAG = /^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
const UTC_ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/;
const POSITIVE = /^[1-9]\d*$/;
const LOGIN = /^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$/;
// Any invalid stored receipt excludes the PR; fixed precedence keeps the reason order-independent.
const RECEIPT_FAILURE_PRECEDENCE = Object.freeze([
  'receipt-digest-mismatch', 'receipt-malformed', 'receipt-pr-mismatch'
]);

const RECEIPT_FIELDS = Object.freeze([
  ['delivery-receipt', value => value === 'v1'],
  ['issue', isSafeId],
  ['comment', value => POSITIVE.test(value)],
  ['comment-created', isUtc],
  ['comment-updated', isUtc],
  ['body-sha256', value => isSha64(value)],
  ['body-edited', value => value === 'none' || isUtc(value)],
  ['comment-sha256', value => isSha64(value)],
  ['approver', value => LOGIN.test(value)],
  ['permission', value => ['write', 'maintain', 'admin'].includes(value)],
  ['auth-run', value => POSITIVE.test(value)],
  ['auth-cutoff', isUtc],
  ['spec-blob', value => isSha40(value)],
  ['pr', isSafeId],
  ['head', value => isSha40(value)],
  ['size', value => ['XS', 'S', 'M', 'L', 'XL', 'XXL'].includes(value)],
  ['xxl-review', value => value === 'none' || POSITIVE.test(value)],
  ['release', value => value === 'eligible' || value === 'excluded']
]);

function isSha40(value) {
  return typeof value === 'string' && SHA40.test(value);
}

function isSha64(value) {
  return typeof value === 'string' && SHA64.test(value);
}

function isSafeId(value) {
  return POSITIVE.test(value) && Number.isSafeInteger(Number(value));
}

function isUtc(value) {
  if (!UTC_ISO.test(value)) return false;
  const parsed = new Date(value);
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 19) === value.slice(0, 19);
}

function receiptDigest(text) {
  return createHash('sha256').update(text, 'utf8').digest('hex');
}

function parseReceipt(text) {
  if (typeof text !== 'string') throw new Error('Receipt must be a string.');
  const parts = text.split(';');
  if (parts.length !== RECEIPT_FIELDS.length) throw new Error('Receipt has the wrong field count.');
  const fields = {};
  RECEIPT_FIELDS.forEach(([name, valid], index) => {
    const separator = parts[index].indexOf(':');
    const key = separator < 0 ? parts[index] : parts[index].slice(0, separator);
    const value = separator < 0 ? '' : parts[index].slice(separator + 1);
    if (key !== name || !valid(value)) throw new Error(`Receipt field ${name} is invalid.`);
    fields[name] = value;
  });
  if (fields.size !== 'XXL' && fields['xxl-review'] !== 'none') {
    throw new Error('Receipt records an XXL review for a non-XXL change.');
  }
  if (fields.size === 'XXL' && fields.release === 'eligible' && fields['xxl-review'] === 'none') {
    throw new Error('Eligible XXL receipt lacks a qualified review.');
  }
  const created = Date.parse(fields['comment-created']);
  const approval = Date.parse(fields['comment-updated']);
  if (approval < created || approval >= Date.parse(fields['auth-cutoff']) ||
      (fields['body-edited'] !== 'none' && Date.parse(fields['body-edited']) > approval)) {
    throw new Error('Receipt timestamps are chronologically inconsistent.');
  }
  return fields;
}

function compareVersion(left, right) {
  for (let index = 0; index < 3; index += 1) {
    if (left[index] !== right[index]) return left[index] < right[index] ? -1 : 1;
  }
  return 0;
}

function selectBaseline(tags) {
  if (!Array.isArray(tags)) throw new Error('Tag inventory is required.');
  let best = null;
  for (const tag of tags) {
    const match = tag && tag.verified === true && typeof tag.sha === 'string' &&
      isSha40(tag.sha) ? SEMVER_TAG.exec(tag.name) : null;
    if (!match) continue;
    const version = match.slice(1).map(BigInt);
    if (!best || compareVersion(version, best.version) > 0) best = { name: tag.name, sha: tag.sha, version };
  }
  return best && { name: best.name, sha: best.sha };
}

function evaluateReceipts(pullRequest, entries) {
  const valid = [];
  const failures = new Set();
  for (const entry of entries || []) {
    if (!entry || typeof entry.text !== 'string' || receiptDigest(entry.text) !== entry.digest) {
      failures.add('receipt-digest-mismatch');
      continue;
    }
    let fields;
    try {
      fields = parseReceipt(entry.text);
    } catch {
      failures.add('receipt-malformed');
      continue;
    }
    if (Number(fields.pr) !== pullRequest.number) {
      failures.add('receipt-pr-mismatch');
      continue;
    }
    valid.push({ fields, digest: entry.digest, cutoff: Date.parse(fields['auth-cutoff']) });
  }
  const failure = RECEIPT_FAILURE_PRECEDENCE.find(code => failures.has(code));
  if (failure) return { disposition: `excluded:${failure}` };
  if (valid.length === 0) return { disposition: 'excluded:missing-receipt' };
  const forHead = valid.filter(item => item.fields.head === pullRequest.headSha);
  if (forHead.length === 0) return { disposition: 'excluded:head-mismatch' };
  const latest = Math.max(...forHead.map(item => item.cutoff));
  const current = forHead.filter(item => item.cutoff === latest);
  if (new Set(current.map(item => item.digest)).size > 1) {
    return { disposition: 'excluded:ambiguous-receipt' };
  }
  const { fields, digest } = current[0];
  const authorization = { issue: Number(fields.issue), commentId: fields.comment, receiptDigest: digest };
  if (fields.release !== 'eligible') return { disposition: 'excluded:release-opt-out', authorization };
  return { disposition: 'included', authorization };
}

function blocked(reasons) {
  return { mode: 'report-only', liveRevalidation: 'not-evaluated', state: 'BLOCKED', reasons };
}

function deriveWindowReport(input) {
  const {
    repositoryId, tags, candidateSha, candidateTreeSha, baselineIsAncestor,
    inventoryComplete, pullRequests, reachableMergeShas, receipts = {}
  } = input || {};
  if (!Number.isSafeInteger(repositoryId) || repositoryId < 1 ||
      !isSha40(candidateSha) || !isSha40(candidateTreeSha)) {
    return blocked(['invalid-candidate']);
  }
  if (!Array.isArray(tags) || !tags.every(tag => tag && typeof tag.name === 'string' &&
      typeof tag.verified === 'boolean' && isSha40(tag.sha))) {
    return blocked(['invalid-tag-inventory']);
  }
  if (new Set(tags.map(tag => tag.name)).size !== tags.length) return blocked(['ambiguous-tag-inventory']);
  const baseline = selectBaseline(tags);
  if (!baseline) return blocked(['no-verified-baseline']);
  if (baselineIsAncestor !== true) return blocked(['baseline-not-ancestor']);
  if (inventoryComplete !== true) return blocked(['incomplete-inventory']);
  if (!Array.isArray(pullRequests) || !Array.isArray(reachableMergeShas) ||
      !reachableMergeShas.every(value => isSha40(value)) ||
      new Set(reachableMergeShas).size !== reachableMergeShas.length) {
    return blocked(['incomplete-inventory']);
  }
  if (!receipts || typeof receipts !== 'object' || Array.isArray(receipts) ||
      !Object.values(receipts).every(Array.isArray)) {
    return blocked(['invalid-receipt-inventory']);
  }

  const numbers = new Set();
  for (const pr of pullRequests) {
    if (!pr || !Number.isSafeInteger(pr.number) || pr.number < 1 || numbers.has(pr.number) ||
        !isSha40(pr.mergeSha) || !isSha40(pr.headSha)) {
      return blocked(['invalid-pull-request-inventory']);
    }
    numbers.add(pr.number);
  }
  const apiShas = new Set(pullRequests.map(pr => pr.mergeSha));
  if (apiShas.size !== pullRequests.length) return blocked(['invalid-pull-request-inventory']);
  const gitShas = new Set(reachableMergeShas);
  const missingFromGit = [...apiShas].filter(value => !gitShas.has(value)).sort();
  const missingFromApi = [...gitShas].filter(value => !apiShas.has(value)).sort();
  if (missingFromGit.length || missingFromApi.length) {
    return { ...blocked(['inventory-mismatch']), missingFromGit, missingFromApi };
  }

  const dispositions = [...pullRequests].sort((a, b) => a.number - b.number).map(pr => {
    const entries = Object.prototype.hasOwnProperty.call(receipts, String(pr.number))
      ? receipts[String(pr.number)] : [];
    return { number: pr.number, mergeSha: pr.mergeSha, ...evaluateReceipts(pr, entries) };
  });
  const included = dispositions.some(item => item.disposition === 'included');
  const authorizations = dispositions.filter(item => item.authorization).map(item => item.authorization);
  const ambiguous = dispositions.some(item => item.disposition === 'excluded:ambiguous-receipt');
  const report = {
    mode: 'report-only',
    liveRevalidation: 'not-evaluated',
    state: ambiguous ? 'BLOCKED' : included ? 'CANDIDATE' : 'NO_RELEASE',
    ...(ambiguous ? { reasons: ['ambiguous-authorization'] } : {}),
    baseline,
    candidateSha,
    candidateTreeSha,
    authorizations,
    pullRequests: dispositions.map(({ number, mergeSha, disposition }) => ({ number, mergeSha, disposition }))
  };
  if (report.state === 'CANDIDATE') {
    report.windowKey = createWindowKey({
      repositoryId, baselineTag: baseline.name, baselineSha: baseline.sha, candidateSha,
      candidateTreeSha, authorizations, pullRequests: report.pullRequests, generation: 1
    });
  }
  return report;
}

const RECEIPT_FIELD_NAMES = Object.freeze(RECEIPT_FIELDS.map(([name]) => name));

module.exports = {
  RECEIPT_FIELD_NAMES, deriveWindowReport, parseReceipt, receiptDigest, selectBaseline
};

if (require.main === module) {
  const [inputPath] = process.argv.slice(2);
  if (!inputPath) {
    console.error('Usage: node scripts/release-owner-report.cjs <inventory.json>');
    process.exit(2);
  }
  const report = deriveWindowReport(JSON.parse(fs.readFileSync(inputPath, 'utf8')));
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}
