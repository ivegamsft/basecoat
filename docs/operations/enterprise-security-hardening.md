# Enterprise Security Hardening Patterns

This document provides best practices for hardening Azure environments against security threats and vulnerabilities.

## Network Security

### Network Segmentation

Segment networks by trust level:

- **DMZ**: Public-facing resources (web servers, load balancers)
- **Application tier**: Internal services, APIs
- **Data tier**: Databases, storage accounts
- **Management tier**: Admin consoles, CI/CD systems

Each segment has distinct NSG rules restricting traffic.

### DDoS Protection

Enable DDoS Standard for production endpoints:

- **Layer 3/4 (volumetric)**: Mitigation of volumetric attacks
- **Layer 7 (application)**: WAF rules for app-layer attacks
- **Monitoring**: Real-time attack analytics

## Encryption and Secrets

### Encryption at Rest

All data must be encrypted when stored:

- **Storage accounts**: Azure Storage Service Encryption (SSE)
- **Databases**: Transparent Data Encryption (TDE)
- **VMs**: Azure Disk Encryption
- **Backups**: Geo-redundant encrypted backups

### Encryption in Transit

All data in motion must be encrypted:

- **TLS 1.2+**: Enforce minimum TLS version
- **mTLS**: For service-to-service communication
- **VPN/ExpressRoute**: For hybrid connectivity

### Secrets Management

Use Key Vault to store and rotate secrets:

- **API keys**: Third-party service credentials
- **Database passwords**: Connection strings, admin passwords
- **Certificates**: SSL/TLS certificates, code signing
- **Rotation**: Automatic key rotation policies

## Access Control

### Least Privilege

Grant minimum permissions required:

- **Role-Based Access Control (RBAC)**: Use built-in roles when possible
- **Custom roles**: Define for specific job functions
- **Time-bound access**: PIM (Privileged Identity Management) for temporary escalation
- **Access reviews**: Quarterly removal of unused permissions

### Managed Identity

Never hardcode credentials; use managed identity:

- **System-assigned**: One per resource; managed by Azure
- **User-assigned**: Shared identity; manual lifecycle management
- **Workload identity federation**: For GitHub Actions, external CI/CD

## Monitoring and Threat Detection

### Azure Security Center

Enable Security Center for continuous monitoring:

- **Compliance tracking**: NIST, CIS, PCI-DSS
- **Vulnerability scanning**: Detect CVEs in VMs, containers
- **Threat detection**: Unusual sign-ins, suspicious activities
- **Recommendations**: Prioritized security improvements

### Logging and Auditing

Enable audit logs for all services:

- **Azure AD sign-ins**: Track user authentication events
- **Resource logs**: Track who accessed/modified resources
- **Network security group flow logs**: Monitor network traffic
- **Retention**: Store logs for compliance (1-7 years)

## Endpoint Security

### VM Hardening

- Disable unnecessary services and ports
- Apply Windows/Linux security baselines
- Enable Windows Defender or native antivirus
- Keep OS and patches current

### Container Security

- Scan images for vulnerabilities
- Run as non-root users
- Use read-only filesystems
- Limit resource consumption (CPU, memory)

## Compliance and Governance

### Policy as Code

Use Azure Policy to enforce security controls:

- **Require encryption**: Deny storage accounts without HTTPS
- **Mandatory tags**: Enforce tagging for all resources
- **Approved locations**: Restrict resources to approved Azure regions
- **Enforce RBAC**: Deny owner role assignments

### Regular Audits

Conduct security audits quarterly:

- **Penetration testing**: Authorized attacks to find vulnerabilities
- **Code review**: Review high-risk code for security issues
- **Access review**: Validate that permissions are current
- **Patch management**: Verify all systems have latest patches

## Base Coat Assets

**Related agents & skills**:

- Agent: \gents/security-analyst.agent.md\ — Vulnerability assessment and review
- Agent: \gents/policy-as-code-compliance.agent.md\ — Compliance validation
- Skill: \skills/azure-security-hardening/\ — Configuration patterns
- Instruction: \instructions/security-hardening-checklist.instructions.md\

## Next Steps

1. **Assess**: Run Azure Security Center recommendations
2. **Harden**: Apply security baselines to VMs and containers
3. **Encrypt**: Enable TDE, SSE, and secrets management
4. **Monitor**: Set up logging and threat detection
5. **Audit**: Conduct quarterly compliance reviews

## References

- [Azure Security Documentation](https://docs.microsoft.com/azure/security/)
- [Microsoft Security Baselines](https://docs.microsoft.com/windows/security/threat-protection/windows-security-baselines)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
