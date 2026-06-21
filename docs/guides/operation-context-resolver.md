---
description: "Integration guide: how agents use the operation-context-resolver skill to obtain deterministic environment routing before taking action"
---

# Operation Context Resolver — Integration Guide

The `operation-context-resolver` skill provides a deterministic, policy-driven mapping
from runtime signals (GitHub event, PR labels, user intent, incident keywords) to a
fully-populated `OperationContext` struct. Agents that read from or deploy to an
environment should resolve context first rather than making environment decisions
themselves.

## When to use

Call the resolver whenever your agent must:

- Select the correct Azure subscription, resource group, or Log Analytics workspace for a
  task
- Decide whether human approval is required before a destructive action
- Determine whether an incident is active and which environment it affects
- Enforce `allowed_actions` / `blocked_actions` from the repo's `environment-map.yml`

Do **not** hard-code environment names or branch-to-environment mappings in agent
instructions — route through the resolver so the policy lives in one place.

## TypeScript usage

```typescript
import { OperationContextResolver } from '@basecoat/operation-context-resolver';
import type { OperationContext, ResolverInput } from '@basecoat/operation-context-resolver';

const input: ResolverInput = {
  github_event_name: process.env.GITHUB_EVENT_NAME,
  github_ref: process.env.GITHUB_REF,
  user_intent: 'deploy hotfix for payment timeout',
  pr_labels: ['hotfix', 'production'],
  repo_root: process.env.GITHUB_WORKSPACE ?? process.cwd(),
};

const resolver = await OperationContextResolver.fromRepoRoot(input.repo_root!);
const ctx: OperationContext = await resolver.resolve(input);

if (ctx.human_approval_required) {
  throw new Error(`Human approval required for ${ctx.mode} on ${ctx.target_environment}`);
}

if (ctx.blocked_actions.includes('deploy')) {
  throw new Error(`Deploy is blocked in ${ctx.target_environment}: ${ctx.errors?.join(', ')}`);
}

console.log(`Resolved → env=${ctx.target_environment}, mode=${ctx.mode}, risk=${ctx.risk_level}`);
// Use ctx.azure_subscription and ctx.resource_group for Azure SDK calls
```

## CLI / shell usage

Validate `environment-map.yml` (returns non-zero if invalid):

```bash
cd skills/operation-context-resolver
npm ci && npm run build
node dist/cli.js validate --repo-root /path/to/repo
```

In a GitHub Actions step:

```yaml
- name: Validate environment map
  working-directory: skills/operation-context-resolver
  run: node dist/cli.js validate --repo-root "$GITHUB_WORKSPACE"
```

## `environment-map.yml` example

```yaml
environments:
  dev:
    github_environment: development
    azure_subscription: 00000000-0000-0000-0000-000000000000
    resource_group: myapp-dev-rg
    autonomy_level: A1
    allowed_branch_patterns: ['refs/heads/feat/*', 'refs/heads/fix/*']

  prod:
    github_environment: production
    production: true
    azure_subscription: 11111111-1111-1111-1111-111111111111
    resource_group: myapp-prod-rg
    autonomy_level: A4
    allowed_branch_patterns: ['refs/heads/main']
    approval_required:
      prod_incident: true
      hotfix: true
    blocked_actions:
      prod_readonly: ['deploy', 'delete']

rules:
  - name: incident-to-prod
    match:
      user_intent_contains: ['incident', 'sev1', 'sev2', 'outage']
    context:
      target_environment: prod
      mode: incident_readonly
      risk_level: high
      human_approval_required: true

  - name: pr-label-staging
    match:
      pr_labels: ['staging-deploy']
    context:
      target_environment: staging
      mode: staging_deploy
      risk_level: medium
```

## Agent integration pattern

When writing an agent that acts on environments, add a resolver step to the workflow:

```markdown
## Workflow

1. **Resolve context** — call `operation-context-resolver` with the GitHub event, ref, user intent, and any PR labels.
2. **Check gates** — if `human_approval_required: true`, stop and request approval. If the target action is in `blocked_actions`, abort with explanation.
3. **Act** — use `azure_subscription`, `resource_group`, and `log_analytics_workspace` from `OperationContext` for all Azure API calls.
4. **Log** — include `operation_id` from context in all audit log entries for traceability.
```

## Live workflow activation in this repository

Resolver and drift checks are now wired into live deployment entrypoints:

- [`.github/workflows/extension-deploy.yml`](../../.github/workflows/extension-deploy.yml)
- [`.github/workflows/mcp-deploy.yml`](../../.github/workflows/mcp-deploy.yml)

Both workflows run this policy gate sequence before deployment:

1. Resolve context with `@basecoat/operation-context-resolver` using the workflow target environment.
2. Fail if resolver returns policy errors or blocks `deploy_app`.
3. Run `@basecoat/environment-audit-drift` preflight and block on critical drift for the target environment.

## Drift status linkage

The resolver's `OperationContext` carries a `drift_status` field that reflects the most
recent environment-audit-drift report for the resolved environment. Agents should treat
`drift_status: 'critical'` as a soft block on destructive operations and surface it to
the user before proceeding.

See [`environment-audit-drift`](../../skills/environment-audit-drift/README.md) for the
companion skill that produces drift reports used to populate this field.

## Fallback patterns

When `environment-map.yml` is missing or unparseable, the resolver returns an
`OperationContext` with:

- `mode: 'read_only'`
- `risk_level: 'high'`
- `human_approval_required: true`
- `errors` array containing the parse failure message

Agents should always check `ctx.errors` and surface them when non-empty. Never silently
proceed on a context resolved with errors.

## Related assets

| Asset | Path |
|---|---|
| Resolver skill | `skills/operation-context-resolver/` |
| Drift audit skill | `skills/environment-audit-drift/` |
| Validate workflow | `.github/workflows/validate-operation-context.yml` |
| Drift workflow | `.github/workflows/audit-environment-drift.yml` |
| Live deployment gates | `.github/workflows/extension-deploy.yml`, `.github/workflows/mcp-deploy.yml` |
| Incident responder (reference agent) | `agents/basecoat-60-workflow-incident-responder.agent.md` |
