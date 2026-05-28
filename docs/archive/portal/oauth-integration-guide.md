# GitHub OAuth 2.0 Integration Guide

Complete implementation guide for GitHub OAuth 2.0 authentication in Basecoat Portal.

---

## 1. GitHub Application Setup

### Step 1: Register OAuth Application

Navigate to: **GitHub Settings → Developer settings → OAuth Apps → New OAuth App**

Fill in the following fields:

| Field | Value |
|-------|-------|
| **Application name** | Basecoat Portal |
| **Homepage URL** | https://portal.basecoat.dev |
| **Authorization callback URL** | https://portal.basecoat.dev/auth/callback |
| **Application description** | Governance and security audit platform |

### Step 2: Store Credentials in Azure Key Vault

After registration, GitHub displays:
- **Client ID**: Public identifier for the application
- **Client Secret**: Private key (store immediately, cannot be retrieved)

**Store in Azure Key Vault**:
```bash
az keyvault secret set --vault-name basecoat-kv \
  --name "github-oauth-client-id" \
  --value "{CLIENT_ID}"

az keyvault secret set --vault-name basecoat-kv \
  --name "github-oauth-client-secret" \
  --value "{CLIENT_SECRET}"
```

---

## 2. Authentication Flow

### 2.1 Redirect to GitHub

When user clicks "Sign in with GitHub", redirect to:

```
GET https://github.com/login/oauth/authorize
  ?client_id={CLIENT_ID}
  &redirect_uri=https://portal.basecoat.dev/auth/callback
  &scope=user:email,read:org,read:user
  &state={RANDOM_STATE}
```

**Parameters**:
- `client_id`: Your application's Client ID
- `redirect_uri`: Must match registered value exactly
- `scope`: Requested permissions (see below)
- `state`: Random string to prevent CSRF attacks (store in session)

### 2.2 Exchange Authorization Code for Token

User approves access. GitHub redirects to:

```
GET https://portal.basecoat.dev/auth/callback?code=xxx&state=yyy
```

Your backend exchanges the code:

```bash
POST https://github.com/login/oauth/access_token
  -H "Accept: application/json"
  -d "client_id={CLIENT_ID}"
  -d "client_secret={CLIENT_SECRET}"
  -d "code={AUTHORIZATION_CODE}"
  -d "redirect_uri=https://portal.basecoat.dev/auth/callback"
```

GitHub responds:

```json
{
  "access_token": "ghu_16C7e42F...",
  "expires_in": 28800,
  "refresh_token": "ghr_1B4a2e77...",
  "refresh_token_expires_in": 15811200,
  "token_type": "bearer",
  "scope": "user:email,read:org"
}
```

### 2.3 Fetch User Profile

Use the access token to fetch user information:

```bash
GET https://api.github.com/user
  -H "Authorization: Bearer {ACCESS_TOKEN}"
  -H "Accept: application/vnd.github.v3+json"
```

Response:

```json
{
  "login": "alice",
  "id": 123456,
  "email": "alice@company.com",
  "name": "Alice Smith",
  "avatar_url": "https://avatars.githubusercontent.com/u/123456?v=4",
  "bio": "Security engineer",
  "company": "Acme Corp",
  "location": "San Francisco"
}
```

### 2.4 Fetch Organization Memberships

For enterprise role mapping, fetch GitHub Teams:

```bash
GET https://api.github.com/user/orgs
  -H "Authorization: Bearer {ACCESS_TOKEN}"
  -H "Accept: application/vnd.github.v3+json"
```

Response:

```json
[
  {
    "login": "acme-corp",
    "id": 789012,
    "avatar_url": "https://avatars.githubusercontent.com/u/789012?v=4",
    "description": "Acme Corporation",
    "url": "https://api.github.com/orgs/acme-corp"
  }
]
```

Fetch teams within organization:

```bash
GET https://api.github.com/user/teams
  -H "Authorization: Bearer {ACCESS_TOKEN}"
  -H "Accept: application/vnd.github.v3+json"
```

---

## 3. Scope Specifications

### Required Scopes

| Scope | Permission | Reason |
|-------|-----------|--------|
| `user:email` | Access user email address | User identification and notifications |
| `read:org` | Read organization and team memberships | Role assignment based on GitHub Teams |
| `read:user` | Access public profile information | User display name, avatar, bio |

### Optional Scopes (Not Recommended for Basecoat)

Do NOT request these scopes:
- `repo` — Full repository access (violates least privilege)
- `admin:org_hook` — Organization webhooks (not needed)
- `write:org` — Modify organization settings (security risk)

---

## 4. Role Mapping from GitHub Teams

### Team to Role Mapping

Configure in Basecoat Settings → Identity Providers:

```json
{
  "provider": "github",
  "team_mapping": {
    "acme-corp/auditors": "auditor",
    "acme-corp/developers": "developer",
    "acme-corp/admins": "admin",
    "acme-corp/org-leads": "organization_admin"
  }
}
```

### Implementation Logic

