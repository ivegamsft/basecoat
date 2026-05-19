# Portal App IaC Boundary

Use this folder for portal app infrastructure-as-code modules, environment
parameters, and deployment notes.

## Layout

- `main.bicep` — staging composition entrypoint
- `modules/backend-container-app.bicep` — backend Container App module
- `modules/frontend-container-app.bicep` — frontend Container App module
- `modules/postgresql-flexible-server.bicep` — PostgreSQL Flexible Server module

## Staging deploy

The repo workflow `.github/workflows/portal-deploy.yml` builds the backend and
dashboard images, deploys `main.bicep`, and smoke-tests the exposed endpoints.

Required secrets and vars:

- `AZURE_CLIENT_ID` (repo variable; OIDC client ID)
- `AZURE_TENANT_ID` (repo variable; Entra tenant ID)
- `AZURE_SUBSCRIPTION_ID` (repo variable; target Azure subscription)
- Container registry credentials use the workflow's built-in `GITHUB_TOKEN` (no separate PAT)
- `PORTAL_RESOURCE_GROUP` (optional, defaults to `basecoat-portal-staging-rg`)
- `PORTAL_AZURE_LOCATION` (optional, defaults to `eastus`)

Optional override:

- `PORTAL_POSTGRES_ADMIN_PASSWORD` — if omitted from workflow parameters, `main.bicep` generates a secure admin password per deployment.
