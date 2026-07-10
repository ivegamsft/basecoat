# Basecoat Portal Security Review

## Executive Summary

This document provides a comprehensive security architecture and threat modeling analysis for the Basecoat Portal, a multi-tenant governance and compliance audit platform.

**Key Findings:**
- Authentication architecture is sound with GitHub OAuth 2.0 as primary auth mechanism
- RBAC model provides granular access control across 5 tiers
- Key recommendations focus on API rate limiting, input validation, and incident response procedures

---

## 1. OWASP Top 10 (2021) Analysis & Mitigations

### A1: Broken Access Control

**Risk**: Multi-tenant Portal with org-level scoping could expose data across tenants

**Current Mitigations**:
- 5-tier RBAC model (Admin → Org Admin → Auditor → Developer → Viewer)
- Access control decision tree: Org validation → Permission check → Team scope check
- JWT token validation on all authenticated endpoints

**Gaps & Recommendations**:
1. **Add tenant isolation testing**: Automated tests verifying cross-org data access is impossible
2. **Implement access control lists (ACLs)**: Per-resource verification beyond role checks
3. **Add audit logging**: Log all access denials and permission changes
4. **Rate limiting by org**: Prevent resource exhaustion per tenant

**Implementation Priority**: CRITICAL
**Effort**: 2-3 sprints

---

### A2: Cryptographic Failures

**Risk**: Data at rest or in transit could be compromised

**Current Mitigations**:
- HTTPS/TLS for all data in transit (implied by App Service deployment)
- GitHub OAuth secrets stored in Azure Key Vault
- JWT tokens with signed payloads

**Gaps & Recommendations**:
1. **Enforce TLS 1.2+**: Explicitly block older TLS versions in load balancer
2. **Encrypt sensitive fields at rest**: Database encryption for audit results, credentials
3. **Implement field-level encryption**: For highly sensitive data (credentials, API keys)
4. **Key rotation strategy**: Rotate Azure Key Vault secrets quarterly
5. **Add certificate pinning**: For OAuth and external API calls

**Implementation Priority**: HIGH
**Effort**: 2-3 sprints

---

### A3: Injection

**Risk**: SQL injection, command injection, or NoSQL injection attacks

**Current Mitigations**:
- OpenAPI spec implies parameterized queries (backend responsibility)
- GitHub OAuth token validation before use

**Gaps & Recommendations**:
1. **Input validation layer**: Strict schema validation on all API inputs
2. **Parameterized queries everywhere**: Audit all database queries for injection vulnerabilities
3. **NoSQL injection prevention**: If using document databases, validate all queries
4. **LDAP injection prevention**: If using LDAP for Azure AD integration
5. **Add security linter**: Static analysis for injection vulnerabilities in CI/CD

**Implementation Priority**: CRITICAL
**Effort**: 1-2 sprints + ongoing

---

### A4: Insecure Design

**Risk**: Portal lacks explicit incident response and security operational procedures

**Current Mitigations**:
- Terraform IaC provides infrastructure consistency
- Azure Key Vault for secrets management
- Monitoring infrastructure identified in Terraform modules

**Gaps & Recommendations**:
1. **Formalize incident response plan**: Define escalation, communication, recovery procedures
2. **Add security headers**: HSTS, CSP, X-Frame-Options, X-Content-Type-Options
3. **Implement rate limiting**: Per-user and per-IP rate limiting on authentication endpoints
4. **Add CSRF protection**: Token-based CSRF validation on state-changing operations
5. **Design DDoS mitigation**: Azure DDoS Protection or front-end WAF rules

**Implementation Priority**: HIGH
**Effort**: 1-2 sprints

---

### A5: Security Misconfiguration

**Risk**: Insecure default configurations in Terraform, Azure, or application code

**Current Mitigations**:
- Terraform modules for consistent IaC deployment
- Azure Key Vault for secrets (not in config files)

**Gaps & Recommendations**:
1. **Add Terraform security scanning**: Run tfsec in CI/CD pipeline
2. **Review Azure RBAC assignments**: Minimize service principal permissions
3. **Disable unneeded services**: Turn off diagnostic logging if unused
4. **Add security headers in Azure App Service configuration**
5. **Harden database firewall rules**: Restrict access to authorized subnets only
6. **Validate Terraform security**: No public endpoints by default

