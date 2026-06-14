import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';
import { v4 as uuidv4 } from 'uuid';
import {
  ResolverInput,
  OperationContext,
  EnvironmentMap,
  Environment,
  OperationMode,
  RiskLevel,
} from './types';

const RESOLVER_VERSION = '1.0.0';
const DEFAULT_SAFE_ENV: Environment = 'dev';

export class OperationContextResolver {
  private environmentMap: EnvironmentMap;
  private repoRoot: string;

  constructor(environmentMap: EnvironmentMap, repoRoot: string = process.cwd()) {
    this.environmentMap = environmentMap;
    this.repoRoot = repoRoot;
  }

  static async fromRepoRoot(repoRoot: string = process.cwd()): Promise<OperationContextResolver> {
    const mapPath = path.join(repoRoot, '.github', 'environment-map.yml');
    
    if (!fs.existsSync(mapPath)) {
      throw new Error(`environment-map.yml not found at ${mapPath}`);
    }

    const content = fs.readFileSync(mapPath, 'utf-8');
    const map = yaml.load(content) as EnvironmentMap;

    return new OperationContextResolver(map, repoRoot);
  }

  async resolve(input: ResolverInput): Promise<OperationContext> {
    const operationId = uuidv4();
    const now = new Date().toISOString();

    try {
      // Parse GitHub event if provided
      const githubEvent = this.parseGithubEvent(input);

      // Step 1: Check explicit override
      if (input.workflow_dispatch_input?.environment) {
        const env = input.workflow_dispatch_input.environment as Environment;
        return this.buildContext(env, 'explicit_override', operationId, now, input);
      }

      // Step 2: Check incident keywords
      if (input.user_intent && this.hasIncidentKeywords(input.user_intent)) {
        return this.buildContext('prod', 'incident_readonly', operationId, now, input, {
          human_approval_required: true,
          incident_mode: true,
          risk_level: 'critical',
        });
      }

      // Step 3: Check PR labels
      const labels = input.pr_labels || githubEvent?.pull_request?.labels || [];
      const envFromLabel = this.extractEnvironmentFromLabels(labels);
      if (envFromLabel) {
        return this.buildContext(envFromLabel, 'branch_deploy', operationId, now, input);
      }

      // Step 4: Check branch pattern
      const branch = this.extractBranch(input.github_ref, githubEvent);
      const envFromBranch = this.resolveEnvironmentFromBranch(branch);

      return this.buildContext(envFromBranch, 'branch_deploy', operationId, now, input);
    } catch (error) {
      throw new Error(`Resolver error: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private parseGithubEvent(input: ResolverInput): Record<string, unknown> | null {
    if (!input.github_event_payload) return null;

    if (typeof input.github_event_payload === 'string') {
      try {
        return JSON.parse(input.github_event_payload);
      } catch {
        return null;
      }
    }

    return input.github_event_payload as Record<string, unknown>;
  }

  private hasIncidentKeywords(intent: string): boolean {
    const incidentKeywords = [
      'site is down',
      'production is down',
      'customers cannot access',
      'critical incident',
      'prod down',
      'prod is down',
    ];

    const lowerIntent = intent.toLowerCase();
    return incidentKeywords.some(keyword => lowerIntent.includes(keyword));
  }

  private extractEnvironmentFromLabels(labels: string[]): Environment | null {
    for (const label of labels) {
      if (label === 'env:prod') return 'prod';
      if (label === 'env:staging') return 'staging';
      if (label === 'env:dev') return 'dev';
      if (label === 'env:preview') return 'preview';
    }
    return null;
  }

  private extractBranch(githubRef: string | undefined, githubEvent: Record<string, unknown> | null): string {
    // PR source branch takes priority
    if (githubEvent?.pull_request) {
      const pr = githubEvent.pull_request as Record<string, unknown>;
      const head = pr.head as Record<string, unknown>;
      if (head?.ref) return head.ref as string;
    }

    // Fall back to github.ref
    if (githubRef) {
      const refParts = githubRef.split('/');
      return refParts[refParts.length - 1];
    }

    return 'unknown';
  }

  private resolveEnvironmentFromBranch(branch: string): Environment {
    for (const [env, config] of Object.entries(this.environmentMap.environments)) {
      for (const pattern of config.allowed_branch_patterns) {
        if (this.matchPattern(branch, pattern)) {
          return env as Environment;
        }
      }
    }

    // Default to safe environment
    return DEFAULT_SAFE_ENV;
  }

  private matchPattern(branch: string, pattern: string): boolean {
    // Simple glob-like matching
    if (pattern === '*') return true;
    if (pattern === branch) return true;

    // Support simple wildcards: feature/* matches feature/foo
    if (pattern.includes('*')) {
      const regex = new RegExp(`^${pattern.replace(/\*/g, '.*')}$`);
      return regex.test(branch);
    }

    return false;
  }

  private buildContext(
    env: Environment,
    mode: OperationMode,
    operationId: string,
    now: string,
    input: ResolverInput,
    overrides?: Partial<OperationContext>
  ): OperationContext {
    const envConfig = this.environmentMap.environments[env];

    if (!envConfig) {
      throw new Error(`Environment '${env}' not found in environment-map.yml`);
    }

    const allowedActions = envConfig.allowed_actions[mode] || [];
    const blockedActions = envConfig.blocked_actions[mode] || [];
    const humanApprovalRequired = overrides?.human_approval_required !== undefined
      ? overrides.human_approval_required
      : envConfig.approval_required[mode] || false;

    const context: OperationContext = {
      request: input.user_intent || 'unspecified',
      operation_id: operationId,
      target_environment: env,
      canonical_environment: env,
      github_environment: envConfig.github_environment,
      azure_subscription: envConfig.azure_subscription,
      resource_group: envConfig.resource_group,
      container_apps_environment: envConfig.container_apps_environment,
      log_analytics_workspace: envConfig.log_analytics_workspace,
      app_config: envConfig.app_config,
      key_vault: envConfig.key_vault,
      front_door_profile: envConfig.front_door_profile,
      production: envConfig.production,
      risk_level: overrides?.risk_level || (env === 'prod' ? 'high' : 'medium'),
      mode,
      allowed_actions: allowedActions,
      blocked_actions: blockedActions,
      human_approval_required: humanApprovalRequired,
      incident_mode: overrides?.incident_mode || false,
      deployment_lookup_available: !!input.deployment_record_sha,
      resolved_at: now,
      resolver_version: RESOLVER_VERSION,
    };

    return context;
  }

  isActionAllowed(context: OperationContext, action: string): boolean {
    return (
      context.allowed_actions.includes(action) &&
      !context.blocked_actions.includes(action)
    );
  }

  requiresHumanApproval(context: OperationContext, action: string): boolean {
    return context.human_approval_required && context.blocked_actions.includes(action);
  }
}

// Standalone function for convenience
export async function resolveOperationContext(input: ResolverInput): Promise<OperationContext> {
  const repoRoot = input.repo_root || process.cwd();
  const resolver = await OperationContextResolver.fromRepoRoot(repoRoot);
  return resolver.resolve(input);
}
