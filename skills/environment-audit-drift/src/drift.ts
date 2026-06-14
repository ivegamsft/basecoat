import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';
import { v4 as uuidv4 } from 'uuid';
import {
  DriftAuditInput,
  DriftReport,
  DriftFinding,
  SeveritySummary,
  EnvironmentMap,
  EnvironmentConfig,
} from './types';

export class EnvironmentAuditDrifter {
  private input: DriftAuditInput;
  private environmentMap: EnvironmentMap;
  private findings: DriftFinding[] = [];

  constructor(input: DriftAuditInput, environmentMap: EnvironmentMap) {
    this.input = input;
    this.environmentMap = environmentMap;
  }

  async audit(): Promise<DriftReport> {
    const startTime = Date.now();
    const auditId = uuidv4();
    const now = new Date().toISOString();

    try {
      // Audit each environment
      for (const [env, config] of Object.entries(this.environmentMap.environments || {})) {
        await this.auditConfigDrift(env, config);
        await this.auditSecurityDrift(env, config);
      }

      // Optional: audit deployment version drift
      if (this.input.release_manifest_path) {
        await this.auditDeploymentDrift();
      }

      if (this.input.app_config_key_check) {
        await this.auditAppConfigKeyDrift();
      }

      if (!this.input.skip_tag_check) {
        await this.auditTagDrift();
      }
    } catch (error) {
      this.addFinding({
        id: 'audit-error',
        environment: 'unknown',
        severity: 'critical',
        category: 'config_drift',
        finding: `Audit failed: ${error instanceof Error ? error.message : String(error)}`,
        expected: 'successful audit',
        actual: 'error',
        remediation: 'Check Azure/GitHub credentials and config file',
        timestamp: now,
      });
    }

    const duration = Date.now() - startTime;
    const summary = this.calculateSeveritySummary();

    return {
      audit_id: auditId,
      timestamp: now,
      config_file: this.input.config_path,
      total_drifts: this.findings.length,
      severity_summary: summary,
      findings: this.findings,
      resolved_drifts: 0,
      actionable: summary.critical === 0,
      validation_duration_ms: duration,
      next_audit: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    };
  }

  private async auditConfigDrift(env: string, config: EnvironmentConfig): Promise<void> {
    // Mock Azure resource checks
    const resources = [
      { type: 'resource_group', name: config.resource_group, critical: true },
      { type: 'container_apps_environment', name: config.container_apps_environment, critical: false },
      { type: 'log_analytics_workspace', name: config.log_analytics_workspace, critical: false },
      { type: 'app_config', name: config.app_config, critical: false },
      { type: 'key_vault', name: config.key_vault, critical: false },
    ];

    for (const resource of resources) {
      if (typeof resource.name !== 'string' || resource.name.length === 0) {
        continue;
      }
      // In real implementation, query Azure here
      const exists = await this.mockCheckAzureResource(resource.name);

      if (!exists) {
        this.addFinding({
          id: `config-resource-missing-${env}-${resource.type}`,
          environment: env,
          severity: resource.critical ? 'critical' : 'high',
          category: 'config_drift',
          finding: `${resource.type} '${resource.name}' not found in Azure`,
          expected: resource.name,
          actual: 'not_found',
          remediation: `Create the resource in Azure or update ${resource.type} in environment-map.yml`,
          resource: resource.name,
          timestamp: new Date().toISOString(),
        });
      }
    }

    // Check GitHub environment
    if (!config.github_environment) {
      this.addFinding({
        id: `config-github-environment-missing-value-${env}`,
        environment: env,
        severity: 'high',
        category: 'config_drift',
        finding: 'github_environment is missing from environment config',
        expected: 'non-empty github_environment value',
        actual: 'missing',
        remediation: 'Set github_environment for this environment in environment-map.yml',
        timestamp: new Date().toISOString(),
      });
      return;
    }
    const githubEnvExists = await this.mockCheckGitHubEnvironment(config.github_environment);
    if (!githubEnvExists) {
      this.addFinding({
        id: `config-github-environment-missing-${env}`,
        environment: env,
        severity: 'high',
        category: 'config_drift',
        finding: `GitHub environment '${config.github_environment}' not found`,
        expected: config.github_environment,
        actual: 'not_found',
        remediation: 'Create the GitHub environment or update github_environment in config',
        timestamp: new Date().toISOString(),
      });
    }
  }