```pseudocode
function mapGitHubTeamsToRoles(userTeams):
    roles = []
    
    for each team in userTeams:
        mappedRole = TEAM_MAPPING[team.full_slug]
        
        if mappedRole:
            roles.append(mappedRole)
    
    if roles.empty():
        roles = ["viewer"]  // Default role
    
    return roles
```

---

## 5. Session & Token Management

### 5.1 Create JWT After OAuth Login

After successful profile fetch:

```typescript
const jwtPayload = {
  sub: user.id,
  email: user.email,
  name: user.name,
  avatar: user.avatar_url,
  org_id: determineOrganization(user),
  roles: rolesFromGitHubTeams(user),
  permissions: permissionsFromRoles(roles),
  github_login: user.login,
  iat: Math.floor(Date.now() / 1000),
  exp: Math.floor(Date.now() / 1000) + (15 * 60), // 15 minutes
  iss: "https://portal.basecoat.dev",
  aud: "basecoat-portal"
};

const accessToken = jwt.sign(jwtPayload, privateKey, { algorithm: "RS256" });
```

### 5.2 Store Refresh Token (Secure Cookie)

```typescript
res.setHeader('Set-Cookie', `refresh_token=${refreshToken}; 
  HttpOnly; 
  Secure; 
  SameSite=Strict; 
  Path=/auth; 
  Max-Age=2592000`); // 30 days
```

---

## 6. Account Linking & Updates

### 6.1 Link GitHub Account to Portal User

On first login with GitHub:

```sql
INSERT INTO users (
  user_id, email, name, avatar_url, 
  github_login, github_id, organization_id, roles
) VALUES (
  NEW_UUID, $1, $2, $3, $4, $5, $6, $7
)
```

### 6.2 Update User on Subsequent Logins

```sql
UPDATE users SET
  last_login = NOW(),
  roles = $1,  -- Re-fetch from GitHub Teams
  avatar_url = $2
WHERE github_id = $3;
```

---

## 7. Error Handling

### Common OAuth Errors

| Error | Cause | Resolution |
|-------|-------|-----------|
| `redirect_uri_mismatch` | Callback URL doesn't match registered | Verify exact URL in GitHub settings |
| `invalid_client_id` | Client ID is invalid | Regenerate credentials in GitHub |
| `invalid_scope` | Requested scope not allowed | Check scope list; remove restricted scopes |
| `access_denied` | User denied authorization | Prompt user to re-authorize |
| `timeout` | Request took too long | Retry with exponential backoff |

### Error Response Handling

```typescript
if (error) {
  logAuditEvent({
    type: 'github_oauth_error',
    error_code: error.error,
    error_description: error.error_description,
    ip_address: req.ip,
    timestamp: new Date()
  });

  return res.redirect(`/auth/login?error=${encodeURIComponent(error.error)}`);
}
```

---

## 8. Security Best Practices

### CSRF Protection

1. Generate random `state` parameter
2. Store in secure session/cache (Redis)
3. Validate on callback
4. Discard after use (one-time only)

```typescript
// Initiate login
const state = crypto.randomBytes(32).toString('hex');
await redis.setex(`oauth_state_${state}`, 600, '1'); // 10 min expiry

// Callback
const storedState = await redis.get(`oauth_state_${query.state}`);
if (!storedState) throw new Error('Invalid state parameter');
```

### Token Storage

- **Access Token**: Store in memory (JavaScript variable), not localStorage
- **Refresh Token**: Store in HTTP-only secure cookie (cannot access via JavaScript)
- **Private Key**: Never expose; keep in backend only

### Rate Limiting

Limit OAuth callback handler to prevent brute force:

```
5 failed login attempts → 10 minute lockout per IP
```

---

## 9. Testing OAuth Flow

### Manual Testing

1. Navigate to `https://portal.basecoat.dev/auth/login`
2. Click "Sign in with GitHub"
3. Approve scopes
4. Verify redirect to callback URL
5. Check JWT token created
6. Verify roles mapped from GitHub Teams

### Automated Testing

```typescript
describe('GitHub OAuth', () => {
  it('should redirect to GitHub authorization endpoint', async () => {
    const res = await request(app).get('/auth/login');
    expect(res.redirect).toBe(302);
    expect(res.location).toMatch(/github.com\/login\/oauth\/authorize/);
  });

  it('should exchange code for token', async () => {
    const res = await request(app)
      .get('/auth/callback')
      .query({ code: 'test_code', state: 'test_state' });
    
    expect(res.status).toBe(302);
    expect(res.headers['set-cookie']).toBeDefined();
  });
});
```

---

## 10. Troubleshooting

### Common Issues

**Issue**: "Invalid redirect_uri"
- Solution: Verify callback URL matches GitHub settings exactly (case-sensitive)

**Issue**: "Token refresh returns 401"
- Solution: Check refresh token expiry; may need re-authentication

**Issue**: "Roles not updating after team changes"
- Solution: Force re-fetch of GitHub Teams on next login or manual sync

---

**Version**: 1.0  
**Last Updated**: 2025  
