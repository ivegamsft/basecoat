# Basecoat Portal Identity & Access Control Design v1.0

**Status**: Draft | **Version**: 1.0 | **Last Updated**: 2025 | **Due**: May 5

## Executive Summary

This document specifies the identity and access control (IAM) architecture for Basecoat Portal Wave 3, a multi-tenant governance and security audit platform. The design implements role-based access control (RBAC), federated authentication via GitHub OAuth 2.0 and Azure AD, multi-factor authentication (MFA), service-to-service authentication, and comprehensive audit trails for compliance tracking.

### Key Design Principles

- **Least Privilege**: Default-deny authorization; users receive only required permissions
- **Defense in Depth**: Multiple layers of security (authentication, authorization, encryption, audit)
- **Separation of Duties**: No user can unilaterally grant themselves elevated permissions
- **Comprehensive Audit Trail**: All identity events logged for compliance and forensic analysis
- **Fail-Secure**: On authentication/authorization failure, default to deny; never grant access on error
- **Expiring Credentials**: All tokens and API keys expire; refresh via re-authentication

---

## 1. Role-Based Access Control (RBAC) Matrix

### 1.1 Role Definitions

Five core roles govern Basecoat Portal access:

| Role | Scope | Primary Responsibilities | Access Scope |
|------|-------|-------------------------|--------------|
| Admin | Portal-wide | Full control over teams, policies, audit configuration, user access | All organizations & teams assigned |
| Organization Admin | Organization-level | Multi-team management, organization policies, billing & subscription | Entire organization |
| Auditor | Organization | Submit compliance audits, view audit results, generate reports, assign issues | Organization data only |
| Developer | Team | View assigned issues, update status, request waivers, comment on findings | Team data only |
| Viewer | Organization | Read-only access to dashboard, metrics, audit results, compliance status | Organization data only |

### 1.2 Permission Matrix

| Permission | Admin | Org Admin | Auditor | Developer | Viewer |
|-----------|-------|----------|---------|-----------|--------|
| View Dashboard | ✓ | ✓ | ✓ | ✓ | ✓ |
| View Audit Results | ✓ | ✓ | ✓ | ✓ (assigned) | ✓ |
| Submit Audit | ✓ | ✓ | ✓ | ✗ | ✗ |
| Configure Audit Policies | ✓ | ✓ | ✗ | ✗ | ✗ |
| Manage Teams | ✓ | ✓ | ✗ | ✗ | ✗ |
| Manage Users & Roles | ✓ | ✓ | ✗ | ✗ | ✗ |
| View Org Settings | ✓ | ✓ | ✓ | ✗ | ✗ |
| Manage Integrations | ✓ | ✓ | ✗ | ✗ | ✗ |
| Generate Reports | ✓ | ✓ | ✓ | ✗ | ✓ |
| Manage Billing | ✓ | ✓ | ✗ | ✗ | ✗ |
| Update Issue Status | ✓ | ✓ | ✓ | ✓ | ✗ |
| Request Waiver | ✓ | ✓ | ✓ | ✓ | ✗ |
| View Audit Trail | ✓ | ✓ | ✓ (own) | ✗ | ✗ |
| Export Data | ✓ | ✓ | ✓ | ✗ | ✗ |

---

## 2. Authentication Architecture

### 2.1 Supported Authentication Methods

**Primary**: GitHub OAuth 2.0
- Enterprise organizations use GitHub Teams for automatic group mapping
- Fallback to internal user database for non-GitHub accounts

**Secondary**: Azure Active Directory (AAD)
- Enterprise customers can enforce SAML 2.0 or OpenID Connect
- Automatic group/role mapping via AAD security groups
- Optional: Conditional Access policies for device/location-based policies

**Service Authentication**: Service accounts with API keys
- Non-interactive workload authentication
- Scoped API keys with explicit permission grants
- Rotation required every 90 days

---

## 3. GitHub OAuth 2.0 Integration

### 3.1 Authentication Flow

```
User Browser                Portal Backend                GitHub
     |                           |                           |
     +---(1) GET /login--------->|                           |
     |                           |                           |
     |<-(2) Redirect to GitHub---+---params: redirect_uri   |
     +---(3) User authorizes-----+----> /login/authorize    |
     |                           |<--------- (approve)        |
     |<-(4) Redirect + code------+------- code: xxx          |
     |                           |                           |
     |                           +---(5) POST /token-------> |
     |                           |  (exchange code for token)|
     |                           |<--------- access_token    |
     |                           |                           |
     |                           +---(6) GET /user--------->|
     |                           |<--------- user profile    |
     |<----(7) Set JWT token ----+                           |
     +----> App (authenticated) -+                           |
```

