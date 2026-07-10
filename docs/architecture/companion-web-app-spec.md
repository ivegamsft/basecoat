# Companion Web App Specification

## Purpose

Define a companion web app that provides an operational surface for BaseCoat governance assets, workflow telemetry, and release/compliance controls.

This is a phase-1 specification and scaffolding baseline. It is intentionally implementation-ready without forcing a full runtime migration in one sprint.

## Product Scope

### In Scope (Phase 1)

1. App domain model and folder boundaries
2. Backend/dashboard/database/IaC grouping model
3. Workflow model for CI, preview, deployment, and smoke checks
4. Alignment with existing `portal/` components and MCP IaC patterns

### Out of Scope (Phase 1)

1. Full runtime migration of existing `portal/frontend`, `portal/backend`, and `portal/ui`
2. Feature-by-feature UI parity implementation
3. Multi-cloud rollout

## Proposed App Topology

```text
portal/
  app/
    backend/      # API services, auth, persistence layer interfaces
    dashboard/    # web UI shell and feature modules
    db/           # schema, migrations, seed, backup/restore helpers
    iac/          # app-specific IaC modules, environment params, deploy notes
```

## Architecture Boundaries

### Backend

- Exposes health, auth/session, and governance API endpoints
- Owns persistence integrations and application business logic
- Publishes operational health for workflow smoke checks

### Dashboard

- Presents operational and governance views
- Uses backend APIs only (no direct DB coupling)
- Encapsulates admin and compliance user flows

### Database

- Versioned schema and migration assets
- Seed and backup/restore helpers
- Explicit environment separation in scripts/config

### IaC

- Deploys companion app infrastructure by environment
- Reuses existing repo patterns (Bicep-first where already established)
- Keeps sensitive config out of source; environment variables/secrets only

## Non-Functional Requirements

1. Secure by default configuration (no hardcoded credentials)
2. Deterministic CI validation for app, db, and IaC changes
3. Environment-specific deployment workflow (staging/prod)
4. Health and smoke checks as release gates

## Delivery Plan

### Sprint A (Current)

- Publish spec and folder scaffold
- Publish workflow plan
- Define migration map from current portal folders

### Sprint B

- Move/alias DB assets into `portal/app/db`
- Create app CI workflow and staging preview workflow
- Add smoke tests for backend + dashboard health endpoints

### Sprint C

- Introduce app deploy workflow with environment approvals
- Add release packaging handoff for companion app artifacts

## Migration Map (Current to Target)

| Current path | Target path | Strategy |
|---|---|---|
| `portal/backend/` | `portal/app/backend/` | staged move after CI coverage |
| `portal/frontend/` | `portal/app/dashboard/` | staged move after route parity |
| `portal/backend/db/` | `portal/app/db/` | phase-in with migration scripts |
| `infra/*` app-specific modules | `portal/app/iac/` | app IaC co-location where applicable |

## Acceptance Criteria (Phase 1)

1. Companion app spec exists and is discoverable
2. Folder scaffold exists under `portal/app/`
3. Workflow plan exists and references current repo workflow assets
4. No runtime paths are broken by the scaffold-only changes