**Implementation Priority**: MEDIUM
**Effort**: 1 sprint

---

### A6: Vulnerable and Outdated Components

**Risk**: Dependency vulnerabilities could be exploited

**Current Mitigations**:
- Implied use of npm/nuget dependency management
- GitHub Dependabot availability (if enabled)

**Gaps & Recommendations**:
1. **Enable Dependabot alerts**: Automatic notifications for dependency vulnerabilities
2. **Add dependency scanning to CI/CD**: Fail builds on known vulnerabilities
3. **Implement dependency version pinning**: Avoid auto-upgrade of minor versions
4. **Add SBOM generation**: Generate Software Bill of Materials for audit/compliance
5. **Regular dependency audits**: Monthly audit of transitive dependencies

**Implementation Priority**: MEDIUM
**Effort**: 1 sprint setup + ongoing maintenance

---

### A7: Authentication & Session Management

**Risk**: Weak token lifecycle or session hijacking

**Current Mitigations**:
- JWT tokens with 1-hour expiration
- Refresh token endpoint (/auth/refresh)
- GitHub OAuth 2.0 flow with code exchange
- MFA support mentioned in Identity Design

**Gaps & Recommendations**:
1. **Add token revocation list (TRL)**: Implement immediate logout capability
2. **Enforce secure cookie attributes**: HttpOnly, Secure, SameSite=Strict on refresh tokens
3. **Add token signing validation**: Verify JWT signatures on every request
4. **Implement MFA enforcement**: Require MFA for Admin roles, optional for others
5. **Add device fingerprinting**: Detect token use from different devices/locations
6. **Implement session binding**: Tie tokens to specific IP or user-agent

**Implementation Priority**: HIGH
**Effort**: 2-3 sprints

---

### A8: Software & Data Integrity Failures

**Risk**: Malicious code injection or unauthorized data modification

**Current Mitigations**:
- GitHub security (repository protection rules implied)
- Terraform infrastructure management

**Gaps & Recommendations**:
1. **Add code signing**: Sign commits and releases with GPG
2. **Implement branch protection**: Require code review and status checks before merge
3. **Add artifact integrity verification**: Sign and verify container images/releases
4. **Implement audit trails**: Immutable logs of all data modifications
5. **Add transaction integrity**: Database-level constraints and checksums

**Implementation Priority**: MEDIUM
**Effort**: 1-2 sprints

---

### A9: Logging & Monitoring Failures

**Risk**: Security incidents not detected or investigated

**Current Mitigations**:
- Terraform monitoring module identified

**Gaps & Recommendations**:
1. **Implement security logging**: Log authentication, authorization, and config changes
2. **Add SIEM integration**: Send logs to Azure Log Analytics or similar
3. **Create alert rules**: Alert on multiple failed login attempts, privilege escalation, suspicious API activity
4. **Implement log retention**: Comply with SOC 2 Type II (minimum 1 year recommended)
5. **Add log tamper protection**: Immutable logging for audit trails

**Implementation Priority**: HIGH
**Effort**: 2-3 sprints

---

### A10: SSRF (Server-Side Request Forgery)

**Risk**: Portal calls external APIs (GitHub) and could be exploited to access internal services

**Current Mitigations**:
- OAuth 2.0 server-to-server exchange (backend-only, no client-side redirects to internal IPs)

**Gaps & Recommendations**:
1. **Add URL validation**: Whitelist allowed external hosts
2. **Implement DNS rebinding protection**: Verify resolved IP matches expected range
3. **Add outbound firewall rules**: Restrict egress to known external services
4. **Disable private IP access**: Explicitly reject requests to 10.x, 172.16-31.x, 192.168.x ranges
5. **Add request timeout limits**: Prevent hanging connections to unreachable internal services

**Implementation Priority**: MEDIUM
**Effort**: 1 sprint

---

## 2. STRIDE Threat Model

### Spoofing (Identity Spoofing)

| Threat | Likelihood | Impact | Risk Level | Mitigation |
|--------|------------|--------|-----------|-----------|
| Attacker impersonates user via stolen JWT | High | Critical | RED | Add token revocation list, enforce short expiration, bind tokens to IP/device |
| Attacker forges GitHub OAuth token | Medium | Critical | RED | Validate token with GitHub API, add signature verification |
| Service account credentials leaked | Medium | High | ORANGE | Rotate API keys every 90 days, store in Key Vault only, audit key usage |

