# Basecoat Portal Identity & Access Control System Design

Complete enterprise identity and access control (IAM) architecture for Basecoat Portal Wave 3.

**Status**: ✅ Complete  
**Delivery Date**: May 5  
**Total Documentation**: 7 documents, 1,810+ lines, 75+ KB

## 📚 Start Here

1. **[IAM_DESIGN_INDEX.md](./IAM_DESIGN_INDEX.md)** — Navigation guide and quick reference
2. **[PORTAL_IDENTITY_DESIGN_v1.md](./PORTAL_IDENTITY_DESIGN_v1.md)** — Main design document (8+ pages)

## 📖 Documents Overview

| Document | Purpose | Audience |
|----------|---------|----------|
| **PORTAL_IDENTITY_DESIGN_v1.md** | Complete IAM architecture & design patterns | Architects, Security, Development |
| **RBAC_MATRIX.md** | Detailed role and permission reference | Developers, DevOps, Product |
| **OAUTH_INTEGRATION_GUIDE.md** | GitHub OAuth 2.0 implementation | Backend developers |
| **AZURE_AD_INTEGRATION_GUIDE.md** | Azure AD OIDC/SAML setup | DevOps, Security architects |
| **CODE_EXAMPLES.md** | Production-ready code samples | Backend developers |
| **AUDIT_TRAIL_SCHEMA.sql** | Database schema for compliance | Data engineers, DBAs |
| **IAM_DESIGN_INDEX.md** | Navigation & reference guide | All stakeholders |

## 🎯 What's Included

### Core Features
✅ **Role-Based Access Control** — 5 roles, 14 permissions  
✅ **Authentication** — GitHub OAuth 2.0, Azure AD (OIDC/SAML), API Keys  
✅ **Authorization** — Permission middleware, ABAC patterns  
✅ **Session Management** — JWT tokens (15 min access, 30 day refresh)  
✅ **Multi-Factor Authentication** — TOTP & FIDO2 (role-based enforcement)  
✅ **Multi-Tenancy** — Organization/team isolation with row-level security  
✅ **Audit Trail** — Comprehensive compliance logging (2-year retention)  
✅ **Incident Response** — Procedures for account/key compromise  

### Security Principles
�� Least Privilege (default-deny)  
🔒 Defense in Depth (multiple layers)  
🔒 Separation of Duties (no self-escalation)  
🔒 Comprehensive Audit (all identity events)  
🔒 Fail-Secure (errors deny by default)  
🔒 Expiring Credentials (90-day rotation)  

### Compliance
✅ SOC 2 audit trail requirements  
✅ HIPAA-compatible patterns  
✅ Multi-tenancy enforcement  
✅ Permission change tracking  
✅ Failed authentication logging  

## 🚀 Quick Start

### For Architects/Security
1. Read [PORTAL_IDENTITY_DESIGN_v1.md](./PORTAL_IDENTITY_DESIGN_v1.md) (main design)
2. Review [RBAC_MATRIX.md](./RBAC_MATRIX.md) (role definitions)
3. Check security sections in main design

### For Backend Developers
1. Start with [CODE_EXAMPLES.md](./CODE_EXAMPLES.md) (Node.js implementation)
2. Reference [OAUTH_INTEGRATION_GUIDE.md](./OAUTH_INTEGRATION_GUIDE.md) (GitHub setup)
3. Consult [RBAC_MATRIX.md](./RBAC_MATRIX.md) (permissions reference)

### For DevOps/Cloud
1. Read [AZURE_AD_INTEGRATION_GUIDE.md](./AZURE_AD_INTEGRATION_GUIDE.md)
2. Deploy [AUDIT_TRAIL_SCHEMA.sql](./AUDIT_TRAIL_SCHEMA.sql)
3. Configure Key Vault secrets (see main design, section 8)

### For DBAs/Data Engineers
1. Review [AUDIT_TRAIL_SCHEMA.sql](./AUDIT_TRAIL_SCHEMA.sql) (schema)
2. Check main design, section 10 (audit trail & compliance)
3. Configure retention policies per compliance requirements

## 📊 Design Coverage

- [x] Multi-provider authentication (GitHub, Azure AD, API keys)
- [x] Enterprise role hierarchy (5 roles with explicit permissions)
- [x] Team/organization-scoped access control
- [x] Audit trail for all identity events
- [x] MFA enforcement policies
- [x] Service account management
- [x] API key lifecycle (generation, rotation, revocation)
- [x] Secrets management (Azure Key Vault)
- [x] Incident response procedures
- [x] Production code examples
- [x] Database schema with indexes & views
- [x] Compliance reporting capabilities

## 🔐 Architecture Highlights

### Authentication Flow
```
User → GitHub OAuth / Azure AD / API Key
         ↓
JWT Token Generation (Access + Refresh)
         ↓
Authorization Middleware (Permission Check)
         ↓
Row-Level Security (Org/Team Filter)
         ↓
Grant/Deny Access
```

### Role Model
```
Admin (Portal-wide)
  ↓
Organization Admin (Org-level)
  ├─ Auditor (Org-wide audits)
  ├─ Developer (Team issues)
  └─ Viewer (Read-only)
```

### Audit Trail
```
Every Identity Event → audit_events Table
                    → Indexed by org_id, timestamp
                    → Exported for compliance
                    → Retained 90 days (or 2 years for compliance)
```

## 📋 File Checklist

- [x] PORTAL_IDENTITY_DESIGN_v1.md (291 lines) — Main design document
- [x] RBAC_MATRIX.md (122 lines) — Permission reference
- [x] OAUTH_INTEGRATION_GUIDE.md (292 lines) — GitHub OAuth setup
- [x] AZURE_AD_INTEGRATION_GUIDE.md (319 lines) — Azure AD configuration
- [x] CODE_EXAMPLES.md (396 lines) — Production code samples
- [x] AUDIT_TRAIL_SCHEMA.sql (390 lines) — Database schema
- [x] IAM_DESIGN_INDEX.md (detailed index) — Navigation guide

**Total**: 7 documents, 1,810+ lines, 75+ KB

## 🎓 Implementation Phases

1. **Phase 1** (Weeks 1-2): Core authentication (JWT, GitHub OAuth)
2. **Phase 2** (Weeks 3-4): Enhanced identity (Azure AD, MFA, API keys)
3. **Phase 3** (Weeks 5-6): Audit & compliance (event logging, reports)
4. **Phase 4** (Weeks 7-8): Security hardening (incident response, detection)

## 📞 Support & Questions

Refer to:
- **Architecture questions**: [PORTAL_IDENTITY_DESIGN_v1.md](./PORTAL_IDENTITY_DESIGN_v1.md)
- **Permission questions**: [RBAC_MATRIX.md](./RBAC_MATRIX.md)
- **Implementation questions**: [CODE_EXAMPLES.md](./CODE_EXAMPLES.md)
- **Integration questions**: OAuth/Azure guides
- **Database questions**: [AUDIT_TRAIL_SCHEMA.sql](./AUDIT_TRAIL_SCHEMA.sql)
- **Navigation help**: [IAM_DESIGN_INDEX.md](./IAM_DESIGN_INDEX.md)

---

**Version**: 1.0  
**Status**: Complete & Ready for Implementation  
**Last Updated**: January 15, 2025  
**Delivery Deadline**: May 5 ✅

