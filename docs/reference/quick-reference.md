# Basecoat Portal API — Quick Reference Card

## 🎯 At a Glance

| Aspect | Details |
|--------|---------|
| **Version** | 1.0.0 |
| **Base URL** | `https://api.basecoat.dev/v1` |
| **Spec Format** | OpenAPI 3.0.0 |
| **Auth** | JWT Bearer (1h expiration) + OAuth 2.0 |
| **Rate Limit** | 500 req/min per user |
| **Scalability** | 1000+ concurrent requests |
| **Endpoints** | 17 paths / 28 operations |
| **Schemas** | 8 core + nested objects |
| **Error Codes** | 8 standardized types |
| **Status Codes** | 200, 201, 204, 400, 401, 403, 404, 409, 429, 500 |

---

## 🔐 Authentication Quick Start

### Login
```bash
curl -X POST https://api.basecoat.dev/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"pass123"}'
```

**Response:** `{token, user, expiresIn: 3600}`

### Using Token in Requests
```bash
curl -X GET https://api.basecoat.dev/v1/teams \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..."
```

### Refresh Token
```bash
curl -X POST https://api.basecoat.dev/v1/auth/refresh \
  -H "Authorization: Bearer TOKEN"
```

### Logout
```bash
curl -X POST https://api.basecoat.dev/v1/auth/logout \
  -H "Authorization: Bearer TOKEN"
```

---

## 👥 User Roles & Permissions

| Role | Auth | Teams | Repos | Audits | Compliance | Reports |
|------|------|-------|-------|--------|-----------|---------|
| **admin** | ✓ | ✓✓ | ✓✓ | ✓✓ | ✓✓ | ✓ |
| **auditor** | ✓ | ✗ | ✗ | ✓✓ | ✓✓ | ✓ |
| **developer** | ✓ | ✗ | ✓ | ✓ | ✗ | ✓ |
| **viewer** | ✓ | ✗ | ✗ | ✗ | ✗ | ✓ |

---

## 📊 Core Endpoints (28 operations)

### Authentication (4)
- `POST /auth/login` — User login
- `POST /auth/refresh` — Refresh token
- `POST /auth/logout` — Logout
- `GET /auth/oauth/github` — GitHub OAuth

### Teams (6)
- `GET /teams` — List teams
- `POST /teams` — Create team
- `GET /teams/{id}` — Get team
- `PATCH /teams/{id}` — Update team
- `DELETE /teams/{id}` — Delete team
- `POST /teams/{id}/members` — Add member

### Repositories (5)
- `GET /repositories` — List repos
- `POST /repositories` — Register repo
- `GET /repositories/{id}` — Get repo
- `PATCH /repositories/{id}` — Update repo
- `DELETE /repositories/{id}` — Delete repo

### Audits (4)
- `GET /audits` — List audits
- `POST /audits` — Create audit
- `GET /audits/{id}` — Get audit
- `POST /audits/batch` — Batch create

### Compliance (3)
- `GET /compliance/policies` — List policies
- `POST /compliance/policies` — Create policy
- `GET /compliance/status` — Get compliance

### Reports (4)
- `GET /reports` — List reports
- `POST /reports` — Generate report
- `GET /analytics/dashboard` — Dashboard

---

## 📋 Pagination Pattern

```json
{
  "items": [...],
  "pagination": {
    "total": 150,
    "limit": 20,
    "offset": 0,
    "hasMore": true
  }
}
```

**Query Parameters:**
```
?limit=20&offset=0
```

---

## ❌ Error Response Format

```json
{
  "code": "ERROR_CODE",
  "message": "Human readable message",
  "details": { "field": "context" },
  "timestamp": "2023-01-01T12:00:00Z",
  "requestId": "req-12345"
}
```

### Error Codes
- `AUTH_UNAUTHORIZED` (401) — Missing/invalid token
- `AUTH_INVALID_CREDENTIALS` (401) — Wrong email/password
- `INSUFFICIENT_PERMISSIONS` (403) — User lacks role
- `RESOURCE_NOT_FOUND` (404) — Entity not found
- `VALIDATION_ERROR` (400) — Invalid parameters
- `CONFLICT_DUPLICATE` (409) — Already exists
- `RATE_LIMIT_EXCEEDED` (429) — Over quota
- `INTERNAL_ERROR` (500) — Server error

