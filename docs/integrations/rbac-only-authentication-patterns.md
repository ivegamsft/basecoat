# RBAC-Only Authentication Patterns (No Secrets in Code)

This document describes best practices for implementing authentication and authorization using RBAC and managed identities in Azure, eliminating the need to store secrets in code or configuration files.

## Core Principles

### Zero Secrets in Code

Eliminate hardcoded credentials, connection strings, and API keys:

| Anti-Pattern | Problem | Solution |
|---|---|---|
| `connectionString = "Server=db;User=sa;Password=..."` | Secrets in code | Managed Identity |
| `apiKey = Environment.GetEnvironmentVariable("APIKEY")` | Secrets in env vars | Managed Identity + Azure RBAC |
| `secrets.json` committed to Git | Exposed in history | Use Key Vault with managed identity |
| `appsettings.Production.json` with connection strings | Secrets in config | Azure App Configuration + managed identity |

### Authentication vs Authorization

**Authentication**: "Who are you?" (validated via Entra ID)

**Authorization**: "What can you do?" (enforced via RBAC)

```
Request -> Entra ID Authentication -> RBAC Authorization -> Access Granted/Denied
           (Verify identity)            (Check permissions)
```

## Azure Managed Identity

### System-Assigned Managed Identity

One per resource, lifecycle tied to resource:

```powershell
# Create App Service with system-assigned identity
$appService = New-AzAppService `
  -ResourceGroupName 'prod-rg' `
  -Name 'my-app' `
  -AppServicePlanName 'my-plan' `
  -IdentityType 'SystemAssigned'

# Check assigned identity
$identity = Get-AzAppService -ResourceGroupName 'prod-rg' -Name 'my-app' | 
  Select-Object -ExpandProperty Identity

Write-Host "Object ID: $($identity.PrincipalId)"
```

### User-Assigned Managed Identity

Shared identity, manual lifecycle management:

```powershell
# Create user-assigned identity
$identity = New-AzUserAssignedIdentity `
  -ResourceGroupName 'prod-rg' `
  -Name 'app-shared-identity'

# Assign to multiple resources
New-AzAppService `
  -ResourceGroupName 'prod-rg' `
  -Name 'my-app-1' `
  -AppServicePlanName 'my-plan' `
  -IdentityType 'UserAssigned' `
  -IdentityId $identity.Id

New-AzAppService `
  -ResourceGroupName 'prod-rg' `
  -Name 'my-app-2' `
  -AppServicePlanName 'my-plan' `
  -IdentityType 'UserAssigned' `
  -IdentityId $identity.Id
```

## RBAC Role Assignments

### Azure Built-In Roles

Assign least-privilege roles:

```powershell
# App needs to read from storage account
$role = 'Storage Blob Data Reader'
$scope = "/subscriptions/.../resourceGroups/prod-rg/providers/Microsoft.Storage/storageAccounts/mystore"

New-AzRoleAssignment `
  -ObjectId $appIdentity.PrincipalId `
  -RoleDefinitionName $role `
  -Scope $scope

# Verify role assignment
Get-AzRoleAssignment `
  -ObjectId $appIdentity.PrincipalId `
  -Scope $scope
```

### Common Role Patterns

| Resource | Read | Write | Admin |
|---|---|---|---|
| **Storage** | Storage Blob Data Reader | Storage Blob Data Contributor | Storage Account Contributor |
| **Key Vault** | Key Vault Secrets User | Key Vault Secrets Officer | Key Vault Administrator |
| **SQL Database** | SQL DB Datareader | SQL DB Datawriter | SQL Server Contributor |
| **Service Bus** | Azure Service Bus Data Receiver | Azure Service Bus Data Sender | Azure Service Bus Data Owner |

### Custom Roles

Define custom roles for fine-grained control:

```powershell
# Custom role: Can read secrets but not delete
$customRole = @{
    Name = 'KeyVault Secret Reader'
    Description = 'Can read (get) secrets only'
    Actions = @('Microsoft.KeyVault/vaults/secrets/read')
    NotActions = @('Microsoft.KeyVault/vaults/secrets/delete')
    AssignableScopes = @("/subscriptions/")
}

$role = New-AzRoleDefinition -InputObject $customRole

New-AzRoleAssignment `
  -ObjectId $appIdentity.PrincipalId `
  -RoleDefinitionId $role.Id `
  -Scope $scope
```

## Code Patterns: No Secrets

### Pattern 1: App Service → Azure SQL

Use managed identity to authenticate:

