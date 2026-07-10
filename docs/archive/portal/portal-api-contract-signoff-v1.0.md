# Basecoat Portal — API Contract Sign-Off Document
## Wave 3 Day 2 Binding Agreement

**Version**: 1.0  
**Status**: DRAFT - AWAITING STAKEHOLDER SIGN-OFF  
**Stakeholders**: Backend Engineering, Frontend Team, Mobile Team, CLI Team, Security & Compliance

---

## Executive Summary

This document establishes a **binding API contract** for the Basecoat Portal backend service. It serves as the authoritative specification for all frontend, mobile, and CLI client implementations. All 28+ endpoints, authentication flows, error handling patterns, and data contracts are subject to team sign-off before production deployment.

### Key Contract Provisions

- **28+ endpoints** fully specified with request/response contracts
- **Dual JWT authentication system** (15-min access tokens + 30-day refresh tokens)
- **GitHub OAuth 2.0 integration** with RBAC (5 roles × 14 permissions)
- **Multi-tenancy enforcement** via org_id row-level security
- **Rate limiting tiers** (Public: 1000 req/hr, Premium: 5000 req/hr)
- **MFA enforcement** (TOTP all users, FIDO2 for Admin/Org Admin)
- **Comprehensive error handling** with standard error schemas and retry semantics
- **Pagination contract** (limit 1-100, default 20; offset; hasMore boolean)
- **Audit trail logging** (2-year retention for compliance)

---

## Section 1: Endpoint Inventory (28+ Endpoints)

### 1.1 Authentication (5 endpoints)

| # | Method | Path | Purpose | Status |
|---|--------|------|---------|--------|
| 1 | POST | /auth/login | GitHub OAuth initiation | ✓ Specified |
| 2 | POST | /auth/callback | OAuth code exchange | ✓ Specified |
| 3 | POST | /auth/logout | Session termination | ✓ Specified |
| 4 | POST | /auth/refresh-token | Refresh JWT pair | ✓ Specified |
| 5 | POST | /auth/verify-mfa | MFA verification | ✓ Specified |

### 1.2 User & Team Management (8 endpoints)

| # | Method | Path | Purpose | Status |
|---|--------|------|---------|--------|
| 6 | GET | /users/me | Current user profile | ✓ Specified |
| 7 | GET | /users/{userId} | User details | ✓ Specified |
| 8 | GET | /teams | List teams | ✓ Specified |
| 9 | POST | /teams | Create team | ✓ Specified |
| 10 | GET | /teams/{teamId} | Get team details | ✓ Specified |
| 11 | PATCH | /teams/{teamId} | Update team | ✓ Specified |
| 12 | DELETE | /teams/{teamId} | Delete team | ✓ Specified |
| 13 | POST | /teams/{teamId}/members | Add team member | ✓ Specified |

### 1.3 Repository Management (6 endpoints)

| # | Method | Path | Purpose | Status |
|---|--------|------|---------|--------|
| 14 | GET | /repositories | List repositories | ✓ Specified |
| 15 | POST | /repositories | Register repository | ✓ Specified |
| 16 | GET | /repositories/{repoId} | Get repository details | ✓ Specified |
| 17 | PATCH | /repositories/{repoId} | Update repository | ✓ Specified |
| 18 | DELETE | /repositories/{repoId} | Unregister repository | ✓ Specified |
| 19 | GET | /repositories/{repoId}/branches | List branches | ✓ Specified |

### 1.4 Audit & Scanning (4 endpoints)

| # | Method | Path | Purpose | Status |
|---|--------|------|---------|--------|
| 20 | GET | /audits | List audit events | ✓ Specified |
| 21 | GET | /audits/{auditId} | Get audit details | ✓ Specified |
| 22 | POST | /scan/repository | Start repository scan | ✓ Specified |
| 23 | GET | /scan/results/{scanId} | Poll scan results | ✓ Specified |

### 1.5 Compliance & Policy (3 endpoints)

| # | Method | Path | Purpose | Status |
|---|--------|------|---------|--------|
| 24 | GET | /policies | List compliance policies | ✓ Specified |
| 25 | POST | /policies | Create custom policy | ✓ Specified |
| 26 | PATCH | /policies/{policyId} | Update policy | ✓ Specified |

### 1.6 Simulation & Reports (2 endpoints)

| # | Method | Path | Purpose | Status |
|---|--------|------|---------|--------|
| 27 | POST | /simulations | Start attack simulation | ✓ Specified |
| 28 | GET | /reports/compliance | Generate compliance report | ✓ Specified |

