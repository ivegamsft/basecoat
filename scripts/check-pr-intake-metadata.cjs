'use strict';

const fs = require('node:fs');
const { parseScope } = require('../.github/base-coat/scripts/pr-decomposition-evaluator.cjs');

const FIELD_FORMATS = {
  'Change scope': { format: 'Change scope: individual   (or: batch)', sample: 'individual' },
  'Source issues': { format: 'Source issues: #3782   (comma-separated issue numbers, e.g. #12, #34)', sample: '#1' },
  'Independently deliverable units': {
    format: 'Independently deliverable units: 1   (plain integer >= 1; 1 for individual, 2+ for batch)',
    sample: '1'
  },
  'Unit inventory': {
    format: 'Unit inventory: <unit name>; <unit name>   (one meaningful name per deliverable unit, separated by ";")',
    sample: 'unit'
  },
  'Expected files': {
    format: 'Expected files: 7   (plain integer changed-file count; no "~", ranges, or text)',
    sample: '0'
  },
  'Expected changed lines (additions + deletions)': {
    format: 'Expected changed lines (additions + deletions): 224   (plain integer; no "~", ranges, or text)',
    sample: '0'
  },
  'Classification rationale': {
    format: 'Classification rationale: <why this is one cohesive change or a batch>',
    sample: 'diagnostic rationale'
  }
};

const MAX_DIAGNOSTIC_PASSES = Object.keys(FIELD_FORMATS).length + 2;

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function fieldNamedIn(message) {
  return Object.keys(FIELD_FORMATS).find(label => message.includes(`'${label}'`)) || '';
}

const RELATIONAL_FIELDS = new Set(['Change scope', 'Independently deliverable units', 'Unit inventory']);

function fieldValue(body, label) {
  const match = body.match(new RegExp(`^${escapeRegExp(label)}:[ \\t]*([^\\r\\n]*?)[ \\t]*$`, 'im'));
  return match ? match[1] : '';
}

const MAX_DIAGNOSTIC_UNITS = 100;

// Repairs preserve the scope/unit-count/inventory relationships so a substitution
// never causes a different field to be blamed.
function repairField(field, body) {
  const scope = fieldValue(body, 'Change scope').toLowerCase();
  const unitsText = fieldValue(body, 'Independently deliverable units');
  const units = /^[1-9]\d*$/.test(unitsText) ? Number(unitsText) : 0;
  const inventory = fieldValue(body, 'Unit inventory').split(';').filter(value => value.trim()).length;
  if (field === 'Change scope') {
    return setField(body, field, Math.max(units, inventory) > 1 ? 'batch' : 'individual');
  }
  if (field === 'Independently deliverable units') {
    if (scope === 'individual') return setField(body, field, '1');
    return setField(body, field, String(Math.max(scope === 'batch' ? 2 : 1, inventory)));
  }
  if (field === 'Unit inventory') {
    // Cap the temporary inventory and keep the unit count consistent with it.
    const count = Math.min(units || (scope === 'batch' ? 2 : 1), MAX_DIAGNOSTIC_UNITS);
    const repaired = count === units ? body : setField(body, 'Independently deliverable units', String(count));
    return setField(
      repaired,
      field,
      Array.from({ length: count }, (_, index) => `unit ${index + 1}`).join('; ')
    );
  }
  return setField(body, field, FIELD_FORMATS[field].sample);
}

function setField(body, label, value) {
  const pattern = new RegExp(`^(${escapeRegExp(label)}:)[^\\r\\n]*$`, 'gim');
  if (pattern.test(body)) return body.replace(pattern, `$1 ${value}`);
  return body.replace(/^### Design[ \t]*$/im, heading => `${heading}\n${label}: ${value}`);
}

// Reuses the merge-eligibility parser. Each failing field is temporarily replaced
// with a valid sample so authors see every bad field in one run, not one per push.
function checkBody(body, counts = {}) {
  const errors = [];
  const warnings = [];
  const seen = new Set();
  let candidate = String(body || '');
  let parsed = null;
  let normalizedRelations = false;
  for (let pass = 0; pass < MAX_DIAGNOSTIC_PASSES; pass += 1) {
    try {
      parsed = parseScope(candidate);
      break;
    } catch (error) {
      const field = fieldNamedIn(error.message);
      if (!field) {
        if (normalizedRelations) break;
        // Cross-field errors are only trustworthy when no related field was substituted.
        if (![...seen].some(label => RELATIONAL_FIELDS.has(label))) {
          errors.push({ field: '', message: error.message, format: '' });
        }
        normalizedRelations = true;
        candidate = setField(candidate, 'Change scope', 'individual');
        candidate = setField(candidate, 'Independently deliverable units', '1');
        candidate = setField(candidate, 'Unit inventory', 'unit 1');
        continue;
      }
      if (seen.has(field)) break;
      seen.add(field);
      errors.push({ field, message: error.message, format: FIELD_FORMATS[field].format });
      candidate = repairField(field, candidate);
    }
  }
  if (errors.length === 0 && parsed) {
    const { changedFiles, additions, deletions } = counts;
    if (Number.isSafeInteger(changedFiles) && parsed.expectedFiles !== changedFiles) {
      warnings.push(`'Expected files' is ${parsed.expectedFiles} but the PR changes ${changedFiles} files.`);
    }
    if (Number.isSafeInteger(additions) && Number.isSafeInteger(deletions)) {
      const changedLines = additions + deletions;
      if (parsed.expectedLines !== changedLines) {
        warnings.push(
          `'Expected changed lines (additions + deletions)' is ${parsed.expectedLines} but the PR changes ${changedLines} lines.`
        );
      }
    }
  }
  return { ok: errors.length === 0, errors, warnings, scope: parsed };
}

function readCount(name) {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return undefined;
  return /^\d+$/.test(raw) ? Number(raw) : undefined;
}

function escapeAnnotation(value) {
  return String(value).replace(/%/g, '%25').replace(/\r/g, '%0D').replace(/\n/g, '%0A');
}

function main() {
  const result = checkBody(process.env.PR_BODY || '', {
    changedFiles: readCount('PR_CHANGED_FILES'),
    additions: readCount('PR_ADDITIONS'),
    deletions: readCount('PR_DELETIONS')
  });
  const lines = [];
  for (const error of result.errors) {
    const detail = error.format ? `${error.message} Expected format: ${error.format}` : error.message;
    process.stdout.write(`::error title=PR intake metadata${error.field ? `: ${escapeAnnotation(error.field)}` : ''}::${escapeAnnotation(detail)}\n`);
    lines.push(`- ${detail}`);
  }
  for (const warning of result.warnings) {
    process.stdout.write(`::warning title=PR intake metadata counts::${escapeAnnotation(warning)}\n`);
    lines.push(`- Warning: ${warning}`);
  }
  if (result.ok) {
    process.stdout.write(`PR intake metadata is valid (scope ${result.scope.scope}).\n`);
  } else {
    process.stdout.write(
      'Fix the Intake Contract > Design fields in the PR body (see .github/PULL_REQUEST_TEMPLATE.md); ' +
      'editing the body re-runs this check.\n'
    );
    process.exitCode = 1;
  }
  if (process.env.GITHUB_STEP_SUMMARY && lines.length > 0) {
    fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, `### PR intake metadata\n\n${lines.join('\n')}\n`);
  }
}

if (require.main === module) main();

module.exports = { checkBody, FIELD_FORMATS };
