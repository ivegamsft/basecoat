'use strict';

const { createHash } = require('node:crypto');

const SHA_PATTERN = /^[0-9a-f]{40}$/i;
const MAX_FILES = 15;
const MAX_LINES = 300;

function sha256(value) {
  return createHash('sha256').update(value, 'utf8').digest('hex');
}

function reviewSnapshotDigest(reviews) {
  const snapshot = reviews.map(review => ({
    id: Number(review.id || 0),
    login: String(review.user?.login || ''),
    type: String(review.user?.type || ''),
    state: String(review.state || ''),
    commit_id: String(review.commit_id || ''),
    body: String(review.body || ''),
    submitted_at: String(review.submitted_at || ''),
    created_at: String(review.created_at || '')
  })).sort((left, right) => left.id - right.id);
  return sha256(canonicalJson(snapshot));
}

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value).sort().map(key => [key, canonicalize(value[key])])
    );
  }
  return value;
}

function canonicalJson(value) {
  return JSON.stringify(canonicalize(value));
}

function compareStrings(left, right) {
  return left < right ? -1 : left > right ? 1 : 0;
}

function parseJsonWithoutDuplicateKeys(text) {
  let index = 0;
  const skipWhitespace = () => {
    while (/\s/.test(text[index] || '')) index += 1;
  };
  const parseString = () => {
    const start = index;
    if (text[index] !== '"') throw new Error('expected JSON string');
    index += 1;
    while (index < text.length) {
      if (text[index] === '\\') {
        index += 2;
      } else if (text[index] === '"') {
        index += 1;
        try {
          return JSON.parse(text.slice(start, index));
        } catch {
          throw new Error('Mechanical exception JSON contains an invalid string.');
        }
      } else {
        index += 1;
      }
    }
    throw new Error('unterminated JSON string');
  };
  const parseValue = () => {
    skipWhitespace();
    if (text[index] === '"') {
      parseString();
      return;
    }
    if (text[index] === '{') {
      index += 1;
      skipWhitespace();
      const keys = new Set();
      if (text[index] === '}') {
        index += 1;
        return;
      }
      while (index < text.length) {
        skipWhitespace();
        const key = parseString();
        if (keys.has(key)) throw new Error('Mechanical exception JSON contains a duplicate object key.');
        keys.add(key);
        skipWhitespace();
        if (text[index] !== ':') throw new Error('expected colon after JSON key');
        index += 1;
        parseValue();
        skipWhitespace();
        if (text[index] === '}') {
          index += 1;
          return;
        }
        if (text[index] !== ',') throw new Error('expected comma in JSON object');
        index += 1;
      }
      throw new Error('unterminated JSON object');
    }
    if (text[index] === '[') {
      index += 1;
      skipWhitespace();
      if (text[index] === ']') {
        index += 1;
        return;
      }
      while (index < text.length) {
        parseValue();
        skipWhitespace();
        if (text[index] === ']') {
          index += 1;
          return;
        }
        if (text[index] !== ',') throw new Error('expected comma in JSON array');
        index += 1;
      }
      throw new Error('unterminated JSON array');
    }
    const primitive = text.slice(index).match(/^(?:true|false|null|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)/);
    if (!primitive) throw new Error('invalid JSON value');
    index += primitive[0].length;
  };

  parseValue();
  skipWhitespace();
  if (index !== text.length) throw new Error('unexpected trailing JSON content');
  try {
    return JSON.parse(text);
  } catch {
    throw new Error('Mechanical exception JSON is malformed.');
  }
}

function uniqueField(section, label) {
  const escapedLabel = label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const pattern = new RegExp(`^${escapedLabel}:\\s*(.*?)\\s*$`, 'gim');
  const values = Array.from(section.matchAll(pattern), match => match[1].trim());
  if (values.length !== 1 || !values[0]) {
    throw new Error(`Design section must contain exactly one non-empty '${label}' field.`);
  }
  return values[0];
}