  private async auditSecurityDrift(env: string, config: EnvironmentConfig): Promise<void> {
    // Mock GitHub branch protection checks
    for (const pattern of config.allowed_branch_patterns || []) {
      const protection = await this.mockCheckBranchProtection(pattern);
      const expectedApprovals = this.getMinimumApprovalsForAutonomy(config.autonomy_level);

      if (protection.required_approvals < expectedApprovals) {
        this.addFinding({
          id: `security-approval-mismatch-${env}-${pattern}`,
          environment: env,
          severity: config.autonomy_level === 'A1' ? 'critical' : 'high',
          category: 'security_drift',
          finding: `Branch '${pattern}' configured as ${config.autonomy_level} requires ${expectedApprovals}+ approvals but has ${protection.required_approvals}`,
          expected: `${expectedApprovals}+ required approvals`,
          actual: String(protection.required_approvals),
          remediation: 'Update GitHub branch protection rules to require approvals',
          resource: pattern,
          timestamp: new Date().toISOString(),
        });
      }
    }
  }

  private async auditDeploymentDrift(): Promise<void> {
    if (!fs.existsSync(this.input.release_manifest_path!)) {
      this.addFinding({
        id: 'deployment-manifest-missing',
        environment: 'unknown',
        severity: 'medium',
        category: 'deployment_drift',
        finding: 'Release manifest not found',
        expected: `file at ${this.input.release_manifest_path}`,
        actual: 'not_found',
        remediation: 'Create release manifest or disable deployment drift check',
        timestamp: new Date().toISOString(),
      });
      return;
    }

    try {
      const parsed = JSON.parse(fs.readFileSync(this.input.release_manifest_path!, 'utf-8'));
      const manifest = this.parseReleaseManifest(parsed);
      const manifestAge = this.calculateManifestAge(manifest.timestamp);

      if (manifestAge > 168) {
        // older than 1 week
        this.addFinding({
          id: 'deployment-manifest-stale',
          environment: 'all',
          severity: 'medium',
          category: 'deployment_drift',
          finding: `Release manifest is ${manifestAge} hours old`,
          expected: '< 168 hours (1 week)',
          actual: `${manifestAge} hours`,
          remediation: 'Verify release promotion workflow is running correctly',
          timestamp: new Date().toISOString(),
        });
      }

      let comparedEnvironments = 0;
      for (const env of Object.keys(this.environmentMap.environments || {})) {
        const expectedVersion = manifest.expectedByEnvironment[env];
        const actualVersion = manifest.actualByEnvironment[env];
        if (expectedVersion && actualVersion) {
          comparedEnvironments += 1;
          if (expectedVersion !== actualVersion) {
            this.addFinding({
              id: `deployment-version-mismatch-${env}`,
              environment: env,
              severity: 'high',
              category: 'deployment_drift',
              finding: `Release manifest version '${expectedVersion}' does not match deployed Container Apps revision '${actualVersion}'`,
              expected: expectedVersion,
              actual: actualVersion,
              remediation: 'Run promotion/deployment workflow to align deployed revision with release manifest',
              resource: env,
              timestamp: new Date().toISOString(),
            });
          }
          continue;
        }

        if (expectedVersion && !actualVersion) {
          this.addFinding({
            id: `deployment-actual-missing-${env}`,
            environment: env,
            severity: 'medium',
            category: 'deployment_drift',
            finding: `Expected version '${expectedVersion}' found in manifest but deployed revision is missing`,
            expected: expectedVersion,
            actual: 'missing',
            remediation: 'Populate deployed Container Apps revision in the release manifest',
            resource: env,
            timestamp: new Date().toISOString(),
          });
        }
      }

      if (comparedEnvironments === 0) {
        this.addFinding({
          id: 'deployment-version-comparison-unavailable',
          environment: 'all',
          severity: 'medium',
          category: 'deployment_drift',
          finding: 'Release manifest does not include comparable expected and deployed versions for configured environments',
          expected: 'expected_version and deployed_revision data',
          actual: 'insufficient',
          remediation: 'Store per-environment expected_version and deployed_revision values in the release manifest',
          timestamp: new Date().toISOString(),
        });
      }
    } catch (error) {
      this.addFinding({
        id: 'deployment-manifest-invalid',
        environment: 'unknown',
        severity: 'high',
        category: 'deployment_drift',
        finding: 'Release manifest is not valid JSON',
        expected: 'valid JSON',
        actual: 'invalid',
        remediation: 'Fix manifest format or remove file',
        timestamp: new Date().toISOString(),
      });
    }
  }

  private async auditTagDrift(): Promise<void> {
    // Mock Azure tag checks
    const requiredTags = ['Environment', 'App', 'ManagedBy', 'ReleaseId'];

    for (const [env, config] of Object.entries(this.environmentMap.environments || {})) {
      for (const tag of requiredTags) {
        if (!config.tags || !config.tags[tag]) {
          this.addFinding({
            id: `tag-missing-${env}-${tag}`,
            environment: env,
            severity: 'medium',
            category: 'tag_drift',
            finding: `Azure resources may be missing tag '${tag}'`,
            expected: tag,
            actual: 'not_set',
            remediation: `Add tag ${tag}=${config.tags?.[tag] || 'value'} to resources`,
            resource: config.resource_group,
            timestamp: new Date().toISOString(),
          });
        }
      }
    }
  }

