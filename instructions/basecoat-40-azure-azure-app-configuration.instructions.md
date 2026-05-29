---
description: "Use when working with Azure App Configuration — centralizing feature flags, application settings, and dynamic configuration for Azure-hosted applications."
applyTo: "**/*.{bicep,bicepparam,tf,tfvars,ps1,sh,json,yml,yaml,cs,ts,js,py}"
---

# Azure App Configuration Standards

Use this instruction when changes involve reading or writing configuration from Azure App Configuration,
managing feature flags, setting up dynamic configuration refresh, or provisioning App Configuration
resources in IaC.

## What Is Azure App Configuration

Azure App Configuration is a managed service for centralizing application settings and feature flags.
It decouples configuration from code, enables dynamic refresh without redeployment, and provides
built-in feature management with targeted rollout capabilities.

Key concepts:
- **Key-Value store** — hierarchical key-value pairs with optional labels (environment, region, version)
- **Feature flags** — on/off toggles with optional filters (percentage rollout, user/group targeting, time window)
- **Configuration snapshot** — immutable point-in-time copy of a configuration set
- **Key Vault references** — keys that reference Key Vault secrets (never store secrets directly in App Configuration)

## Expectations

### Authentication
- Use managed identity to authenticate to App Configuration. Do not use connection strings or access keys in application code or environment variables.
- Assign the `App Configuration Data Reader` role to the compute resource's managed identity for read-only access.
- Assign `App Configuration Data Owner` only to deployment principals, not to runtime application identities.

### Key Naming
- Use a hierarchical `/` separator: `{service}/{component}/{key}` (e.g., `payments/api/timeout-ms`).
- Use labels to separate environments (`dev`, `staging`, `prod`) rather than separate key names or stores.
- Keep keys lowercase with hyphens, not underscores or camelCase.

### Secrets
- Never store secrets, connection strings, or credentials as key-values in App Configuration.
- Reference secrets from Key Vault using App Configuration Key Vault references.
- The application reads the App Configuration reference; App Configuration retrieves the secret from Key Vault transparently.

### Feature Flags
- Define feature flags in App Configuration, not in code constants or environment variables.
- Always provide a safe default (disabled) state that works if App Configuration is unreachable.
- Name feature flags in kebab-case: `my-feature-name`.
- For gradual rollout, use percentage filters. For A/B testing, use user/group targeting filters.

### Dynamic Refresh
- Configure a sentinel key (`{service}/sentinel`) and set refresh to trigger when the sentinel changes.
- Set an appropriate refresh interval (minimum 30 seconds for production; avoid < 5 seconds).
- Handle refresh failures gracefully — stale configuration is safer than application crash.

### IaC
- Provision App Configuration with `sku: Standard` for production (supports private endpoints, snapshots, geo-replication).
- Enable soft-delete and configure a purge protection policy.
- Apply resource locks on production stores to prevent accidental deletion.
- Configure private endpoints for production environments.

```bicep
resource appConfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' = {
  name: appConfigName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    disableLocalAuth: true      // managed identity only
    enablePurgeProtection: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Disabled'  // private endpoint only in prod
  }
}

resource readerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appConfig.id, appManagedIdentity.id, '516239f1-63e1-4d78-a4de-a74fb236a071')
  scope: appConfig
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '516239f1-63e1-4d78-a4de-a74fb236a071')  // App Configuration Data Reader
    principalId: appManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
```

### SDK Usage (.NET example)

```csharp
// Prefer AddAzureAppConfiguration with managed identity
builder.Configuration.AddAzureAppConfiguration(options =>
{
    options.Connect(new Uri(appConfigEndpoint), new DefaultAzureCredential())
           .Select("payments/*", labelFilter: environment)
           .ConfigureKeyVault(kv => kv.SetCredential(new DefaultAzureCredential()))
           .ConfigureRefresh(refresh =>
           {
               refresh.Register("payments/sentinel", refreshAll: true)
                      .SetRefreshInterval(TimeSpan.FromMinutes(5));
           })
           .UseFeatureFlags();
});
```

## Review Lens

- Is authentication using managed identity? No connection strings in config or environment variables?
- Are secrets stored as Key Vault references, not directly in App Configuration?
- Are key names following the `{service}/{component}/{key}` hierarchy with labels for environments?
- Is there a safe default state if App Configuration is unreachable?
- Does the IaC set `disableLocalAuth: true` for production stores?
- Is purge protection enabled on production stores?
- Is a private endpoint configured for production?