**Mitigation Actions**:
- [ ] Implement token revocation list within 1 sprint
- [ ] Add TOTP-based MFA for Admin tier
- [ ] Monthly credential rotation audit
- [ ] Add anomaly detection for token usage patterns

---

### Tampering (Data Tampering)

| Threat | Likelihood | Impact | Risk Level | Mitigation |
|--------|------------|--------|-----------|-----------|
| Attacker modifies audit results in database | Low | Critical | RED | Add database encryption at rest, enable transparent data encryption (TDE), audit all writes |
| API request modified in transit | Low | High | ORANGE | Enforce HTTPS, add request signing for sensitive endpoints |
| JWT token payload altered | Low | Critical | RED | Add signature verification on every request, monitor token parsing errors |

**Mitigation Actions**:
- [ ] Enable Azure SQL TDE in next sprint
- [ ] Add request signature validation for data-modifying endpoints
- [ ] Implement immutable audit log backed by append-only database

---

### Repudiation (Denial of Actions)

| Threat | Likelihood | Impact | Risk Level | Mitigation |
|--------|------------|--------|-----------|-----------|
| User denies making an API call | Medium | Medium | YELLOW | Add comprehensive audit logging, correlate logs with user identity |
| Admin denies deleting data | Medium | High | ORANGE | Add audit trail with immutable timestamps and signing |

**Mitigation Actions**:
- [ ] Implement comprehensive audit logging for all user actions
- [ ] Add non-repudiation signatures for compliance-critical operations
- [ ] Retain logs for minimum 3 years per SOC 2 Type II

---

### Information Disclosure (Data Leakage)

| Threat | Likelihood | Impact | Risk Level | Mitigation |
|--------|------------|--------|-----------|-----------|
| Credentials leaked in logs or error messages | High | Critical | RED | Add PII masking in logs, use structured logging, never log secrets |
| API error messages reveal system internals | High | Medium | ORANGE | Return generic error messages to client, log details server-side |
| Unauthorized org access due to weak scoping | Medium | High | ORANGE | Add automated tenant isolation tests, verify all org checks |
| Data exposed via backup or cache | Low | High | ORANGE | Encrypt backups, encrypt Redis cache, implement cache expiration |

**Mitigation Actions**:
- [ ] Add PII masking in logging layer immediately
- [ ] Audit all error messages for information leakage
- [ ] Add cache encryption for sensitive data
- [ ] Implement backup encryption strategy

---

### Denial of Service (DoS)

| Threat | Likelihood | Impact | Risk Level | Mitigation |
|--------|------------|--------|-----------|-----------|
| Attacker floods /auth/login endpoint | High | Medium | ORANGE | Add rate limiting (10 requests/min per IP), add captcha after 3 failures |
| Attacker uploads massive audit result | Medium | Medium | ORANGE | Add file size limits, implement chunked upload with validation |
| Database connection pool exhausted | Medium | High | ORANGE | Add connection limits, monitor pool utilization, add circuit breakers |
| Slow loris attack on long-lived connections | Low | Medium | YELLOW | Add request timeout (30s), implement connection limits |

**Mitigation Actions**:
- [ ] Implement rate limiting middleware in next sprint
- [ ] Add file size and upload limits to API spec
- [ ] Configure database connection pool limits
- [ ] Add DDoS protection via Azure DDoS Standard

---

### Elevation of Privilege (Authorization Bypass)

| Threat | Likelihood | Impact | Risk Level | Mitigation |
|--------|------------|--------|-----------|-----------|
| Developer elevates self to Admin | Medium | Critical | RED | Add admin approval workflow, add audit logging, implement code review for role changes |
| Attacker exploits IDOR to access other org's data | Medium | Critical | RED | Add automated IDOR testing, verify all org checks, add request scoping |
| Service account used for unauthorized operations | Low | High | ORANGE | Implement least-privilege scoping, add usage monitoring, rotate credentials regularly |
| Unauthed user calls admin endpoint | Medium | Critical | RED | Add middleware auth check on all admin routes, add unit tests |

