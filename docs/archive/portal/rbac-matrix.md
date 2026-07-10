# RBAC Matrix Reference

Comprehensive role-based access control matrix for Basecoat Portal Wave 3.

## Overview

Five core roles with explicit permission mappings:
- **Admin**: Portal-wide administrative access
- **Organization Admin**: Organization-level management and billing
- **Auditor**: Audit submission, tracking, and reporting
- **Developer**: Issue management within assigned teams
- **Viewer**: Read-only access to dashboard and reports

---

## Detailed Permission Reference

### Dashboard & Visibility

| Permission | Admin | Org Admin | Auditor | Developer | Viewer | Description |
|-----------|-------|----------|---------|-----------|--------|-------------|
| `view:dashboard` | ✓ | ✓ | ✓ | ✓ | ✓ | View portal dashboard and summary metrics |
| `view:org_summary` | ✓ | ✓ | ✓ | ✗ | ✗ | View organization-wide summaries |
| `view:team_summary` | ✓ | ✓ | ✓ | ✓ | ✗ | View team summaries |

### Audit Management

| Permission | Admin | Org Admin | Auditor | Developer | Viewer | Description |
|-----------|-------|----------|---------|-----------|--------|-------------|
| `read:audits` | ✓ | ✓ | ✓ | ✓ (assigned) | ✓ | Read audit records and results |
| `create:audits` | ✓ | ✓ | ✓ | ✗ | ✗ | Submit new compliance audits |
| `update:audits` | ✓ | ✓ | ✗ | ✗ | ✗ | Modify audit policies and configuration |
| `delete:audits` | ✓ | ✗ | ✗ | ✗ | ✗ | Archive or delete audit records |
| `export:audits` | ✓ | ✓ | ✓ | ✗ | ✗ | Export audit data for analysis |

### Issue Management

| Permission | Admin | Org Admin | Auditor | Developer | Viewer | Description |
|-----------|-------|----------|---------|-----------|--------|-------------|
| `read:issues` | ✓ | ✓ | ✓ | ✓ | ✓ | Read security/compliance issues |
| `update:issues` | ✓ | ✓ | ✓ | ✓ | ✗ | Update issue status and details |
| `assign:issues` | ✓ | ✓ | ✓ | ✗ | ✗ | Assign issues to developers |
| `comment:issues` | ✓ | ✓ | ✓ | ✓ | ✗ | Comment on issues |
| `request_waiver:issues` | ✓ | ✓ | ✓ | ✓ | ✗ | Request exemptions/waivers |

### Organization & Team Management

| Permission | Admin | Org Admin | Auditor | Developer | Viewer | Description |
|-----------|-------|----------|---------|-----------|--------|-------------|
| `manage:teams` | ✓ | ✓ | ✗ | ✗ | ✗ | Create, edit, delete teams |
| `manage:users` | ✓ | ✓ | ✗ | ✗ | ✗ | Manage user accounts and memberships |
| `manage:roles` | ✓ | ✓ | ✗ | ✗ | ✗ | Assign roles to users |
| `read:org_settings` | ✓ | ✓ | ✓ | ✗ | ✗ | View organization configuration |
| `write:org_settings` | ✓ | ✓ | ✗ | ✗ | ✗ | Modify organization configuration |

### Integration & Billing

| Permission | Admin | Org Admin | Auditor | Developer | Viewer | Description |
|-----------|-------|----------|---------|-----------|--------|-------------|
| `manage:integrations` | ✓ | ✓ | ✗ | ✗ | ✗ | Configure GitHub, Azure AD, webhooks |
| `manage:billing` | ✓ | ✓ | ✗ | ✗ | ✗ | Manage billing and subscriptions |
| `view:billing` | ✓ | ✓ | ✗ | ✗ | ✗ | View billing and usage reports |

### Audit Trail & Compliance

| Permission | Admin | Org Admin | Auditor | Developer | Viewer | Description |
|-----------|-------|----------|---------|-----------|--------|-------------|
| `read:audit_trail` | ✓ | ✓ | ✓ (own) | ✗ | ✗ | Access system audit logs |
| `export:reports` | ✓ | ✓ | ✓ | ✗ | ✓ | Generate and export compliance reports |
| `view:reports` | ✓ | ✓ | ✓ | ✗ | ✓ | View compliance reports and dashboards |

---

## Permission Groupings (by Feature)

### Audit Submission & Tracking

**Required Roles**: Admin, Organization Admin, Auditor

- `create:audits` — Submit compliance audits
- `read:audits` — View audit results
- `export:audits` — Export audit data

### Issue Resolution

**Required Roles**: Admin, Organization Admin, Auditor, Developer

- `read:issues` — View assigned/team issues
- `update:issues` — Change issue status
- `comment:issues` — Add findings or context
- `request_waiver:issues` — Request exemptions

### Organization Management

**Required Roles**: Admin, Organization Admin only

- `manage:teams` — Create/delete teams
- `manage:users` — Add/remove users
- `manage:roles` — Assign role changes
- `write:org_settings` — Configure policies

### Reporting & Analytics

**Required Roles**: Admin, Organization Admin, Auditor, Viewer

- `read:audits` — Access audit data
- `export:reports` — Download reports
- `view:reports` — View dashboards

---

## Scope Resolution

### Team-Scoped Permissions

Developers are restricted to their assigned teams:

```
Developer in Team A:
- Can read/update issues assigned to Team A only
- Cannot view Team B issues
- Cannot access organization-wide audit settings
```

### Organization-Scoped Permissions

Auditors and Organization Admins access all team data:

```
Auditor in Organization X:
- Can read/submit audits for all teams in Org X
- Cannot access Organization Y data
- Cannot modify audit policies (Org Admin only)
```

### Portal-Scoped Permissions

Admins have access across all organizations:

```
Admin:
- Can manage teams/users across all organizations
- Can modify audit policies (all orgs)
- Can export data from any organization
```

---

## Access Control Decision Tree

**User requests access to resource**

```
1. Is resource org_id == user's org_id?
   NO  → 403 Forbidden
   YES → Continue

2. Does user have required permission?
   NO  → 403 Forbidden
   YES → Continue

3. If resource is team-scoped:
   - Is user in resource team?
   NO  → 403 Forbidden
   YES → Continue

4. Grant access
```

---

**Version**: 1.0  
**Last Updated**: 2025  