```csharp
using Azure.Identity;
using Microsoft.Data.SqlClient;

public class OrderRepository
{
    private readonly string _connectionString;
    
    public OrderRepository(IConfiguration config)
    {
        // No password, no credentials
        _connectionString = "Server=orders-db.database.windows.net;Database=Orders;";
    }
    
    public async Task<Order> GetOrderAsync(int orderId)
    {
        // DefaultAzureCredential uses managed identity in App Service
        var credential = new DefaultAzureCredential();
        
        using (var connection = new SqlConnection(_connectionString))
        {
            // Get access token from Entra ID
            var token = await credential.GetTokenAsync(
                new TokenRequestContext(scopes: new[] { "https://database.windows.net/.default" }));
            
            connection.AccessToken = token.Token;
            await connection.OpenAsync();
            
            using (var command = connection.CreateCommand())
            {
                command.CommandText = "SELECT * FROM Orders WHERE OrderId = @id";
                command.Parameters.AddWithValue("@id", orderId);
                
                using (var reader = await command.ExecuteReaderAsync())
                {
                    if (await reader.ReadAsync())
                    {
                        return new Order { /* map from reader */ };
                    }
                }
            }
        }
        
        return null;
    }
}
```

### Pattern 2: App Service → Azure Storage

Access blobs without connection string:

```csharp
using Azure.Identity;
using Azure.Storage.Blobs;

public class DocumentService
{
    private readonly BlobContainerClient _containerClient;
    
    public DocumentService(IConfiguration config)
    {
        var accountUri = new Uri("https://mystore.blob.core.windows.net");
        var credential = new DefaultAzureCredential();
        
        _containerClient = new BlobContainerClient(
            new Uri($"{accountUri}/documents"),
            credential);
    }
    
    public async Task<Stream> DownloadDocumentAsync(string fileName)
    {
        // Managed identity automatically authenticated via RBAC
        var blobClient = _containerClient.GetBlobClient(fileName);
        BlobDownloadInfo download = await blobClient.DownloadAsync();
        return download.Content;
    }
    
    public async Task UploadDocumentAsync(string fileName, Stream content)
    {
        var blobClient = _containerClient.GetBlobClient(fileName);
        await blobClient.UploadAsync(content, overwrite: true);
    }
}
```

### Pattern 3: App Service → Key Vault

Retrieve secrets without storing them:

```csharp
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

public class ConfigurationService
{
    private readonly SecretClient _secretClient;
    
    public ConfigurationService(IConfiguration config)
    {
        var vaultUri = new Uri("https://mykeyvault.vault.azure.net/");
        var credential = new DefaultAzureCredential();
        _secretClient = new SecretClient(vaultUri, credential);
    }
    
    public async Task<string> GetDatabasePasswordAsync()
    {
        // Retrieve secret at runtime (never stored in code/config)
        KeyVaultSecret secret = await _secretClient.GetSecretAsync("db-password");
        return secret.Value;
    }
    
    public async Task<string> GetApiKeyAsync(string keyName)
    {
        KeyVaultSecret secret = await _secretClient.GetSecretAsync(keyName);
        return secret.Value;
    }
}
```

### Pattern 4: Azure Function → Event Hub

Receive messages using managed identity:

```csharp
using Azure.Identity;
using Azure.Messaging.EventHubs.Consumer;

public static class EventProcessorFunction
{
    [FunctionName("ProcessEvents")]
    public static async Task Run(
        [TimerTrigger("0 */1 * * * *")] TimerInfo myTimer,
        ILogger log)
    {
        var credential = new DefaultAzureCredential();
        var fullyQualifiedNamespace = "myeventhub.servicebus.windows.net";
        
        var consumerClient = new EventHubConsumerClient(
            EventHubConsumerClient.DefaultConsumerGroupName,
            fullyQualifiedNamespace,
            "my-hub",
            credential);
        
        try
        {
            // List partition IDs
            string[] partitionIds = await consumerClient.GetPartitionIdsAsync();
            
            foreach (string partitionId in partitionIds)
            {
                EventPosition startingPosition = EventPosition.Latest;
                using (var partitionReceiver = new PartitionReceiver(
                    EventHubConsumerClient.DefaultConsumerGroupName,
                    partitionId,
                    startingPosition,
                    fullyQualifiedNamespace,
                    "my-hub",
                    credential))
                {
                    IEnumerable<EventData> events = await partitionReceiver.ReceiveBatchAsync(
                        maximumEventCount: 100,
                        maximumWaitTime: TimeSpan.FromSeconds(5));
                    
                    foreach (EventData eventData in events)
                    {
                        log.LogInformation($"Event: {Encoding.UTF8.GetString(eventData.Body.ToArray())}");
                    }
                }
            }
        }
        finally
        {
            await consumerClient.CloseAsync();
        }
    }
}
```