**Mitigation Actions**:
- [ ] Add admin approval workflow for role assignments
- [ ] Implement IDOR testing in security test suite
- [ ] Add service account usage monitoring and alerting

---

## 3. Authentication & Authorization Architecture

### Authentication Flow (GitHub OAuth 2.0 Primary)

`
User -> [Login UI] -> GitHub OAuth Authorization
  -> Authorization Code -> App Backend
  -> Token Exchange -> GitHub API
  -> JWT Token Created
  -> User Session
`

**JWT Token Structure**:
- Subject: user ID
- Issuer: Portal backend
- Audience: Portal frontend + API
- Expires in: 1 hour
- Refresh token: stored in HttpOnly cookie

**Recommendations**:
1. Add token type claim (access vs. refresh)
2. Add client ID to token for validation
3. Add token version for revocation support
4. Add scopes claim for fine-grained authorization

---

### Authorization Model (RBAC with Tenant Scoping)

`
Request -> Org Validation -> Permission Check -> Team Scope Check -> Resource Access
`

**5-Tier Model**:
- **Admin**: Portal-wide permissions (manage orgs, view all data)
- **Org Admin**: Organization-level (manage team members, enable features)
- **Auditor**: Read audit results for assigned org
- **Developer**: Deploy and manage assigned team resources
- **Viewer**: Read-only access to assigned team data

**Enforcement Points**:
- [ ] Route middleware: Verify authentication before handler execution
- [ ] Handler level: Verify authorization for specific resource
- [ ] Database query: Filter results by org/team scope

---

### Multi-Factor Authentication (MFA)

**Current State**: MFA mentioned in Identity Design, implementation details pending

**Recommendations**:
1. Require MFA for Admin role (TOTP + SMS backup)
2. Require MFA for Org Admin role (TOTP or SMS)
3. Optional MFA for other roles
4. Add backup codes for account recovery
5. Add adaptive MFA (require MFA for suspicious locations)

**Implementation Approach**:
- Use Azure AD TOTP provider or similar
- Store MFA metadata in secure database table
- Add MFA enforcement middleware

---

## 4. Data Protection Architecture

### Encryption at Rest

**Required Fields**:
- Database: Credentials, API keys, OAuth tokens, sensitive audit data
- Backups: All database contents
- Secrets storage: GitHub OAuth credentials, service account keys
- Cache (Redis): Session tokens, temporary data

**Strategy**:
- Azure SQL: Enable Transparent Data Encryption (TDE) with customer-managed keys
- Application-level: Encrypt PII and credentials at application layer
- Backups: Use Azure Backup with encryption
- Redis: Enable encryption at-rest and enforce TLS for in-transit

**Key Rotation**:
- Rotate Azure Key Vault keys quarterly
- Rotate database encryption keys annually
- Rotate OAuth credentials every 90 days
- Implement automated rotation workflows

---

### Encryption in Transit

**Enforcement**:
- HTTPS/TLS 1.2+ for all external endpoints
- Internal service-to-service: mTLS or VPN tunnel
- Database connections: Enforce SSL/TLS
- Redis connections: Enforce TLS

**Configuration**:
`
- App Service: HTTPS only, disable HTTP
- Azure SQL: Enforce SSL connection
- Redis: Enable TLS, set minimum TLS version to 1.2
- Load Balancer: Terminate TLS at front end, HTTPS to backend
`

---

### Secrets Management

**All Secrets in Azure Key Vault**:
- GitHub OAuth client ID and secret
- Database connection strings
- Redis connection strings
- JWT signing key
- Service account API keys
- Third-party API credentials

**Key Vault Configuration**:
- Enable purge protection
- Enable soft delete (90-day retention)
- Restrict access via RBAC
- Add audit logging of all access
- Monitor for suspicious access patterns

**Rotation Strategy**:
- GitHub OAuth credentials: Every 90 days (manual process with downtime planning)
- JWT signing key: Every 6 months (with key versioning support)
- Service account API keys: Every 90 days
- Database passwords: Every 90 days (automated via managed identity)

---

## 5. Security Architecture (Defense in Depth)

