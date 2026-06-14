import { OperationContextResolver } from '../resolver';
import { EnvironmentMap } from '../types';

describe('OperationContextResolver', () => {
  const mockEnvironmentMap: EnvironmentMap = {
    environments: {
      preview: {
        github_environment: 'preview',
        autonomy_level: 'A4',
        production: false,
        azure_subscription: 'sub-dev',
        resource_group: 'rg-preview',
        container_apps_environment: 'cae-preview',
        log_analytics_workspace: 'law-preview',
        app_config: 'appcs-preview',
        key_vault: 'kv-preview',
        front_door_profile: null,
        tags: { Environment: 'Preview' },
        allowed_branch_patterns: ['feature/*', 'agent/*'],
        allowed_workflows: ['ci.yml'],
        approval_required: { 
          read_only: false, 
          branch_deploy: false, 
          staging_deploy: false,
          incident_readonly: false,
          prod_readonly: false,
          prod_incident: false,
          hotfix: false
        },
        allowed_actions: {
          read_only: ['read_logs'],
          branch_deploy: ['read_logs', 'deploy'],
          staging_deploy: ['read_logs'],
          incident_readonly: ['read_logs'],
          prod_readonly: ['read_logs'],
          prod_incident: ['read_logs'],
          hotfix: ['read_logs']
        },
        blocked_actions: {
          read_only: ['deploy'],
          branch_deploy: [],
          staging_deploy: ['deploy'],
          incident_readonly: ['deploy'],
          prod_readonly: ['deploy'],
          prod_incident: ['deploy'],
          hotfix: []
        },
      },
      dev: {
        github_environment: 'dev',
        autonomy_level: 'A4',
        production: false,
        azure_subscription: 'sub-dev',
        resource_group: 'rg-dev',
        container_apps_environment: 'cae-dev',
        log_analytics_workspace: 'law-dev',
        app_config: 'appcs-dev',
        key_vault: 'kv-dev',
        front_door_profile: null,
        tags: { Environment: 'Dev' },
        allowed_branch_patterns: ['dev', 'dev/*'],
        allowed_workflows: ['ci.yml'],
        approval_required: { 
          read_only: false, 
          branch_deploy: false, 
          staging_deploy: false,
          incident_readonly: false,
          prod_readonly: false,
          prod_incident: false,
          hotfix: false
        },
        allowed_actions: { 
          read_only: ['read_logs'], 
          branch_deploy: ['read_logs', 'deploy'],
          staging_deploy: ['read_logs'],
          incident_readonly: ['read_logs'],
          prod_readonly: ['read_logs'],
          prod_incident: ['read_logs'],
          hotfix: ['read_logs']
        },
        blocked_actions: { 
          read_only: ['deploy'], 
          branch_deploy: [],
          staging_deploy: ['deploy'],
          incident_readonly: ['deploy'],
          prod_readonly: ['deploy'],
          prod_incident: ['deploy'],
          hotfix: []
        },
      },
      staging: {
        github_environment: 'staging',
        autonomy_level: 'A3',
        production: false,
        azure_subscription: 'sub-staging',
        resource_group: 'rg-staging',
        container_apps_environment: 'cae-staging',
        log_analytics_workspace: 'law-staging',
        app_config: 'appcs-staging',
        key_vault: 'kv-staging',
        front_door_profile: 'fd-staging',
        tags: { Environment: 'Staging' },
        allowed_branch_patterns: ['staging', 'release/*'],
        allowed_workflows: ['ci.yml'],
        approval_required: { 
          read_only: false, 
          branch_deploy: false, 
          staging_deploy: false,
          incident_readonly: false,
          prod_readonly: false,
          prod_incident: false,
          hotfix: false
        },
        allowed_actions: { 
          read_only: ['read_logs'], 
          branch_deploy: ['read_logs'],
          staging_deploy: ['read_logs', 'deploy'],
          incident_readonly: ['read_logs'],
          prod_readonly: ['read_logs'],
          prod_incident: ['read_logs'],
          hotfix: ['read_logs']
        },
        blocked_actions: { 
          read_only: ['deploy'], 
          branch_deploy: ['deploy'],
          staging_deploy: [],
          incident_readonly: ['deploy'],
          prod_readonly: ['deploy'],
          prod_incident: ['deploy'],
          hotfix: []
        },
      },
      prod: {
        github_environment: 'production',
        autonomy_level: 'A2',
        production: true,
        azure_subscription: 'sub-prod',
        resource_group: 'rg-prod',
        container_apps_environment: 'cae-prod',
        log_analytics_workspace: 'law-prod',
        app_config: 'appcs-prod',
        key_vault: 'kv-prod',
        front_door_profile: 'fd-prod',
        tags: { Environment: 'Production' },
        allowed_branch_patterns: ['main'],
        allowed_workflows: ['ci.yml'],
        approval_required: { 
          read_only: false, 
          branch_deploy: true, 
          staging_deploy: false,
          incident_readonly: true,
          prod_readonly: true,
          prod_incident: false,
          hotfix: false
        },
        allowed_actions: { 
          read_only: ['read_logs'], 
          branch_deploy: ['read_logs'],
          staging_deploy: ['read_logs'],
          incident_readonly: ['read_logs'],
          prod_readonly: ['read_logs'],
          prod_incident: ['read_logs'],
          hotfix: ['read_logs']
        },
        blocked_actions: { 
          read_only: ['deploy'], 
          branch_deploy: ['deploy'],
          staging_deploy: ['deploy'],
          incident_readonly: ['deploy'],
          prod_readonly: ['deploy'],
          prod_incident: ['deploy'],
          hotfix: []
        },
      },
    },
    rules: [],
  };

  let resolver: OperationContextResolver;

  beforeEach(() => {
    resolver = new OperationContextResolver(mockEnvironmentMap);
  });

  describe('feature branch resolution', () => {
    it('should resolve feature/* branch to preview', async () => {
      const context = await resolver.resolve({
        github_ref: 'refs/heads/feature/add-login',
      });

      expect(context.target_environment).toBe('preview');
      expect(context.github_environment).toBe('preview');
      expect(context.production).toBe(false);
    });

    it('should resolve agent/* branch to preview', async () => {
      const context = await resolver.resolve({
        github_ref: 'refs/heads/agent/fix-timeout',
      });

      expect(context.target_environment).toBe('preview');
    });
  });

  describe('incident override', () => {
    it('should override branch context with incident keywords', async () => {
      const context = await resolver.resolve({
        github_ref: 'refs/heads/feature/something',
        user_intent: 'site is down in prod',
      });

      expect(context.target_environment).toBe('prod');
      expect(context.incident_mode).toBe(true);
      expect(context.human_approval_required).toBe(true);
      expect(context.risk_level).toBe('critical');
    });

    it('should recognize "customers cannot access" as incident', async () => {
      const context = await resolver.resolve({
        github_ref: 'refs/heads/dev',
        user_intent: 'customers cannot access the service',
      });

      expect(context.target_environment).toBe('prod');
      expect(context.incident_mode).toBe(true);
    });
  });

  describe('PR labels', () => {
    it('should resolve env:prod label to prod', async () => {
      const context = await resolver.resolve({
        github_ref: 'refs/heads/feature/something',
        pr_labels: ['env:prod', 'type:bugfix'],
      });

      expect(context.target_environment).toBe('prod');
    });
  });

  describe('human approval', () => {
    it('should require approval for prod branch deploy', async () => {
      const context = await resolver.resolve({
        github_ref: 'refs/heads/main',
      });

      expect(context.target_environment).toBe('prod');
      expect(context.human_approval_required).toBe(true);
    });
  });

  describe('permission checking', () => {
    it('should allow read_logs for preview', async () => {
      const context = await resolver.resolve({
        github_ref: 'refs/heads/feature/something',
      });

      expect(resolver.isActionAllowed(context, 'read_logs')).toBe(true);
    });

    it('should block deploy for read_only mode', async () => {
      const context = await resolver.resolve({
        github_ref: 'refs/heads/unknown-branch',
      });

      expect(resolver.isActionAllowed(context, 'deploy')).toBe(false);
    });
  });

  describe('default fallback', () => {
    it('should default to dev for unknown branch', async () => {
      const context = await resolver.resolve({
        github_ref: 'refs/heads/random-unknown-branch',
      });

      expect(context.target_environment).toBe('dev');
      expect(context.production).toBe(false);
    });
  });
});
