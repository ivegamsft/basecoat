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

- Contents: **Read-only**
- Pull requests: **Read and write**
- Actions: **Read and write**
- Metadata: **Read-only** (implicit)

### Organization Permissions

- Members: **Read-only** (recommended for org-scoped eligibility checks)

### Subscribe to Events

- `pull_request`
- `pull_request_review`
- `workflow_run`
- `installation`
- `installation_repositories`

## Handoff Checklist (Owner + Outcome)

1. **Org Owner/Admin**: Create GitHub App using this runbook and `docs/templates/copilot-extension/github-app-registration.template.json`.
2. **Platform Engineer**: Configure ACA env vars from generated App credentials (`APP_ID`, `CLIENT_ID`, `CLIENT_SECRET`, `WEBHOOK_SECRET`, `PRIVATE_KEY`).
3. **Org Owner/Admin**: Install App on `IBuySpy-Shared` org with target repo access (`basecoat`, extension backend repo when created).
4. **Platform Engineer**: Configure Copilot Extension registration to target `<ACA_BASE_URL>`.
5. **QA/Platform**: Validate invocation path (`@basecoat`) and verify tool calls reach backend.
6. **Maintainer**: Update issue #1127 with App ID, installation link, and validation evidence; then close #1127 and #1073.

## Validation Steps After Admin Work

1. Confirm App is installed on `IBuySpy-Shared`.
2. Confirm extension endpoint responds at health route.
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
