# Basecoat Portal Identity & Access Control Design
## Complete Implementation Guide

**Version**: 1.0 | **Status**: Complete | **Delivery Date**: May 5  
**Total Pages**: 8+ | **Total Lines**: 1,810 | **Code Examples**: 6

---

## 📋 Document Index

### Main Design Document
- **[PORTAL_IDENTITY_DESIGN_v1.md](./PORTAL_IDENTITY_DESIGN_v1.md)** — 291 lines
  - Executive summary and design principles
  - Complete RBAC matrix with 5 roles and 14 permissions
  - GitHub OAuth 2.0 architecture and flow
  - Multi-tenancy model with row-level security
  - JWT token management (access + refresh tokens)
  - Multi-factor authentication enforcement
  - Service-to-service authentication and API keys
  - Azure Active Directory integration options
  - Secrets management via Azure Key Vault
  - Audit trail schema and compliance requirements
  - Authorization enforcement patterns
  - Incident response procedures

### Supporting Reference Documents
- **[RBAC_MATRIX.md](./RBAC_MATRIX.md)** — 122 lines
  - Detailed role definitions and scope
  - Permission matrix (all 14 permissions across 5 roles)
  - Permission groupings organized by feature area
  - Scope resolution guide (team/org/portal levels)
  - Access control decision tree

- **[OAUTH_INTEGRATION_GUIDE.md](./OAUTH_INTEGRATION_GUIDE.md)** — 292 lines
  - Step-by-step GitHub OAuth application setup
  - Complete OAuth 2.0 flow (4-step exchange)
  - Required scopes and rationale
  - GitHub Teams to role mapping configuration
  - Session and JWT token creation
  - CSRF protection and state validation
  - Error handling and security best practices
  - Testing procedures (manual and automated)
  - Troubleshooting common OAuth issues

- **[AZURE_AD_INTEGRATION_GUIDE.md](./AZURE_AD_INTEGRATION_GUIDE.md)** — 319 lines
  - Azure AD application registration
  - OpenID Connect (OIDC) flow and configuration
  - SAML 2.0 as alternative authentication method
  - AAD security group mapping to Basecoat roles
  - Conditional Access policies (MFA, location, legacy auth)
  - Node.js implementation using openid-client
  - Troubleshooting common AAD integration issues

- **[CODE_EXAMPLES.md](./CODE_EXAMPLES.md)** — 396 lines
  - JWT token validation middleware (RS256)
  - Authorization middleware with permission checking
  - Organization-scoped access control
  - Team-scoped access control
  - Complete GitHub OAuth callback handler
  - Token refresh endpoint implementation
  - Service account and API key validation
  - Audit event logging patterns
  - Production-ready Node.js examples

- **[AUDIT_TRAIL_SCHEMA.sql](./AUDIT_TRAIL_SCHEMA.sql)** — 390 lines
  - Core audit_events table design with indexes
  - Authentication event logging (login/logout)
  - Authorization and permission event tracking
  - Role assignment history
  - API key lifecycle events
  - MFA and session management events
  - permission_audit table for permission history
  - Compliance reporting views (24h activity, failed auth, admin actions)
  - Data retention and cleanup policies

---

## 🎯 Quick Reference

### Identity Providers Supported
| Provider | Method | Enterprise Support |
|----------|--------|-------------------|
| GitHub | OAuth 2.0 | ✓ GitHub Teams mapping |
| Azure AD | OIDC/SAML 2.0 | ✓ Security group mapping |
| Internal | API Keys | ✓ Service accounts |

### Role Model (5 Roles)
| Role | Scope | Primary Use |
|------|-------|------------|
| **Admin** | Portal-wide | Full administrative control |
| **Organization Admin** | Organization | Org-level management & billing |
| **Auditor** | Organization | Compliance audits & reporting |
| **Developer** | Team | Issue resolution & updates |
| **Viewer** | Organization | Read-only access |

### Key Security Principles
- ✓ **Least Privilege**: Default-deny authorization
- ✓ **Defense in Depth**: Multiple security layers
- ✓ **Separation of Duties**: No self-escalation
- ✓ **Audit Everything**: Complete event logging
- ✓ **Fail-Secure**: Errors default to deny
- ✓ **Expiring Credentials**: Forced rotation

