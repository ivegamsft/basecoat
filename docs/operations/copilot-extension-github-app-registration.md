# Copilot Extension GitHub App Registration Runbook

This runbook tracks issue [#1073](https://github.com/IBuySpy-Shared/basecoat/issues/1073) and follow-up execution issue [#1127](https://github.com/IBuySpy-Shared/basecoat/issues/1127), and captures the exact handoff needed to register the BaseCoat Copilot Extension GitHub App.

## Scope

- In-repo work (done here): registration checklist, validation steps, and config scaffolding
- External org-admin work (required): creating and installing the GitHub App in `IBuySpy-Shared`

## Required App Configuration

Use these baseline settings when creating the App:

| Setting | Value |
|---|---|
| App name | `BaseCoat Copilot Extension` |
| Description | `Org-scoped Copilot Extension backend for BaseCoat assets and workflows.` |
| Homepage URL | `https://github.com/IBuySpy-Shared/basecoat` |
| Callback URL | `<ACA_BASE_URL>/api/github/oauth/callback` |
| Setup URL | `<ACA_BASE_URL>/api/github/setup` |
| Webhook URL | `<ACA_BASE_URL>/api/github/webhook` |
| Webhook secret | Generate in org vault; do not store in git |
| User authorization callback URL | `<ACA_BASE_URL>/api/github/oauth/callback` |

### Repository Permissions

Grant these permissions exactly:

- `contents`: **read**
- `pull_requests`: **write**
- `actions`: **write**

`metadata:read` remains implicit and does not require a separate grant.

### Subscribe to Events

- `pull_request`
- `pull_request_review`
- `workflow_run`
- `installation`
- `installation_repositories`

## Handoff Checklist (Owner + Outcome)

1. **Org Owner/Admin**: Create GitHub App using this runbook and `docs/templates/copilot-extension/github-app-registration.template.json`.
2. **Org Owner/Admin**: Configure callback/setup/webhook URLs to deployed extension endpoints.
3. **Org Owner/Admin**: Install App on `IBuySpy-Shared` org and confirm installation scope.
4. **Org Owner/Admin**: Share App metadata with maintainers: App ID, Client ID, Installation ID.
5. **Platform Engineer**: Configure ACA secrets/env vars:
   - `BASECOAT_EXTENSION_APP_ID`
   - `BASECOAT_EXTENSION_CLIENT_ID`
   - `BASECOAT_EXTENSION_CLIENT_SECRET`
   - `BASECOAT_EXTENSION_WEBHOOK_SECRET`
   - `BASECOAT_EXTENSION_PRIVATE_KEY_PEM`
6. **Maintainer**: Validate `GET /api/github/oauth/request` and `GET /api/github/oauth/callback` in deployed environment.
7. **Maintainer**: Validate webhook signature verification using a signed test payload.
8. **Maintainer**: Capture evidence that `@basecoat` appears in Copilot Chat and link evidence to issue #1073.
2. **Platform Engineer**: Configure ACA env vars from generated App credentials (`APP_ID`, `CLIENT_ID`, `CLIENT_SECRET`, `WEBHOOK_SECRET`, `PRIVATE_KEY`).
3. **Org Owner/Admin**: Install App on `IBuySpy-Shared` org with target repo access (`basecoat`, extension backend repo when created).
4. **Platform Engineer**: Configure Copilot Extension registration to target `<ACA_BASE_URL>`.
5. **QA/Platform**: Validate invocation path (`@basecoat`) and verify tool calls reach backend.
6. **Maintainer**: Update issue #1127 with App ID, installation link, and validation evidence; then close #1127 and #1073.

## Validation Steps After Admin Work

1. Confirm App is installed on `IBuySpy-Shared` and installation scope is correct.
2. Confirm extension endpoint responds at health route.
3. Confirm `GET /api/github/oauth/request` returns an authorization URL and state.
4. Confirm `GET /api/github/oauth/callback` succeeds for a valid state/code path.
5. Confirm webhook signature verification succeeds with a signed test payload.
6. Confirm `@basecoat` appears in Copilot Chat and routes a test prompt.
7. Capture evidence in issue #1073 (screenshots/log snippets + app metadata).
3. Confirm OAuth callback succeeds for org member.
4. Confirm `@basecoat` appears in Copilot Chat and routes a test prompt.
5. Capture evidence in issue #1127 (screenshots/log snippets) and reference it from #1073.

## Blocking Criteria

Issue #1073 remains blocked until issue #1127 is completed with org-admin App creation and installation evidence.

## References

- Design: `docs/design/copilot-extension-prd.md`
- Blocked issues log: `docs/operations/BLOCKED_ISSUES.md`
- Config scaffold: `docs/templates/copilot-extension/github-app-registration.template.json`
- Follow-up tracker: `https://github.com/IBuySpy-Shared/basecoat/issues/1127`
