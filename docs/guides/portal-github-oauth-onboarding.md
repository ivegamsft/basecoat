# Portal GitHub OAuth Onboarding

Use this guide when a downstream repository runs the legacy BaseCoat Portal
(`portal/frontend` and `portal/backend`) and needs browser sign-in.

## Scope and ownership

The Portal supports a standard **GitHub OAuth App** for human sign-in. This is
separate from:

- the Azure Entra application registration and OIDC federation created by
  `scripts/bootstrap.ps1` for deployment;
- the BaseCoat Copilot Extension GitHub App; and
- personal access tokens used by workflows or package pulls.

An organization or application administrator must create the OAuth App and
store its client secret in the environment that runs the Portal. BaseCoat
onboarding does not create OAuth Apps or copy their credentials to downstream
repositories.

## Prerequisites

Before configuration, identify:

| Item | Local development value | Hosted environment value |
|---|---|---|
| Portal API URL | `http://localhost:3000` | Public HTTPS API URL |
| Portal frontend URL | `http://localhost:5173` | Public HTTPS frontend URL |
| OAuth callback URL | `http://localhost:3000/auth/github/callback` | `<API_URL>/auth/github/callback` |
| Credential owner | Repository/application administrator | Organization/application administrator |

Use distinct OAuth Apps for local development, staging, and production. Do not
use a production client secret locally, and do not commit a client secret,
access token, private key, or populated `.env` file.

## Create the OAuth App

1. Sign in to the GitHub account or organization that will own the Portal
   login integration.
2. Open **Settings** > **Developer settings** > **OAuth Apps** > **New OAuth
   App**.
3. Enter an environment-specific application name, for example
   `Contoso BaseCoat Portal - Development`.
4. Set the homepage URL to the Portal frontend URL.
5. Set the authorization callback URL to the Portal API callback URL.
6. Register the application and copy the generated client ID.
7. Generate a client secret and store it immediately in the approved secret
   store. GitHub shows the secret only once.

The current Portal requests only the `user:email` scope. Review any proposed
scope expansion as an application security change.

## Configure the Portal

For local development, create `portal/backend/.env` from the checked-in
template:

```powershell
Copy-Item portal\backend\.env.example portal\backend\.env
```

Set the OAuth values and URLs for the active environment:

```dotenv
PORT=3000
GITHUB_CLIENT_ID=<client-id-from-the-oauth-app>
GITHUB_CLIENT_SECRET=<secret-from-your-approved-secret-store>
GITHUB_CALLBACK_URL=http://localhost:3000/auth/github/callback
FRONTEND_URL=http://localhost:5173
```

For hosted environments, supply the same values through the platform's secret
and environment configuration. The client secret belongs in a secret store;
the client ID, callback URL, and frontend URL may be ordinary environment
variables when that matches local policy.

Start the legacy Portal services:

```powershell
Set-Location portal\backend
npm run dev

# In a separate terminal
Set-Location portal\frontend
npm run dev
```

## Validate the configuration

Check OAuth readiness before opening the browser:

```powershell
Invoke-RestMethod http://localhost:3000/auth/github/availability
```

Expected result:

```json
{ "data": { "configured": true } }
```

Then visit `http://localhost:5173/login`, select **Sign in with GitHub**, and
complete sign-in. A successful callback returns to
`http://localhost:5173/auth/callback`, which stores the issued Portal token
and opens the authenticated application.

When credentials are absent, malformed, or placeholders, the API returns
`503 GITHUB_OAUTH_NOT_CONFIGURED` from `/auth/github` and the login page
disables the sign-in button. Configure both client values; do not work around
the error by adding a test credential or bypass.

## Troubleshooting

| Symptom | Likely cause | Remediation |
|---|---|---|
| Sign-in button is disabled | Client ID or secret is absent, placeholder, or unreachable from the API | Confirm both variables are available in the backend process and restart it. |
| GitHub reports callback mismatch | OAuth App callback URL differs from `GITHUB_CALLBACK_URL` | Make the values identical, including scheme, host, port, and path. |
| Callback completes but browser does not enter Portal | `FRONTEND_URL` does not match the served frontend origin | Set `FRONTEND_URL` to the exact frontend origin and retry. |
| User sign-in fails after callback | Portal database is unavailable or migrations are missing | Restore PostgreSQL connectivity, run the documented migrations, and retry. |
| A secret appears in output or source control | Credential exposure | Revoke and regenerate the exposed secret, remove it from the unsafe location, and follow the incident procedure. |

## Handoff checklist

Before marking a downstream Portal onboarding complete:

1. Record the OAuth App owner, environment, and callback URL in the
   downstream runbook without recording the client secret.
2. Confirm the backend readiness endpoint reports `configured: true`.
3. Complete a browser login with a permitted test account.
4. Confirm the callback returns to the expected frontend origin.
5. Confirm no populated `.env` file or credential value was committed.
6. Capture the credential rotation owner and schedule in the downstream
   secret-management system.

## Copy-ready prompts

### Plan provisioning

```text
plan: prepare GitHub OAuth App onboarding for this repository's BaseCoat Portal.

Use docs/guides/portal-github-oauth-onboarding.md. Inventory the frontend and
backend URLs, identify the required callback URL, distinguish Portal user-login
OAuth from Azure deployment OIDC and workflow credentials, and produce a
least-privilege secret-handling plan. Do not create an OAuth App, expose a
secret, edit environment files, or change GitHub settings.
```

### Review a proposed configuration

```text
audit: review this proposed BaseCoat Portal GitHub OAuth configuration against
docs/guides/portal-github-oauth-onboarding.md. Verify callback and frontend
URLs, environment separation, secret-storage boundaries, and that it does not
reuse deployment OIDC, a PAT, or the Copilot Extension GitHub App. Read-only;
return findings and remediations only.
```

### Diagnose an unavailable login

```text
bug: diagnose why BaseCoat Portal GitHub sign-in is unavailable. Start by
calling /auth/github/availability and inspecting non-secret environment
presence, callback URL alignment, frontend origin, and database readiness.
Never print credentials or tokens. Make the smallest safe configuration or
code change only after recording the work item and presenting evidence.
```

