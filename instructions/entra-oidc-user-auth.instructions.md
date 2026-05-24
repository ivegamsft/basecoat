---
description: "Use when implementing human user authentication via browser — Authorization Code Flow with PKCE, confidential client flows, MSAL token caching, and Entra ID app registration. Complements bac-authentication.instructions.md which covers service-to-service managed identity."
applyTo: "**/auth/**,**/identity/**,**/*.bicep,**/iac/**,**/.github/workflows/**"
---

# Entra ID OIDC / OAuth 2.0 — User-Facing Authentication

Use this instruction when building or reviewing **human user authentication** flows
through a browser. This covers Authorization Code Flow (with and without PKCE),
token validation, session externalization, and per-stack wiring for Entra ID.

## When to Use This vs bac-authentication

| Scenario | Instruction file |
|---|---|
| Service accessing another Azure service (no human user) | `bac-authentication.instructions.md` |
| Human user signs in through a browser | **This file** |
| GitHub Actions authenticating to Azure | `security.instructions.md` (OIDC federation) |

Key distinction: `bac-authentication` uses **managed identity / workload identity**
(no user, no browser). This file covers **OAuth 2.0 Authorization Code Flow** where
a real person authenticates interactively.

## Core OIDC Concepts

### Authorization Code Flow with PKCE (Public Clients)

Use for **SPAs and mobile apps** — clients that cannot securely store a `client_secret`.

1. App generates a random `code_verifier` and derives `code_challenge = BASE64URL(SHA256(code_verifier))`.
2. App redirects the user to the Entra ID `/authorize` endpoint with `response_type=code`, `code_challenge`, and `code_challenge_method=S256`.
3. User authenticates; Entra ID redirects back with an authorization `code`.
4. App exchanges `code` + `code_verifier` for tokens at the `/token` endpoint — no `client_secret` required.

Never use the **Implicit Flow** (`response_type=token`) — it is deprecated and insecure for token delivery.

### Confidential Client Flow (Server-Rendered Apps)

Use for **server-rendered web apps** (Spring MVC, Django, Rails, Express with server-side rendering)
where the `client_secret` (or certificate) is stored securely on the server.

1. User is redirected to `/authorize` with `response_type=code`.
2. Server exchanges `code` + `client_secret` for tokens at `/token`.
3. Access token is used to call downstream APIs; ID token establishes the user session.

### Token Caching Strategies

- **In-process / in-memory**: Default for MSAL. Fine for single-instance deployments.
  Tokens are lost on restart and not shared across instances.
- **Redis-backed distributed cache**: Required for horizontally-scaled deployments
  (App Service multiple instances, Container Apps). All MSAL libraries support a
  pluggable token cache serialization interface.
- **Key rule**: Never persist tokens to `localStorage` or `sessionStorage` in the browser.
  Use `httpOnly` + `Secure` + `SameSite=Strict` cookies for session tokens, or keep
  them in memory only (MSAL browser default for access tokens).

### ID Token vs Access Token

| Token | Purpose | Who validates it |
|---|---|---|
| **ID token** | Who the user is — establishes identity for the app session | Your server validates it |
| **Access token** | Authorize calls to a downstream API | The target API validates it |

Critical claims to validate on every token received server-side:

- `iss` — must equal `https://login.microsoftonline.com/{tenant-id}/v2.0`
- `aud` — must equal your app's `client_id`
- `exp` — must be in the future
- `nonce` — must match the nonce sent in the original `/authorize` request
- `roles` — app-role claims for authorization decisions

Never trust claims that arrive in a query parameter or request body — only trust
decoded and signature-verified tokens from the JWKS endpoint.

### Entra ID App Registration Checklist

- Redirect URIs — register all exact callback URLs; wildcards are not permitted for
  production.
- Token version — set **v2.0** (`accessTokenAcceptedVersion: 2` in the manifest).
- API permissions — request only the minimum required scopes; prefer delegated over
  application permissions for user-context flows.
- App roles — define custom roles in the manifest and assign users/groups to them
  in Enterprise Applications.
- Certificates vs secrets — prefer certificate credentials over client secrets for
  confidential clients; rotate secrets on a defined schedule.
- Single-tenant vs multi-tenant — lock to `organizations` or a specific tenant ID
  unless multi-tenant is an explicit requirement.

## Stack-Specific Wiring

### Spring Boot

Dependencies: `spring-security-oauth2-client`, `spring-security-oauth2-jose`,
`com.azure.spring:spring-cloud-azure-starter-active-directory`.

```yaml
# application.yml
spring:
  security:
    oauth2:
      client:
        registration:
          azure:
            client-id: ${AZURE_CLIENT_ID}
            client-secret: ${AZURE_CLIENT_SECRET}
            scope: openid, profile, email
        provider:
          azure:
            issuer-uri: https://login.microsoftonline.com/${AZURE_TENANT_ID}/v2.0
```

