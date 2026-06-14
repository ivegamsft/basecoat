// Type definitions for operation context resolver

export type Environment = 'preview' | 'dev' | 'staging' | 'prod';
export type RiskLevel = 'low' | 'medium' | 'high' | 'critical';
export type OperationMode = 
  | 'read_only'
  | 'branch_deploy'
  | 'staging_deploy'
  | 'prod_readonly'
  | 'incident_readonly'
  | 'prod_incident'
  | 'hotfix';

export interface ResolverInput {
  github_event_payload?: string | object;
  github_event_name?: string;
  github_ref?: string;
  user_intent?: string;
  pr_labels?: string[];
  workflow_dispatch_input?: Record<string, unknown>;
  deployment_record_sha?: string;
  release_manifest_path?: string;
  incident_severity?: string;
  repo_root?: string;
}

export interface EnvironmentConfig {
  github_environment: string;
  autonomy_level: string;
  production: boolean;
  azure_subscription: string;
  resource_group: string;
  container_apps_environment: string;
  log_analytics_workspace: string;
  app_config: string;
  key_vault: string;
  front_door_profile: string | null;
  tags: Record<string, string>;
  allowed_branch_patterns?: string[];
  allowed_workflows: string[];
  approval_required: Partial<Record<OperationMode, boolean>>;
  allowed_actions: Partial<Record<OperationMode, string[]>>;
  blocked_actions: Partial<Record<OperationMode, string[]>>;
}

export interface OperationContext {
  request: string;
  operation_id: string;
  target_environment: Environment;
  canonical_environment: Environment;
  github_environment: string;
  azure_subscription: string;
  resource_group: string;
  container_apps_environment: string;
  log_analytics_workspace: string;
  app_config: string;
  key_vault: string;
  front_door_profile: string | null;
  production: boolean;
  risk_level: RiskLevel;
  mode: OperationMode;
  allowed_actions: string[];
  blocked_actions: string[];
  human_approval_required: boolean;
  incident_mode: boolean;
  deployment_lookup_available: boolean;
  resolved_at: string;
  resolver_version: string;
  warnings?: string[];
  errors?: string[];
}

export interface EnvironmentMap {
  environments: Record<Environment, EnvironmentConfig>;
  rules: ResolverRule[];
}

export interface ResolverRule {
  name: string;
  match:
    | '*'
    | {
        user_intent_contains?: string[];
        pr_labels?: string[];
        event_name?: string;
        source_branch?: string | string[];
      };
  context: {
    target_environment: Environment;
    mode: OperationMode;
    risk_level?: RiskLevel;
    human_approval_required?: boolean;
  };
}

export interface ValidationResult {
  valid: boolean;
  errors: string[];
  warnings: string[];
  environments_found: Environment[];
  rules_count: number;
}
