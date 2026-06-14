---
name: operation-context-resolver
description: Deterministic environment routing for agentic troubleshooting and deployment workflows
category: infrastructure
visibility: public
autonomy: A2
requires:
  - GitHub Environments configured
  - ".github/environment-map.yml in repo"
  - "Optional: Azure subscription context"
provides:
  - "operation-context.json (JSON output)"
  - "ResolverInput/OperationContext TypeScript types"
  - "GitHub Actions workflow template"
examples:
  - "Resolve environment for branch troubleshooting"
  - "Determine permissions for prod incident response"
  - "Route deployment to correct environment"
eval_coverage:
  - Resolver outputs correct environment for each branch pattern
  - Incident keywords override branch context
  - Mutations are blocked when context forbids them
  - Human approval is required for prod operations
tags:
  - environment
  - routing
  - troubleshooting
  - deployment
  - incident-response
---

# Operation Context Resolver

Resolves operational context (target environment, permissions, allowed/blocked actions) for GitHub Actions workflows and agentic tasks.

## Quick Start

### 1. Provide environment map

Create `.github/environment-map.yml` in your repo (template provided in `templates/`).

### 2. Import resolver in your agent

```typescript
import { resolveOperationContext } from 'skills/operation-context-resolver';

const context = await resolveOperationContext({
  github_event_payload: process.env.GITHUB_EVENT,
  github_ref: process.env.GITHUB_REF,
  user_intent: 'troubleshoot login timeout'
});

// Now context has:
// - target_environment
// - allowed_actions
// - blocked_actions
// - human_approval_required
// etc.
```

### 3. Check permissions before action

```typescript
if (!context.isActionAllowed('read_logs')) {
  throw new Error(`Action blocked: read_logs not in allowed_actions`);
}

if (context.human_approval_required && context.target_environment === 'prod') {
  console.log(`⚠️  Production operation requires human approval`);
}
```

## Key Features

- **Deterministic routing**: Branch name, PR labels, incident keywords → environment
- **Explicit permissions**: Define allowed/blocked actions per environment and mode
- **Human gates**: Production operations require approval by default
- **Incident override**: Keywords like "site is down in prod" override branch context
- **Audit trail**: Operation context is immutable JSON; can be logged and reviewed
- **Extensible**: Add custom modes, rules, and fields without breaking changes

## Inputs

| Input | Type | Example | Purpose |
|-------|------|---------|---------|
| `github_event_payload` | JSON | `github.event` | Extract branch, SHA, PR labels |
| `github_ref` | string | `refs/heads/main` | Determine branch/tag |
| `user_intent` | string | "site is down in prod" | Keyword matching for incident |
| `pr_labels` | string[] | `["env:prod"]` | Explicit environment signal |
| `workflow_dispatch_input` | object | `{ environment: "staging" }` | Human override |

## Output

```json
{
  "request": "user request or trigger",
  "operation_id": "UUID for audit",
  "target_environment": "preview|dev|staging|prod",
  "github_environment": "preview|dev|staging|production",
  "azure_subscription": "...",
  "resource_group": "...",
  "production": false,
  "risk_level": "low|medium|high|critical",
  "mode": "read_only|branch_deploy|incident_readonly",
  "allowed_actions": ["read_logs", "read_deployments"],
  "blocked_actions": ["prod_deploy", "migrate_db"],
  "human_approval_required": false,
  "incident_mode": false,
  "resolved_at": "ISO8601 timestamp",
  "resolver_version": "1.0.0"
}
```

## Decision Logic

Resolver uses this priority:

1. Human-provided override (workflow_dispatch input)
2. Incident keywords ("site is down", "customers cannot access")
3. PR labels (`env:prod`, `env:staging`)
4. GitHub deployment records for commit SHA
5. Branch patterns (matched against environment-map.yml)
6. Default to safe mode (read-only, non-prod)

## See Also

- [Integration Guide](./README.md)
- [Environment Map Template](./templates/environment-map.yml)
- [TypeScript Types](./src/types.ts)
