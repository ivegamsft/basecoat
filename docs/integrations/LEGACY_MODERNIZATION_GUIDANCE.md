# Legacy Modernization Guidance

This guide closes the oldest modernization backlog items by providing one shared
set of migration patterns for the legacy stacks BaseCoat sees most often:
Ruby on Rails, Django, Node.js/Express, SharePoint 2013, Classic ASP, UWP, and
cross-stack Entra ID OIDC.

## Backlog Coverage

| Issue | Coverage |
|---|---|
| #898 | Ruby on Rails Azure App Service migration guidance |
| #899 | Python/Django Azure web application migration guidance |
| #900 | Cross-stack Entra ID OIDC integration patterns |
| #901 | Node.js/Express Azure migration guidance |
| #902 | SharePoint 2013 → SPFx / Azure migration guidance |
| #903 | Classic ASP (VBScript) modernization guidance |
| #904 | UWP modernization guidance |

## Shared modernization rules

- Start with an app inventory and dependency map.
- Prefer strangler-fig routing for user-facing traffic.
- Add an anti-corruption layer around legacy APIs and data models.
- Externalize sessions before scaling to multiple instances.
- Use Entra ID OIDC for interactive user authentication.
- Keep secrets in Key Vault or managed configuration, never in source.

## Stack guidance

### Ruby on Rails

- Target Azure App Service for Linux or Azure Container Apps.
- Externalize sessions to Redis.
- Move databases to Azure Database for PostgreSQL Flexible Server.
- Use `omniauth-azure-activedirectory-v2` for Entra ID sign-in.
- See `instructions/ruby-on-rails.instructions.md` and
  `instructions/entra-oidc-user-auth.instructions.md`.

### Django

- Target Azure App Service for Linux or Azure Container Apps.
- Use PostgreSQL Flexible Server instead of SQLite in production.
- Externalize sessions with `django-redis`.
- Use `social-auth-app-django` or `django-allauth` for Entra ID sign-in.
- See `instructions/django.instructions.md` and
  `instructions/entra-oidc-user-auth.instructions.md`.

### Node.js and Express

- Prefer Azure App Service for Linux or Azure Container Apps.
- Move callback-heavy code toward async/await and ESM where practical.
- Use `@azure/msal-node` for user sign-in and `passport-azure-ad` for API
  protection.
- Externalize sessions with `express-session` plus Redis.
- See `instructions/entra-oidc-user-auth.instructions.md`.

### SharePoint 2013

- Inventory farm solutions, custom web parts, event receivers, and workflows
  before choosing a target.
- Replace page customizations with SPFx where possible.
- Move business logic into Azure APIs or Power Platform instead of farm code.
- Treat custom full-trust assemblies as a blocker for simple lift-and-shift.
- Use phased coexistence while content and workflows are migrated.

### Classic ASP and VBScript

- Freeze new VBScript features and wrap the legacy site behind a routing layer.
- Extract database access into a separate service or repository boundary.
- Replace inline authentication with Entra ID sign-in at the edge.
- Modernize one page or endpoint at a time into ASP.NET Core, Node, or another
  supported web stack.
- Treat COM dependencies and ad-hoc server-side includes as migration risk.

### UWP

- Prefer WinUI 3 for Windows-only desktop modernization.
- Use .NET MAUI when cross-platform support is required and API parity exists.
- Move shared business logic into class libraries before rewriting UI shells.
- Isolate UWP-only APIs behind adapters so they can be swapped incrementally.
- Treat hardware-specific or shell-specific APIs as blockers until alternatives
  are validated.

## Cross-stack Entra ID OIDC patterns

| App type | Recommended flow | Notes |
|---|---|---|
| Server-rendered web app | Authorization Code Flow with a confidential client | Best fit for Rails, Django, and Express server apps |
| SPA | Authorization Code Flow with PKCE | Keep tokens in memory; do not use `localStorage` |
| Desktop app | Authorization Code Flow with PKCE | Use the system browser and a public client |
| API | Bearer token validation | Validate `iss`, `aud`, `exp`, and `nonce` server-side |

## Blockers

These conditions require an explicit migration plan before a simple modernization
path can be claimed:

- SharePoint farm solutions or full-trust code
- Classic ASP pages tightly coupled to COM components
- UWP-only APIs with no WinUI 3 or MAUI equivalent
- Legacy apps that cannot externalize sessions or token caches

When one of these blockers exists, document the phased replacement path instead
of recommending a one-step rewrite.