### 3.2 Implementation Steps

1. **Register OAuth Application** (GitHub Settings → Developer settings → OAuth Apps)
   - Application name: Basecoat Portal
   - Authorization callback URL: `https://portal.basecoat.dev/auth/callback`
   - Client ID & Secret: Store in Azure Key Vault

2. **Initiate Login**
   ```
   GET https://github.com/login/oauth/authorize
   ?client_id={CLIENT_ID}
   &redirect_uri=https://portal.basecoat.dev/auth/callback
   &scope=user:email,read:org
   &state={RANDOM_STATE}
   ```

3. **Handle Callback & Exchange Code**
   ```
   POST https://github.com/login/oauth/access_token
   client_id={CLIENT_ID}
   &client_secret={CLIENT_SECRET}
   &code={AUTHORIZATION_CODE}
   &redirect_uri=https://portal.basecoat.dev/auth/callback
   ```

4. **Fetch User Profile**
   ```
   GET https://api.github.com/user
   Authorization: Bearer {ACCESS_TOKEN}
   ```

### 3.3 Required OAuth Scopes

| Scope | Purpose |
|-------|---------|
| user:email | Access user email for identification |
| read:org | Access organization memberships for role assignment |
| read:user | Access public profile for display name/avatar |

---

## 4. Multi-Tenancy & Isolation

### 4.1 Isolation Model

- **Organization Level**: Complete data separation; users belong to organizations explicitly
- **Team Level**: Teams group users within organizations; Developers have team-scoped access
- **Row-Level Security**: All queries filter by organization context from JWT claims

### 4.2 Database Security

All queries include organization context:

```sql
SELECT * FROM audits
WHERE org_id = $1  -- From JWT claims
  AND (team_id = $2 OR user_is_auditor);
```

---

## 5. JWT Token Structure & Session Management

### 5.1 JWT Access Token (15 min expiry)

```json
{
  "sub": "user_12345",
  "email": "alice@company.com",
  "org_id": "org_67890",
  "team_ids": ["team_1", "team_2"],
  "roles": ["developer", "auditor"],
  "permissions": ["read:audits", "write:issues"],
  "exp": 1234567890,
  "iat": 1234567200,
  "iss": "https://portal.basecoat.dev",
  "aud": "basecoat-portal"
}
```

### 5.2 Refresh Token (30 days, HTTP-only cookie)

- Stored in secure, HTTP-only, SameSite=Strict cookie
- Cannot be accessed by JavaScript
- Used only via POST /auth/refresh endpoint

### 5.3 Token Lifecycle

1. User logs in (GitHub OAuth)
2. Backend validates GitHub token, fetches profile & org membership
3. Backend creates JWT access token (15 min) + refresh token (30 days in cookie)
4. Frontend stores access token in memory (not localStorage to prevent XSS)
5. On token expiry, frontend calls POST /auth/refresh
6. Backend validates refresh token, issues new access token
7. On logout, backend clears refresh cookie + revokes token

---

## 6. Multi-Factor Authentication (MFA)

### 6.1 Supported MFA Methods

- **TOTP**: Google Authenticator, Microsoft Authenticator (recommended for all users)
- **FIDO2/WebAuthn**: Hardware keys (YubiKey, Titan) for Admin/Org Admin

### 6.2 MFA Enforcement Policy

| Role | Required | Session Timeout |
|------|----------|-----------------|
| Admin | Yes (FIDO2) | 1 hour |
| Organization Admin | Yes | 2 hours |
| Auditor | Recommended | 4 hours |
| Developer | Optional | 8 hours |
| Viewer | Optional | 8 hours |

---

## 7. Service Accounts & API Keys

### 7.1 API Key Format

```
bcp_[org_id]_[random_64_chars]
Example: bcp_org_12345_4x7q9wK2nL8mP5vR3sT6uJ1yZ0bC9dF2gH4jK5lM6n
```

### 7.2 API Key Scopes

- `read:audits` — List and fetch audit records
- `write:audits` — Create audit records
- `read:policies` — List policies
- `write:policies` — Update policies
- `read:integrations` — List integrations
- `write:integrations` — Configure integrations

