'use strict';

// Validates and renders the #3594 layered release-branch rulesets into GitHub
// ruleset API bodies. Rendering fails closed until every writer App exists.

const fs = require('node:fs');
const path = require('node:path');

const DEFINITION_PATH = path.join(__dirname, '..', '.github', 'governance', 'rulesets',
  'release-owner-rulesets.json');
const WRITERS = Object.freeze(['release-owner', 'merge-eligibility', 'publisher']);
const STATE_BRANCHES = Object.freeze({
  'refs/heads/release-state': 'release-owner',
  'refs/heads/release-receipts': 'merge-eligibility',
  'refs/heads/release-publication': 'publisher'
});
const MIRROR_REF = 'refs/heads/release-mirror/*';
const ADMISSION_RULES = new Set(['creation', 'update']);
const HISTORY_RULES = new Set(['non_fast_forward', 'deletion']);
const KNOWN_RULES = new Set([...ADMISSION_RULES, ...HISTORY_RULES]);

function sameSet(values, expected) {
  return values.length === expected.length && expected.every(value => values.includes(value));
}

function validateDefinition(definition) {
  if (!definition || typeof definition !== 'object' || !Array.isArray(definition.rulesets)) {
    throw new Error('Ruleset definition must contain a rulesets array.');
  }
  const writers = definition.writers || {};
  if (!sameSet(Object.keys(writers), WRITERS)) {
    throw new Error(`Writers must be exactly: ${WRITERS.join(', ')}.`);
  }
  for (const name of WRITERS) {
    const writer = writers[name];
    if (!writer || typeof writer !== 'object' || Array.isArray(writer) ||
        !(writer.app_id === null || (Number.isSafeInteger(writer.app_id) && writer.app_id > 0))) {
      throw new Error(`Writer ${name} must have an unprovisioned or positive safe-integer app_id.`);
    }
  }
  const provisionedIds = WRITERS.map(name => writers[name].app_id).filter(Number.isSafeInteger);
  if (new Set(provisionedIds).size !== provisionedIds.length) {
    throw new Error('Provisioned writer App IDs must be distinct.');
  }
  const names = new Set();
  const byRef = new Map();
  for (const ruleset of definition.rulesets) {
    if (!ruleset || typeof ruleset.name !== 'string' || names.has(ruleset.name)) {
      throw new Error('Each ruleset needs a unique name.');
    }
    names.add(ruleset.name);
    if (!Array.isArray(ruleset.rules) || ruleset.rules.length === 0 ||
        !ruleset.rules.every(rule => KNOWN_RULES.has(rule)) ||
        new Set(ruleset.rules).size !== ruleset.rules.length) {
      throw new Error(`Ruleset ${ruleset.name} has invalid rules.`);
    }
    if (ruleset.writer !== null && !WRITERS.includes(ruleset.writer)) {
      throw new Error(`Ruleset ${ruleset.name} names an unknown writer.`);
    }
    if (ruleset.writer !== null && ruleset.rules.some(rule => HISTORY_RULES.has(rule))) {
      throw new Error(`Ruleset ${ruleset.name} lets a writer bypass history protection.`);
    }
    if (!byRef.has(ruleset.ref)) byRef.set(ruleset.ref, []);
    byRef.get(ruleset.ref).push(ruleset);
  }
  const expectedRefs = [...Object.keys(STATE_BRANCHES), MIRROR_REF];
  if (!sameSet([...byRef.keys()], expectedRefs)) {
    throw new Error(`Rulesets must cover exactly: ${expectedRefs.join(', ')}.`);
  }
  for (const [ref, writer] of Object.entries(STATE_BRANCHES)) {
    requireLayers(ref, byRef.get(ref), writer, ['creation', 'update'], ['non_fast_forward', 'deletion']);
  }
  requireLayers(MIRROR_REF, byRef.get(MIRROR_REF), 'publisher', ['creation'],
    ['update', 'non_fast_forward', 'deletion']);
  return definition;
}

function requireLayers(ref, rulesets, writer, admission, history) {
  const admitting = rulesets.filter(item => item.writer !== null);
  const locked = rulesets.filter(item => item.writer === null);
  if (rulesets.length !== 2 || admitting.length !== 1 || locked.length !== 1) {
    throw new Error(`${ref} needs exactly one writer-admission and one no-bypass ruleset.`);
  }
  if (admitting[0].writer !== writer || !sameSet(admitting[0].rules, admission)) {
    throw new Error(`${ref} admission must admit only ${writer} for ${admission.join(', ')}.`);
  }
  if (!sameSet(locked[0].rules, history)) {
    throw new Error(`${ref} no-bypass ruleset must enforce ${history.join(', ')}.`);
  }
}

function renderRulesets(definition) {
  validateDefinition(definition);
  const missing = WRITERS.filter(name => definition.writers[name].app_id === null);
  if (missing.length) {
    throw new Error(`Writer Apps are not provisioned: ${missing.join(', ')}. Refusing to render rulesets.`);
  }
  return definition.rulesets.map(ruleset => ({
    name: ruleset.name,
    target: 'branch',
    enforcement: 'active',
    conditions: { ref_name: { include: [ruleset.ref], exclude: [] } },
    rules: ruleset.rules.map(type => ({ type })),
    bypass_actors: ruleset.writer === null ? [] : [{
      actor_id: definition.writers[ruleset.writer].app_id,
      actor_type: 'Integration',
      bypass_mode: 'always'
    }]
  }));
}

function loadDefinition(file = DEFINITION_PATH) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

module.exports = { DEFINITION_PATH, loadDefinition, renderRulesets, validateDefinition };

if (require.main === module) {
  try {
    const fileArg = process.argv.slice(2).find(arg => !arg.startsWith('--'));
    const definition = validateDefinition(loadDefinition(fileArg));
    if (process.argv.includes('--render')) {
      process.stdout.write(`${JSON.stringify(renderRulesets(definition), null, 2)}\n`);
    } else {
      process.stdout.write(`Release-owner rulesets valid: ${definition.rulesets.length} rulesets.\n`);
    }
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}
