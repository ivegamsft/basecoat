# Basecoat Portal Technical Documentation Index v1.0

## Complete Reference for Wave 3 Design Acceleration

**Status**: Final | **Version**: 1.0 | **Last Updated**: May 5, 2025 | **Target Audience**: Backend Developers, Frontend Developers, DevOps Engineers, QA Teams

---

## Table of Contents

1. [Getting Started Guide](#getting-started-guide)
2. [Architecture Documentation](#architecture-documentation)
3. [API Documentation](#api-documentation)
4. [Database Documentation](#database-documentation)
5. [Development Guides](#development-guides)
6. [Deployment Runbooks](#deployment-runbooks)
7. [Operations Runbooks](#operations-runbooks)
8. [Troubleshooting Guide](#troubleshooting-guide)
9. [Security & Authentication](#security--authentication)

---

## 1. Getting Started Guide

### 1.1 Prerequisites

- PostgreSQL 14+ (local dev: `docker run -d -p 5432:5432 -e POSTGRES_PASSWORD=password postgres:14`)
- Node.js 18+ / Python 3.9+ / Go 1.19+ (pick one backend)
- Git, npm/pip/go, curl
- GitHub account (for OAuth 2.0 setup)

### 1.2 Local Development Setup

#### Initialize Database

```bash
# Create database
createdb basecoat_portal

# Initialize schema
psql -d basecoat_portal -f db/migrations/v1.0/001_initial_schema.sql

# Load seed data (development only)
psql -d basecoat_portal -f db/seeds/001_initial_data.sql

# Verify setup
psql -d basecoat_portal -c "\dt"
```

#### Backend Setup (Node.js)

```bash
npm install
npm run dev
# API runs on http://localhost:3000
```

#### Frontend Setup

```bash
cd frontend
npm install
npm run dev
# UI runs on http://localhost:5173
```

### 1.3 Quick Start Commands

```bash
# Run all services
docker-compose up

# Verify connectivity
curl http://localhost:3000/health
curl http://localhost:5173
```

---

## 2. Architecture Documentation

### 2.1 System Context Diagram (C4 Level 1)

The Basecoat Portal is an enterprise governance, security audit, and compliance platform designed to serve 100-1000+ concurrent users across multi-region cloud deployments.

**Key Characteristics:**
- **Scale**: 100-1000+ concurrent users with burst capacity to 2000+
- **Availability**: 99.99% uptime SLA (RTO <4 hours, RPO <1 hour)
- **Regions**: Multi-region deployment (AWS/Azure/GCP agnostic)
- **Security**: Zero-trust, SOC 2 Type II, FedRAMP-ready compliance
- **Cost**: Optimized for 60-70% cost efficiency through auto-scaling

**External Systems:**
- **GitHub.com**: Source of truth for repository metadata, audit trails, PR/issue activity
- **Enterprise SSO**: Okta/Entra ID for authentication and RBAC
- **Reporting Consumers**: Governance teams, compliance officers, stakeholders

### 2.2 Container Architecture (C4 Level 2)

**Core Containers:**
- **Web Frontend**: Single-page application (React/SPA) with governance dashboards
- **API Gateway**: REST + gRPC with rate limiting and authentication
- **Auth Service**: OIDC with enterprise SSO and JWT tokens
- **Audit Module**: GitHub webhook consumer and event normalization
- **Compliance Module**: Policy evaluation and rule engine
- **GitHub Sync**: Repository and user synchronization
- **Events Stream**: Event bus for async communication
- **Metrics Collector**: Application metrics and telemetry

**Data Stores:**
- PostgreSQL 14+: Primary SQL datastore
- Event Stream: Kafka/RabbitMQ message bus
- Object Storage: S3/Blob for reports

### 2.3 Deployment Strategy

**Multi-Region Topology:**
- Active-active in 2+ regions (AWS us-east, us-west / Azure East US, West US)
- PostgreSQL streaming replication (master-standby)
- Global load balancer with geographic routing
- DNS failover on region outage
- RTO: 4 hours, RPO: 1 hour

---

## 3. API Documentation

### 3.1 Base URL

```
https://api.basecoat.example.com/v1
```

### 3.2 Authentication

All API requests require Bearer token:

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

Tokens expire in 1 hour. Use refresh endpoint:

```
POST /v1/auth/refresh
Content-Type: application/json
```

### 3.3 Core Endpoints

#### Organizations

```
GET /v1/organizations
GET /v1/organizations/{org_id}
POST /v1/organizations
PATCH /v1/organizations/{org_id}
DELETE /v1/organizations/{org_id}
```

#### Repositories

```
GET /v1/organizations/{org_id}/repositories
POST /v1/organizations/{org_id}/repositories
GET /v1/repositories/{repo_id}/scans
POST /v1/repositories/{repo_id}/scans
```

#### Audit & Compliance

```
GET /v1/audit-logs
GET /v1/compliance-issues
PATCH /v1/compliance-issues/{issue_id}
POST /v1/reports/export
```

### 3.4 Error Handling

Consistent error schema:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid organization ID",
    "details": [
      {"field": "org_id", "reason": "must be a valid UUID"}
    ]
  }
}
```

**Common Status Codes:** 200, 201, 400, 401, 403, 404, 500

### 3.5 Pagination

List endpoints support pagination:

```
GET /v1/audit-logs?page=1&page_size=50&sort=-created_at
```

---

## 4. Database Documentation

### 4.1 Schema Overview

**Multi-Tenant Architecture:**
- `organizations`, `users`, `teams`, `team_members`, `roles`

**Scanning & Results:**
- `repositories`, `scans`, `scan_results`, `compliance_issues`

**Audit & Compliance:**
- `audit_logs` (immutable, 7-year retention)
- `reports` (aggregated insights)

### 4.2 Data Volume Projections

| Metric | 12 Months |
|--------|-----------|
| Users | 5K |
| Organizations | 100+ |
| Repositories | 50K+ |
| Scans | 2M+ |
| Audit Logs | 10M+ |
| **Total Size** | **~2.2 GB** |

### 4.3 Key Indexes

- `(repository_id, created_at, severity)` - Scan results
- `(organization_id, created_at)` - Org-scoped pagination
- `(user_id, created_at DESC)` - Audit queries
- Partial indexes: `WHERE deleted_at IS NULL`

### 4.4 Backup & Recovery

```bash
./db/backup-scripts/backup.sh
# Creates: backups/basecoat_portal_YYYY-MM-DD.sql.gz

# Restore
./db/backup-scripts/restore.sh backups/basecoat_portal_2025-05-01.sql.gz
```

---

## 5. Development Guides

### 5.1 Backend Technology Stack

**Node.js + Fastify:**

```
src/
├── routes/          # API endpoints
├── handlers/        # Business logic
├── middleware/      # Auth, logging
├── db/              # Query builders
├── services/        # External integrations
└── types/           # TypeScript interfaces
```

**Python + FastAPI:**

```
app/
├── api/routes/      # API endpoints
├── models/          # SQLAlchemy ORM
├── schemas/         # Pydantic validation
└── services/        # Business logic
```

### 5.2 Frontend Implementation

**Tech Stack: React 18 + TypeScript + Tailwind CSS**

```
src/
├── components/      # React components
├── pages/          # Page-level components
├── hooks/          # Custom hooks
├── state/          # Zustand stores
├── services/       # API client
└── types/          # TypeScript interfaces
```

### 5.3 Testing Strategy

**Backend:** 80%+ coverage, integration tests, E2E critical workflows

```bash
npm test                    # Run all tests
npm run test:coverage       # Coverage report
```

**Frontend:** Component tests, snapshot tests, visual regression

```bash
npm test                    # Vitest
npm run storybook           # Component documentation
```

---

## 6. Deployment Runbooks

### 6.1 Development Environment

```bash
docker-compose up -d
npm run seed:dev
npm run migrate
npm run dev
```

### 6.2 Staging Environment

```bash
docker build -t basecoat:v1.0.0 .
docker push myregistry.azurecr.io/basecoat:v1.0.0
terraform apply -var-file=staging.tfvars
kubectl apply -f k8s/staging/
kubectl exec -it deployment/basecoat-api -- npm run migrate
npm run test:smoke
```

### 6.3 Production - Blue-Green Deployment

```bash
# Deploy to green
kubectl apply -f k8s/production/green/

# Health checks
kubectl logs deployment/basecoat-api-green
curl https://green.basecoat.example.com/health

# Route traffic
kubectl patch service basecoat-api -p '{"spec":{"selector":{"version":"green"}}}'

# Monitor (30 min), then clean up
kubectl delete deployment basecoat-api-blue
```

### 6.4 Rollback Procedure

```bash
# Automatic on health check failure
kubectl rollout undo deployment/basecoat-api

# Manual rollback
kubectl rollout history deployment/basecoat-api
kubectl rollout undo deployment/basecoat-api --to-revision=3
```

---

## 7. Operations Runbooks

### 7.1 Monitoring & Alerting

**Key Metrics:**
- API response time (p50, p95, p99)
- Error rate (4xx, 5xx)
- Database connection pool utilization
- Disk space on PostgreSQL

**Alerting Thresholds:**
- Error rate > 1% (warning), > 5% (critical)
- Response p99 > 2000ms (warning), > 5000ms (critical)
- Database disk > 80% (warning), > 90% (critical)

### 7.2 Scaling Operations

```bash
# Horizontal: scale API servers
kubectl scale deployment basecoat-api --replicas=5
kubectl autoscale deployment basecoat-api --min=2 --max=10 --cpu-percent=70

# Vertical: database upgrades
# Create standby with larger instance, failover, upgrade old master
```

### 7.3 Maintenance Tasks

**Daily:** Error logs, backup verification, disk space

**Weekly:** Slow query analysis, vacuum, disaster recovery test

**Monthly:** API key rotation, access log review, dependency updates

### 7.4 Incident Response

1. **Alert triggered** → on-call notified
2. **Initial response** → check dashboards, logs
3. **Diagnosis** → trace to component
4. **Mitigation** → rollback, scale, failover
5. **Resolution** → fix, deploy
6. **Postmortem** → document, action items

---

## 8. Troubleshooting Guide

### 8.1 Common Errors

**PostgreSQL connection refused**

```
Error: connect ECONNREFUSED 127.0.0.1:5432
Solution:
- Check: ps aux | grep postgres
- Verify: DATABASE_URL=postgresql://user:pass@host:5432/db
- Check firewall for port 5432
```

**Authentication token expired**

```
Error: 401 Unauthorized
Solution:
- Refresh: POST /v1/auth/refresh
- Re-login: POST /v1/auth/login
- Check: kubectl logs svc/auth-service
```

**GitHub OAuth callback mismatch**

```
Error: redirect_uri_mismatch
Solution:
- GitHub app settings verify callback URL
- Check: GITHUB_OAUTH_CALLBACK_URL env var
- Verify load balancer forwarding
```

### 8.2 Performance Debugging

```bash
# Slow API endpoint
SET log_min_duration_statement = 500;
SELECT query, mean_time FROM pg_stat_statements ORDER BY mean_time DESC;
EXPLAIN ANALYZE SELECT ...;
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);
```

**High CPU usage:**
- `top -p <PID>` - check process
- `perf record -p <PID> -F 99 -g` - profile
- Look for: constant 100% CPU or gradual memory increase

### 8.3 Connectivity Issues

```bash
# GitHub API
nslookup api.github.com
curl -v https://api.github.com/zen

# Check rate limits
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/rate_limit

# Database replication lag
SELECT pg_last_xlog_receive_location() AS receive,
       pg_last_xlog_replay_location() AS replay;
```

---

## 9. Security & Authentication

### 9.1 Role-Based Access Control (RBAC)

| Role | Scope | Responsibilities |
|------|-------|------------------|
| Admin | Portal-wide | Full control: teams, policies, audit config |
| Organization Admin | Organization | Multi-team management, org policies |
| Auditor | Organization | Submit audits, view results, reports |
| Developer | Team | View assigned issues, update status |
| Viewer | Organization | Read-only: dashboard, metrics, results |

### 9.2 Permission Matrix

| Permission | Admin | Org Admin | Auditor | Developer | Viewer |
|-----------|-------|----------|---------|-----------|--------|
| View Dashboard | ✓ | ✓ | ✓ | ✓ | ✓ |
| Submit Audit | ✓ | ✓ | ✓ | ✗ | ✗ |
| Configure Policies | ✓ | ✓ | ✗ | ✗ | ✗ |
| Manage Teams | ✓ | ✓ | ✗ | ✗ | ✗ |
| Manage Users/Roles | ✓ | ✓ | ✗ | ✗ | ✗ |

### 9.3 Authentication Architecture

**GitHub OAuth 2.0** (Primary)
- Enterprise organizations use GitHub Teams
- Fallback to internal user database

**Azure Active Directory** (Secondary)
- SAML 2.0 or OpenID Connect
- Automatic group/role mapping
- Conditional Access policies

**Service Accounts** (Workload)
- API keys with permission grants
- 90-day rotation required

### 9.4 GitHub OAuth 2.0 Flow

```
1. User → Portal: "Sign in with GitHub"
2. Portal → GitHub: POST /login/oauth/authorize
3. GitHub → User: "Authorize Basecoat"
4. User → GitHub: Grant access
5. GitHub → Portal: Callback with code
6. Portal → GitHub: Exchange code for token
7. Portal → User: Set JWT cookie
8. User → Portal: JWT in Authorization header
```

### 9.5 JWT Token Structure

```json
{
  "iss": "https://basecoat.example.com",
  "sub": "user-id-123",
  "aud": "basecoat-api",
  "iat": 1620000000,
  "exp": 1620003600,
  "roles": ["developer", "auditor"],
  "org_id": "org-456",
  "teams": ["team-789"],
  "permissions": ["view:audit_logs", "create:compliance_issue"]
}
```

**Expiry:**
- Access token: 1 hour
- Refresh token: 30 days
- Auto-refresh on expiry

### 9.6 Security Best Practices

**Data Protection:**
- AES-256 encryption at rest
- TLS 1.3 for transit
- Sensitive fields encrypted in database

**Authentication:**
- MFA for admin accounts
- 15-minute session timeout
- Password: 12+ chars, mixed case, numbers, symbols

**Authorization:**
- Least-privilege default-deny
- Immediate role change propagation
- Audit all permission changes

**Audit Logging:**
- Immutable append-only logs
- Login, role changes, data exports logged with IP/user agent
- 7-year retention (compliance)

### 9.7 Compliance Requirements

**Standards:**
- SOC 2 Type II
- GDPR (right to be forgotten, data portability)
- FedRAMP (in-progress)
- HIPAA (available for healthcare)

**Data Residency:**
- US data → US regions only
- EU data → EU regions (GDPR)
- Customer-controlled retention policies

---

## Quick Reference

### Port Mappings

| Service | Port | Protocol |
|---------|------|----------|
| API | 3000 | HTTP/REST, gRPC |
| Frontend | 5173 | HTTP |
| PostgreSQL | 5432 | TCP |
| Event Stream | 9092 | TCP (Kafka) |

### Environment Variables

```bash
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/basecoat_portal

# GitHub OAuth
GITHUB_CLIENT_ID=xxx
GITHUB_CLIENT_SECRET=xxx
GITHUB_OAUTH_CALLBACK_URL=http://localhost:3000/v1/auth/github/callback

# JWT
JWT_SECRET=your-secret-key-min-32-chars
JWT_EXPIRES_IN=1h
JWT_REFRESH_EXPIRES_IN=30d

# Environment
NODE_ENV=development
PORT=3000
LOG_LEVEL=debug
```

### Common Commands

```bash
# Database
npm run migrate               # Run migrations
npm run seed:dev             # Load dev data
npm run db:backup            # Create backup

# Testing
npm test                      # All tests
npm run test:coverage         # Coverage report
npm run test:e2e             # End-to-end tests

# Development
npm run dev                   # Dev server
npm run lint                  # Lint code
npm run format               # Format code

# Deployment
docker build -t basecoat:v1.0.0 .
kubectl apply -f k8s/
```

---

## Additional Resources

- **Architecture Deep Dive**: `docs/PORTAL_ARCHITECTURE_v1.md`
- **Database Schema Details**: `docs/PORTAL_DATABASE_SCHEMA_v1.md`
- **Implementation Guide**: `docs/PORTAL_IMPLEMENTATION_GUIDE_v1.md`
- **Frontend Guide**: `FRONTEND_IMPLEMENTATION_GUIDE.md`
- **Identity Design**: `PORTAL_IDENTITY_DESIGN_v1.md`
- **OpenAPI Spec**: `PORTAL_API_v1.0.yml`
- **Database Guide**: `db/README.md`

---

**Document Version**: 1.0 | **Last Updated**: May 5, 2025 | **Next Review**: June 5, 2025
