---
name: operation-context-resolver
compatibility: [github-copilot-cli]
description: "Resolve deterministic environment context for branch, label, and incident driven workflows using environment-map.yml, returning target environment, operation mode, and action permissions. USE FOR: resolving preview/dev/staging/prod target before troubleshooting or deployment, enforcing allowed and blocked action checks, applying incident-readonly routing, validating human approval requirements for risky actions. DO NOT USE FOR: direct infrastructure mutation without policy checks, replacing platform branch protection controls, or bypassing environment-map validation."
category: platform-governance

metadata:
  category: platform-governance
  domain: platform-governance
  maturity: production
  audience:
    - maintainer
    - operator
allowed-tools:
  - bash
  - git
  - gh
visibility: public
---
# Operation Context Resolver

Routes a request to the correct environment and mode, then returns allowed and blocked actions.

## Inputs

- `github_ref`, `github_event_payload`, `pr_labels`
- `user_intent` for incident keyword routing
- `workflow_dispatch_input.environment` for explicit override

## Output

`OperationContext` includes (and can be emitted as `operation-context.json` from the CLI):

- `target_environment`, `mode`, `risk_level`
- `allowed_actions`, `blocked_actions`
- `human_approval_required`, `incident_mode`

## Behavior order

1. Explicit workflow override
2. Incident keyword override
3. Environment labels
4. YAML rules from `environment-map.yml`
5. Branch pattern matching
6. Safe default (`dev`, `read_only`)

## Usage

```typescript
import fs from 'fs';
import { resolveOperationContext } from '@basecoat/operation-context-resolver';

const githubEventPayload = process.env.GITHUB_EVENT_PATH
  ? fs.readFileSync(process.env.GITHUB_EVENT_PATH, 'utf-8')
  : undefined;

const context = await resolveOperationContext({
  github_ref: process.env.GITHUB_REF,
  github_event_name: process.env.GITHUB_EVENT_NAME,
  github_event_payload: githubEventPayload,
  user_intent: "troubleshoot login timeout",
  pr_labels: ["env:staging"],
});

const isActionAllowed =
  context.allowed_actions.includes("read_logs") &&
  !context.blocked_actions.includes("read_logs");
```

## Artifacts

- Template: `templates/environment-map.yml`
- Guide: `README.md`
- Types: `src/types.ts`
