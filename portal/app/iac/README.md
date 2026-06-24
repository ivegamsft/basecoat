# Portal App IaC Boundary

Use this folder for portal app infrastructure-as-code modules, environment
parameters, and deployment notes.

## Layout

- `main.bicep` — staging composition entrypoint
- `modules/container-registry.bicep` — Azure Container Registry module
- `modules/backend-container-app.bicep` — backend Container App module
- `modules/frontend-container-app.bicep` — frontend Container App module
- `modules/postgresql-flexible-server.bicep` — PostgreSQL Flexible Server module

## Architecture

Images are pushed to an Azure Container Registry (ACR) deployed by this template.
Container Apps pull images via system-assigned managed identity with AcrPull role —
no registry credentials are stored as secrets.

## Deployment boundary modes

Portal IaC now models two explicit deployment modes:

- `internal` — default mode for BaseCoat-owned staging deployment
- `downstream` — constrained mode intended for consumer-aligned deployment paths

Mode is passed from `.github/workflows/portal-deploy.yml` to `main.bicep` as
`deploymentMode`. Resource naming, ingress posture, and PostgreSQL public access
are mode-gated to prevent mixed-mode resource composition in one deployment.

The portal deploy workflow enforces guardrails:

- push-triggered runs are internal mode only
- downstream mode cannot target the internal default resource group

## Staging deploy

The repo workflow `.github/workflows/portal-deploy.yml`:

1. Provisions infrastructure (ACR, Log Analytics, Container Apps Environment, PostgreSQL)
2. Builds and pushes images to ACR using OIDC-authenticated `az acr login`
3. Deploys the full stack with image tags, assigns AcrPull roles to Container App identities
4. Deploys Application Insights linked to Log Analytics and wires telemetry settings to apps
5. Smoke-tests the exposed endpoints

Required repo variables:

- `AZURE_CLIENT_ID` — OIDC client ID
- `AZURE_TENANT_ID` — Entra tenant ID
- `AZURE_SUBSCRIPTION_ID` — target Azure subscription

Optional overrides:

- `PORTAL_RESOURCE_GROUP` — defaults to `basecoat-portal-staging-rg`
- `PORTAL_AZURE_LOCATION` — defaults to `eastus`
- `PORTAL_POSTGRES_ADMIN_PASSWORD` — if omitted, `main.bicep` generates a secure password per deployment
