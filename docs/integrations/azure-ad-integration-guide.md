# Azure Active Directory Integration Guide

Enterprise authentication setup for Basecoat Portal with Azure AD.

---

## 1. Azure AD Application Registration

### Step 1: Create Application in Azure Portal

Navigate to: **Azure Portal → Azure Active Directory → App registrations → New registration**

Fill in:
- **Name**: Basecoat Portal
- **Supported account types**: Accounts in this organizational directory (Single tenant)
- **Redirect URI**: Web → `https://portal.basecoat.dev/auth/aad-callback`

### Step 2: Configure Certificates & Secrets

Go to: **Certificates & secrets → New client secret**

- **Description**: Basecoat Portal Secret
- **Expires**: 90 days

Store secret securely:
```bash
az keyvault secret set --vault-name basecoat-kv \
  --name "azure-ad-client-secret" \
  --value "{CLIENT_SECRET}"
```

### Step 3: Configure API Permissions

Go to: **API permissions → Add a permission**

Add the following Microsoft Graph permissions:
- `User.Read` (Delegated) — Read user profile
- `Directory.Read.All` (Delegated) — Read directory/group information
- `email` (Delegated) — Access email address
- `profile` (Delegated) — Access profile information
- `openid` (Delegated) — Sign users in

Click **Grant admin consent for {organization}**

---

## 2. OpenID Connect (OIDC) Configuration

### 2.1 Discovery Endpoint

AAD publishes endpoint metadata at:

```
https://login.microsoftonline.com/{TENANT_ID}/v2.0/.well-known/openid-configuration
```

This returns:
```json
{
  "authorization_endpoint": "https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/authorize",
  "token_endpoint": "https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token",
  "userinfo_endpoint": "https://graph.microsoft.com/oidc/userinfo",
  "jwks_uri": "https://login.microsoftonline.com/{TENANT_ID}/discovery/v2.0/keys"
}
```

### 2.2 OIDC Login Flow

```
1. Redirect to authorization endpoint:
   GET https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/authorize
     ?client_id={CLIENT_ID}
     &response_type=code
     &redirect_uri=https://portal.basecoat.dev/auth/aad-callback
     &scope=openid profile email
     &state={RANDOM_STATE}

2. User authenticates with Azure AD

3. AAD redirects back:
   GET https://portal.basecoat.dev/auth/aad-callback?code=xxx&state=yyy

4. Exchange code for token:
   POST https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token
     client_id={CLIENT_ID}
     &client_secret={CLIENT_SECRET}
     &code={CODE}
     &redirect_uri=https://portal.basecoat.dev/auth/aad-callback
     &grant_type=authorization_code

5. AAD responds with ID token (JWT) containing user info

6. Verify ID token signature and extract claims
```

### 2.3 ID Token Claims

```json
{
  "aud": "{CLIENT_ID}",
  "iss": "https://login.microsoftonline.com/{TENANT_ID}/v2.0",
  "iat": 1234567890,
  "exp": 1234571490,
  "sub": "aad-user-object-id",
  "name": "Alice Smith",
  "preferred_username": "alice@contoso.com",
  "oid": "aad-user-object-id",
  "tid": "{TENANT_ID}",
  "groups": [
    "group-object-id-1",
    "group-object-id-2"
  ]
}
```

---

## 3. SAML 2.0 Configuration (Alternative)

### 3.1 Enable SAML in Azure AD

Go to: **Single sign-on → SAML**

Configure:

| Field | Value |
|-------|-------|
| **Entity ID** | `https://portal.basecoat.dev/saml/metadata` |
| **Reply URL (Assertion Consumer Service URL)** | `https://portal.basecoat.dev/auth/saml-callback` |
| **Sign On URL** | `https://portal.basecoat.dev/auth/login` |
| **Sign On URL** | `https://portal.basecoat.dev` |
| **Logout URL** | `https://portal.basecoat.dev/auth/logout` |

### 3.2 SAML Assertion Example

```xml
<saml:Assertion xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion">
  <saml:Subject>
    <saml:NameID Format="urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress">
      alice@contoso.com
    </saml:NameID>
  </saml:Subject>
  
  <saml:AuthnStatement AuthnInstant="2025-01-15T10:30:00Z">
    <saml:AuthnContext>
      <saml:AuthnContextClassRef>
        urn:oasis:names:tc:SAML:2.0:ac:classes:Password
      </saml:AuthnContextClassRef>
    </saml:AuthnContext>
  </saml:AuthnStatement>
  
  <saml:AttributeStatement>
    <saml:Attribute Name="email" NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:basic">
      <saml:AttributeValue>alice@contoso.com</saml:AttributeValue>
    </saml:Attribute>
    
    <saml:Attribute Name="name">
      <saml:AttributeValue>Alice Smith</saml:AttributeValue>
    </saml:Attribute>
    
    <saml:Attribute Name="groups">
      <saml:AttributeValue>contoso-auditors</saml:AttributeValue>
      <saml:AttributeValue>contoso-developers</saml:AttributeValue>
    </saml:Attribute>
  </saml:AttributeStatement>
</saml:Assertion>
```

---

## 4. Group Mapping & Role Assignment

### 4.1 Configure Group Claim

In Azure AD: **Manifest editor**, find `groupMembershipClaims` and set:

```json
"groupMembershipClaims": "SecurityGroup"
```

This includes all security group memberships in the ID token.

### 4.2 Map AAD Groups to Basecoat Roles

Configure in Basecoat Settings → Identity Providers → Azure AD:

