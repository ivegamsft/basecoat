# Operation Context Resolver — Integration Guide

## Overview

The operation context resolver provides deterministic environment routing for agents and workflows. Before any agent reads logs, deploys, or modifies infrastructure, it should call the resolver to determine:

- Which environment to target (preview, dev, staging, prod)
- What actions are allowed/blocked
- Whether human approval is required
- Risk level of the operation

## Setup

### 1. Copy environment-map template

```bash
cp skills/operation-context-resolver/templates/environment-map.yml .github/environment-map.yml
```

Edit `.github/environment-map.yml`:
- Replace `YOUR_DEV_SUBSCRIPTION_ID` with your Azure dev subscription
- Replace `YOUR_PROD_SUBSCRIPTION_ID` with your Azure prod subscription
- Update resource group names, Container Apps names, etc.
- Customize branch patterns for your workflow

### 2. Install resolver in your project

```bash
npm install @basecoat/operation-context-resolver
```

Or import directly from BaseCoat:

```typescript
import { resolveOperationContext } from '@basecoat/operation-context-resolver';
```

## Usage in Agents

### Basic pattern

```typescript
import { resolveOperationContext } from '@basecoat/operation-context-resolver';

// In your agent or workflow
const context = await resolveOperationContext({
  github_event_payload: process.env.GITHUB_EVENT,
  github_ref: process.env.GITHUB_REF,
  user_intent: 'troubleshoot login timeout',
  pr_labels: JSON.parse(process.env.PR_LABELS || '[]'),
});

// Now you have:
console.log(`Target environment: ${context.target_environment}`);
console.log(`Allowed actions: ${context.allowed_actions.join(', ')}`);
console.log(`Requires approval: ${context.human_approval_required}`);
```

### Check before reading logs

```typescript
if (!context.isActionAllowed('read_logs')) {
  throw new Error(`Action 'read_logs' not allowed in ${context.mode} for ${context.target_environment}`);
}

// Safe to read logs from target_environment
const logs = await readLogsFromEnvironment(context.target_environment);
```

### Check before deployment

```typescript
if (context.blocked_actions.includes('deploy')) {
  console.log('Deployment blocked in this mode.');
  if (context.human_approval_required) {
    throw new Error('Human approval required before proceeding.');
  }
}

// Safe to deploy
await deployToEnvironment(context.target_environment);
```

### Incident handling

```typescript
if (context.incident_mode) {
  console.log(`⚠️  Incident mode: ${context.risk_level}`);
  console.log(`Target environment: ${context.target_environment}`);
  console.log(`Allowed read-only actions: ${context.allowed_actions.join(', ')}`);
  
  // Gather evidence without mutating
  const health = await checkHealth(context);
  const logs = await readLogs(context);
  const deployments = await readDeployments(context);
  
  return recommendedActions(health, logs, deployments);
}
```

## Shell/GitHub Actions Usage

### Example workflow step

```yaml
- name: Resolve operation context
  id: context
  run: |
    npx @basecoat/operation-context-resolver \
      --github-event "${{ toJSON(github.event) }}" \
      --github-ref "${{ github.ref }}" \
      --user-intent "troubleshoot" \
      --output context.json

- name: Read context
  run: |
    jq '.' context.json
    TARGET_ENV=$(jq -r '.target_environment' context.json)
    echo "Target environment: $TARGET_ENV"
```

## Common Scenarios

### Scenario 1: Feature branch troubleshooting

User: _"Debug this issue on the feature branch I'm working on"_

```typescript
const context = await resolveOperationContext({
  github_ref: 'refs/heads/feature/login-timeout',
  user_intent: 'troubleshoot login timeout',
});

// Result:
// target_environment: preview
// mode: read_only
// allowed_actions: [read_logs, read_deployments]
// human_approval_required: false
```

### Scenario 2: Production incident

User: _"Site is down in production"_

```typescript
const context = await resolveOperationContext({
  user_intent: 'site is down in production',
  pr_labels: [],
});

// Result:
// target_environment: prod
// mode: incident_readonly
// incident_mode: true
// risk_level: critical
// human_approval_required: true
// allowed_actions: [read_logs, read_deployments, read_infra_state]
// blocked_actions: [deploy, migrate_db, apply_iac, rollback]
```

### Scenario 3: Staging deployment via label

User: _"Deploy to staging for testing"_

PR has label: `env:staging`

```typescript
const context = await resolveOperationContext({
  pr_labels: ['env:staging', 'type:testing'],
  github_ref: 'refs/heads/feature/new-feature',
});

// Result:
// target_environment: staging
// mode: branch_deploy
// allowed_actions: [read_logs, read_deployments, deploy_app]
// human_approval_required: false
```

## Validation

### Validate environment-map.yml in your repo

```bash
npx @basecoat/operation-context-resolver validate \
  --repo-root .
```

Output:
```
✓ environment-map.yml is valid
✓ Found 4 environments: preview, dev, staging, prod
✓ Found 6 rules
✓ All environments have required fields
⚠ warning: preview: no front_door_profile defined
```

### Add validation to CI

```yaml
- name: Validate environment map
  run: npx @basecoat/operation-context-resolver validate
```

## Customization

### Add new environment

```yaml
environments:
  canary:
    github_environment: canary
    production: false
    # ... other fields
```

### Add new rule

```yaml
rules:
  - name: my_rule
    match:
      pr_labels: [my-label]
    context:
      target_environment: canary
      mode: branch_deploy
```

### Add custom allowed/blocked actions

Define in environment config:

```yaml
allowed_actions:
  read_only: [read_logs, my_custom_action]
  branch_deploy: [read_logs, deploy_app, my_custom_action]

blocked_actions:
  read_only: [deploy, my_blocked_action]
```

Then check:

```typescript
if (context.isActionAllowed('my_custom_action')) {
  // Safe to proceed
}
```

## Testing

### Unit test example

```typescript
import { resolveOperationContext } from '@basecoat/operation-context-resolver';

describe('my agent with resolver', () => {
  it('should read logs from preview for feature branch', async () => {
    const context = await resolveOperationContext({
      github_ref: 'refs/heads/feature/test',
    });

    expect(context.target_environment).toBe('preview');
    expect(context.isActionAllowed('read_logs')).toBe(true);
  });

  it('should override to prod for incident', async () => {
    const context = await resolveOperationContext({
      github_ref: 'refs/heads/dev',
      user_intent: 'site is down in production',
    });

    expect(context.target_environment).toBe('prod');
    expect(context.incident_mode).toBe(true);
  });
});
```

## Troubleshooting

### "environment-map.yml not found"

- Ensure file exists at `.github/environment-map.yml`
- Check working directory is repo root

### "Environment 'xyz' not found"

- Check environment-map.yml YAML syntax
- Verify environment name matches a key in `environments:`

### "Action 'X' not in allowed_actions"

- Check environment config for the target environment
- Verify the mode is correct (read_only, branch_deploy, etc.)
- Add action to `allowed_actions[mode]` if needed

## See Also

- [SKILL.md](./SKILL.md) — Skill overview
- [Resolver Types](./src/types.ts) — TypeScript interfaces
- [Environment Map Template](./templates/environment-map.yml) — Customizable template
