# Copilot Extension OAuth Token Exchange Implementation Guide

This document provides guidance for implementing real GitHub OAuth token exchange in the BaseCoat Copilot Extension (issue #1114, follow-up to Sprint 31).

## Current State (Sprint 31)

The `/api/github/oauth/callback` endpoint is currently a **placeholder**:

```typescript
// mcp/basecoat-extension/src/app.ts, lines 165-206
app.get("/api/github/oauth/callback", (req, res) => {
  // Validates state parameter
  const session = gitHubOAuthManager.validateAndGetUserSession(state);
  
  // Returns placeholder response
  res.status(200).json({
    status: "authorized",
    message: "OAuth callback received. Token exchange will be performed by client.",
    code,
    state,
    sessionId: session.sessionId,
  });
});
```

The placeholder:
- ✅ Validates state (CSRF protection)
- ✅ Creates session record
- ❌ **Does NOT** exchange authorization code for access token
- ❌ **Does NOT** fetch user info
- ❌ **Does NOT** verify org membership
- ❌ **Does NOT** return session cookie

## Deployment Flow

The extension deployment is fully automated:

```
Org-Admin: Creates & installs GitHub App (#1073)
  ↓
Platform Engineer: Runs bootstrap-credentials.ps1 (stores credentials in GitHub Secrets + KV)
  ↓
CI/CD Workflow: extension-deploy.yml
  - Reads secrets from GitHub Secrets
  - Builds Docker image
  - Pushes to GHCR
  - Deploys via Bicep IaC
  - Performs health checks
  ↓
Developer: Implements token exchange (this guide)
  ↓
Deployment complete
```

**Note:** bootstrap-credentials.ps1 is credentials-only (chicken-egg problem). All infrastructure and environment configuration is handled by Bicep IaC and the CI/CD workflow—NOT by manual scripts.

## Implementation Path

### Phase 1: Install @octokit/app

Add the GitHub App client library:

```bash
cd mcp/basecoat-extension
npm install --save @octokit/app
npm run typecheck && npm test
```

Package: [@octokit/app](https://github.com/octokit/app.js)  
Documentation: [Creating an Octokit instance](https://github.com/octokit/app.js#usage)

### Phase 2: Create OAuth Token Manager

Create `src/github-token-manager.ts` to encapsulate token exchange logic:

```typescript
import { App } from "@octokit/app";
import { Logger } from "./logger";

export interface OAuthTokenExchangeRequest {
  code: string;
  redirectUri: string;
}

export interface OAuthTokenResponse {
  accessToken: string;
  tokenType: "bearer";
  expiresIn: number;
  scope: string[];
  userId: number;
  userLogin: string;
  userEmail: string;
}

export class GitHubTokenManager {
  private app: App;
  private logger: Logger;

  constructor(logger: Logger) {
    this.logger = logger;
    
    // Initialize Octokit App with credentials from environment
    this.app = new App({
      appId: process.env.BASECOAT_EXTENSION_GITHUB_APP_ID!,
      privateKey: process.env.BASECOAT_EXTENSION_GITHUB_PRIVATE_KEY!,
      clientId: process.env.BASECOAT_EXTENSION_GITHUB_CLIENT_ID!,
      clientSecret: process.env.BASECOAT_EXTENSION_GITHUB_CLIENT_SECRET!,
    });
  }

  /**
   * Exchange OAuth authorization code for access token.
   *
   * @param request - Contains code and redirectUri from OAuth flow
   * @returns Parsed token response with user info
   * @throws Error if code is invalid, expired, or rate-limited
   */
  async exchangeCodeForToken(
    request: OAuthTokenExchangeRequest
  ): Promise<OAuthTokenResponse> {
    try {
      // Exchange code for access token
      // Documentation: https://docs.github.com/en/developers/apps/building-github-apps/authenticating-with-github-apps-for-user-to-server-requests
      const tokenResponse = await this.app.oauth.createToken({
        code: request.code,
        redirectUrl: request.redirectUri,
      });

      if (!tokenResponse.token) {
        this.logger.error("oauth_token_exchange_failed", {
          reason: "no_token_in_response",
        });
        throw new Error("GitHub API did not return access token");
      }

      // Use access token to fetch authenticated user info
      const octokit = await this.app.getUserOctokit(tokenResponse.token);
      const userResponse = await octokit.rest.users.getAuthenticated();

      const user = userResponse.data;

      this.logger.info("oauth_token_exchange_success", {
        userId: user.id,
        userLogin: user.login,
        scope: tokenResponse.scope || "user",
      });

      return {
        accessToken: tokenResponse.token,
        tokenType: "bearer",
        expiresIn: tokenResponse.expiresIn || 28800, // GitHub tokens don't expire by default
        scope: (tokenResponse.scope || "").split(",").filter(Boolean),
        userId: user.id,
        userLogin: user.login,
        userEmail: user.email || "",
      };
    } catch (error) {
      if (error instanceof Error) {
        if (error.message.includes("Validation Failed")) {
          this.logger.warn("oauth_token_exchange_failed", {
            reason: "invalid_code",
            errorMessage: error.message.slice(0, 100),
          });
          throw new Error("Invalid authorization code");
        }
        if (error.message.includes("rate limited")) {
          this.logger.warn("oauth_token_exchange_failed", {
            reason: "rate_limited",
          });
          throw new Error("Rate limited. Please try again later.");
        }
      }
      this.logger.error("oauth_token_exchange_failed", {
        reason: "unexpected_error",
        errorType: error instanceof Error ? error.constructor.name : typeof error,
      });
      throw error;
    }
  }

  /**
   * Verify user is member of allowed organization.
   *
   * @param accessToken - GitHub access token
   * @param org - Organization slug
   * @param username - GitHub username to check
   * @returns true if user is a public member of org
   */
  async verifyOrgMembership(
    accessToken: string,
    org: string,
    username: string
  ): Promise<boolean> {
    try {
      const octokit = await this.app.getInstallationOctokit(
        this.app.auth({ type: "token", token: accessToken })
      );

      const response = await octokit.rest.orgs.checkMembershipForUser({
        org,
        username,
      });

      const isMember = response.status === 204;

      this.logger.info("org_membership_check", {
        org,
        username,
        isMember,
      });

      return isMember;
    } catch (error) {
      if (error instanceof Error && error.message.includes("404")) {
        this.logger.warn("org_membership_check", {
          org,
          username,
          isMember: false,
        });
        return false;
      }

      this.logger.error("org_membership_check_failed", {
        org,
        username,
        reason: error instanceof Error ? error.message : "unknown",
      });
      throw error;
    }
  }
}
```

### Phase 3: Update OAuth Callback Handler

Modify `/api/github/oauth/callback` in `src/app.ts` to use real token exchange:

```typescript
import { GitHubTokenManager } from "./github-token-manager";

const tokenManager = new GitHubTokenManager(logger);

app.get("/api/github/oauth/callback", async (req, res) => {
  const { code, state } = req.query;

  // Validate state (existing logic)
  if (!code || !state || typeof state !== "string") {
    res.status(400).json({ error: "invalid_request" });
    return;
  }

  const session = gitHubOAuthManager.validateAndGetUserSession(state);
  if (!session) {
    res.status(403).json({ error: "invalid_state" });
    return;
  }

  try {
    // Exchange code for token
    const tokenResponse = await tokenManager.exchangeCodeForToken({
      code: code as string,
      redirectUri: process.env.BASECOAT_EXTENSION_OAUTH_CALLBACK_URL!,
    });

    // Verify org membership
    const allowedOrg = process.env.BASECOAT_EXTENSION_ALLOWED_ORG || "IBuySpy-Shared";
    const isMember = await tokenManager.verifyOrgMembership(
      tokenResponse.accessToken,
      allowedOrg,
      tokenResponse.userLogin
    );

    if (!isMember) {
      logger.warn("oauth_access_denied", {
        reason: "not_org_member",
        org: allowedOrg,
        userLogin: tokenResponse.userLogin,
      });
      res.status(403).json({
        error: "access_denied",
        detail: `User is not a member of ${allowedOrg} organization`,
      });
      return;
    }

    // Store token in session
    session.accessToken = tokenResponse.accessToken;
    session.userId = tokenResponse.userId;
    session.userLogin = tokenResponse.userLogin;
    session.authorizedAt = Date.now();

    // Set secure session cookie (HttpOnly, Secure, SameSite=Strict)
    res.cookie("basecoat_session", session.sessionId, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "strict",
      maxAge: parseInt(process.env.BASECOAT_EXTENSION_SESSION_TTL_MS || "86400000"),
    });

    logger.info("oauth_flow_complete", {
      userId: tokenResponse.userId,
      userLogin: tokenResponse.userLogin,
      org: allowedOrg,
    });

    // Redirect to extension or return token
    res.status(200).json({
      status: "authorized",
      sessionId: session.sessionId,
      user: {
        id: tokenResponse.userId,
        login: tokenResponse.userLogin,
        email: tokenResponse.userEmail,
      },
    });
  } catch (error) {
    logger.error("oauth_callback_failed", {
      reason: error instanceof Error ? error.message : "unknown",
    });
    res.status(500).json({
      error: "server_error",
      detail: "Failed to complete OAuth flow",
    });
  }
});
```

### Phase 4: Add Token Storage

Extend `SessionStore` to persist access tokens:

```typescript
// In src/session.ts
export interface Session {
  sessionId: string;
  createdAt: number;
  expiresAt: number;
  state: string;
  accessToken?: string;  // ADD
  userId?: number;       // ADD
  userLogin?: string;    // ADD
  authorizedAt?: number; // ADD
}
```

### Phase 5: Add Unit Tests

Extend `session.test.ts` and create `github-token-manager.test.ts`:

```bash
npm test -- --testPathPattern="github-token-manager|session"
```

Test coverage should include:
- Token exchange with valid code
- Token exchange with invalid code (error handling)
- Org membership check (member / non-member)
- Rate limiting response
- Token expiration handling (future refresh token logic)

### Phase 6: Update Documentation

1. **Update README.md** OAuth section with token exchange flow
2. **Update OAUTH_FLOW.md** with real token exchange sequence diagram
3. **Add token refresh strategy** for long-lived sessions (out of scope for Sprint 32)

## References

- [@octokit/app documentation](https://github.com/octokit/app.js)
- [GitHub OAuth documentation](https://docs.github.com/en/developers/apps/building-github-apps/authenticating-with-github-apps-for-user-to-server-requests)
- [GitHub organization membership API](https://docs.github.com/en/rest/orgs/members?apiVersion=2022-11-28#check-organization-membership-for-a-user)
- Issue #1114 (GitHub token exchange implementation)
- Sprint 32 planning

## Checklist for Implementation

- [ ] Install @octokit/app dependency
- [ ] Create GitHubTokenManager class
- [ ] Update OAuth callback handler
- [ ] Extend SessionStore for token storage
- [ ] Add token exchange unit tests
- [ ] Test with actual GitHub App (after #1073 is complete)
- [ ] Update documentation
- [ ] Merge as PR #1118 (token exchange implementation)

## Blockers

- **#1073**: GitHub App registration (required for real token exchange)
  - Need: GitHub App ID, Client ID, Client Secret, Private Key
  - Status: Waiting on org-admin

Once #1073 is complete, this implementation can proceed in Sprint 32.

---

**Generated:** Sprint 31  
**Status:** Ready for Sprint 32 implementation  
**Priority:** P1 (blocks extension activation)