---

## Section 2: Authentication Architecture

### 2.1 GitHub OAuth 2.0 Flow

1. Client initiates login at /auth/login
2. Redirect to GitHub OAuth provider
3. User authenticates at GitHub and grants permission
4. GitHub redirects to /auth/callback with authorization code
5. Backend exchanges code for GitHub access token
6. Backend fetches user profile and organization memberships
7. Backend issues JWT pair:
   - Access token: 15-minute expiry (stored in memory)
   - Refresh token: 30-day expiry (HTTP-only SameSite=Strict cookie)
8. Frontend stores access token in memory, refresh token in secure cookie
9. Subsequent requests include Bearer token or use cookie-based refresh

### 2.2 JWT Token Structure

**Access Token (15-minute expiry):**
```json
{
  "sub": "github_user_id_123",
  "org_id": "org_9999",
  "role": "Developer",
  "permissions": ["read:teams", "write:teams", "read:repos", "read:audits"],
  "iat": 1690000000,
  "exp": 1690000900,
  "iss": "https://basecoat.portal/auth"
}
```

**Refresh Token Rotation:**
- Each refresh generates new token pair
- Previous refresh token immediately invalidated
- Enables seamless background token refresh
- Protection against token theft

### 2.3 MFA Verification

- TOTP (Time-based One-Time Password): Required for all users
- FIDO2: Required for Admin and Org Admin roles
- Session invalidation if MFA is removed while user is active
- MFA status checked on login and sensitive operations

### 2.4 Session Timeout by Role

| Role | Session Timeout | Refresh Token Validity |
|------|-----------------|----------------------|
| Admin | 1 hour | 30 days (with MFA check) |
| Org Admin | 2 hours | 30 days (with MFA check) |
| Auditor | 4 hours | 30 days |
| Developer | 6 hours | 30 days |
| Viewer | 8 hours | 30 days |

---

## Section 3: RBAC Matrix & Permissions

### 3.1 Role Definitions

**Admin** (Full System Access)
- Required MFA: FIDO2
- Session Timeout: 1 hour
- Permissions: All 14 permissions
- Can: Create/modify/delete any resource

**Org Admin** (Organization-Level Management)
- Required MFA: FIDO2
- Session Timeout: 2 hours
- Permissions: 13 permissions (excluding system-level operations)
- Can: Manage teams, repos, policies within organization

**Auditor** (Read-Only Compliance Access)
- Required MFA: TOTP
- Session Timeout: 4 hours
- Permissions: read:audits, read:findings, read:policies, read:reports, export:reports
- Can: View and export audit trail and compliance reports

**Developer** (Team & Repo Management)
- Required MFA: TOTP
- Session Timeout: 6 hours
- Permissions: read/write teams, read/write repos, read:audits, read:findings
- Can: Manage teams and repositories within organization

**Viewer** (Read-Only Access)
- Required MFA: Optional
- Session Timeout: 8 hours
- Permissions: read:teams, read:repos, read:audits, read:findings, read:policies, read:reports
- Can: View all resources (no modifications)

### 3.2 API Key Permission Scoping

API keys support granular permission scoping:
- `read:audits` — Query audit trail
- `write:audits` — Create audit events
- `read:policies` — List/get policies
- `write:policies` — Create/update policies
- `read:findings` — Query findings
- `write:findings` — Create findings
- `read:reports` — Access reports
- `read:teams` — List/get teams
- `write:teams` — Manage team members
- `read:repos` — List/get repositories
- `write:repos` — Register/manage repositories
- `exec:simulations` — Execute simulations
- `admin:org` — Organization management (limited)

**API Key Security:**
- Format: `bcp_[org_id]_[random_64_chars_lowercase_alphanumeric]`
- Storage: SHA-256 hashed in database
- Rotation Required: 90 days
- Revocation: Immediate (no grace period)
- Header: `Authorization: Bearer bcp_org_9999_a7f3d2b8c1e5g9h2k4m7n1p3q8r2s5t9v6w8x0z`

---

## Section 4: Error Handling Contract

### 4.1 Standard Error Response Schema

