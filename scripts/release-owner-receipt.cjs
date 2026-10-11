'use strict';

// Delivery-receipt emission contract (#3594 Authorization step 2). Pure: it
// builds receipts and plans `appendReceipt` decisions but never writes refs.

const {
  RECEIPT_FIELD_NAMES, parseReceipt, receiptDigest
} = require('./release-owner-report.cjs');
const {
  hasQualifiedPermission, isBotActor
} = require('../.github/base-coat/scripts/ship-it/preapproval-evidence.cjs');

const SIZES = Object.freeze(['XS', 'S', 'M', 'L', 'XL', 'XXL']);
const SHA40 = /^[0-9a-f]{40}$/;
const SHA64 = /^[0-9a-f]{64}$/;

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value) &&
    Object.getPrototypeOf(value) === Object.prototype;
}

function receiptPath(pr, head, digest) {
  return `receipts/${pr}/${head}/${digest}`;
}

// Opt-out scopes are excluded; XXL is eligible only with a qualified review on
// the exact head, otherwise it fails closed as excluded.
function deriveReleaseDisposition({ size, scopeOptsOut, xxlReview } = {}) {
  if (!SIZES.includes(size)) throw new Error('Size must be one of XS, S, M, L, XL, XXL.');
  if (typeof scopeOptsOut !== 'boolean') throw new Error('scopeOptsOut must be a boolean.');
  if (size !== 'XXL') {
    if (xxlReview !== undefined) throw new Error('Only XXL changes may record an XXL review.');
    return { release: scopeOptsOut ? 'excluded' : 'eligible', 'xxl-review': 'none' };
  }
  const review = selectQualifiedXxlReview(xxlReview) || 'none';
  const eligible = !scopeOptsOut && review !== 'none';
  return { release: eligible ? 'eligible' : 'excluded', 'xxl-review': review };
}

// Merge-eligibility review rules, failing closed where the gate is order- or case-dependent:
// logins fold case, latest-time state conflicts throw, unresolved current-head blockers exclude.
function selectQualifiedXxlReview({ reviews, head, prAuthor, permissions } = {}) {
  if (!Array.isArray(reviews) || typeof head !== 'string' || !SHA40.test(head) ||
      typeof prAuthor !== 'string' || !prAuthor || !isPlainObject(permissions)) {
    throw new Error('XXL review evidence requires reviews, head, prAuthor, and permissions.');
  }
  const author = prAuthor.toLowerCase();
  const permissionByLogin = new Map(Object.entries(permissions).map(([name, value]) => [name.toLowerCase(), value]));
  if (permissionByLogin.size !== Object.keys(permissions).length) throw new Error('XXL permissions repeat a login.');
  const latest = new Map();
  for (const review of reviews) {
    const login = review && review.user && typeof review.user.login === 'string' ? review.user.login.toLowerCase() : '';
    if (!login || login === author || isBotActor(review.user)) continue;
    if (!Number.isSafeInteger(review.id) || review.id < 1) throw new Error('XXL review IDs must be positive integers.');
    const stamp = review.submitted_at || review.created_at;
    const time = typeof stamp === 'string' ? new Date(stamp).getTime() : NaN;
    if (!Number.isFinite(time)) throw new Error('XXL review timestamps must be valid dates.');
    const previous = latest.get(login);
    const tied = Boolean(previous) && time === previous.time;
    const conflict = tied && (previous.conflict || review.state !== previous.review.state);
    if (!previous || time > previous.time || (tied && review.id > previous.review.id)) {
      latest.set(login, { review, login, time, conflict });
    } else if (conflict) previous.conflict = true;
  }
  if ([...latest.values()].some(entry => entry.conflict)) throw new Error('XXL review evidence has conflicting same-time reviews.');
  const levels = login => [permissionByLogin.get(login)?.permission, permissionByLogin.get(login)?.role_name];
  const resolved = login => levels(login).some(level => typeof level === 'string' && level !== '');
  const current = [...latest.values()].filter(({ review }) => review.commit_id === head);
  if (current.some(({ review, login }) => review.state === 'CHANGES_REQUESTED' &&
    (!resolved(login) || hasQualifiedPermission(permissionByLogin.get(login))))) return null;
  const qualified = current.filter(({ review, login }) => review.state === 'APPROVED' && hasQualifiedPermission(permissionByLogin.get(login)))
    .map(entry => entry.review).sort((left, right) => right.id - left.id);
  return qualified.length > 0 ? String(qualified[0].id) : null;
}

function buildDeliveryReceipt(fields) {
  if (!isPlainObject(fields)) throw new Error('Receipt fields must be a plain object.');
  const supplied = { 'delivery-receipt': 'v1', ...fields };
  const names = Object.keys(supplied);
  const unknown = names.filter(name => !RECEIPT_FIELD_NAMES.includes(name));
  if (unknown.length > 0) throw new Error(`Unknown receipt field: ${unknown.sort()[0]}.`);
  const missing = RECEIPT_FIELD_NAMES.filter(name => !names.includes(name));
  if (missing.length > 0) throw new Error(`Missing receipt field: ${missing[0]}.`);
  const text = RECEIPT_FIELD_NAMES.map(name => {
    const value = supplied[name];
    if (typeof value !== 'string' && !Number.isSafeInteger(value)) {
      throw new Error(`Receipt field ${name} must be a string or safe integer.`);
    }
    return `${name}:${value}`;
  }).join(';');
  const parsed = parseReceipt(text);
  const digest = receiptDigest(text);
  return { text, digest, path: receiptPath(parsed.pr, parsed.head, digest), fields: parsed };
}

function reject(reason) {
  return { action: 'reject', reason };
}

// `existing` maps paths already stored under receipts/<pr>/<head>/ to their text.
function planReceiptAppend({ text, pr, head, merged, existing } = {}) {
  if (typeof merged !== 'boolean') return reject('invalid-merge-state');
  if (merged) return reject('pr-merged');
  if (!isPlainObject(existing) || !Object.values(existing).every(value => typeof value === 'string')) {
    return reject('invalid-existing-inventory');
  }
  let fields;
  try {
    fields = parseReceipt(text);
  } catch {
    return reject('receipt-malformed');
  }
  if (!Number.isSafeInteger(pr) || String(pr) !== fields.pr) return reject('pr-mismatch');
  if (typeof head !== 'string' || !SHA40.test(head) || head !== fields.head) return reject('head-mismatch');
  const digest = receiptDigest(text);
  const path = receiptPath(fields.pr, fields.head, digest);
  const prefix = receiptPath(fields.pr, fields.head, '');
  const scoped = Object.keys(existing).every(key => key.startsWith(prefix) && SHA64.test(key.slice(prefix.length)));
  if (!scoped) return reject('invalid-existing-inventory');
  if (Object.prototype.hasOwnProperty.call(existing, path)) {
    return existing[path] === text ? { action: 'noop', path, digest } : reject('path-conflict');
  }
  // Every stored entry must still match its digest path before anything is appended.
  if (!Object.entries(existing).every(([key, value]) => receiptDigest(value) === key.slice(prefix.length))) {
    return reject('invalid-existing-inventory');
  }
  return { action: 'create', path, digest, content: text };
}

module.exports = { buildDeliveryReceipt, deriveReleaseDisposition, planReceiptAppend, receiptPath };
