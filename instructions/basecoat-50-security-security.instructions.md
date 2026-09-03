---
description: "Use when working on authentication, authorization, secrets, input handling, or any change with security implications. Covers common secure coding best practices."
applyTo: "**/*.{cs,csproj,fs,fsproj,ts,tsx,js,jsx,py,go,java,kt,rb,php,rs,sql,bicep,tf}"
---

# Security Standards

Use this instruction for any change that touches trust boundaries, data handling, or privileged behavior.

## Expectations

- Validate untrusted input at system boundaries and encode output for its destination context.
- Do not hardcode secrets, tokens, certificates, or connection strings.
- Do not include secrets, tokens, keys, passwords, or connection strings in commit messages.
- Do not include PII or production identifiers in commit messages.
- Prefer least privilege for identities, roles, API scopes, and data access.
- Fail closed when authorization or required security context is missing.
- Avoid logging sensitive values, security tokens, or personal data unless explicitly required and protected.
- Prefer platform security primitives over custom cryptography or homegrown auth flows.

## OIDC Federation for Azure Authentication

- All GitHub Actions workflows authenticating to Azure **must** use OIDC federated credentials via `azure/login@v2`.
- Storing service principal client secrets (`AZURE_CLIENT_SECRET`) as GitHub Secrets is **forbidden**.
- Workflows must include `permissions: id-token: write` to enable OIDC token issuance.
- Only non-secret identifiers (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) may be stored as GitHub Secrets.
- See [`docs/guardrails/oidc-federation.md`](../docs/guardrails/oidc-federation.md) for the full bootstrap pattern and rationale.

## VS Code Agent Mode Tool Confirmation

- In VS Code agent mode, tools with side effects must require explicit user confirmation before execution.
- Treat all mutating tool actions as confirm-required by default; allow unconfirmed execution only for strictly read-only tools.
- Require confirmation re-prompting when action targets or arguments materially change after an initial approval.
- Rejecting confirmation must cancel execution with no silent fallback path.
- Follow the full policy and risk-tier definitions in [`docs/reference/guardrails/tool-confirmation-policy.md`](../docs/reference/guardrails/tool-confirmation-policy.md).

## Review Lens

- What are the trust boundaries in this change?
- Can a caller bypass validation or authorization through alternate paths?
- Are secrets handled through configuration and secret stores rather than source control?
- Does the commit message contain any secret-like data or PII?
- Does the change expand attack surface through deserialization, shelling out, dynamic code, or unsafe parsing?

## Workflow Secrets

GitHub Actions workflow files (`*.yml` / `*.yaml` in `.github/workflows/`) must never contain hardcoded secrets, tokens, passwords, or connection strings — not in `env` blocks, `with` parameters, or `run` scripts.

- All sensitive values must be referenced via `${{ secrets.SECRET_NAME }}`.
- Treat any literal credential in a workflow file as a leaked secret — rotate immediately.
- See the full guardrail document: [`docs/guardrails/secrets-in-workflows.md`](/docs/guardrails/secrets-in-workflows.md).

## Commit Message Guardrails

- Keep commit messages descriptive but non-sensitive.
- Reference issue IDs or work items instead of embedding payloads, tokens, emails, or credentials.
- If a commit message accidentally contains sensitive content, rewrite history immediately and rotate affected credentials.

## Browser Storage Threat Model

Client-side storage (`localStorage`, `sessionStorage`, `IndexedDB`, cookies) is accessible to any script running in the page origin — including XSS payloads and malicious dependencies.

- **Never** store authentication tokens (JWTs, access tokens, refresh tokens) in `localStorage` or `sessionStorage`.
- **Never** store secrets, API keys, or PII in any browser storage mechanism.
- Prefer `httpOnly` + `secure` + `SameSite=Strict` cookies for session tokens — they are inaccessible to JavaScript.
- If client-side storage is unavoidable for non-secret data, treat every read as untrusted input and validate/sanitize before use.
- Clear sensitive storage on logout: call `localStorage.clear()`, `sessionStorage.clear()`, and revoke server sessions.

### Review Lens — Browser Storage

- Does any client-side code write tokens, secrets, or PII to `localStorage`, `sessionStorage`, or `IndexedDB`?
- Are session tokens stored in `httpOnly` cookies rather than JavaScript-accessible storage?
- Is stored data validated on read, not assumed safe?