All error responses (4xx, 5xx) follow this structure:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "User-facing error message",
    "details": {
      "field": "email",
      "reason": "Invalid email format"
    },
    "timestamp": "2024-07-15T14:30:45.123Z",
    "requestId": "req_abc123xyz789",
    "retryable": false,
    "retryAfter": null
  }
}
```

### 4.2 HTTP Status Codes & Error Mapping

| Code | Scenario | Error Code | Retryable | Example |
|------|----------|-----------|-----------|---------|
| 200 | Success (GET/PATCH) | — | — | Team fetched |
| 201 | Created (POST) | — | — | New team created |
| 204 | No Content (DELETE) | — | — | Team deleted |
| 400 | Validation error | VALIDATION_ERROR | No | Missing required field |
| 401 | Not authenticated | UNAUTHORIZED | No | Missing Bearer token |
| 401 | MFA required | MFA_REQUIRED | No | MFA not verified |
| 403 | Insufficient permissions | FORBIDDEN | No | Role lacks permission |
| 404 | Resource not found | NOT_FOUND | No | Team ID doesn't exist |
| 409 | Conflict (duplicate) | CONFLICT | No | Team name already exists |
| 429 | Rate limit exceeded | RATE_LIMIT_EXCEEDED | Yes | Too many requests |
| 500 | Internal server error | INTERNAL_ERROR | Yes | Database failure |
| 503 | Service unavailable | SERVICE_UNAVAILABLE | Yes | Maintenance mode |

### 4.3 Retry Semantics

**Retryable Errors (429, 500, 503):**
- Client MUST implement exponential backoff
- Initial retry delay: 1 second
- Max retry delay: 60 seconds
- Max attempts: 3-5 (client configurable)
- Response includes Retry-After header in seconds

**Non-Retryable Errors (400, 401, 403, 404):**
- Client must NOT retry automatically
- Fix underlying issue (validation, auth, permissions)

---

## Section 5: Pagination & Filtering

### 5.1 Pagination Specification

All list endpoints (GET /teams, /repos, /audits, /policies) support pagination:

**Query Parameters:**
```
GET /teams?limit=20&offset=0&sortBy=name&sortOrder=asc
```

| Parameter | Type | Default | Min | Max | Required |
|-----------|------|---------|-----|-----|----------|
| limit | integer | 20 | 1 | 100 | No |
| offset | integer | 0 | 0 | ∞ | No |
| sortBy | string | name | — | — | No |
| sortOrder | string | asc | asc/desc | — | No |

**Response Structure:**
```json
{
  "data": [
    {"id": "team_1", "name": "Platform", "description": "Platform team"},
    {"id": "team_2", "name": "Security", "description": "Security team"}
  ],
  "pagination": {
    "limit": 20,
    "offset": 0,
    "hasMore": true,
    "total": 47
  }
}
```

**Pagination Contract:**
- `hasMore: true` — More records available; use `offset: 20` for next page
- `hasMore: false` — End of results
- `total` field for UI progress indicators

### 5.2 Filtering Operators

Supported filter operators on list endpoints:
- `eq` — Exact match: `?filter=status:eq:active`
- `neq` — Not equal: `?filter=role:neq:Viewer`
- `gt` — Greater than (numeric): `?filter=created:gt:2024-01-01`
- `gte` — Greater than or equal: `?filter=findings:gte:5`
- `lt` — Less than: `?filter=score:lt:0.5`
- `lte` — Less than or equal: `?filter=score:lte:0.9`
- `contains` — String contains (case-insensitive): `?filter=name:contains:test`
- `startsWith` — String prefix: `?filter=name:startsWith:Platform`
- `in` — Enum list: `?filter=role:in:Admin,OrgAdmin`

**Date Range Filtering:**
```
?filter=createdDate:gte:2024-07-01&filter=createdDate:lt:2024-08-01
```

---

## Section 6: Rate Limiting Strategy

### 6.1 Rate Limiting Tiers

| Tier | Requests/Hour | Burst | API Key Scope |
|------|---------------|-------|---------------|
| Public | 1000 | 20 req/sec | Default |
| Premium | 5000 | 50 req/sec | premium:api |
| Unlimited | Unlimited | — | unlimited:api |

### 6.2 Rate Limit Headers

**All responses include:**
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 847
X-RateLimit-Reset: 1689619234
```

**429 Response (Rate Limit Exceeded):**
```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "API rate limit exceeded",
    "retryAfter": 45
  }
}
```

Headers:
```
Retry-After: 45
X-RateLimit-Reset: 1689619234
```

### 6.3 Rate Limit Persistence

- **Implementation**: Redis-backed counter with 1-hour rolling window
- **Precision**: Per-second burst tracking with 60-second sliding window
- **Fallback**: In-memory counter if Redis unavailable

---

## Section 7: Multi-Tenancy & Security

### 7.1 Row-Level Security (Org_ID Enforcement)

