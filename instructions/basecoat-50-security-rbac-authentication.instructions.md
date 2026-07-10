---
description: "Use when provisioning or reviewing Azure resources. Enforces RBAC-only authentication — no shared keys, SAS tokens, access policies, or connection string auth."
applyTo: "**/*.tf,**/*.bicep,**/*.cs,**/*.ts,**/*.py"
---

# RBAC-Only Authentication for Azure Resources

Use this instruction when provisioning, configuring, or connecting to Azure resources.

## Expectations

- All Azure resources must use **RBAC-only authentication**.
- Disable key-based, SAS-based, and access-policy-based auth at the resource level.
- All service-to-service auth must use **managed identity** with least-privilege RBAC roles.
- Application code must use `DefaultAzureCredential` (or platform equivalent) — never connection strings for auth.

## Resource Configuration

| Resource | Terraform Setting | Effect |
|----------|-------------------|--------|
| Storage Account | `shared_access_key_enabled = false` | No connection strings, no SAS |
| Key Vault | `enable_rbac_authorization = true` | No access policies |
| Cosmos DB | `local_authentication_disabled = true` | No primary/secondary keys |
| Event Hub | `local_auth_enabled = false` | No SAS tokens |
| Service Bus | `local_auth_enabled = false` | No SAS tokens |
| SQL Database | Azure AD-only auth enabled | No SQL auth |

## RBAC Role Assignments

Assign the **narrowest** built-in role that covers the workload:

| Workload | Role | Scope |
|----------|------|-------|
| App reads blobs | `Storage Blob Data Reader` | Storage account or container |
| App writes blobs | `Storage Blob Data Contributor` | Storage account or container |
| App reads secrets | `Key Vault Secrets User` | Key Vault |
| CI/CD manages infra | `Key Vault Administrator` | Key Vault |
| App reads Cosmos | `Cosmos DB Account Reader Role` | Cosmos account |
| App writes Cosmos | `Cosmos DB Built-in Data Contributor` | Cosmos account |

## Application Code

```csharp
// CORRECT — DefaultAzureCredential chains managed identity → CLI → env
var client = new BlobServiceClient(
    new Uri("https://mystorageaccount.blob.core.windows.net"),
    new DefaultAzureCredential());

// CORRECT — Python
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient
credential = DefaultAzureCredential()
client = BlobServiceClient(account_url, credential=credential)
```

## Anti-Patterns

```hcl
# WRONG — leaves key-based access enabled (default is true)
resource "azurerm_storage_account" "main" {
  name = "mystorage"
  # shared_access_key_enabled not set — defaults to true
}

# WRONG — access policy instead of RBAC
resource "azurerm_key_vault_access_policy" "app" {
  key_vault_id = azurerm_key_vault.main.id
  secret_permissions = ["Get", "List"]
}
```

```csharp
// WRONG — connection string auth
var client = new BlobServiceClient("DefaultEndpointsProtocol=https;AccountName=...;AccountKey=...");

// WRONG — SAS token
var sasUri = container.GenerateSasUri(permissions, expiry);
```

## Review Lens

- Does every Azure resource explicitly disable key/SAS/access-policy auth?
- Are RBAC role assignments using the narrowest built-in role?
- Does application code use `DefaultAzureCredential`, not connection strings?
- Are managed identities used for service-to-service auth instead of shared secrets?
