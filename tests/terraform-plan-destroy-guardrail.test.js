const { describe, test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');

const {
  detectProtectedListDrift,
  evaluatePlanDestroys,
  extractDestroys,
  matchProtectedType,
  parseBooleanFlag,
  renderComment,
} = require('../templates/terraform-plan-destroy-guardrail/inspect-terraform-plan-destroys.js');

function buildPolicy(overrides = {}) {
  return {
    version: 1,
    protectedResourceTypeGlobs: ['azuread_*', 'azurerm_role_assignment', 'azurerm_key_vault*'],
    override: { label: 'terraform-destroy-ack' },
    ...overrides,
  };
}

function buildPlan(resourceChanges) {
  return { resource_changes: resourceChanges };
}

describe('inspect-terraform-plan-destroys', () => {
  test('extracts delete and replace actions and ignores creates', () => {
    const destroys = extractDestroys(
      buildPlan([
        {
          address: 'azuread_application.app',
          type: 'azuread_application',
          change: { actions: ['create'] },
        },
        {
          address: 'azuread_application_federated_identity_credential.github',
          type: 'azuread_application_federated_identity_credential',
          change: { actions: ['delete'] },
        },
        {
          address: 'azurerm_role_assignment.reader',
          type: 'azurerm_role_assignment',
          change: { actions: ['delete', 'create'] },
        },
      ])
    );

    assert.equal(destroys.length, 2);
    assert.equal(destroys[0].mode, 'delete');
    assert.equal(destroys[1].mode, 'replace');
  });

  test('matches protected resource type globs', () => {
    const globs = buildPolicy().protectedResourceTypeGlobs;
    assert.equal(matchProtectedType('azuread_application_federated_identity_credential', globs), true);
    assert.equal(matchProtectedType('azurerm_key_vault_secret', globs), true);
    assert.equal(matchProtectedType('azurerm_storage_account', globs), false);
  });

  test('passes when the plan has no deletes', () => {
    const result = evaluatePlanDestroys({
      plan: buildPlan([
        {
          address: 'azurerm_storage_account.data',
          type: 'azurerm_storage_account',
          change: { actions: ['update'] },
        },
      ]),
      policy: buildPolicy(),
      overrideApproved: false,
    });

    assert.equal(result.ok, true);
    assert.equal(result.destroys.length, 0);
    assert.deepEqual(result.violations, []);
  });

  test('fails closed on protected destroy without override', () => {
    const result = evaluatePlanDestroys({
      plan: buildPlan([
        {
          address: 'azuread_application_federated_identity_credential.github',
          type: 'azuread_application_federated_identity_credential',
          change: { actions: ['delete'] },
        },
      ]),
      policy: buildPolicy(),
      overrideApproved: false,
    });

    assert.equal(result.ok, false);
    assert.match(result.violations[0], /azuread_application_federated_identity_credential.github/);
  });

  test('passes with warning when override is approved', () => {
    const result = evaluatePlanDestroys({
      plan: buildPlan([
        {
          address: 'azurerm_role_assignment.reader',
          type: 'azurerm_role_assignment',
          change: { actions: ['delete', 'create'] },
        },
      ]),
      policy: buildPolicy(),
      overrideApproved: true,
    });

    assert.equal(result.ok, true);
    assert.equal(result.warnings.length, 1);
    assert.match(result.warnings[0], /override approved/);
  });

  test('does not fail on unprotected destroys', () => {
    const result = evaluatePlanDestroys({
      plan: buildPlan([
        {
          address: 'azurerm_storage_account.scratch',
          type: 'azurerm_storage_account',
          change: { actions: ['delete'] },
        },
      ]),
      policy: buildPolicy(),
      overrideApproved: false,
    });

    assert.equal(result.ok, true);
    assert.equal(result.destroys.length, 1);
    assert.equal(result.protectedDestroys.length, 0);
  });

  test('uses baseline policy globs so a PR cannot shrink protection', () => {
    const result = evaluatePlanDestroys({
      plan: buildPlan([
        {
          address: 'azuread_application.app',
          type: 'azuread_application',
          change: { actions: ['delete'] },
        },
      ]),
      policy: buildPolicy({ protectedResourceTypeGlobs: ['azurerm_role_assignment'] }),
      baselinePolicy: buildPolicy(),
      overrideApproved: false,
    });

    assert.equal(result.ok, false);
    assert.equal(result.protectedDestroys.length, 1);
  });

  test('detects protected glob list drift', () => {
    const drift = detectProtectedListDrift({
      policy: buildPolicy({ protectedResourceTypeGlobs: ['azurerm_role_assignment'] }),
      baselinePolicy: buildPolicy(),
    });

    assert.ok(drift.some((message) => message.includes('azuread_*')));
    assert.ok(drift.some((message) => message.includes('azurerm_key_vault*')));
  });

  test('renders a comment table for destroys', () => {
    const destroys = [
      {
        address: 'azuread_application.app',
        type: 'azuread_application',
        actions: ['delete'],
        mode: 'delete',
      },
    ];
    const markdown = renderComment({
      destroys,
      protectedDestroys: destroys,
      overrideApproved: false,
    });

    assert.match(markdown, /Terraform plan destroys/);
    assert.match(markdown, /azuread_application.app/);
    assert.match(markdown, /acknowledgement label/);
  });

  test('parses boolean override flag values', () => {
    assert.equal(parseBooleanFlag('true'), true);
    assert.equal(parseBooleanFlag('1'), true);
    assert.equal(parseBooleanFlag('yes'), true);
    assert.equal(parseBooleanFlag('false'), false);
    assert.equal(parseBooleanFlag(undefined), false);
  });

  test('template files exist for sync', () => {
    const root = path.resolve(__dirname, '..');
    const required = [
      'templates/terraform-plan-destroy-guardrail/inspect-terraform-plan-destroys.js',
      'templates/terraform-plan-destroy-guardrail/terraform-plan-destroy-guardrail-policy.example.json',
      'templates/terraform-plan-destroy-guardrail/terraform-plan-destroy-guardrail.yml',
      'templates/terraform-plan-destroy-guardrail/README.md',
      'docs/guides/terraform-plan-destroy-guardrail.md',
    ];
    for (const rel of required) {
      assert.equal(fs.existsSync(path.join(root, rel)), true, rel);
    }
  });
});