Every query enforced at middleware level:
```
ALL queries: WHERE org_id = :org_id_from_jwt_claim
```

**Contract:**
- org_id extracted from JWT at authentication
- Middleware checks org_id on every API call
- Response filtered to only org_id resources
- Cross-org data access: 403 Forbidden

### 7.2 API Key Org Scoping

- API key format embeds org_id: `bcp_[org_id]_[random]`
- Backend extracts and enforces org_id from key
- Provides fast org routing and cross-org prevention

---

## Section 8: Audit Trail & Compliance Logging

### 8.1 Audit Events Specification

All audit events logged with:
```json
{
  "eventId": "audit_abc123xyz",
  "timestamp": "2024-07-15T14:30:45.123Z",
  "userId": "github_user_id",
  "org_id": "org_9999",
  "action": "user.login | team.created | repo.deleted | policy.updated",
  "resource": {
    "type": "team | repo | policy | user",
    "id": "team_123",
    "name": "Platform"
  },
  "result": "success | failure",
  "ipAddress": "192.168.1.1",
  "userAgent": "Mozilla/5.0...",
  "details": {}
}
```

### 8.2 Audit Event Categories

| Category | Events |
|----------|--------|
| User Session | login, logout, refresh_token, session_timeout |
| MFA | mfa_enabled, mfa_verified, mfa_disabled |
| Team Management | team_created, team_updated, team_deleted, member_added |
| Repository | repo_registered, repo_updated, repo_unregistered |
| Policies | policy_created, policy_updated, policy_deleted |
| Scans & Findings | scan_started, scan_completed, finding_created |
| API Access | api_key_created, api_key_rotated, api_key_revoked |
| Security | unauthorized_access, rate_limit_violation, cross_org_attempt |

### 8.3 Retention & Compliance

- **Retention Period**: 2 years for all events
- **Archival**: Annual archives to cold storage
- **Export**: Auditor role can export (CSV, JSON)
- **Immutability**: Write-once, no delete/update operations

---

## Section 9: Integration Sign-Off Checklists

### 9.1 Frontend Integration

- [ ] OAuth 2.0 callback handling implemented
- [ ] JWT storage (memory) + refresh token (secure cookie)
- [ ] Error handling (401 re-auth, 403 denied, 429 rate limit)
- [ ] Pagination (limit/offset, hasMore navigation)
- [ ] MFA verification UI implemented
- [ ] Rate limit display (X-RateLimit-Remaining)
- [ ] Audit trail with filtering and sorting
- [ ] Request correlation (X-Request-ID logging)
- [ ] 401 → logout + redirect flow
- [ ] Cross-browser testing (Chrome, Firefox, Safari, Edge)
- [ ] Accessibility audit (WCAG 2.1 AA)

**Frontend Lead**: _________________ Date: __________

### 9.2 Mobile Integration

- [ ] OAuth 2.0 (iOS: SFSafariViewController, Android: Custom Tabs)
- [ ] Secure credential storage (iOS Keychain, Android Keystore)
- [ ] Refresh token rotation and cookie handling
- [ ] Background sync for pagination
- [ ] MFA UI (TOTP + FIDO2 support)
- [ ] Retry logic with exponential backoff
- [ ] Offline queueing
- [ ] Certificate pinning (production)
- [ ] Encryption at rest for cached data
- [ ] Device testing (iOS 15+, Android 12+)

**Mobile Lead**: _________________ Date: __________

### 9.3 CLI Integration

- [ ] API key authentication (Bearer token)
- [ ] OAuth device flow or browser-based auth
- [ ] Pagination cursor navigation
- [ ] JSON/YAML output formats
- [ ] Filtering (--filter, --sort, --limit)
- [ ] Progress indication for async operations
- [ ] Clear error messages
- [ ] Timeout handling + retry logic
- [ ] Config file storage
- [ ] Shell completion (bash, zsh, pwsh)

**CLI Lead**: _________________ Date: __________

---

## Section 10: Security & Compliance

### 10.1 Data Protection

- **Transit**: TLS 1.3+ (HTTPS only)
- **At Rest**: AES-256 encryption for sensitive fields
- **JWT Signing Key**: Quarterly rotation, Azure Key Vault
- **GitHub OAuth Secret**: Semi-annual rotation, Azure Key Vault
- **Database Credentials**: Managed identity authentication

### 10.2 Compliance Standards

- **GDPR**: Data export/deletion (right to be forgotten)
- **SOC 2**: Audit trail, access controls, encryption
- **CIS Controls**: Identity verification, MFA, role-based access
- **OWASP Top 10**: Input validation, output encoding, CSRF (SameSite cookies)

