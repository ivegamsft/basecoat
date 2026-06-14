import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';
import { EnvironmentMap, ValidationResult, Environment } from './types';

export async function validateEnvironmentMap(repoRoot: string): Promise<ValidationResult> {
  const mapPath = path.join(repoRoot, '.github', 'environment-map.yml');
  const errors: string[] = [];
  const warnings: string[] = [];

  // Check file exists
  if (!fs.existsSync(mapPath)) {
    return {
      valid: false,
      errors: [`environment-map.yml not found at ${mapPath}`],
      warnings: [],
      environments_found: [],
      rules_count: 0,
    };
  }

  let map: EnvironmentMap;

  try {
    const content = fs.readFileSync(mapPath, 'utf-8');
    const parsed = yaml.load(content);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return {
        valid: false,
        errors: ['Root of environment-map.yml must be a YAML object'],
        warnings: [],
        environments_found: [],
        rules_count: 0,
      };
    }
    map = parsed as EnvironmentMap;
  } catch (error) {
    return {
      valid: false,
      errors: [`Failed to parse environment-map.yml: ${error instanceof Error ? error.message : String(error)}`],
      warnings: [],
      environments_found: [],
      rules_count: 0,
    };
  }

  // Validate environments
  if (!map.environments || typeof map.environments !== 'object') {
    errors.push('Root must contain "environments" object');
  }
  const hasValidEnvironments = !!map.environments && typeof map.environments === 'object';

  const environmentsFound: Environment[] = [];

  for (const [envKey, config] of Object.entries(map.environments || {})) {
    environmentsFound.push(envKey as Environment);

    // Required fields
    if (!config.github_environment) {
      errors.push(`${envKey}: missing required field "github_environment"`);
    }
    if (!config.azure_subscription) {
      errors.push(`${envKey}: missing required field "azure_subscription"`);
    }
    if (!config.resource_group) {
      errors.push(`${envKey}: missing required field "resource_group"`);
    }

    // Optional but recommended
    if (!config.allowed_branch_patterns) {
      warnings.push(`${envKey}: no allowed_branch_patterns defined`);
    }
    if (!config.allowed_actions) {
      warnings.push(`${envKey}: no allowed_actions defined`);
    }
    if (!config.blocked_actions) {
      warnings.push(`${envKey}: no blocked_actions defined`);
    }

    // Validate production flag for prod environment
    if (envKey === 'prod' && !config.production) {
      errors.push(`prod: production flag must be true`);
    }
    if (envKey !== 'prod' && config.production) {
      errors.push(`${envKey}: production flag should only be true for prod environment`);
    }
  }

  // Validate rules
  const rulesCount = (map.rules || []).length;
  for (const [index, rule] of (map.rules || []).entries()) {
    if (!rule.name) {
      errors.push(`Rule ${index}: missing required field "name"`);
    }
    if (!rule.match) {
      errors.push(`Rule ${index}: missing required field "match"`);
    }
    if (!rule.context) {
      errors.push(`Rule ${index}: missing required field "context"`);
    }
    if (hasValidEnvironments && rule.context?.target_environment && !map.environments[rule.context.target_environment]) {
      errors.push(
        `Rule ${index} (${rule.name}): target_environment '${rule.context.target_environment}' not found in environments`
      );
    }
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
    environments_found: environmentsFound,
    rules_count: rulesCount,
  };
}
