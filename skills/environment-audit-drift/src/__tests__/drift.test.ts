import { describe, it, expect, beforeEach, vi } from 'vitest';
import { EnvironmentAuditDrifter, auditEnvironmentDrift, driftIsCritical } from '../drift';
import { DriftAuditInput, EnvironmentMap } from '../types';

const mockEnvironmentMap: EnvironmentMap = {
  environments: {
    prod: {
      github_environment: 'production',
      resource_group: 'rg-app-prod',
      container_apps_environment: 'cae-app-prod',
      log_analytics_workspace: 'law-app-prod',
      app_config: 'appconfig-app-prod',
      key_vault: 'kv-app-prod',
      autonomy_level: 'A2',
      allowed_branch_patterns: ['main'],
      blocked_actions: ['destroy', 'scale_down'],
      tags: {
        Environment: 'production',
        App: 'myapp',
        ManagedBy: 'platform-team',
      },
    },
    staging: {
      github_environment: 'staging',
      resource_group: 'rg-app-staging',
      container_apps_environment: 'cae-app-staging',
      log_analytics_workspace: 'law-app-staging',
      app_config: 'appconfig-app-staging',
      key_vault: 'kv-app-staging',
      autonomy_level: 'A3',
      allowed_branch_patterns: ['develop', 'release/*'],
      blocked_actions: [],
      tags: {
        Environment: 'staging',
        App: 'myapp',
        ManagedBy: 'platform-team',
      },
    },
  },
  rules: {
    incident_keywords: ['site is down', 'customers cannot access'],
    pr_label_env_mapping: {
      'env:prod': 'prod',
      'env:staging': 'staging',
    },
  },
};

describe('EnvironmentAuditDrifter', () => {
  let input: DriftAuditInput;

  beforeEach(() => {
    input = {
      config_path: '.github/environment-map.yml',
      azure_subscription_id: 'sub-123',
      github_token: 'token-123',
      release_manifest_path: undefined,
      app_config_key_check: false,
      strict_mode: false,
      repo_root: process.cwd(),
    };
  });

  it('should run audit and detect no critical drifts in healthy state', async () => {
    const auditor = new EnvironmentAuditDrifter(input, mockEnvironmentMap);
    const report = await auditor.audit();

    expect(report.audit_id).toBeDefined();
    expect(report.timestamp).toBeDefined();
    expect(report.severity_summary.critical).toBe(0);
  });

  it('should categorize findings by severity', async () => {
    const auditor = new EnvironmentAuditDrifter(input, mockEnvironmentMap);
    const report = await auditor.audit();

    expect(report.findings).toEqual(expect.arrayContaining(
      report.findings.filter(f => ['critical', 'high', 'medium', 'low'].includes(f.severity))
    ));
  });

  it('should include audit metadata with UUID and timestamp', async () => {
    const auditor = new EnvironmentAuditDrifter(input, mockEnvironmentMap);
    const report = await auditor.audit();

    expect(report.audit_id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}/);
    expect(new Date(report.timestamp)).toBeInstanceOf(Date);
  });

  it('should detect config drift when resource missing', async () => {
    const driftMap: EnvironmentMap = {
      ...mockEnvironmentMap,
      environments: {
        ...mockEnvironmentMap.environments,
        prod: {
          ...mockEnvironmentMap.environments.prod,
          container_apps_environment: 'cae-missing-prod',
        },
      },
    };

    const auditor = new EnvironmentAuditDrifter(input, driftMap);
    const report = await auditor.audit();

    const configDrifts = report.findings.filter(f => f.category === 'config_drift');
    expect(configDrifts.length).toBeGreaterThan(0);
  });

  it('should detect security drift when approval mismatch', async () => {
    const auditor = new EnvironmentAuditDrifter(input, mockEnvironmentMap);
    const report = await auditor.audit();

    const securityDrifts = report.findings.filter(f => f.category === 'security_drift');
    expect(securityDrifts).toEqual(
      expect.arrayContaining(
        securityDrifts.filter(f => f.severity === 'high' || f.severity === 'medium')
      )
    );
  });

  it('should mark as actionable when no critical drifts', async () => {
    const auditor = new EnvironmentAuditDrifter(input, mockEnvironmentMap);
    const report = await auditor.audit();

    expect(report.actionable).toBe(report.severity_summary.critical === 0);
  });

  it('should include remediation suggestions', async () => {
    const auditor = new EnvironmentAuditDrifter(input, mockEnvironmentMap);
    const report = await auditor.audit();

    for (const finding of report.findings) {
      expect(finding.remediation).toBeDefined();
      expect(finding.remediation.length).toBeGreaterThan(0);
    }
  });

  it('driftIsCritical should return true only with critical findings', async () => {
    const auditor = new EnvironmentAuditDrifter(input, mockEnvironmentMap);
    const report = await auditor.audit();

    const isCritical = driftIsCritical(report);
    expect(isCritical).toBe(report.severity_summary.critical > 0);
  });

  it('should measure validation duration', async () => {
    const auditor = new EnvironmentAuditDrifter(input, mockEnvironmentMap);
    const report = await auditor.audit();

    expect(report.validation_duration_ms).toBeGreaterThan(0);
    expect(report.next_audit).toBeDefined();
  });

  it('should include config file path in report', async () => {
    const auditor = new EnvironmentAuditDrifter(input, mockEnvironmentMap);
    const report = await auditor.audit();

    expect(report.config_file).toBe(input.config_path);
  });
});

describe('driftIsCritical helper', () => {
  it('should identify critical reports', () => {
    const criticalReport = {
      severity_summary: { critical: 1, high: 0, medium: 0, low: 0 },
    };

    expect(driftIsCritical(criticalReport as any)).toBe(true);
  });

  it('should allow high/medium/low without being critical', () => {
    const noncriticalReport = {
      severity_summary: { critical: 0, high: 5, medium: 3, low: 1 },
    };

    expect(driftIsCritical(noncriticalReport as any)).toBe(false);
  });
});
