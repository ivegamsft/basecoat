# Enterprise Identity and Access Management Guidance

This document provides best practices for identity and access management in Azure.

## Zero Trust Identity

Zero Trust assumes breach and verifies every access:

- Never trust, always verify
- Least privilege access
- Continuous validation

## Entra ID Integration

Register all applications in Entra ID for authentication and authorization.

### Managed Identity

Use managed identity to eliminate credentials from code:

- System-assigned: One per resource, Azure manages lifecycle
- User-assigned: Shared identity, manual lifecycle management
- Workload identity: For GitHub Actions and external CI/CD

## RBAC (Role-Based Access Control)

Assign roles with minimum permissions:

- **Reader**: View-only access
- **Contributor**: Create, modify resources
- **Key Vault Secrets User**: Access secrets only

## Conditional Access

Enforce access policies based on context:

- Require MFA for all cloud apps
- Block access from risky locations
- Require compliant devices

## Key Vault Integration

Store and rotate secrets securely:

`csharp
// Use managed identity to access Key Vault
var credential = new DefaultAzureCredential();
var client = new SecretClient(vaultUri, credential);
var secret = await client.GetSecretAsync("MySecret");
`

## Base Coat Assets

- Agent: \gents/identity-architect.agent.md\
- Instruction: \instructions/zero-trust-identity.instructions.md\

## References

- [Azure RBAC Documentation](https://docs.microsoft.com/azure/role-based-access-control/)
- [Managed Identity Overview](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview)
