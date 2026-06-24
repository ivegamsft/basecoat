# Secrets Rotation Policy (Issue #1747)

**Effective Date**: Sprint 38, June 24, 2026  
**Policy Owner**: Platform Security  
**Last Updated**: June 24, 2026

---

## Secrets Inventory

Repository manages 12 action secrets for portfolio operations:

- Repository action secrets (`AZURE_CREDENTIALS`, `COPILOT_GITHUB_TOKEN`, `MEMORY_REPO_TOKEN`, `PRODUCTION_REPO_TOKEN`)
- Organization secrets (`DASHBOARD_ORG`, `BASECOAT_EXTENSION_*`)
- Webhook secrets and OAuth tokens

| Secret Name | Type | Last Rotated | Next Due | Rotation Frequency |
| --- | --- | --- | --- | --- |
| `AZURE_CREDENTIALS` | Service Principal | 2026-05-08 | 2026-08-08 | Quarterly |
| `COPILOT_GITHUB_TOKEN` | GitHub PAT | 2026-06-10 | 2026-09-10 | Quarterly |
| `MEMORY_REPO_TOKEN` | GitHub PAT | 2026-02-15 | 2026-08-15 | Semi-annual |
| `PRODUCTION_REPO_TOKEN` | GitHub PAT | 2026-03-22 | 2026-09-22 | Semi-annual |
| `DASHBOARD_ORG` | OAuth | 2026-01-20 | 2026-07-20 | Semi-annual |

---

## Rotation Schedule

### Quarterly Rotation (Every 90 days)

- `AZURE_CREDENTIALS`
- `COPILOT_GITHUB_TOKEN`

**Schedule**:

- Q1: Jan 1–Mar 31
- Q2: Apr 1–Jun 30
- Q3: Jul 1–Sep 30
- Q4: Oct 1–Dec 31

### Semi-Annual Rotation (Every 180 days)

- `MEMORY_REPO_TOKEN`
- `PRODUCTION_REPO_TOKEN`
- `DASHBOARD_ORG`
- `BASECOAT_EXTENSION_*` secrets

**Schedule**:

- H1: Jan 1–Jun 30
- H2: Jul 1–Dec 31

---

## Rotation Procedures

### Step 1: Pre-Rotation Notification (7 days before)

- **Owner** must send notification to `#portfolio-ops` Slack channel
- Include: Secret name, reason (if unscheduled), estimated downtime (if any)

### Step 2: Generate New Secret

1. Follow service-specific secret rotation procedure (see Service Procedures below)
2. Document the new secret value securely (password manager or secure note)

### Step 3: Update GitHub Secret

1. Go to repo **Settings → Secrets and variables → Actions**
2. Click the secret name
3. Update the value with new secret
4. Save (GitHub records timestamp as rotation date)

### Step 4: Verify Functionality

1. Trigger test workflow using new secret to confirm functionality
2. Review workflow logs for successful authentication

### Step 5: Post-Rotation Cleanup

1. Delete old secret from secure note
2. Record rotation in audit log (see Audit Trail section)
3. Send completion notification to `#portfolio-ops`

---

## Service-Specific Procedures

### AZURE_CREDENTIALS

Process:

```bash
# Step 1: Generate new service principal credentials
az ad sp credential reset --id <service-principal-id> --credential-description "rotation-$(date +%Y%m%d)"

# Step 2: Convert to Azure JSON
az ad sp credential list --id <service-principal-id> --query '[0].displayName'

# Step 3: Update GitHub secret with new JSON payload
# (Paste into GitHub Secrets UI)
```

### GitHub Tokens (COPILOT_GITHUB_TOKEN, MEMORY_REPO_TOKEN, PRODUCTION_REPO_TOKEN)

Process:

```bash
# Step 1: Go to GitHub Settings > Developer settings > Personal access tokens
# Step 2: Click "Generate new token" (same scopes as old token)
# Step 3: Copy new token value
# Step 4: Update GitHub secret in repo
# Step 5: Delete old token from GitHub
```

### Webhook Secrets (BASECOAT_EXTENSION_*)

Process:

```bash
# Step 1: Regenerate webhook secret in GitHub
# Step 2: Update repo secret with new value
# Step 3: Verify webhook deliveries succeed with new secret
```

---

## Audit Trail

**Location**: `docs/security/SECRETS_AUDIT_LOG.json`

**Log Entry Format**:

```json
{
  "date": "2026-06-24T15:30:00Z",
  "secret_name": "AZURE_CREDENTIALS",
  "action": "rotate",
  "old_hash": "sha256:abc123...",
  "new_hash": "sha256:def456...",
  "owner": "platform-security",
  "reason": "quarterly-rotation",
  "verified": true,
  "notes": "Successful Azure authentication test"
}
```

### Audit Access

- **Who**: Platform Security team members and audit log readers
- **When**: During quarterly/semi-annual rotation reviews
- **Review frequency**: Monthly audit log review to detect anomalies

### Incident Response

If a secret is suspected compromised:

1. Immediately rotate the secret (out-of-band)
2. Review all workflow runs using the compromised secret (last 24 hours)
3. Audit all downstream systems accessed via the compromised secret
4. File incident report in GitHub Issue for portfolio ops visibility
5. Document root cause and remediation in audit log

---

## Retention and Cleanup

- **Audit log retention**: 2 years (90-day archive after rotation)
- **Old secret values**: Securely deleted immediately after new secret verified
- **Rotation notifications**: Retained in Slack archive (searchable for 1 year)

### Compliance Checks

- **Automation**: Weekly `token-rotation-audit.yml` workflow
- **Alert conditions**: Secrets older than 60 days (warn), older than 90 days (critical)
- **Escalation**: Critical alerts sent to `#portfolio-security` Slack channel

---

## Service Account Procedures

### Azure Credentials (AZURE_CREDENTIALS)

1. Go to Azure Portal → Service Principals
2. Find the linked service principal
3. Navigate to **Certificates & secrets**
4. Click **New client secret**
5. Copy the new secret value and Client ID (if needed)
6. Update GitHub secret
7. Monitor first workflow run for success

### GitHub PAT (COPILOT_GITHUB_TOKEN, MEMORY_REPO_TOKEN, PRODUCTION_REPO_TOKEN)

1. Go to GitHub **Settings → Developer settings → Personal access tokens**
2. Find the token by ID (usually named after service)
3. Click **Regenerate token**
4. Copy new token value
5. Update GitHub secret
6. Delete old token to remove access

### GitHub OAuth (BASECOAT_EXTENSION_*)

1. Go to GitHub **Settings → Developer settings → OAuth Apps**
2. Select the application
3. Click **Regenerate client secret**
4. Copy new secret value
5. Update GitHub secret
6. Monitor extension webhook for successful authentication

---

## Policy Review Schedule

- **Frequency**: Annual (or on-demand if incident occurs)
- **Last Reviewed**: June 24, 2026
- **Next Review**: June 24, 2027
- **Owner**: Platform Security

---

**Policy Version**: 1.0  
**Approved By**: Security Audit (Issue #1747)  
**Distribution**: Platform Security, DevOps Team, Portfolio Operations