  private async auditAppConfigKeyDrift(): Promise<void> {
    for (const [env, config] of Object.entries(this.environmentMap.environments || {})) {
      if (!config.app_config) {
        this.addFinding({
          id: `app-config-key-check-missing-store-${env}`,
          environment: env,
          severity: 'medium',
          category: 'config_drift',
          finding: 'App Configuration key check requested, but app_config is not set for this environment',
          expected: 'app_config value',
          actual: 'missing',
          remediation: 'Set app_config for the environment or disable app_config_key_check',
          timestamp: new Date().toISOString(),
        });
      }
    }
  }

  private addFinding(finding: DriftFinding): void {
    this.findings.push(finding);
  }

  private calculateSeveritySummary(): SeveritySummary {
    return {
      critical: this.findings.filter(f => f.severity === 'critical').length,
      high: this.findings.filter(f => f.severity === 'high').length,
      medium: this.findings.filter(f => f.severity === 'medium').length,
      low: this.findings.filter(f => f.severity === 'low').length,
    };
  }

  private calculateManifestAge(timestamp?: string): number {
    if (!timestamp) return 0;
    const manifestTime = new Date(timestamp).getTime();
    const nowTime = Date.now();
    return Math.floor((nowTime - manifestTime) / (1000 * 60 * 60));
  }

  private getMinimumApprovalsForAutonomy(level: EnvironmentConfig['autonomy_level']): number {
    switch (level) {
      case 'A1':
        return 2;
      case 'A2':
        return 1;
      case 'A3':
        return 1;
      case 'A4':
      default:
        return 0;
    }
  }

  private parseReleaseManifest(parsed: unknown): {
    timestamp?: string;
    expectedByEnvironment: Record<string, string>;
    actualByEnvironment: Record<string, string>;
  } {
    const manifestObject =
      parsed && typeof parsed === 'object' && !Array.isArray(parsed)
        ? (parsed as Record<string, unknown>)
        : {};

    const expectedByEnvironment: Record<string, string> = {};
    const actualByEnvironment: Record<string, string> = {};
    const globalVersion = this.readString(manifestObject['version']);
    const environmentBlock = this.asRecord(manifestObject['environments']);

    for (const env of Object.keys(this.environmentMap.environments || {})) {
      const envRecord = this.asRecord(environmentBlock[env]);
      expectedByEnvironment[env] =
        this.readString(envRecord['expected_version']) ||
        this.readString(envRecord['release_version']) ||
        globalVersion ||
        '';
      actualByEnvironment[env] =
        this.readString(envRecord['deployed_revision']) ||
        this.readString(envRecord['deployed_version']) ||
        this.readString(envRecord['container_app_revision']) ||
        this.readString(this.asRecord(manifestObject['deployed_revisions'])[env]) ||
        this.readString(this.asRecord(manifestObject['actual_versions'])[env]) ||
        '';
    }

    return {
      timestamp: this.readString(manifestObject['timestamp']),
      expectedByEnvironment,
      actualByEnvironment,
    };
  }

  private asRecord(value: unknown): Record<string, unknown> {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      return value as Record<string, unknown>;
    }
    return {};
  }

  private readString(value: unknown): string {
    return typeof value === 'string' ? value : '';
  }

  // Mock helpers (would be replaced with real Azure/GitHub API calls)
  private async mockCheckAzureResource(name: string): Promise<boolean> {
    // In real implementation: query Azure for resource
    if (!name) {
      return false;
    }
    return !name.includes('missing');
  }

  private async mockCheckGitHubEnvironment(name: string): Promise<boolean> {
    // In real implementation: query GitHub API
    if (!name) {
      return false;
    }
    return !name.includes('missing');
  }

  private async mockCheckBranchProtection(
    branch: string
  ): Promise<{ required_approvals: number }> {
    // In real implementation: query GitHub API
    return { required_approvals: branch === 'main' ? 1 : 0 };
  }
}

export async function auditEnvironmentDrift(input: DriftAuditInput): Promise<DriftReport> {
  // Load environment-map
  const mapPath = path.join(input.repo_root || process.cwd(), input.config_path);
  const content = fs.readFileSync(mapPath, 'utf-8');
  const loaded = yaml.load(content);
  if (!loaded || typeof loaded !== 'object' || Array.isArray(loaded)) {
    throw new Error('environment-map.yml root must be a YAML object');
  }
  const envMap = loaded as Partial<EnvironmentMap>;
  if (!envMap.environments || typeof envMap.environments !== 'object' || Array.isArray(envMap.environments)) {
    throw new Error('environment-map.yml must contain an environments object');
  }

  const auditor = new EnvironmentAuditDrifter(input, envMap as EnvironmentMap);
  return auditor.audit();
}

export function driftIsCritical(report: DriftReport): boolean {
  return report.severity_summary.critical > 0;
}
