# Secrets Manager — Detail Reference

## Secrets Taxonomy

Application Secrets: API Keys, Database Credentials, Service Accounts, Encryption Keys, Session Tokens.
Infrastructure Secrets: SSH Private Keys, TLS/SSL Certificates, VPN Credentials, Container Registry Credentials, Code Signing Certificates.
Supply Chain Secrets: Package Repository Credentials, Artifact Repository Tokens, Source Control PATs, Build System Credentials.

## Lifecycle Stages

1. **Generation** — cryptographically secure random generation; min entropy (API keys: 128 bits, passwords: 16 chars); assign owner.
2. **Storage** — never in version control; centralized Vault; encrypt at rest; least-privilege IAM policies.
3. **Distribution** — inject at deployment time; never log values; audit all access.
4. **Rotation** — API keys: 90d, passwords: 60d, tokens: 30d; maintain N+1 versions during rollover; automate where possible.
5. **Expiry Scanning** — automated daily scans for certs expiring within 30 days; CT log monitoring; TLS endpoint validation.
6. **Emergency Revocation** — revoke immediately; break-glass procedures; audit trail; notify stakeholders.
7. **Retirement** — securely delete from all backups; archive audit logs (7-year retention); document reason and timestamp.

## Vault Pattern

Providers: HashiCorp Vault, Azure Key Vault, AWS Secrets Manager, GCP Secret Manager.

Capabilities: Dynamic Secrets (temporary DB credentials), Encryption as a Service, Identity-based Access (OIDC/mTLS), Audit Logging, Secret Leasing.

Workload Identity Pattern (recommended):

- Traditional: App + static API key → Vault
- Modern: App → Workload Identity Provider (OIDC/mTLS) → Vault → temporary token

## Workflow Commands

```bash
# Secrets discovery
gitleaks detect --source=.
truffleHog filesystem /path/to/repo
vault kv list secret/

# Expiry scanning
openssl x509 -enddate -noout -in cert.pem
openssl s_client -connect example.com:443 -servername example.com </dev/null 2>/dev/null | openssl x509 -noout -enddate
```

## Rotation Frequency Reference

| Secret Type | Rotation Frequency |
|---|---|
| API Keys | 90 days |
| Database Passwords | 60 days |
| OAuth/JWT Tokens | 30 days |
| TLS Certificates | 365 days (pre-rotate at 30 days before expiry) |
| SSH Keys | 180 days |

## Compliance Mappings

| Framework | Relevant Control |
|---|---|
| SOC2 | CC6.1 — Logical and Physical Access Controls |
| HIPAA | Security Rule §164.308(a)(3)(ii)(B) |
| PCI-DSS | Requirement 8 — Identify and authenticate access |

## Emergency Exposure Workflow

For a known or suspected credential exposure:

1. Treat the credential as compromised; do not retrieve or print its current
   value for verification.
2. Inventory consumers and identify the credential owner with authority to
   revoke and replace it.
3. Revoke the exposed credential. Replacing a stored secret without revoking the
   source credential is incomplete containment.
4. Create a least-privilege replacement with an explicit expiration and update
   each secret store through masked or interactive input.
5. Validate authentication and required permissions without echoing the value.
6. Confirm secret metadata changed after the exposure and verify every consumer
   with a targeted recovery run.
7. Return the old credential identifier, replacement identifier, and timestamps
   only when they are non-sensitive; never return credential values.

If credential creation or revocation requires a human-owned account, emit a
blocking owner action and keep the incident open.
