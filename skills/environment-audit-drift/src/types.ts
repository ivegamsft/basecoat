export type DriftSeverity = 'critical' | 'high' | 'medium' | 'low';
export type DriftCategory = 'config_drift' | 'deployment_drift' | 'security_drift' | 'tag_drift';
export type AutonomyLevel = 'A1' | 'A2' | 'A3' | 'A4';
export type OperationMode = 'full' | 'read_only' | 'incident_readonly';

export interface EnvironmentConfig {
  github_environment: string;
  resource_group: string;
  container_apps_environment?: string;
  log_analytics_workspace?: string;
  app_config?: string;
  key_vault?: string;
  autonomy_level: AutonomyLevel;
  allowed_branch_patterns: string[];
  blocked_actions?: string[];
  tags?: Record<string, string>;
}

export interface EnvironmentMap {
  environments: Record<string, EnvironmentConfig>;
  rules?: {
    incident_keywords?: string[];
    pr_label_env_mapping?: Record<string, string>;
  };
}

export interface DriftFinding {
  id: string;
  environment: string;
  severity: DriftSeverity;
  category: DriftCategory;
  finding: string;
  expected: string;
  actual: string;
  remediation: string;
  resource?: string;
  timestamp: string;
}

export interface SeveritySummary {
  critical: number;
  high: number;
  medium: number;
  low: number;
}

export interface DriftReport {
  audit_id: string;
  timestamp: string;
  config_file: string;
  total_drifts: number;
  severity_summary: SeveritySummary;
  findings: DriftFinding[];
  resolved_drifts: number;
  actionable: boolean;
  validation_duration_ms: number;
  next_audit: string;
}

export interface DriftAuditInput {
  config_path: string;
  azure_subscription_id: string;
  github_token: string;
  release_manifest_path?: string;
  log_analytics_query_enabled?: boolean;
  app_config_key_check?: boolean;
  skip_tag_check?: boolean;
  strict_mode?: boolean;
  repo_root?: string;
}

export interface ConfigDriftCheck {
  resource_type: string;
  resource_name: string;
  exists: boolean;
  error?: string;
}

export interface DeploymentDriftCheck {
  environment: string;
  expected_version: string;
  actual_version: string;
  matches: boolean;
  manifest_age_hours?: number;
}

export interface SecurityDriftCheck {
  branch: string;
  autonomy_level: string;
  required_approvals: number;
  actual_approvals: number;
  matches: boolean;
}

export interface TagDriftCheck {
  resource: string;
  tag_key: string;
  expected_value: string;
  actual_value?: string;
  exists: boolean;
}
