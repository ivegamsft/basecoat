---
description: "Prepare a safe, environment-specific GitHub OAuth App configuration for a downstream BaseCoat Portal without exposing credentials or changing settings before approval."
model: claude-sonnet-5
tools: ["codebase", "terminal", "githubRepo"]
---

# Onboard Portal GitHub OAuth

Use this prompt to prepare or review GitHub OAuth App configuration for the
legacy BaseCoat Portal user-login flow.

## Prompt

Plan GitHub OAuth App onboarding for this repository's BaseCoat Portal using
`docs/guides/portal-github-oauth-onboarding.md`.

1. Identify the Portal API URL, frontend URL, and exact callback URL for each
   requested environment.
2. Confirm this is Portal user authentication, not Azure deployment OIDC, a
   workflow PAT, or the BaseCoat Copilot Extension GitHub App.
3. Produce the GitHub administrator handoff, required environment variable
   names, secret-store boundary, and validation steps.
4. Check readiness through `/auth/github/availability` without printing
   secrets, tokens, or populated environment files.
5. Report blockers and the smallest safe remediation.

Do not create OAuth Apps, create secrets, change GitHub settings, expose
credentials, or add an authentication bypass. Stop before any external
configuration change and request approval.
