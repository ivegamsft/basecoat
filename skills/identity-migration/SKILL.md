---
name: identity-migration
compatibility: [github-copilot-cli]
title: Identity Migration to ASP.NET Core & Entra ID
description: "Use when migrating legacy authentication to ASP.NET Core Identity with Entra ID, claims transformation, password hash compatibility, and hybrid auth flows. USE FOR: migrate ASP.NET Membership users, preserve legacy password verification, integrate Entra ID OIDC with Identity, convert roles to claims, plan hybrid local and Entra authentication. DO NOT USE FOR: non-.NET identity stacks, frontend-only login widgets, generic network access control."
category: security
metadata:
  category: security
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# Identity Migration Skill

Migrate legacy ASP.NET Membership systems to ASP.NET Core Identity with Azure Entra ID
integration. Covers user model conversion, password hash compatibility, claims-based auth,
role migration, OIDC setup, and hybrid local + Entra ID scenarios.

## Reference Files

| File | Contents |
|------|----------|
| [`references/migration-patterns.md`](references/migration-patterns.md) | User model migration, DB steps, password hash compatibility, claims, role migration |
| [`references/azure-integration.md`](references/azure-integration.md) | Entra ID OIDC, Azure AD config, hybrid auth, OAuth2 providers, token refresh |
| [`references/testing-checklist.md`](references/testing-checklist.md) | Migration checklist, test scenarios, rollback plan |

## Key Patterns

- **LegacyPasswordHasher** — falls back to PBKDF2 verification; upgrades hash on login
- **IClaimsTransformation** — converts Identity roles to claims on each request
- **Hybrid auth** — `AddCookie` + `AddMicrosoftIdentityWebApp` for local + Entra ID
- **Never store secrets** in `appsettings.json` — use Key Vault or environment variables
