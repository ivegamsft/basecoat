import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { validateEnvironmentMap } from '../validator.js';

function createRepoRoot(fileContent?: string): string {
  const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'operation-context-validator-'));

  if (fileContent !== undefined) {
    fs.mkdirSync(path.join(repoRoot, '.github'), { recursive: true });
    fs.writeFileSync(path.join(repoRoot, '.github', 'environment-map.yml'), fileContent, 'utf-8');
  }

  return repoRoot;
}

describe('validateEnvironmentMap', () => {
  it('should fail when environment-map.yml is missing', async () => {
    const result = await validateEnvironmentMap(createRepoRoot());

    expect(result.valid).toBe(false);
    expect(result.errors[0]).toContain('environment-map.yml not found');
  });

  it('should fail when the YAML root is not an object', async () => {
    const result = await validateEnvironmentMap(createRepoRoot('- preview'));

    expect(result.valid).toBe(false);
    expect(result.errors).toContain('Root of environment-map.yml must be a YAML object');
  });

  it('should report environment and rule validation errors', async () => {
    const result = await validateEnvironmentMap(
      createRepoRoot(`
environments:
  dev:
    github_environment: dev
    production: true
rules:
  - name: bad-rule
    match:
      source_branch: feature/*
    context:
      target_environment: missing
      mode: branch_deploy
`.trim())
    );

    expect(result.valid).toBe(false);
    expect(result.errors).toContain('dev: missing required field "azure_subscription"');
    expect(result.errors).toContain('dev: missing required field "resource_group"');
    expect(result.errors).toContain('dev: production flag should only be true for prod environment');
    expect(result.errors).toContain("Rule 0 (bad-rule): target_environment 'missing' not found in environments");
    expect(result.warnings).toContain('dev: no allowed_branch_patterns defined');
  });

  it('should validate a complete environment map', async () => {
    const result = await validateEnvironmentMap(
      createRepoRoot(`
environments:
  preview:
    github_environment: preview
    production: false
    azure_subscription: sub-preview
    resource_group: rg-preview
    allowed_branch_patterns:
      - feature/*
    allowed_actions:
      read_only: [read_logs]
    blocked_actions:
      read_only: [deploy]
  prod:
    github_environment: production
    production: true
    azure_subscription: sub-prod
    resource_group: rg-prod
    allowed_branch_patterns:
      - main
    allowed_actions:
      incident_readonly: [read_logs]
    blocked_actions:
      incident_readonly: [deploy]
rules:
  - name: incident_override
    match:
      user_intent_contains:
        - site is down
    context:
      target_environment: prod
      mode: incident_readonly
`.trim())
    );

    expect(result.valid).toBe(true);
    expect(result.errors).toHaveLength(0);
    expect(result.environments_found).toEqual(['preview', 'prod']);
    expect(result.rules_count).toBe(1);
  });
});
