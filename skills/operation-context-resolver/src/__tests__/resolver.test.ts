import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { OperationContextResolver, resolveOperationContext } from '../resolver.js';
import { EnvironmentMap } from '../types.js';

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

    it('should extract label names from pull request event payload objects', async () => {
      const context = await resolver.resolve({
        github_ref: 'refs/heads/feature/something',
        github_event_payload: {
          pull_request: {
            labels: [{ name: 'env:staging' }],
          },
        },
      });

      expect(context.target_environment).toBe('staging');
    });

    it('should resolve env:dev and env:preview labels', async () => {
      const devContext = await resolver.resolve({
        pr_labels: ['env:dev'],
      });
      const previewContext = await resolver.resolve({
        pr_labels: ['env:preview'],
      });

      expect(devContext.target_environment).toBe('dev');
      expect(previewContext.target_environment).toBe('preview');
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

    it('should not require human approval for read actions', async () => {
      const context = await resolver.resolve({
        github_ref: 'refs/heads/main',
      });

      expect(resolver.requiresHumanApproval(context, 'read_logs')).toBe(false);
      expect(resolver.requiresHumanApproval(context, 'deploy')).toBe(true);
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

  describe('rule resolution', () => {
    it('should use explicit workflow environment override when valid', async () => {
      const context = await resolver.resolve({
        github_ref: 'refs/heads/feature/add-login',
        workflow_dispatch_input: { environment: 'staging' },
      });

      expect(context.target_environment).toBe('staging');
      expect(context.mode).toBe('branch_deploy');
    });

    it('should reject invalid workflow environment override', async () => {
      await expect(
        resolver.resolve({
          workflow_dispatch_input: { environment: 'qa' },
        })
      ).rejects.toThrow("Resolver error: Invalid workflow_dispatch_input.environment 'qa'");
    });

    it('should resolve read-only deployment lookup context from branch', async () => {
      const context = await resolver.resolve({
        github_ref: 'refs/heads/feature/add-login',
        deployment_record_sha: 'abc123',
      });

      expect(context.target_environment).toBe('preview');
      expect(context.mode).toBe('read_only');
      expect(context.deployment_lookup_available).toBe(true);
    });

    it('should resolve rule matches by event name', async () => {
      const resolverWithRules = new OperationContextResolver({
        ...mockEnvironmentMap,
        rules: [
          {
            name: 'workflow_dispatch_staging',
            match: {
              event_name: ['workflow_dispatch'],
            },
            context: {
              target_environment: 'staging',
              mode: 'staging_deploy',
            },
          },
        ],
      });

      const context = await resolverWithRules.resolve({
        github_event_name: 'workflow_dispatch',
        github_ref: 'refs/heads/feature/add-login',
      });

      expect(context.target_environment).toBe('staging');
      expect(context.mode).toBe('staging_deploy');
    });

    it('should resolve rule matches by user intent, labels, source branch, and wildcard', async () => {
      const resolverWithRules = new OperationContextResolver({
        ...mockEnvironmentMap,
        rules: [
          {
            name: 'intent_rule',
            match: {
              user_intent_contains: ['deploy to prod'],
            },
            context: {
              target_environment: 'prod',
              mode: 'prod_readonly',
            },
          },
          {
            name: 'label_rule',
            match: {
              pr_labels: ['go-staging'],
            },
            context: {
              target_environment: 'staging',
              mode: 'branch_deploy',
            },
          },
          {
            name: 'source_branch_rule',
            match: {
              source_branch: 'release/*',
            },
            context: {
              target_environment: 'staging',
              mode: 'read_only',
            },
          },
          {
            name: 'fallback_rule',
            match: '*',
            context: {
              target_environment: 'dev',
              mode: 'read_only',
            },
          },
        ],
      });

      const intentContext = await resolverWithRules.resolve({
        user_intent: 'please deploy to prod after checks',
      });
      const labelContext = await resolverWithRules.resolve({
        pr_labels: ['go-staging'],
      });
      const branchContext = await resolverWithRules.resolve({
        github_ref: 'refs/heads/release/2026.06.14',
      });
      const fallbackContext = await resolverWithRules.resolve({
        github_ref: 'refs/heads/no-match',
      });

      expect(intentContext.mode).toBe('prod_readonly');
      expect(labelContext.target_environment).toBe('staging');
      expect(branchContext.mode).toBe('read_only');
      expect(fallbackContext.target_environment).toBe('dev');
    });

    it('should resolve from PR source branch in event payload', async () => {
      const context = await resolver.resolve({
        github_ref: 'refs/heads/ignored-branch',
        github_event_payload: {
          pull_request: {
            head: {
              ref: 'release/2026.06.14',
            },
          },
        },
      });

      expect(context.target_environment).toBe('staging');
    });

    it('should fall back when event payload JSON is invalid', async () => {
      const context = await resolver.resolve({
        github_ref: 'refs/heads/feature/invalid-json',
        github_event_payload: '{not-json',
      });

      expect(context.target_environment).toBe('preview');
    });
  });

  describe('repo root loading', () => {
    it('should resolve from repo root environment-map.yml', async () => {
      const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'operation-context-resolver-'));
      fs.mkdirSync(path.join(repoRoot, '.github'), { recursive: true });
      fs.writeFileSync(
        path.join(repoRoot, '.github', 'environment-map.yml'),
        `
environments:
  preview:
    github_environment: preview
    production: false
    azure_subscription: sub-preview
    resource_group: rg-preview
    allowed_branch_patterns:
      - feature/*
    allowed_actions:
      branch_deploy: [read_logs]
    blocked_actions:
      branch_deploy: [deploy]
  dev:
    github_environment: dev
    production: false
    azure_subscription: sub-dev
    resource_group: rg-dev
    allowed_branch_patterns:
      - dev
    allowed_actions:
      read_only: [read_logs]
    blocked_actions:
      read_only: [deploy]
`.trim(),
        'utf-8'
      );

      const context = await resolveOperationContext({
        repo_root: repoRoot,
        github_ref: 'refs/heads/feature/add-login',
      });

      expect(context.target_environment).toBe('preview');
    });
  });
});