### 10.3 Incident Response

- **401 Failures**: Log attempts; rate-limit after 5 failures
- **403 Violations**: Log access attempt; escalate if cross-org
- **Rate Limit Abuse**: Flag account after 10 violations/hour
- **Suspicious Activity**: Alert security if >100 violations/hour

---

## Section 11: Production Deployment Quality Gates

### 11.1 Backend Readiness Checklist

- [ ] All 28+ endpoints tested (>90% code coverage)
- [ ] Load test passed (5000 concurrent users, p99 <500ms)
- [ ] Chaos engineering test passed (graceful degradation)
- [ ] Security scan passed (no critical/high vulnerabilities)
- [ ] OWASP Top 10 review completed
- [ ] Rate limiting tested under load
- [ ] Audit logging immutability verified
- [ ] Database backups tested (restore-to-RPO)
- [ ] API documentation generated (OpenAPI)

**Backend Lead**: _________________ Date: __________

### 11.2 Client Integration Readiness

- [ ] All frontend/mobile/CLI teams have signed checklists
- [ ] Cross-integration test passed (simultaneous connections)
- [ ] Error handling validated (all 4xx/5xx scenarios)
- [ ] MFA flow end-to-end testing
- [ ] Pagination boundary conditions tested
- [ ] Rate limiting client retry logic tested

**Integration Lead**: _________________ Date: __________

### 11.3 Documentation & Training

- [ ] API documentation published and linked
- [ ] SDK generation tested (OpenAPI → SDK artifacts)
- [ ] Team training completed (leads trained)
- [ ] Runbook created (deployment, rollback, incident response)
- [ ] Support escalation procedures documented

**Tech Lead**: _________________ Date: __________

---

## Section 12: Stakeholder Sign-Off

**THIS DOCUMENT ESTABLISHES BINDING API CONTRACTS. ALL SIGNATURES BELOW REPRESENT ACCEPTANCE AND COMMITMENT TO IMPLEMENT PER SPECIFICATIONS.**

### Backend Engineering Team

Lead: _________________________ Title: _________________ Date: __________

Confirmation: "We commit to implementing all 28+ endpoints per specification, including authentication, error handling, audit logging, and rate limiting. We accept responsibility for production readiness validation and security compliance."

**Signature**: _________________________

### Frontend Team

Lead: _________________________ Title: _________________ Date: __________

Confirmation: "We commit to implementing frontend client integration per the checklist, including OAuth 2.0 flow, JWT management, error handling, and pagination. We confirm architectural compatibility and testing completion."

**Signature**: _________________________

### Mobile Team

Lead: _________________________ Title: _________________ Date: __________

Confirmation: "We commit to implementing mobile client integration per the checklist, including secure credential storage, platform-specific OAuth, MFA, and offline sync. We confirm device compatibility and security review completion."

**Signature**: _________________________

### CLI Team

Lead: _________________________ Title: _________________ Date: __________

Confirmation: "We commit to implementing CLI client per the checklist, including API key authentication, pagination, filtering, and error handling. We confirm usability testing and documentation completion."

**Signature**: _________________________

### Security & Compliance Team

Lead: _________________________ Title: _________________ Date: __________

Confirmation: "We confirm this specification meets GDPR, SOC 2, and OWASP compliance requirements. We approve deployment subject to security scanning and audit logging validation."

**Signature**: _________________________

---

## Document Version Control

| Version | Date | Changes | Author | Status |
|---------|------|---------|--------|--------|
| 1.0 | 2024-07-15 | Initial API Contract Sign-Off | API Design Review Team | DRAFT |

---

## Amendment Process

1. **Initiate**: File GitHub Issue with `[API-AMENDMENT]` prefix
2. **Impact Analysis**: Document breaking changes and affected clients
3. **Review**: All 5 stakeholders must review and approve amendments
4. **Version Bump**: New version number with changelog entry
5. **Re-Sign**: All stakeholders must re-sign before deployment

---

## Effective Date & Expiration

- **Effective Date**: Upon final signature (all 5 stakeholders)
- **Expiration**: 12 months or until superseded by new version
- **Annual Review**: If no material changes, re-sign annually

---

**END OF API CONTRACT SIGN-OFF DOCUMENT**

*This document is a binding legal contract establishing API specifications between backend, frontend, mobile, and CLI teams. Unauthorized modification or distribution requires approval from all stakeholders.*