---

## ⏱️ Rate Limiting

**Headers in Response:**
```
X-Rate-Limit-Limit: 500
X-Rate-Limit-Remaining: 487
X-Rate-Limit-Reset: 1672534860
```

**When Exceeded (429):**
```
Retry-After: 60
```

---

## 🗂️ Data Schemas Summary

### User
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "name": "John Doe",
  "role": "admin|auditor|developer|viewer",
  "createdAt": "2023-01-01T00:00:00Z"
}
```

### Team
```json
{
  "id": "uuid",
  "name": "Platform Engineering",
  "members": [{userId, role, joinedAt}],
  "createdAt": "2023-01-01T00:00:00Z"
}
```

### Repository
```json
{
  "id": "uuid",
  "name": "basecoat",
  "url": "https://github.com/...",
  "complianceLevel": "level1|level2|level3|level4",
  "team": "uuid",
  "lastAuditAt": "2023-01-15T12:00:00Z"
}
```

### Audit
```json
{
  "id": "uuid",
  "repositoryId": "uuid",
  "type": "security|compliance|code-quality|dependency",
  "status": "pending|in_progress|completed|failed",
  "findings": [{id, severity, category, description}]
}
```

### Finding
```json
{
  "id": "uuid",
  "severity": "critical|high|medium|low|info",
  "category": "secrets-in-code|dependency-vulnerability|...",
  "description": "...",
  "remediation": "...",
  "status": "open|acknowledged|resolved|false_positive"
}
```

---

## 🎯 Implementation Checklist

- [ ] Read PORTAL_API_v1.0.yml
- [ ] Study IMPLEMENTATION_NOTES.md
- [ ] Install dependencies (jsonwebtoken, bcryptjs, redis, bull)
- [ ] Implement JWT service
- [ ] Create auth middleware
- [ ] Implement RBAC checks
- [ ] Set up database schema
- [ ] Implement auth endpoints
- [ ] Implement team endpoints
- [ ] Implement repository endpoints
- [ ] Implement audit endpoints
- [ ] Implement compliance endpoints
- [ ] Add error handling
- [ ] Add rate limiting
- [ ] Write tests (>80% coverage)
- [ ] Load test (1000+ concurrent)
- [ ] Deploy and monitor

---

## 📚 Documentation Files

1. **PORTAL_API_v1.0.yml** — OpenAPI specification (import into Swagger/Postman)
2. **API_DOCUMENTATION.md** — Developer guide with examples
3. **IMPLEMENTATION_NOTES.md** — Backend implementation patterns
4. **API_DELIVERY_SUMMARY.md** — Executive overview

---

## 🚀 Sample Workflow

```bash
# 1. Login
TOKEN=$(curl -s -X POST https://api.basecoat.dev/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"pass"}' \
  | jq -r '.token')

# 2. List teams
curl -X GET https://api.basecoat.dev/v1/teams \
  -H "Authorization: Bearer $TOKEN"

# 3. Create audit
AUDIT_ID=$(curl -s -X POST https://api.basecoat.dev/v1/audits \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"repositoryId":"repo-uuid","type":"security"}' \
  | jq -r '.id')

# 4. Check audit status
curl -X GET https://api.basecoat.dev/v1/audits/$AUDIT_ID \
  -H "Authorization: Bearer $TOKEN"

# 5. Logout
curl -X POST https://api.basecoat.dev/v1/auth/logout \
  -H "Authorization: Bearer $TOKEN"
```

---

## 📞 Support

- **Documentation:** See API_DOCUMENTATION.md
- **Implementation:** See IMPLEMENTATION_NOTES.md
- **Spec:** See PORTAL_API_v1.0.yml
- **Email:** api-support@basecoat.dev
- **Issues:** https://github.com/IBuySpy-Shared/basecoat/issues

---

**Deadline: May 5, 2024**