function parseInteger(value, label, minimum = 0) {
  if (!/^(?:0|[1-9]\d*)$/.test(value)) {
    throw new Error(`'${label}' must be a nonnegative integer.`);
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < minimum) {
    throw new Error(`'${label}' is outside the supported integer range.`);
  }
  return parsed;
}

function parseScope(body) {
  const text = String(body || '');
  const headings = Array.from(text.matchAll(/^### Design[ \t]*$/gim));
  if (headings.length !== 1) {
    throw new Error('PR body must contain exactly one Intake Contract Design section.');
  }
  const start = headings[0].index + headings[0][0].length;
  const remainder = text.slice(start).replace(/^\r?\n/, '');
  const nextHeading = remainder.search(/^#{1,3}\s/m);
  const section = (nextHeading < 0 ? remainder : remainder.slice(0, nextHeading))
    .replace(/<!--[\s\S]*?-->/g, '');
  const scope = uniqueField(section, 'Change scope').toLowerCase();
  if (!['individual', 'batch'].includes(scope)) {
    throw new Error("'Change scope' must be 'individual' or 'batch'.");
  }
  const sourceText = uniqueField(section, 'Source issues');
  if (!/^\s*#?\d+(?:\s*,\s*#?\d+)*\s*$/.test(sourceText)) {
    throw new Error("'Source issues' must be a comma-separated list of issue numbers.");
  }
  const sourceIssues = sourceText
    .split(',')
    .map(value => Number(value.trim().replace(/^#/, '')));
  if (
    sourceIssues.some(number => !Number.isSafeInteger(number) || number < 1) ||
    new Set(sourceIssues).size !== sourceIssues.length
  ) {
    throw new Error("'Source issues' must contain unique positive issue numbers.");
  }
  const units = parseInteger(
    uniqueField(section, 'Independently deliverable units'),
    'Independently deliverable units',
    1
  );
  const unitInventory = uniqueField(section, 'Unit inventory');
  const unitsListed = unitInventory.split(';').map(value => value.trim()).filter(Boolean);
  if (unitsListed.length !== units) {
    throw new Error("'Unit inventory' entries must match the independently deliverable unit count.");
  }
  if ((scope === 'individual' && units !== 1) || (scope === 'batch' && units < 2)) {
    throw new Error(`'${scope}' scope contradicts the independently deliverable unit count.`);
  }
  const expectedFiles = parseInteger(uniqueField(section, 'Expected files'), 'Expected files');
  const expectedLines = parseInteger(
    uniqueField(section, 'Expected changed lines (additions + deletions)'),
    'Expected changed lines (additions + deletions)'
  );
  const rationale = uniqueField(section, 'Classification rationale');

  const exceptionHeadings = Array.from(
    section.matchAll(/^Mechanical batch exception evidence:\s*(.*?)\s*$/gim)
  );
  if (exceptionHeadings.length > 1) {
    throw new Error("Design section may contain only one 'Mechanical batch exception evidence' field.");
  }
  let exception = null;
  if (exceptionHeadings.length === 1 && exceptionHeadings[0][1].toLowerCase() !== 'none') {
    const following = section.slice(exceptionHeadings[0].index + exceptionHeadings[0][0].length);
    const blocks = Array.from(following.matchAll(/```json\s*\r?\n([\s\S]*?)\r?\n```/gi));
    if (blocks.length !== 1) {
      throw new Error('A proposed mechanical exception must have exactly one JSON evidence block.');
    }
    exception = parseJsonWithoutDuplicateKeys(blocks[0][1]);
  }

  return {
    scope,
    sourceIssues: sourceIssues.sort((left, right) => left - right),
    units,
    unitInventory: unitsListed,
    expectedFiles,
    expectedLines,
    rationale,
    exception
  };
}

function normalizedFileInventory(files) {
  return files.map(file => ({
    path: String(file?.filename || ''),
    status: String(file?.status || ''),
    previous_path: String(file?.previous_filename || '')
  })).sort((left, right) =>
    compareStrings(left.path, right.path) ||
    compareStrings(left.status, right.status) ||
    compareStrings(left.previous_path, right.previous_path)
  );
}

function hasSensitiveMechanicalPath(files) {
  const protectedPath = /(^|\/)(?:\.github\/(?:base-coat\/)?(?:workflows|actions|governance)|iac|infra|deployment|deploy)(?:\/|$)|(^|\/)[^/]*(?:auth|permission|secret|credential|policy|workflow|governance|deploy|release|provision|infra|iac|environment-protection)[^/]*(?:\/|$)/i;
  return files.some(file =>
    [file.filename, file.previous_filename]
      .filter(Boolean)
      .some(path => protectedPath.test(String(path).replace(/\\/g, '/')))
  );
}

function normalizeException(exception, scope) {
  if (!exception || typeof exception !== 'object' || Array.isArray(exception)) {
    throw new Error('Mechanical exception evidence must be a JSON object.');
  }
  const requiredKeys = [
    'command',
    'tool_version',
    'input_revision',
    'file_inventory',
    'smaller_batches_not_viable',
    'reproduction_diff_evidence',
    'validation_command',
    'validation_result',
    'rollback_procedure',
    'source_issues',
    'head_sha',
    'base_sha'
  ].sort();
  if (Object.keys(exception).sort().join('\0') !== requiredKeys.join('\0')) {
    throw new Error('Mechanical exception evidence has missing or unsupported fields.');
  }
  const stringFields = requiredKeys.filter(key =>
    !['file_inventory', 'source_issues'].includes(key)
  );
  for (const key of stringFields) {
    if (typeof exception[key] !== 'string' || !exception[key].trim()) {
      throw new Error(`Mechanical exception '${key}' must be a non-empty string.`);
    }
  }
  if (
    !SHA_PATTERN.test(exception.input_revision) ||
    !SHA_PATTERN.test(exception.head_sha) ||
    !SHA_PATTERN.test(exception.base_sha)
  ) {
    throw new Error('Mechanical exception revisions must be full 40-character commit SHAs.');
  }
  if (!Array.isArray(exception.source_issues) || !exception.source_issues.every(Number.isSafeInteger)) {
    throw new Error('Mechanical exception source_issues must be an array of issue numbers.');
  }
  if (
    exception.source_issues.length !== scope.sourceIssues.length ||
    [...exception.source_issues].sort((left, right) => left - right).join(',') !== scope.sourceIssues.join(',')
  ) {
    throw new Error('Mechanical exception source issues must match the PR scope metadata.');
  }
  if (
    !Array.isArray(exception.file_inventory) ||
    !exception.file_inventory.every(file =>
      file &&
      typeof file === 'object' &&
      !Array.isArray(file) &&
      Object.keys(file).sort().join(',') === 'path,previous_path,status' &&
      typeof file.path === 'string' &&
      typeof file.status === 'string' &&
      typeof file.previous_path === 'string'
    )
  ) {
    throw new Error('Mechanical exception file_inventory must contain path, status, and previous_path for each file.');
  }
  const fileInventory = exception.file_inventory
    .map(file => ({
      path: file.path.trim(),
      status: file.status.trim(),
      previous_path: file.previous_path.trim()
    }))
    .sort((left, right) =>
      compareStrings(left.path, right.path) ||
      compareStrings(left.status, right.status) ||
      compareStrings(left.previous_path, right.previous_path)
    );
  if (fileInventory.some(file => !file.path || !file.status)) {
    throw new Error('Mechanical exception file_inventory contains an empty path or status.');
  }
  return {
    command: exception.command.trim(),
    tool_version: exception.tool_version.trim(),
    input_revision: exception.input_revision.toLowerCase(),
    file_inventory: fileInventory,
    smaller_batches_not_viable: exception.smaller_batches_not_viable.trim(),
    reproduction_diff_evidence: exception.reproduction_diff_evidence.trim(),
    validation_command: exception.validation_command.trim(),
    validation_result: exception.validation_result.trim(),
    rollback_procedure: exception.rollback_procedure.trim(),
    source_issues: [...exception.source_issues].sort((left, right) => left - right),
    head_sha: exception.head_sha.toLowerCase(),
    base_sha: exception.base_sha.toLowerCase()
  };
}

function latestReviewByUser(reviews, authorLogin) {
  const latest = new Map();
  for (const review of reviews) {
    const login = String(review?.user?.login || '');
    if (
      !login ||
      login.toLowerCase() === String(authorLogin || '').toLowerCase() ||
      review.user?.type === 'Bot' ||
      login.toLowerCase().endsWith('[bot]')
    ) continue;
    const timestamp = new Date(review.submitted_at || review.created_at || 0).getTime();
    const previous = latest.get(login);
    const previousTimestamp = previous
      ? new Date(previous.submitted_at || previous.created_at || 0).getTime()
      : -1;
    if (
      !previous ||
      timestamp > previousTimestamp ||
      (timestamp === previousTimestamp && Number(review.id || 0) > Number(previous.id || 0))
    ) {
      latest.set(login, review);
    }
  }
  return latest;
}

async function findExceptionApproval({
  reviews,
  authorLogin,
  headSha,
  evidenceDigest,
  resolvePermission
}) {
  const expectedLine = `Batch exception: ${headSha.toLowerCase()} ${evidenceDigest}`;
  const candidates = Array.from(latestReviewByUser(reviews, authorLogin).values())
    .filter(review =>
      String(review.state || '').toUpperCase() === 'APPROVED' &&
      String(review.commit_id || '').toLowerCase() === headSha.toLowerCase() &&
      String(review.body || '').split(/\r?\n/).filter(line => line === expectedLine).length === 1
    )
    .sort((left, right) => Number(right.id || 0) - Number(left.id || 0));
  let permissionCheckFailed = false;
  for (const review of candidates) {
    const login = review.user.login;
    let permission;
    try {
      permission = await resolvePermission(login);
    } catch {
      permissionCheckFailed = true;
      continue;
    }
    const levels = [permission?.permission, permission?.role_name]
      .map(level => String(level || '').toLowerCase());
    if (levels.some(level => ['admin', 'maintain', 'write'].includes(level))) {
      return { satisfied: true, reviewId: Number(review.id), reviewer: login };
    }
  }
  return { satisfied: false, reviewId: 0, reviewer: '', permissionCheckFailed };
}

async function evaluateDecomposition({
  body,
  changedFiles,
  additions,
  deletions,
  files,
  headSha,
  baseSha,
  reviews = [],
  authorLogin,
  resolvePermission = async () => null
}) {
  const counts = { changedFiles, additions, deletions };
  const countValues = Object.values(counts);
  if (
    countValues.some(value => !Number.isSafeInteger(value) || value < 0) ||
    !Array.isArray(files) ||
    files.length !== changedFiles ||
    files.some(file => !file || !String(file.filename || '').trim() || !String(file.status || '').trim()) ||
    new Set(files.map(file => String(file.filename))).size !== files.length
  ) {
    return {
      decision: 'block',
      reason: 'Authoritative PR counts or paginated changed-file inventory are missing, invalid, or incomplete.',
      scope: 'unknown',
      counts,
      evidenceDigest: '',
      reviewId: 0,
      reviewPending: false
    };
  }
  let scope;
  try {
    scope = parseScope(body);
  } catch (error) {
    return {
      decision: 'block',
      reason: `PR decomposition metadata is invalid: ${error.message}`,
      scope: 'unknown',
      counts,
      evidenceDigest: '',
      reviewId: 0,
      reviewPending: false
    };
  }
  const changedLines = additions + deletions;
  if (!Number.isSafeInteger(changedLines)) {
    return {
      decision: 'block',
      reason: 'Authoritative additions plus deletions exceed the supported integer range.',
      scope: scope.scope,
      counts: { ...counts, changedLines },
      evidenceDigest: '',
      reviewId: 0,
      reviewPending: false
    };
  }
  const summary = {
    scope: scope.scope,
    counts: { ...counts, changedLines },
    evidenceDigest: '',
    reviewId: 0,
    reviewPending: false
  };
  if (scope.scope === 'individual') {
    if (scope.exception) {
      return {
        ...summary,
        decision: 'block',
        reason: 'Mechanical batch exceptions are valid only for changes classified as a batch.'
      };
    }
    return { ...summary, decision: 'pass', reason: 'Individual feature scope is not subject to the batch size limits.' };
  }
  if (changedFiles <= MAX_FILES && changedLines <= MAX_LINES) {
    return { ...summary, decision: 'pass', reason: 'Batch is within both decomposition limits.' };
  }
  if (!scope.exception) {
    return {
      ...summary,
      decision: 'block',
      reason: `Batch exceeds the limits (${changedFiles}/${MAX_FILES} files; ${changedLines}/${MAX_LINES} changed lines). Split into independently validated PRs.`
    };
  }
  let evidence;
  try {
    evidence = normalizeException(scope.exception, scope);
  } catch (error) {
    return { ...summary, decision: 'block', reason: `Mechanical exception is invalid: ${error.message}` };
  }
  if (hasSensitiveMechanicalPath(files)) {
    return {
      ...summary,
      decision: 'block',
      reason: 'Mechanical exception cannot include workflow, governance, deployment, authentication, permission, secret, or credential changes.'
    };
  }
  if (
    evidence.head_sha !== String(headSha || '').toLowerCase() ||
    evidence.base_sha !== String(baseSha || '').toLowerCase()
  ) {
    return {
      ...summary,
      decision: 'block',
      reason: 'Mechanical exception evidence is bound to a different PR head or base SHA.'
    };
  }
  if (
    evidence.file_inventory.length !== changedFiles ||
    canonicalJson(evidence.file_inventory) !== canonicalJson(normalizedFileInventory(files))
  ) {
    return {
      ...summary,
      decision: 'block',
      reason: 'Mechanical exception inventory does not exactly match the complete GitHub changed-file list.'
    };
  }
  const evidenceDigest = sha256(canonicalJson({
    exception: evidence,
    scope_metadata: {
      scope: scope.scope,
      source_issues: scope.sourceIssues,
      units: scope.units,
      unit_inventory: scope.unitInventory,
      expected_files: scope.expectedFiles,
      expected_lines: scope.expectedLines,
      rationale: scope.rationale
    },
    actual_counts: { changed_files: changedFiles, additions, deletions }
  }));
  const exceptionApproval = await findExceptionApproval({
    reviews,
    authorLogin,
    headSha,
    evidenceDigest,
    resolvePermission
  });
  if (!exceptionApproval.satisfied) {
    return {
      ...summary,
      decision: 'pending',
      reason: exceptionApproval.permissionCheckFailed
        ? 'Mechanical exception reviewer permission could not be verified; API failures deny authorization.'
        : `Mechanical exception requires a current-head qualified human APPROVED review with the exact line: Batch exception: ${String(headSha || '').toLowerCase()} ${evidenceDigest}`,
      evidenceDigest,
      reviewPending: true
    };
  }
  return {
    ...summary,
    decision: 'pass',
    reason: 'Mechanical exception is bound to the complete file inventory and a qualified current-head human review.',
    evidenceDigest,
    reviewId: exceptionApproval.reviewId,
    reviewer: exceptionApproval.reviewer
  };
}

module.exports = {
  MAX_FILES,
  MAX_LINES,
  canonicalJson,
  evaluateDecomposition,
  parseScope,
  reviewSnapshotDigest,
  sha256
};