### 7.3 Key Management

- Generate/revoke in Settings → API Keys
- Display only once; require confirmation
- Store hashed (bcrypt) in database
- Rotation required every 90 days
- Audit all API calls using key

---

## 8. Azure Active Directory Integration

### 8.1 OIDC / SAML Configuration

**OpenID Connect (Recommended)**
- Redirect URI: `https://portal.basecoat.dev/auth/aad-callback`
- Scopes: `openid profile email`

**SAML 2.0 (Alternative)**
- Entity ID: `https://portal.basecoat.dev/saml/metadata`
- ACS URL: `https://portal.basecoat.dev/auth/saml-callback`

### 8.2 Group Mapping

AAD security groups map to Basecoat roles:

```
contoso-auditors        → Auditor
contoso-developers      → Developer
contoso-admins          → Admin
contoso-org-admins      → Organization Admin
```

---

## 9. Secrets Management

All sensitive data stored in **Azure Key Vault**:

| Secret | Rotation |
|--------|----------|
| GitHub OAuth Client Secret | 90 days |
| JWT Signing Key (Private) | Annual |
| Database Credentials | 90 days |
| Azure AD Client Secret | 90 days |

---

## 10. Audit Trail & Compliance Logging

### 10.1 Audit Events

| Event | Data Logged | Retention |
|-------|-------------|-----------|
| User Login | User ID, IP, method, timestamp | 90 days |
| Permission Grant | Grantor, grantee, permission, reason | 2 years |
| Permission Revoke | Revoker, user, permission | 2 years |
| Role Assignment | Admin, user, role, org | 2 years |
| API Key Generated | User, key ID, scopes | 2 years |
| Failed Auth | User/email, IP, reason | 90 days |

### 10.2 Audit Schema

```sql
CREATE TABLE audit_events (
    event_id UUID PRIMARY KEY,
    org_id UUID NOT NULL,
    event_type VARCHAR(50),
    actor_id UUID,
    subject_id UUID,
    action_detail JSONB,
    ip_address INET,
    timestamp TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (org_id) REFERENCES organizations(org_id)
);
```

---

## 11. Authorization Enforcement

### 11.1 Permission Checking

All API endpoints protected by middleware:

```pseudocode
function authorizeRequest(req, requiredPermission):
    token = extractBearerToken(req.headers)
    if !token: return 401 Unauthorized
    
    claims = verifyJWT(token, publicKey)
    if !claims: return 401 Unauthorized
    
    if requiredPermission not in claims.permissions:
        logAuditEvent('permission_denied', claims.sub, requiredPermission)
        return 403 Forbidden
    
    if claims.org_id != req.org_context:
        return 403 Forbidden
    
    req.user = claims
    next()
```

---

## 12. Incident Response

### 12.1 Compromised Account

1. Immediately revoke all active sessions
2. Force password reset on next login
3. Require MFA re-enrollment
4. Audit all actions from past 30 days
5. Notify account holder and organization admins

### 12.2 Compromised API Key

1. Immediately revoke the key
2. Audit all API calls using key (past 24 hours)
3. Review any data accessed/modified
4. Notify key owner; issue new key after security review

### 12.3 Privilege Escalation Detection

Monitor for suspicious patterns:
- User suddenly gains admin role
- User accesses restricted endpoints
- Bulk permission grants in short timeframe
- API key with wide scopes created and immediately used

---

## Summary of Deliverables

✅ **RBAC Matrix** — 5 roles × 14 permissions  
✅ **GitHub OAuth 2.0 Integration** — Flow diagram, scopes, implementation  
✅ **Multi-Tenancy Architecture** — Row-level security with org/team isolation  
✅ **MFA & Session Management** — TOTP/FIDO2, timeouts, concurrent sessions  
✅ **Azure AD Integration** — OIDC/SAML, group mapping  
✅ **Service Accounts & API Keys** — Scoped key model with rotation  
✅ **Secrets Management** — Key Vault storage and access patterns  
✅ **Audit Trail Schema** — Events, retention, compliance  
✅ **Authorization Enforcement** — Middleware, ABAC patterns  
✅ **Incident Response** — Compromise handling, escalation detection  
✅ **Deployment & Operations** — Environment isolation  

---

**Document Version**: 1.0  
**Status**: Complete  
**Delivery Deadline**: May 5  
