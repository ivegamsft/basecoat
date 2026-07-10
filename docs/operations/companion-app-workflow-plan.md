# Companion App Workflow Plan

## Goal

Define a workflow model for the companion web app that aligns with existing BaseCoat CI/CD governance and introduces app-focused validation/deployment stages.

## Existing Workflow Baseline

Relevant current workflows:

- `ci.yml` (repo-wide validation)
- `pr-validation.yml` (pull request checks)
- `publish-to-production.yml` (production publishing)
- `mcp-build.yml` / `mcp-deploy.yml` (IaC + deploy pattern reference)
- `docs.yml` (docs publish model)

## Planned Companion App Workflow Set

| Workflow | Trigger | Responsibility | Gate Type |
|---|---|---|---|
| `companion-app-ci.yml` | PR + push on app paths | lint/type/test for backend/dashboard/db/iac | required |
| `companion-app-preview.yml` | PR on app paths | ephemeral preview environment deployment | optional/visibility |
| `companion-app-deploy.yml` | main + manual dispatch | staging/prod deployment for app resources | required |
| `companion-app-smoke.yml` | post-deploy | health and basic flow verification | required |

## Path Filters (Phase 1)

```text
portal/app/**
portal/backend/**
portal/frontend/**
portal/ui/**
infra/**
```

## Deployment Flow

1. PR runs `companion-app-ci.yml`
2. Optional preview deploy runs for feature branches
3. Merge to `main` triggers staging deploy
4. Manual/approved promotion triggers prod deploy
5. Smoke checks gate release completion

## Security and Secrets Posture

1. No secrets in workflow YAML or compose files
2. Environment secrets in GitHub environments/secrets
3. Explicit secret scanning as a required check

## IaC Plan

1. Keep MCP IaC under `infra/mcp/` unchanged
2. Add companion-app IaC modules under `portal/app/iac/` for app-specific resources
3. Use environment parameter files and explicit outputs for health endpoints

## Rollout Notes

Phase 1 is planning + scaffolding only. Workflow files should be introduced in sequence:

1. CI first
2. Staging deploy
3. Prod deploy + smoke