Map Entra app roles to Spring Security authorities:

```java
@Bean
public GrantedAuthoritiesMapper authoritiesMapper() {
    return authorities -> authorities.stream()
        .filter(a -> a instanceof OidcUserAuthority)
        .flatMap(a -> {
            OidcIdToken token = ((OidcUserAuthority) a).getIdToken();
            List<String> roles = token.getClaimAsStringList("roles");
            return roles == null ? Stream.empty()
                : roles.stream().map(r -> new SimpleGrantedAuthority("ROLE_" + r));
        })
        .collect(Collectors.toSet());
}
```

Session externalization: use `spring-session-data-redis` with a Redis connection to
Azure Cache for Redis.

### Django

Option A — `social-auth-app-django` with the Microsoft OAuth2 backend:

```python
# settings.py
AUTHENTICATION_BACKENDS = ["social_core.backends.microsoft.MicrosoftOAuth2"]
SOCIAL_AUTH_MICROSOFT_GRAPH_KEY = env("AZURE_CLIENT_ID")
SOCIAL_AUTH_MICROSOFT_GRAPH_SECRET = env("AZURE_CLIENT_SECRET")
SOCIAL_AUTH_MICROSOFT_GRAPH_SCOPE = ["openid", "profile", "email"]

SOCIAL_AUTH_PIPELINE = (
    "social_core.pipeline.social_auth.social_details",
    "social_core.pipeline.social_auth.social_uid",
    "social_core.pipeline.social_auth.auth_allowed",
    "social_core.pipeline.social_auth.social_user",
    "social_core.pipeline.user.get_username",
    "social_core.pipeline.user.create_user",   # auto-create from claims
    "social_core.pipeline.social_auth.associate_user",
    "social_core.pipeline.social_auth.load_extra_data",
    "social_core.pipeline.user.user_details",
)
```

Option B — `django-allauth` with the Microsoft provider (simpler for new projects):

```python
INSTALLED_APPS += ["allauth.socialaccount.providers.microsoft"]
SOCIALACCOUNT_PROVIDERS = {
    "microsoft": {
        "APP": {
            "client_id": env("AZURE_CLIENT_ID"),
            "secret": env("AZURE_CLIENT_SECRET"),
        },
        "TENANT": env("AZURE_TENANT_ID"),
    }
}
```

Session externalization: `django-redis` as the `SESSION_ENGINE`.

```python
SESSION_ENGINE = "django.contrib.sessions.backends.cache"
SESSION_CACHE_ALIAS = "default"
CACHES = {
    "default": {
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": env("REDIS_URL"),
    }
}
```

### Ruby on Rails

Gem: `omniauth-azure-activedirectory-v2` + `devise` with OmniAuth integration.

```ruby
# config/initializers/devise.rb
config.omniauth :azure_activedirectory_v2,
  client_id:     ENV["AZURE_CLIENT_ID"],
  client_secret: ENV["AZURE_CLIENT_SECRET"],
  tenant_id:     ENV["AZURE_TENANT_ID"]
```

Register the callback route:

```ruby
# config/routes.rb
devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }
```

Handle the callback and create users from claims:

```ruby
# app/controllers/users/omniauth_callbacks_controller.rb
def azure_activedirectory_v2
  @user = User.from_omniauth(request.env["omniauth.auth"])
  sign_in_and_redirect @user
end
```

Session externalization: `redis-actionpack` gem with `config.session_store :redis_store`.

### Node.js / Express

Use `@azure/msal-node` for token acquisition and `passport-azure-ad` BearerStrategy
to protect API routes.

```javascript
// auth.js — confidential client setup
const { ConfidentialClientApplication } = require("@azure/msal-node");

const msalConfig = {
  auth: {
    clientId: process.env.AZURE_CLIENT_ID,
    clientSecret: process.env.AZURE_CLIENT_SECRET,
    authority: `https://login.microsoftonline.com/${process.env.AZURE_TENANT_ID}`,
  },
};

const cca = new ConfidentialClientApplication(msalConfig);

async function getAuthCodeUrl(req, res) {
  const url = await cca.getAuthCodeUrl({
    scopes: ["openid", "profile", "email"],
    redirectUri: process.env.REDIRECT_URI,
  });
  res.redirect(url);
}

async function handleCallback(req, res) {
  const result = await cca.acquireTokenByCode({
    code: req.query.code,
    scopes: ["openid", "profile", "email"],
    redirectUri: process.env.REDIRECT_URI,
  });
  req.session.account = result.account;
  res.redirect("/");
}
```

Protect API routes with `passport-azure-ad` BearerStrategy:

```javascript
const { BearerStrategy } = require("passport-azure-ad");

