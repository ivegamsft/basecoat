# Environment Protection Baseline

This baseline defines required protection controls for all deployment environments used by BaseCoat workflows.

## Environment tiers and intent

| Environment | Purpose | Approval requirement | Branch policy |
|---|---|---|---|
| `dev` | Early validation and integration | Optional | Any branch for workflow-dispatch testing |
| `staging` | Pre-production validation | Optional (recommended for regulated repos) | `main` and release/hotfix branches only |
| `production` (`prod` alias) | Production-facing deployments | Required manual approval | Protected branches only (`main`, `release/*`, `hotfix/*`) |

## Mandatory production protections

Production (`production`, with `prod` as optional alias) environments must enforce all of the following — manual approvals are required for any release to proceed:

1. Manual approvals are required before deployment jobs start.
2. Deployment is restricted to protected branches or explicitly listed branch patterns.
3. Workflow jobs targeting production use an explicit GitHub environment (`environment: production` preferred).
4. Production deployment configuration is sourced from protected environment secrets/variables, not inline literals.
5. Approval and deployment history remains available in GitHub environment audit trails.

## Manual approval policy

- At least one required reviewer is configured on `production` (or `prod` where still in use).
- Required reviewers should map to release owners or on-call maintainers.
- Self-approval should remain disabled when repository settings support it.
- Emergency bypasses are allowed only when documented in an incident or release issue.

Risk-tier and profile selection for non-production flows are defined in
`docs/reference/governance-policy-packs.md` and
`.github/governance/policy-packs.json`.

## Protected environment variables and secrets

The `production` environment is the source of truth for production deployment values:

- Environment-scoped credentials and tokens
- Environment-specific resource identifiers
- Tenant, subscription, and deployment target configuration

Do not place production values directly in workflow YAML, repository-level variables, or scripts when environment-scoped protection is available.

## Branch-specific deployment rules

Production deployment environments must enable branch restrictions that align with protected release paths:

- `main`
- `release/*`
- `hotfix/*`

Any additional production branch pattern requires a governance update in this file and an associated issue.

## Approval and deployment audit trail

Use GitHub environment deployment history as the canonical approval ledger:

- Who approved production deployment
- Which workflow and run triggered deployment
- Which commit SHA and branch were deployed
- When deployment completed

This audit trail must be retained and referenced during incident review and release retro activities.
