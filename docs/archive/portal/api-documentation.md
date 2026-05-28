# Basecoat Portal API Documentation

## Overview

The Basecoat Portal API is a comprehensive REST API for governance, security audit, compliance tracking, and incident response simulation. It scales to 1000+ concurrent requests and provides role-based access control, audit logging, and webhook support.

**Base URL:** `https://api.basecoat.dev/v1`

**API Version:** 1.0.0

---

## Table of Contents

1. [Authentication](#authentication)
2. [Authorization](#authorization)
3. [Rate Limiting](#rate-limiting)
4. [Error Handling](#error-handling)
5. [Endpoints](#endpoints)
6. [Request/Response Examples](#requestresponse-examples)
7. [Webhooks](#webhooks)
8. [Glossary](#glossary)

---

## Authentication

The Basecoat Portal API supports two authentication methods:

### JWT Bearer Token

After successful login, the API returns a JWT bearer token that must be included in all subsequent requests.

**Request Header:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Token Lifecycle:**
- **Expiration:** 1 hour (3600 seconds)
- **Refresh:** Use `/auth/refresh` endpoint with valid token
- **Revocation:** Automatic on logout or password change

**Token Payload:**
```json
{
  "sub": "user-id-uuid",
  "email": "user@example.com",
  "role": "admin",
  "org": "org-id",
  "iat": 1672531200,
  "exp": 1672534800
}
```

### OAuth 2.0 (GitHub Integration)

For repository access and CI/CD integrations, use GitHub OAuth 2.0.

**Flow:**
1. Initiate: `GET /auth/oauth/github?redirectUri=https://yourapp.com/callback`
2. User authorizes in GitHub
3. GitHub redirects to your URI with `code` parameter
4. Exchange code for token at `/auth/oauth/github/callback`

**Required GitHub Scopes:**
- `repo` - Full control of repositories
- `user` - Read user profile
- `admin:repo_hook` - Full control of repository hooks

---

## Authorization

Access control is role-based (RBAC) with per-endpoint permission enforcement.

### Roles

| Role | Permissions | Use Case |
|------|-------------|----------|
| **admin** | Full access to all endpoints | Organization administrators |
| **auditor** | Create/read audits, view compliance | Security/compliance teams |
| **developer** | Create repositories, view findings | Development teams |
| **viewer** | Read-only access to reports | Executive stakeholders |

### Permission Matrix

| Endpoint | admin | auditor | developer | viewer |
|----------|-------|---------|-----------|--------|
| POST /teams | ✓ | ✗ | ✗ | ✗ |
| POST /teams/{id}/members | ✓ | ✗ | ✗ | ✗ |
| POST /repositories | ✓ | ✗ | ✓ | ✗ |
| POST /audits | ✓ | ✓ | ✓ | ✗ |
| GET /audits | ✓ | ✓ | ✓ | ✓ |
| POST /compliance/policies | ✓ | ✓ | ✗ | ✗ |
| GET /reports | ✓ | ✓ | ✓ | ✓ |

---

## Rate Limiting

All endpoints enforce rate limits to protect infrastructure.

**Default Limits:**
- **500 requests per minute** per user
- **5,000 requests per minute** per API key (service accounts)

**Rate Limit Headers:**
```
X-Rate-Limit-Limit: 500
X-Rate-Limit-Remaining: 487
X-Rate-Limit-Reset: 1672534860
```

**Rate Limit Exceeded Response:**
```json
HTTP/1.1 429 Too Many Requests
Retry-After: 60

{
  "code": "RATE_LIMIT_EXCEEDED",
  "message": "You have exceeded your request quota. Please retry after 60 seconds.",
  "retryAfter": 60,
  "timestamp": "2023-01-01T12:00:00Z"
}
```

---

## Error Handling

All errors follow a standardized format:

**Error Response Structure:**
```json
{
  "code": "ERROR_CODE",
  "message": "Human-readable error message",
  "details": { "field": "additionalContext" },
  "timestamp": "2023-01-01T12:00:00Z",
  "requestId": "req-12345abcde"
}
```

### HTTP Status Codes

| Status | Code | Meaning |
|--------|------|---------|
| 200 | OK | Request succeeded |
| 201 | CREATED | Resource created successfully |
| 204 | NO_CONTENT | Request succeeded, no content to return |
| 400 | VALIDATION_ERROR | Invalid request parameters |
| 401 | AUTH_UNAUTHORIZED | Missing or invalid authentication |
| 403 | INSUFFICIENT_PERMISSIONS | Authenticated but not authorized |
| 404 | RESOURCE_NOT_FOUND | Requested resource does not exist |
| 409 | CONFLICT | Resource already exists or version conflict |
| 429 | RATE_LIMIT_EXCEEDED | Too many requests |
| 500 | INTERNAL_ERROR | Server error |
| 503 | SERVICE_UNAVAILABLE | Service temporarily down for maintenance |

### Common Error Codes

| Code | HTTP | Description | Retry |
|------|------|-------------|-------|
| AUTH_UNAUTHORIZED | 401 | Token missing, invalid, or expired | ✗ |
| AUTH_INVALID_CREDENTIALS | 401 | Email/password incorrect | ✗ |
| INSUFFICIENT_PERMISSIONS | 403 | User lacks required role | ✗ |
| RESOURCE_NOT_FOUND | 404 | Entity does not exist | ✗ |
| VALIDATION_ERROR | 400 | Required fields missing/invalid | ✗ |
| CONFLICT_DUPLICATE | 409 | Resource already exists | ✗ |
| RATE_LIMIT_EXCEEDED | 429 | Quota exceeded | ✓ |
| INTERNAL_ERROR | 500 | Server error | ✓ |
| SERVICE_UNAVAILABLE | 503 | Maintenance/degradation | ✓ |

---

## Endpoints

### Authentication Endpoints

#### 1. POST /auth/login

Authenticate user with email and password.

**Request:**
```bash
curl -X POST https://api.basecoat.dev/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "securePassword123!"
  }'
```

**Response (200 OK):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "name": "John Doe",
    "role": "admin",
    "avatarUrl": "https://gravatar.com/...",
    "createdAt": "2023-01-01T00:00:00Z",
    "lastLoginAt": "2023-01-15T12:30:45Z"
  },
  "expiresIn": 3600
}
```

**Response (401 Unauthorized):**
```json
{
  "code": "AUTH_INVALID_CREDENTIALS",
  "message": "Invalid email or password",
  "timestamp": "2023-01-01T12:00:00Z"
}
```

---

#### 2. POST /auth/refresh

Refresh expired JWT token.

**Request:**
```bash
curl -X POST https://api.basecoat.dev/v1/auth/refresh \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response (200 OK):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600
}
```

---

#### 3. POST /auth/logout

Logout current user and invalidate token.

**Request:**
```bash
curl -X POST https://api.basecoat.dev/v1/auth/logout \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response (204 No Content)**

---

#### 4. GET /auth/oauth/github

Initiate GitHub OAuth 2.0 flow.

**Request:**
```bash
curl -X GET "https://api.basecoat.dev/v1/auth/oauth/github?redirectUri=https://yourapp.com/callback"
```

**Response (302 Found):**
```
Location: https://github.com/login/oauth/authorize?client_id=...&redirect_uri=...&scope=repo,user,admin:repo_hook
```

---

### Team Management Endpoints

#### 5. GET /teams

List all teams.

**Request:**
```bash
curl -X GET "https://api.basecoat.dev/v1/teams?limit=20&offset=0" \
  -H "Authorization: Bearer TOKEN"
```

**Response (200 OK):**
```json
{
  "items": [
    {
      "id": "team-uuid-1",
      "name": "Platform Engineering",
      "description": "Core infrastructure team",
      "members": [
        {
          "userId": "user-uuid-1",
          "role": "owner",
          "joinedAt": "2023-01-01T00:00:00Z"
        }
      ],
      "createdAt": "2023-01-01T00:00:00Z",
      "updatedAt": "2023-01-15T12:00:00Z"
    }
  ],
  "pagination": {
    "total": 1,
    "limit": 20,
    "offset": 0,
    "hasMore": false
  }
}
```

---

#### 6. POST /teams

Create new team.

**Request:**
```bash
curl -X POST https://api.basecoat.dev/v1/teams \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Security Team",
    "description": "Security and compliance"
  }'
```

**Response (201 Created):**
```json
{
  "id": "team-uuid-2",
  "name": "Security Team",
  "description": "Security and compliance",
  "members": [],
  "createdAt": "2023-01-15T12:00:00Z",
  "updatedAt": "2023-01-15T12:00:00Z"
}
```

---

#### 7. POST /teams/{teamId}/members

Add member to team.

**Request:**
```bash
curl -X POST https://api.basecoat.dev/v1/teams/team-uuid-2/members \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user-uuid-1",
    "role": "maintainer"
  }'
```

**Response (201 Created):**
```json
{
  "userId": "user-uuid-1",
  "role": "maintainer",
  "joinedAt": "2023-01-15T12:00:00Z"
}
```

---

### Repository Endpoints

#### 8. POST /repositories

Register repository.

**Request:**
```bash
curl -X POST https://api.basecoat.dev/v1/repositories \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "basecoat",
    "url": "https://github.com/IBuySpy-Shared/basecoat",
    "teamId": "team-uuid-1",
    "complianceLevel": "level3"
  }'
```

**Response (201 Created):**
```json
{
  "id": "repo-uuid-1",
  "name": "basecoat",
  "url": "https://github.com/IBuySpy-Shared/basecoat",
  "team": "team-uuid-1",
  "isPrivate": true,
  "language": "PowerShell",
  "complianceLevel": "level3",
  "lastAuditAt": null
}
```

---

### Audit Endpoints

#### 9. POST /audits

Create security audit.

**Request:**
```bash
curl -X POST https://api.basecoat.dev/v1/audits \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "repositoryId": "repo-uuid-1",
    "type": "security"
  }'
```

**Response (201 Created):**
```json
{
  "id": "audit-uuid-1",
  "repositoryId": "repo-uuid-1",
  "type": "security",
  "status": "pending",
  "findings": [],
  "createdAt": "2023-01-15T12:00:00Z",
  "completedAt": null
}
```

---

#### 10. POST /audits/batch

Create multiple audits in batch.

**Request:**
```bash
curl -X POST https://api.basecoat.dev/v1/audits/batch \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "audits": [
      {"repositoryId": "repo-uuid-1", "type": "security"},
      {"repositoryId": "repo-uuid-2", "type": "compliance"}
    ]
  }'
```

**Response (201 Created):**
```json
{
  "created": [
    {"id": "audit-uuid-1", "repositoryId": "repo-uuid-1", "status": "pending"},
    {"id": "audit-uuid-2", "repositoryId": "repo-uuid-2", "status": "pending"}
  ],
  "failed": []
}
```

---

#### 11. GET /audits/{auditId}

Retrieve audit details and findings.

**Request:**
```bash
curl -X GET https://api.basecoat.dev/v1/audits/audit-uuid-1 \
  -H "Authorization: Bearer TOKEN"
```

**Response (200 OK):**
```json
{
  "id": "audit-uuid-1",
  "repositoryId": "repo-uuid-1",
  "type": "security",
  "status": "completed",
  "findings": [
    {
      "id": "finding-1",
      "severity": "high",
      "category": "secrets-in-code",
      "description": "AWS credentials detected in source code",
      "remediation": "Remove credentials and rotate keys. Use AWS Secrets Manager.",
      "status": "open"
    },
    {
      "id": "finding-2",
      "severity": "medium",
      "category": "dependency-vulnerability",
      "description": "Outdated npm package: lodash@4.17.15",
      "remediation": "Update to lodash@4.17.21 or later",
      "status": "resolved"
    }
  ],
  "createdAt": "2023-01-15T12:00:00Z",
  "completedAt": "2023-01-15T12:15:30Z"
}
```

---

### Compliance Endpoints

#### 12. GET /compliance/policies

List compliance policies.

**Request:**
```bash
curl -X GET "https://api.basecoat.dev/v1/compliance/policies?framework=SOC2" \
  -H "Authorization: Bearer TOKEN"
```

**Response (200 OK):**
```json
{
  "policies": [
    {
      "id": "policy-uuid-1",
      "name": "SOC 2 Type II - Access Control",
      "framework": "SOC2",
      "rules": [
        {"id": "rule-1", "name": "MFA Required", "severity": "critical"},
        {"id": "rule-2", "name": "Password Policy", "severity": "high"}
      ],
      "enforcedAt": "2023-01-01T00:00:00Z"
    }
  ]
}
```

---

#### 13. GET /compliance/status

Get repository compliance status.

**Request:**
```bash
curl -X GET "https://api.basecoat.dev/v1/compliance/status?repositoryId=repo-uuid-1" \
  -H "Authorization: Bearer TOKEN"
```

**Response (200 OK):**
```json
{
  "repositoryId": "repo-uuid-1",
  "policies": [
    {
      "policyId": "policy-uuid-1",
      "name": "SOC 2 Type II",
      "compliance": 87,
      "violations": 3
    }
  ],
  "complianceScore": 87,
  "lastUpdated": "2023-01-15T12:00:00Z"
}
```

---

### Report Endpoints

#### 14. POST /reports

Generate compliance or security report.

**Request:**
```bash
curl -X POST https://api.basecoat.dev/v1/reports \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "SOC2 Compliance Report - Q1 2023",
    "type": "compliance"
  }'
```

**Response (201 Created):**
```json
{
  "id": "report-uuid-1",
  "name": "SOC2 Compliance Report - Q1 2023",
  "type": "compliance",
  "status": "generating",
  "createdAt": "2023-01-15T12:00:00Z"
}
```

---

#### 15. GET /analytics/dashboard

Retrieve analytics dashboard data.

**Request:**
```bash
curl -X GET https://api.basecoat.dev/v1/analytics/dashboard \
  -H "Authorization: Bearer TOKEN"
```

**Response (200 OK):**
```json
{
  "metrics": {
    "totalRepositories": 42,
    "auditsConducted": 156,
    "averageComplianceScore": 84.5,
    "criticalFindings": 12,
    "unresolvedFindings": 34
  },
  "trends": [
    {"date": "2023-01-01", "complianceScore": 82},
    {"date": "2023-01-08", "complianceScore": 84},
    {"date": "2023-01-15", "complianceScore": 85}
  ]
}
```

---

## Request/Response Examples

### Use Case: Complete Audit Workflow

**Step 1: Login**
```bash
curl -X POST https://api.basecoat.dev/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "auditor@company.com", "password": "pass123"}'
```

**Step 2: List Repositories**
```bash
curl -X GET https://api.basecoat.dev/v1/repositories \
  -H "Authorization: Bearer TOKEN"
```

**Step 3: Create Audit**
```bash
curl -X POST https://api.basecoat.dev/v1/audits \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"repositoryId": "repo-uuid", "type": "security"}'
```

**Step 4: Check Audit Status (poll)**
```bash
curl -X GET https://api.basecoat.dev/v1/audits/audit-uuid \
  -H "Authorization: Bearer TOKEN"
```

**Step 5: Generate Report**
```bash
curl -X POST https://api.basecoat.dev/v1/reports \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Audit Report", "type": "security"}'
```

---

## Webhooks

Future releases will support webhook notifications for audit completion and policy violations.

**Planned Events:**
- `audit.completed` - Audit scan finished
- `finding.created` - New security finding
- `policy.violated` - Compliance policy violation detected
- `report.ready` - Report generation complete

---

## Glossary

| Term | Definition |
|------|-----------|
| **Audit** | Automated security or compliance scan of a repository |
| **Finding** | Individual security issue or compliance violation discovered during audit |
| **Compliance Level** | 4-tier classification (L1-L4) indicating governance strictness |
| **Policy** | Set of rules enforced across repositories (e.g., SOC2, HIPAA) |
| **Simulation** | Controlled security incident response exercise |
| **JWT** | JSON Web Token for stateless authentication |
| **RBAC** | Role-Based Access Control for authorization |
| **Remediation** | Steps to resolve a finding or policy violation |

---

## Support

For API issues or questions:
- **Documentation:** https://basecoat.dev/docs
- **Email:** api-support@basecoat.dev
- **Issues:** https://github.com/IBuySpy-Shared/basecoat/issues
