---
name: environment-bootstrap
compatibility: [github-copilot-cli]
description: "Use when bootstrapping secure Azure delivery environments with OIDC federation, state storage, Key Vault, promotion workflows, and Fabric access automation. USE FOR: set up GitHub Actions OIDC to Azure, provision Terraform state storage, configure Key Vault for CI/CD secrets, design dev-to-prod environment promotion, grant Fabric workspace service principal access. DO NOT USE FOR: application feature coding, non-Azure local dev setup, Kubernetes app debugging."

context: fork
---
# Environment Bootstrap Skill

Complete setup for secure Azure environments: federated identity, state backends, secrets, and promotion.

## Reference Files

| File | Contents |
|------|----------|
| [oidc-federation.md](references/oidc-federation.md) | Entra app, federated creds, RBAC, OIDC token exchange, multi-env |
| [terraform-bicep-state-storage.md](references/terraform-bicep-state-storage.md) | State backends, Blob config, Bicep templates |
| [azure-keyvault-provisioning.md](references/azure-keyvault-provisioning.md) | Key Vault creation, RBAC, CI/CD secret management |
| [github-actions-secrets.md](references/github-actions-secrets.md) | Workflow config, Key Vault retrieval, repo secrets |
| [environment-promotion.md](references/environment-promotion.md) | Dev→Staging→Prod, approval gates, GitHub Environments |
| [workload-identity-federation.md](references/workload-identity-federation.md) | AKS pod federated creds, service account config |
| [fabric-workspace-access.md](references/fabric-workspace-access.md) | Fabric service principals, workspace roles via REST |
| [troubleshooting.md](references/troubleshooting.md) | OIDC, state storage, Key Vault errors, diagnostics |