passport.use(new BearerStrategy({
  identityMetadata: `https://login.microsoftonline.com/${process.env.AZURE_TENANT_ID}/v2.0/.well-known/openid-configuration`,
  clientID: process.env.AZURE_CLIENT_ID,
  validateIssuer: true,
  loggingLevel: "warn",
}, (token, done) => done(null, token)));
```

Session externalization: `express-session` + `connect-redis`.

```javascript
const session = require("express-session");
const RedisStore = require("connect-redis").default;
const { createClient } = require("redis");

const redisClient = createClient({ url: process.env.REDIS_URL });
await redisClient.connect();

app.use(session({
  store: new RedisStore({ client: redisClient }),
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: { secure: true, httpOnly: true, sameSite: "strict" },
}));
```

### React SPA

Use `@azure/msal-browser` and `@azure/msal-react`. All tokens stay in memory —
never write them to `localStorage`.

```typescript
// authConfig.ts
import { Configuration, LogLevel } from "@azure/msal-browser";

export const msalConfig: Configuration = {
  auth: {
    clientId: import.meta.env.VITE_AZURE_CLIENT_ID,
    authority: `https://login.microsoftonline.com/${import.meta.env.VITE_AZURE_TENANT_ID}`,
    redirectUri: window.location.origin,
  },
  cache: {
    cacheLocation: "sessionStorage", // acceptable for SPAs; never use localStorage for tokens
    storeAuthStateInCookie: false,
  },
  system: {
    loggerOptions: {
      loggerCallback: (level, message) => {
        if (level === LogLevel.Error) console.error(message);
      },
    },
  },
};
```

```tsx
// main.tsx — wrap app in MsalProvider
import { MsalProvider } from "@azure/msal-react";
import { PublicClientApplication } from "@azure/msal-browser";
import { msalConfig } from "./authConfig";

const pca = new PublicClientApplication(msalConfig);

ReactDOM.createRoot(document.getElementById("root")!).render(
  <MsalProvider instance={pca}>
    <App />
  </MsalProvider>
);
```

Acquire tokens silently; fall back to popup or redirect only when silent fails:

```typescript
import { useMsal } from "@azure/msal-react";

function useAccessToken(scopes: string[]) {
  const { instance, accounts } = useMsal();
  return async () => {
    try {
      const result = await instance.acquireTokenSilent({ scopes, account: accounts[0] });
      return result.accessToken;
    } catch {
      const result = await instance.acquireTokenPopup({ scopes });
      return result.accessToken;
    }
  };
}
```

## Session Externalization for Horizontal Scale

All server-rendered stacks **must** externalize sessions before deploying to
App Service (multiple instances) or Azure Container Apps. In-memory sessions are
lost on instance restart and not shared across replicas.

| Stack | Session Store Package |
|---|---|
| Spring Boot | `spring-session-data-redis` + Azure Cache for Redis |
| Django | `django-redis` with `SESSION_ENGINE = "django.contrib.sessions.backends.cache"` |
| Ruby on Rails | `redis-actionpack` with `:redis_store` session store |
| Node.js/Express | `connect-redis` with `express-session` |

Configure the Redis connection string via an environment variable — never hardcode it.
Use Azure Cache for Redis with TLS enabled (port 6380).

## Security Requirements

- **Never store `client_secret` in source code.** Use Azure Key Vault or App Service
  application settings (which are encrypted at rest and injected as environment variables).
- **Use PKCE for all public clients** (SPAs, mobile, desktop). PKCE is non-negotiable
  when a `client_secret` cannot be kept confidential.
- **Validate tokens server-side** on every request: check `iss`, `aud`, `nonce`, and `exp`.
  Use a vetted library (MSAL, Spring Security OAuth2 Resource Server, `python-jose`,
  `passport-azure-ad`) — do not write custom JWT validation.
- **Rotate client secrets on a defined schedule** (90 days maximum); prefer
  certificate credentials for confidential clients — certificates are auditable
  and support automated rotation via Key Vault.
- **Never log tokens or claims containing PII** (`email`, `name`, `upn`, `oid`).
  Log only non-sensitive correlation identifiers (e.g., a hashed `sub`).
- **Prefer `httpOnly` + `Secure` + `SameSite=Strict` cookies** for session tokens
  on server-rendered apps. Do not store bearer tokens in `localStorage`.

## Review Lens

- Is the correct flow used — PKCE for public clients, confidential client for server apps?
- Are `iss`, `aud`, `nonce`, and `exp` validated on every token server-side?
- Is the `client_secret` sourced from Key Vault or environment config — never from source code?
- Are sessions externalized to Redis for any deployment with more than one instance?
- Does any code write tokens or PII claims to logs, `localStorage`, or `sessionStorage`?
- Do app role claims map correctly to the authorization model (Spring authorities, Django groups, Rails roles)?