### Pattern 5: Container → CosmosDB

Access CosmosDB with managed identity:

```csharp
using Azure.Identity;
using Microsoft.Azure.Cosmos;

public class OrderDataAccess
{
    private readonly Container _container;
    
    public OrderDataAccess(IConfiguration config)
    {
        var endpoint = "https://mycosmosdb.documents.azure.com:443/";
        var credential = new DefaultAzureCredential();
        
        var client = new CosmosClient(endpoint, credential);
        _container = client.GetDatabase("OrdersDB").GetContainer("Orders");
    }
    
    public async Task<Order> GetOrderAsync(string orderId)
    {
        ItemResponse<Order> response = await _container.ReadItemAsync<Order>(
            orderId,
            new PartitionKey(orderId));
        
        return response.Resource;
    }
}
```

## Dependency Injection Setup

### ASP.NET Core Configuration

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

// Register managed identity credential
builder.Services.AddSingleton<TokenCredential>(new DefaultAzureCredential());

// Register services that use managed identity
builder.Services.AddScoped<OrderRepository>();
builder.Services.AddScoped<DocumentService>();
builder.Services.AddScoped<ConfigurationService>();

// Use DefaultAzureCredential for all Azure SDK clients
builder.Services.AddSingleton(x =>
{
    var credential = x.GetRequiredService<TokenCredential>();
    return new BlobContainerClient(
        new Uri("https://mystore.blob.core.windows.net/documents"),
        credential);
});

var app = builder.Build();
// ... rest of configuration
```

## Service-to-Service Authentication

### Workload Identity Federation

Enable GitHub Actions to authenticate to Azure without federated credentials:

```powershell
# Register GitHub app in Entra ID
$app = New-AzADApplication `
  -DisplayName 'github-actions' `
  -SignInAudience 'AzureADMyOrg'

# Create service principal
$sp = New-AzADServicePrincipal `
  -ApplicationId $app.AppId

# Create federated credential for GitHub repo
$credential = @{
    name          = 'github-federated'
    issuer        = 'https://token.actions.githubusercontent.com'
    subject       = 'repo:my-org/my-repo:ref:refs/heads/main'
    audiences     = @('api://AzureADTokenExchange')
    description   = 'GitHub Actions'
}

Update-AzADApplication `
  -ObjectId $app.Id `
  -FederatedIdentityCredentials @($credential)

# Assign role to service principal
New-AzRoleAssignment `
  -ObjectId $sp.Id `
  -RoleDefinitionName 'Contributor' `
  -Scope "/subscriptions/.../resourceGroups/prod-rg"
```

## Monitoring and Auditing

### Track Managed Identity Usage

```powershell
# View managed identity role assignments
Get-AzRoleAssignment -ObjectId $appIdentity.PrincipalId

# Audit access logs
Get-AzLog -ResourceGroup 'prod-rg' `
  -StartTime (Get-Date).AddDays(-7) `
  -Caller $appIdentity.PrincipalId |
  Select-Object -Property EventTimestamp, OperationName, Status
```

### Azure Policy Enforcement

Enforce managed identity usage:

```json
{
  "mode": "All",
  "policyRule": {
    "if": {
      "allOf": [
        {
          "field": "type",
          "equals": "Microsoft.Web/sites"
        },
        {
          "field": "identity.type",
          "notIn": ["SystemAssigned", "UserAssigned"]
        }
      ]
    },
    "then": {
      "effect": "deny"
    }
  }
}
```

## Base Coat Assets

- Agent: `agents/identity-architect.agent.md`
- Instruction: `instructions/zero-trust-identity.instructions.md`
- Skill: `skills/azure-rbac/`

## References

- [Azure Managed Identities](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [Azure RBAC Best Practices](https://docs.microsoft.com/azure/role-based-access-control/best-practices)
- [DefaultAzureCredential Documentation](https://docs.microsoft.com/dotnet/api/azure.identity.defaultazurecredential)
- [Workload Identity Federation](https://docs.microsoft.com/azure/active-directory/workload-identities/workload-identity-federation)
- [Azure SDK Authentication](https://docs.microsoft.com/dotnet/azure/sdk/authentication)
