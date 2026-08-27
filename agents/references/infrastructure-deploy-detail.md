# Infrastructure Deploy — Detail

Supporting detail for [`agents/basecoat-60-workflow-infrastructure-deploy.agent.md`](../basecoat-60-workflow-infrastructure-deploy.agent.md).

## Pre-Deployment Validation

```yaml
- Validate Bicep syntax
- Check parameter file format
- Verify resource group exists
- Validate Azure credentials
- Check subscription access
- Review resource naming conventions
```

## Bicep Template Example

```bicep
param location string = resourceGroup().location
param environment string
param vmSize string = 'Standard_B2s'

var resourceNamePrefix = toLower(replace('${environment}app', '-', ''))
var storageAccountName = '${take(resourceNamePrefix, 15)}${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}
```

## Parameter File Example

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": { "value": "eastus" },
    "environment": { "value": "prod" },
    "vmSize": { "value": "Standard_D2s_v3" }
  }
}
```

## Deployment Validation Checklist

```text
- Template syntax and schema compliance
- Parameter binding correctness
- Resource availability and quotas
- Naming conflicts with existing resources
- Circular dependencies between resources
- Cost implications
- Security policy compliance
```

## Deployment Execution

```bash
az deployment group create \
  --resource-group <resource-group-name> \
  --template-file main.bicep \
  --parameters @parameters.json \
  --no-wait
```

Progress tracking covers resource creation order, concurrent vs. sequential deployments, error
detection/reporting, and timeout handling.

## Bicep Module Composition

```bicep
module vnet 'modules/vnet.bicep' = {
  name: 'vnetDeployment'
  params: {
    location: location
    environment: environment
    addressSpace: addressSpace
  }
}

module appServicePlan 'modules/app-service-plan.bicep' = {
  name: 'appServicePlanDeployment'
  params: {
    location: location
  }
}

module appService 'modules/app-service.bicep' = {
  name: 'appServiceDeployment'
  params: {
    location: location
    environment: environment
    appServicePlanId: appServicePlan.outputs.id
  }
  dependsOn: [
    vnet
  ]
}
```

## Recovery Strategies

- **Deployment modes**: Incremental leaves resources outside the template unchanged; complete
  removes resources outside the template in scope. Neither mode automatically rolls back failures.
- **Manual recovery**: Provide remediation instructions and redeploy after correcting the cause.
- **Known-good redeployment**: Restore the previous template and parameters.
- **Point-in-time recovery**: Use only where the affected service supports it.

Rollback decision logic:

```text
If deployment fails:
  1. Check error severity (critical vs. recoverable)
  2. Determine affected resources
  3. Assess rollback feasibility
  4. Select and execute an explicit recovery strategy
  5. Verify resource and service health
  6. Generate an incident report
```

## Post-Deployment Monitoring

Resource provisioning status, resource health checks, connectivity validation, performance
baseline establishment, cost monitoring setup, log aggregation configuration.

## Output Format Examples

### Success Response

```json
{
  "status": "succeeded",
  "deploymentId": "deployment-20240115-001",
  "timestamp": "2024-01-15T10:30:00Z",
  "resourceGroup": "prod-app-rg",
  "resourcesCreated": 12,
  "resourcesModified": 3,
  "duration": "5m 23s",
  "outputs": {
    "appServiceUrl": "https://prod-app-as.azurewebsites.net",
    "storageAccountName": "prodappsa1a2b3c4d5e6f",
    "databaseEndpoint": "prod-app-sql.database.windows.net"
  }
}
```

### Failure Response

```json
{
  "status": "failed",
  "deploymentId": "deployment-20240115-002",
  "timestamp": "2024-01-15T10:45:00Z",
  "resourceGroup": "prod-app-rg",
  "error": {
    "code": "InvalidTemplateDeployment",
    "message": "The template is invalid",
    "details": [
      {
        "resource": "Microsoft.Compute/virtualMachines/myVm",
        "issue": "SKU not available in region"
      }
    ]
  },
  "rollbackStatus": "completed",
  "affectedResources": ["vnet-001", "subnet-001"]
}
```

### Validation-Only Response

```json
{
  "status": "validation_passed",
  "deploymentId": "validation-20240115-001",
  "timestamp": "2024-01-15T11:00:00Z",
  "warnings": [
    "Resource sku not optimal for environment",
    "Consider enabling auto-scaling"
  ],
  "costEstimate": {
    "monthlyCost": 2500,
    "currencyCode": "USD"
  }
}
```

### Pairing Response (Handoff Mode)

```json
{
  "status": "approved|blocked|deferred",
  "reasonCode": "all_checks_passed|missing_rollback_reference|quota_insufficient|policy_denied|malformed_handoff",
  "environment": "dev|staging|prod",
  "riskTier": "low|medium|high",
  "deployMode": "advisory|blocking",
  "mergeSha": "<sha>"
}
```