```json
{
  "provider": "azure_ad",
  "tenant_id": "12345678-1234-1234-1234-123456789012",
  "client_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "group_mapping": {
    "contoso-auditors": "auditor",
    "contoso-developers": "developer",
    "contoso-admins": "admin",
    "contoso-org-admins": "organization_admin"
  },
  "sync_interval_hours": 24
}
```

### 4.3 Claim Rules

Create claim rules in Azure AD to expose groups:

**Rule Type**: Send group memberships as a role

**Outgoing Claim Type**: Role  
**Group Claim Type**: Groups as role values

---

## 5. Conditional Access Policies

### 5.1 Enforce MFA

Go to: **Conditional Access → New policy → Create new policy**

**Name**: Require MFA for Basecoat Portal

**Conditions**:
- Cloud apps or actions: Include → Basecoat Portal (app registration)
- Users or workload identities: All users

**Access Controls**:
- Grant: ✓ Require multifactor authentication
- Device Compliance: ✓ Require device to be marked as compliant (optional)

### 5.2 Restrict by Location

**Conditions**:
- Locations: Include → Selected locations (configure trusted IP ranges)

**Access Controls**:
- Grant: Allow

### 5.3 Block Legacy Authentication

**Conditions**:
- Client apps: Exchange ActiveSync, Other clients

**Access Controls**:
- Block access

---

## 6. Implementation Code (Node.js)

### Setup Dependencies

```bash
npm install openid-client passport passport-openidconnect
```

### OIDC Callback Handler

```javascript
const { Issuer } = require('openid-client');

let client;

// Initialize OIDC client
async function initializeOIDC() {
  const issuer = await Issuer.discover(
    `https://login.microsoftonline.com/${process.env.AZURE_TENANT_ID}/v2.0`
  );

  client = new issuer.Client({
    client_id: process.env.AZURE_CLIENT_ID,
    client_secret: process.env.AZURE_CLIENT_SECRET,
    redirect_uris: ['https://portal.basecoat.dev/auth/aad-callback'],
    response_types: ['code']
  });
}

// Initiate login
app.get('/auth/aad-login', (req, res) => {
  const state = crypto.randomBytes(32).toString('hex');
  
  // Store state in session
  req.session.oidc_state = state;

  const authUrl = client.authorizationUrl({
    scope: 'openid profile email',
    state: state,
    access_type: 'offline'
  });

  res.redirect(authUrl);
});

// Handle callback
app.get('/auth/aad-callback', async (req, res) => {
  const { code, state } = req.query;

  // Validate state
  if (state !== req.session.oidc_state) {
    return res.status(400).json({ error: 'Invalid state parameter' });
  }

  try {
    // Exchange code for token
    const tokenSet = await client.callback(
      'https://portal.basecoat.dev/auth/aad-callback',
      { code, state }
    );

    // Verify ID token and extract claims
    const userInfo = tokenSet.claims();

    const { email, name, oid, groups } = userInfo;

    // Map AAD groups to Basecoat roles
    const roles = mapAADGroupsToRoles(groups || []);

    // Find or create portal user
    let user = await db.query(
      'SELECT * FROM users WHERE aad_object_id = $1',
      [oid]
    );

    if (!user.rows.length) {
      user = await db.query(
        `INSERT INTO users 
         (email, name, aad_object_id, roles, org_id)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [email, name, oid, roles.join(','), determineOrgId(email)]
      );
    } else {
      // Update roles on each login
      await db.query(
        'UPDATE users SET roles = $1, last_login = NOW() WHERE aad_object_id = $2',
        [roles.join(','), oid]
      );
    }

    // Create JWT token for Basecoat
    const jwtToken = jwt.sign(
      {
        sub: user.rows[0].user_id,
        email: user.rows[0].email,
        name: user.rows[0].name,
        org_id: user.rows[0].org_id,
        roles: roles,
        permissions: getPermissionsFromRoles(roles),
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + (15 * 60)
      },
      fs.readFileSync('./keys/private.pem', 'utf8'),
      { algorithm: 'RS256' }
    );

    // Log successful login
    logAuditEvent({
      type: 'user_login',
      user_id: user.rows[0].user_id,
      auth_method: 'azure_ad_oidc',
      aad_object_id: oid,
      groups: groups,
      ip_address: req.ip,
      timestamp: new Date()
    });

    res.json({
      access_token: jwtToken,
      token_type: 'Bearer',
      expires_in: 900
    });

  } catch (error) {
    console.error('OIDC callback error:', error);
    res.status(500).json({ error: 'Authentication failed' });
  }
});

// Helper: Map AAD groups to Basecoat roles
function mapAADGroupsToRoles(aadGroups) {
  const groupMapping = {
    'contoso-auditors': 'auditor',
    'contoso-developers': 'developer',
    'contoso-admins': 'admin',
    'contoso-org-admins': 'organization_admin'
  };

  const roles = [];

  for (const group of aadGroups) {
    const role = groupMapping[group];
    if (role && !roles.includes(role)) {
      roles.push(role);
    }
  }

  return roles.length > 0 ? roles : ['viewer'];
}
```

---

## 7. Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "AADSTS50058: Silent sign-in request failed" | User session expired; require re-authentication |
| "AADSTS70002: Invalid client_id" | Verify client ID matches Azure AD app registration |
| "AADSTS65001: User or admin has not consented" | Grant admin consent for required permissions |
| "Groups claim missing" | Verify groupMembershipClaims is set in manifest |
| "Redirect URI mismatch" | Ensure exact match with Azure AD configuration |

---

**Version**: 1.0  
**Last Updated**: 2025  