### Compliance Requirements Met
- ✓ SOC 2 audit trail requirements
- ✓ HIPAA-compatible patterns
- ✓ Multi-tenancy isolation
- ✓ Row-level security enforcement
- ✓ Permission change tracking (2-year retention)
- ✓ Failed authentication logging (90-day retention)

---

## 🚀 Implementation Roadmap

### Phase 1: Core Authentication (Week 1-2)
1. Implement JWT token generation and validation
2. Integrate GitHub OAuth 2.0
3. Set up database for users and audit events
4. Deploy authorization middleware

### Phase 2: Enhanced Identity (Week 3-4)
1. Add Azure AD OIDC/SAML support
2. Implement MFA (TOTP/FIDO2)
3. Deploy API key management
4. Enable group-based role mapping

### Phase 3: Audit & Compliance (Week 5-6)
1. Deploy audit trail logging for all events
2. Create compliance reporting views
3. Implement audit data retention policies
4. Validate compliance requirements

### Phase 4: Security Hardening (Week 7-8)
1. Implement incident response procedures
2. Add privilege escalation detection
3. Security audit of implementation
4. Production hardening

---

## 📊 Technical Specifications

### Authentication
- **Access Token**: JWT (RS256), 15-minute expiry
- **Refresh Token**: Secure HTTP-only cookie, 30-day expiry
- **Session Timeout**: Activity-based + role-specific maximums
- **MFA**: TOTP (all users) + FIDO2 (admins required)

### Authorization
- **Model**: Role-Based Access Control (RBAC)
- **Scope**: Portal-wide, organization, team levels
- **Enforcement**: Permission checking middleware + ABAC rules
- **Audit**: All permission decisions logged

### Audit Trail
- **Events Logged**: Login, logout, permission changes, role assignments, API key usage
- **Retention**: 90 days (short-term), 2 years (compliance events)
- **Storage**: PostgreSQL with row-level security
- **Export**: Compliance reports (daily, monthly, annual)

### Secrets Management
- **Provider**: Azure Key Vault
- **Secrets Managed**: OAuth credentials, JWT keys, API credentials
- **Rotation**: 90 days (API), 1 year (keys)
- **Access Control**: Managed identities only

---

## ✅ Verification Checklist

### Document Completeness
- [x] Main design document (8+ pages)
- [x] RBAC matrix with 5 roles and 14 permissions
- [x] GitHub OAuth 2.0 integration guide
- [x] Azure AD OIDC/SAML configuration guide
- [x] Production-ready code examples
- [x] Audit trail schema with compliance logging
- [x] Multi-tenancy architecture documented
- [x] MFA enforcement policy defined
- [x] Service account/API key model specified
- [x] Incident response procedures included

### Design Coverage
- [x] Least privilege enforcement
- [x] Defense in depth strategy
- [x] Separation of duties
- [x] Expiring credentials mandatory
- [x] Comprehensive audit trail
- [x] Multi-provider support (GitHub, Azure AD)
- [x] Enterprise-scale features (org management, billing)
- [x] Security incident handling
- [x] Compliance alignment (SOC 2, HIPAA patterns)

---

## 📝 Usage Notes

1. **Read First**: Start with PORTAL_IDENTITY_DESIGN_v1.md for architecture overview
2. **Implementation**: Reference CODE_EXAMPLES.md for production code
3. **Integration**: Use OAUTH_INTEGRATION_GUIDE.md and AZURE_AD_INTEGRATION_GUIDE.md for specific providers
4. **Database**: Deploy AUDIT_TRAIL_SCHEMA.sql for compliance logging
5. **Reference**: Use RBAC_MATRIX.md for permission lookups during development

---

## 🔒 Security Highlights

- **No plaintext secrets**: All credentials in Azure Key Vault
- **CSRF protection**: State parameter validation in OAuth flows
- **XSS prevention**: Refresh token in HTTP-only cookie, access token in memory
- **Rate limiting**: Brute-force protection on authentication endpoints
- **Audit trail**: All identity events logged for forensic analysis
- **Privilege escalation detection**: Monitoring for suspicious permission grants
- **Incident response**: Procedures for account compromise and API key compromise

---

**Prepared by**: Identity Architecture Team  
**Reviewed**: Security & Compliance  
**Status**: Ready for Implementation  
**Last Updated**: 2025-01-15  

