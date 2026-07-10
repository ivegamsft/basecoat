---
description: "Use when working with Azure Service Connector — connecting App Service, Container Apps, AKS, or Azure Functions to backing services (databases, storage, cache, messaging) using passwordless authentication."
applyTo: "**/*.{bicep,bicepparam,tf,tfvars,ps1,sh,json,yml,yaml,cs,ts,js,py}"
---

# Azure Service Connector Standards

Use this instruction when changes involve connecting an Azure compute resource to a backing service
via Azure Service Connector, or when configuring connection strings, managed identity bindings,
or service-side firewall rules for connected services.

## What Is Azure Service Connector

Azure Service Connector automates the configuration of network access, authentication, and
environment variables needed to connect compute resources (App Service, Container Apps, AKS,
Azure Functions, Spring Apps) to backing services (Azure SQL, Cosmos DB, Storage, Redis,
Service Bus, Key Vault, Event Hubs, and others).

It supports three authentication types:
- **System-assigned managed identity** — preferred for single-service scenarios
- **User-assigned managed identity** — preferred when multiple services share an identity
- **Connection string / secret** — only when managed identity is not supported; store in Key Vault

## Expectations

### Authentication
- Default to managed identity (system-assigned or user-assigned). Never store connection strings in app settings or environment variables as plaintext.
- If a connection string is unavoidable, reference it from Key Vault via a Key Vault reference (`@Microsoft.KeyVault(...)`) in the app setting.
- Ensure the managed identity has the minimum required role on the target service (e.g., `Storage Blob Data Contributor`, not `Owner`).

### Network
- Enable service-side firewall rules or private endpoints as appropriate for the environment.
- For production, prefer private endpoint over service endpoint over public access with IP restrictions.
- Azure Service Connector can configure service-side firewall rules automatically — let it do so rather than applying manual rules that drift.

### Environment Variables
- Service Connector sets standard environment variable names (e.g., `AZURE_STORAGEBLOB_RESOURCEENDPOINT`, `AZURE_COSMOS_CONNECTIONSTRING`). Use these in application code rather than custom names.
- Document all injected environment variables in the service's README or deployment guide.

### IaC
- When using Bicep or Terraform, express connections as `Microsoft.ServiceLinker/linkers` resources attached to the compute resource.
- Pin the `serviceLinker` API version explicitly. Do not rely on `latest`.
- Include `clientType` matching the application language/runtime (e.g., `dotnet`, `python`, `nodejs`, `springBoot`, `none`).

### Testing
- Validate connectivity with `az webapp connection validate` (or equivalent for Container Apps / AKS) after any configuration change.
- Include connection validation in pre-deployment smoke tests.

## Common Patterns

### App Service → Azure SQL (managed identity)

```bicep
resource linker 'Microsoft.ServiceLinker/linkers@2022-11-01-preview' = {
  name: 'appToSql'
  scope: appService
  properties: {
    targetService: {
      type: 'AzureResource'
      id: sqlDatabase.id
    }
    authInfo: {
      authType: 'systemAssignedIdentity'
    }
    clientType: 'dotnet'
  }
}
```

### Container Apps → Redis (user-assigned managed identity)

```bicep
resource linker 'Microsoft.ServiceLinker/linkers@2022-11-01-preview' = {
  name: 'appToRedis'
  scope: containerApp
  properties: {
    targetService: {
      type: 'AzureResource'
      id: redisCache.id
    }
    authInfo: {
      authType: 'userAssignedIdentity'
      clientId: userManagedIdentity.properties.clientId
      subscriptionId: subscription().subscriptionId
    }
    clientType: 'python'
  }
}
```

## Azure SQL + Managed Identity Prerequisites

Before debugging ServiceLinker failures for Azure SQL + managed identity connections,
verify the following prerequisites are in place. Skipping step 2 causes **Error 18456
(Login failed)** even when ServiceLinker reports "Succeeded" and the contained database
user was created correctly. This is a silent CI killer.

### 1. Enable system-assigned managed identity on the SQL server

```bicep
resource sqlServer 'Microsoft.Sql/servers@2022-11-01-preview' = {
  name: sqlServerName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // ...
  }
}
```

### 2. Add the SQL server MI to the Directory Readers role

> **This cannot be done in Bicep or ARM.** It requires the Microsoft Graph API and
> must be run once by someone with the `RoleManagement.ReadWrite.Directory` permission.

Without this role, SQL Server cannot look up the connecting managed identity in
Microsoft Entra ID during token validation, resulting in Error 18456.

Step 1 — Get the Directory Readers role ID:

```bash
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/directoryRoles?\$filter=displayName eq 'Directory Readers'" \
  --query "value[0].id" -o tsv
```

Step 2 — Add the SQL server MI as a member (replace both placeholders):

```bash
az rest --method POST \
  --url "https://graph.microsoft.com/v1.0/directoryRoles/{roleId}/members/\$ref" \
  --body "{\"@odata.id\": \"https://graph.microsoft.com/v1.0/directoryObjects/{sqlServerMiObjectId}\"}"
```

The SQL server MI object ID is available in the Azure portal under the SQL server's
**Identity** blade, or via:

```bash
az sql server show --name <sqlServerName> --resource-group <rg> \
  --query identity.principalId -o tsv
```

### Prerequisites checklist

Before raising a ServiceLinker issue or redeploying, confirm:

- [ ] SQL server has `identity.type = 'SystemAssigned'` in Bicep
- [ ] SQL server MI is a member of the **Directory Readers** directory role (Graph API, one-time)
- [ ] ServiceLinker `authType` is `systemAssignedIdentity` or `userAssignedIdentity`
- [ ] `az webapp connection validate` (or equivalent) passes after deployment

## Review Lens

- Is the authentication type managed identity where supported?
- Are connection strings and secrets stored in Key Vault, not app settings?
- Does the managed identity have the minimum required role?
- Are injected environment variable names using the Service Connector standard names?
- Is the service-side network access restricted appropriately for the environment?
- Is connection validation included in deployment checks?
