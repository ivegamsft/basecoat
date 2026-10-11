'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  loadDefinition,
  renderRulesets,
  validateDefinition
} = require('../scripts/release-owner-rulesets.cjs');

const committed = () => loadDefinition();
const provisioned = () => {
  const definition = committed();
  definition.writers['release-owner'].app_id = 101;
  definition.writers['merge-eligibility'].app_id = 102;
  definition.writers.publisher.app_id = 103;
  return definition;
};
const find = (definition, name) => definition.rulesets.find(item => item.name === name);

test('the committed definition is valid and still unprovisioned', () => {
  assert.equal(validateDefinition(committed()).rulesets.length, 8);
  assert.throws(() => renderRulesets(committed()), /not provisioned: release-owner, merge-eligibility, publisher/);
});

test('renders each writer as the sole bypass actor and history rulesets with none', () => {
  const rendered = renderRulesets(provisioned());
  const byName = Object.fromEntries(rendered.map(item => [item.name, item]));
  assert.deepEqual(byName['release-state-writer-admission'].bypass_actors,
    [{ actor_id: 101, actor_type: 'Integration', bypass_mode: 'always' }]);
  assert.equal(byName['release-receipts-writer-admission'].bypass_actors[0].actor_id, 102);
  assert.equal(byName['release-publication-writer-admission'].bypass_actors[0].actor_id, 103);
  assert.equal(byName['release-mirror-creation-admission'].bypass_actors[0].actor_id, 103);
  for (const ruleset of rendered.filter(item => !item.name.endsWith('admission'))) {
    assert.deepEqual(ruleset.bypass_actors, [], ruleset.name);
    assert.ok(ruleset.rules.some(rule => rule.type === 'deletion'), ruleset.name);
    assert.ok(ruleset.rules.some(rule => rule.type === 'non_fast_forward'), ruleset.name);
  }
  assert.deepEqual(byName['release-mirror-immutable'].rules.map(rule => rule.type),
    ['update', 'non_fast_forward', 'deletion']);
  assert.ok(rendered.every(item => item.enforcement === 'active' && item.target === 'branch'));
});

test('rejects definitions that weaken single-writer or history protection', () => {
  const mutations = [
    [d => { find(d, 'release-state-writer-admission').writer = 'publisher'; }, /admit only release-owner/],
    [d => { find(d, 'release-state-writer-admission').rules.push('deletion'); }, /bypass history/],
    [d => { find(d, 'release-receipts-immutable-history').rules = ['deletion']; }, /must enforce/],
    [d => { find(d, 'release-mirror-immutable').rules = ['non_fast_forward', 'deletion']; }, /must enforce update/],
    [d => { d.rulesets = d.rulesets.filter(item => item.name !== 'release-publication-immutable-history'); },
      /exactly one writer-admission and one no-bypass/],
    [d => { d.rulesets.push({ ...find(d, 'release-state-immutable-history'), name: 'extra' }); },
      /exactly one writer-admission and one no-bypass/],
    [d => { find(d, 'release-state-writer-admission').writer = 'github-token'; }, /unknown writer/],
    [d => { d.writers.extra = { app_id: null }; }, /Writers must be exactly/],
    [d => { find(d, 'release-state-immutable-history').ref = 'refs/heads/main'; }, /must cover exactly/],
    [d => { d.writers.publisher = null; }, /Writer publisher must have/],
    [d => {
      d.writers['release-owner'].app_id = 101;
      d.writers.publisher.app_id = 101;
    },
      /Provisioned writer App IDs must be distinct/]
  ];
  for (const [mutate, expected] of mutations) {
    const definition = committed();
    mutate(definition);
    assert.throws(() => validateDefinition(definition), expected);
  }
});

test('refuses to render with a partially provisioned or invalid App ID', () => {
  const partial = provisioned();
  partial.writers.publisher.app_id = null;
  assert.throws(() => renderRulesets(partial), /not provisioned: publisher/);
  for (const appId of [0, -1, '101', 1.5]) {
    const definition = provisioned();
    definition.writers.publisher.app_id = appId;
    assert.throws(() => renderRulesets(definition), /Writer publisher must have/);
  }
});