`
[External User]
       |
       v
[Azure DDoS Protection / WAF]
       |
       v
[TLS Termination / Load Balancer]
       |
       v
[App Service / Container]
  |
  +-- Authentication Middleware (JWT validation)
  |
  +-- Authorization Middleware (RBAC + tenant scoping)
  |
  +-- Input Validation Middleware
  |
  +-- Rate Limiting Middleware
  |
  +-- Application Logic
  |
  +-- Audit Logging
       |
       v
[Azure SQL Database (TDE)]
       |
       v
[Azure Key Vault]
`

**Security Layers**:

1. **Network Layer**:
   - [ ] Azure DDoS Protection Standard
   - [ ] Network Security Groups (NSGs) with restrictive inbound rules
   - [ ] Private endpoints for database and Redis
   - [ ] VPN for admin access

2. **Transport Layer**:
   - [ ] HTTPS/TLS 1.2+ enforced
   - [ ] HSTS header with 1-year max-age
   - [ ] Certificate pinning for GitHub OAuth API calls
   - [ ] CSP, X-Frame-Options, X-Content-Type-Options headers

3. **Authentication Layer**:
   - [ ] GitHub OAuth 2.0 primary
   - [ ] JWT signature validation
   - [ ] MFA for privileged roles
   - [ ] Token revocation list support

4. **Authorization Layer**:
   - [ ] RBAC middleware on all routes
   - [ ] Tenant/org scoping on all queries
   - [ ] IDOR testing in test suite
   - [ ] Least-privilege principle for service accounts

5. **Application Layer**:
   - [ ] Input validation on all endpoints
   - [ ] Output encoding to prevent XSS
   - [ ] Parameterized queries for SQL injection prevention
   - [ ] Error handling with generic messages to users

6. **Data Layer**:
   - [ ] Database encryption at rest (TDE)
   - [ ] Field-level encryption for credentials
   - [ ] Immutable audit logs
   - [ ] Backup encryption

7. **Monitoring Layer**:
   - [ ] Security event logging (auth, authz, config changes)
   - [ ] SIEM integration for alert generation
   - [ ] Real-time alerting on suspicious patterns
   - [ ] Monthly security log review and analysis

---

## 6. Compliance Alignment

### SOC 2 Type II Requirements

**Availability**:
- [ ] RTO/RPO defined and tested (recommend: RTO 4 hours, RPO 1 hour)
- [ ] Backup and disaster recovery plan with annual testing
- [ ] Load balancing and auto-scaling for high availability
- [ ] Monitoring and alerting for service degradation

**Processing Integrity**:
- [ ] Data validation on input and processing
- [ ] Audit trails for all data modifications
- [ ] Change management procedures with testing
- [ ] Role-based access control enforced

**Confidentiality**:
- [ ] Encryption at rest and in transit
- [ ] Access controls limiting data exposure
- [ ] Secure deletion procedures
- [ ] Monitoring for unauthorized access attempts

**Security**:
- [ ] Incident response plan with testing
- [ ] Vulnerability management program
- [ ] Penetration testing annually
- [ ] Security awareness training for employees

---

### GDPR Compliance

**Data Processing**:
- [ ] Data Processing Agreement (DPA) with all users
- [ ] Privacy policy documenting data collection and use
- [ ] Consent management for personal data processing
- [ ] Record of processing activities (ROPA) maintained

**Data Subject Rights**:
- [ ] Implement right to access: Export user data in machine-readable format
- [ ] Implement right to erasure: Delete user data and associated records
- [ ] Implement right to rectification: Allow users to correct personal data
- [ ] Implement right to restrict processing: Add data retention controls
- [ ] Implement right to data portability: Export data in standard format

**Data Protection**:
- [ ] Encrypt personal data at rest and in transit
- [ ] Implement access controls limiting personnel access
- [ ] Add Data Protection Impact Assessment (DPIA) for high-risk processing
- [ ] Notify supervisory authority within 72 hours of breach

**Retention Policy**:
- [ ] Define retention periods per data type
- [ ] Implement automated deletion after retention period
- [ ] Document retention rationale per GDPR requirements

---

## 7. Incident Response Playbook

### Incident Classification

**Critical (P0)**: Data breach, authentication bypass, widespread service outage
- Response time: Immediate (< 15 minutes)
- Escalation: VP Engineering, Security Officer, Legal

**High (P1)**: Targeted service outage, single-user authentication failure, suspicious activity
- Response time: 1 hour
- Escalation: Engineering Manager, Security Team

**Medium (P2)**: Performance degradation, non-critical vulnerability
- Response time: 4 hours
- Escalation: Engineering Lead

**Low (P3)**: Minor configuration issue, policy violation
- Response time: 1 business day
- Escalation: Team Lead

---

### Response Procedures

**Phase 1: Detection & Triage** (0-30 min)
1. Alert triggered via monitoring system
2. On-call engineer investigates alert
3. Classify incident by priority
4. Page on-call manager if P0/P1

**Phase 2: Containment** (30-60 min)
1. Isolate affected systems (disable compromised account, block malicious IP)
2. Preserve evidence (collect logs, memory dumps)
3. Notify stakeholders of ongoing incident
4. Activate war room (P0 only)

**Phase 3: Investigation** (60 min - ongoing)
1. Analyze logs and system state
2. Determine root cause and blast radius
3. Assess regulatory notification requirements (GDPR breach notification)
4. Coordinate with legal/compliance if breach detected

**Phase 4: Remediation** (ongoing)
1. Implement fix or workaround
2. Deploy fix to production with monitoring
3. Verify incident is resolved
4. Update status notifications

**Phase 5: Recovery** (ongoing)
1. Monitor system for 24 hours after fix
2. Scale up auto-recovery systems if needed
3. Prepare for customer communications
4. Draft postmortem summary

**Phase 6: Post-Incident** (24-72 hours)
1. Conduct postmortem meeting
2. Identify corrective actions
3. File tickets for preventive improvements
4. Conduct GDPR breach notification if required (72 hours from discovery)

---

### Contact List

| Role | Primary | Secondary | Escalation |
|------|---------|-----------|-----------|
| On-Call Engineer | Pagerduty | Team Slack | Engineering Manager |
| Security Officer | Security team lead | VP Engineering | CISO |
| Compliance Officer | Legal team | VP Ops | COO |
| Customer Relations | Support Manager | VP Customer | CEO |

---

### Communication Template

**Initial Notification** (< 15 min for P0):
`
Subject: INCIDENT: [Service] - [Brief Description]

We are experiencing [brief description of issue].
Status: INVESTIGATING
Updates: Every 30 minutes
Tracking: [Ticket #]
`

**Status Update** (Every 30 min for P0, hourly for P1):
`
Subject: [SERVICE] Incident Update - [HH:mm UTC]

Current Status: [INVESTIGATING / MITIGATING / MONITORING]
Root Cause: [If known]
ETA to Resolution: [If known]
`

**Resolution Notification** (< 15 min for P0):
`
Subject: RESOLVED: [Service] - [Brief Description]

Issue has been resolved as of [Time UTC].
Root Cause: [Technical summary]
Next: Postmortem scheduled for [Date/Time]
`

---

### Breach Notification (GDPR)

**Within 72 hours of discovery, notify authorities if**:
- Data breach involves personal data of EU residents
- Breach creates risk of harm (privacy impact assessment)
- No encryption or other controls made data unreadable

**Notification includes**:
- Nature of breach
- Likely consequences
- Measures taken or proposed to address breach
- Contact point for further information
- List of affected data subjects (if feasible)

---

## Appendix: Implementation Roadmap

### Sprint 1 (Weeks 1-2)
- [ ] Implement rate limiting on /auth/login endpoint
- [ ] Add security headers (HSTS, CSP, X-Frame-Options)
- [ ] Enable Azure SQL TDE
- [ ] Add PII masking in logging

### Sprint 2 (Weeks 3-4)
- [ ] Implement token revocation list
- [ ] Add MFA support for Admin role
- [ ] Add automated tenant isolation tests
- [ ] Enable Azure DDoS Standard

### Sprint 3 (Weeks 5-6)
- [ ] Implement comprehensive audit logging
- [ ] Add SIEM integration
- [ ] Conduct penetration testing
- [ ] Create incident response playbook training

### Sprint 4+ (Ongoing)
- [ ] Implement field-level encryption
- [ ] Add IDOR testing to security test suite
- [ ] Conduct quarterly security reviews
- [ ] Perform annual penetration testing

---

## Document Control

**Version**: 1.0
**Last Updated**: 2026-05-04
**Classification**: Internal - Security Sensitive
**Next Review**: 90 days

---

*This security review document is confidential and intended for authorized personnel only.*
