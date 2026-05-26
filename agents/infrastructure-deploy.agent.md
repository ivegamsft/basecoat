---
name: infrastructure-deploy
description: "Orchestrates Azure infrastructure deployments using Bicep, handles resource group management, parameter validation, and rollback strategies. USE FOR: deploy Azure Bicep templates, manage resource group lifecycle, execute infrastructure rollback. DO NOT USE FOR: application code deployments, cost analysis and optimization."
type: task
compatibility: ["VS Code", "Cursor", "Windsurf", "Claude Code"]
metadata:
  category: "Infrastructure & Operations"
  tags: ["infrastructure", "azure", "bicep", "deployment", "iac"]
  maturity: "production"
  audience: ["infrastructure-engineers", "devops-engineers", "platform-teams"]
  model_tier: "balanced"
  task_phase: "deploy"
  interaction_type: "autonomous"
allowed-tools: ["bash", "git", "grep", "powershell", "terraform", "azure-cli"]
model: claude-sonnet-4.6
allowed_skills: []
color: blue
handoffs: []
trigger: Use for detailed trigger conditions in Use For section below.
---

# Infrastructure Deploy Agent

The Infrastructure Deploy Agent automates Azure infrastructure deployments, providing orchestration for Bicep modules, resource management, parameter validation, and deployment recovery strategies.

## Inputs

The agent accepts the following inputs:

- **Bicep Module Path**: Location of the main Bicep template file
- **Parameter File**: JSON file containing deployment parameters and variable values
- **Resource Group**: Target Azure resource group name
- **Environment**: Deployment environment (dev, staging, prod)
- **Subscription**: Azure subscription ID or name
- **Validation Only**: Boolean flag to run validation without deploying
- **Rollback On Failure**: Enable automatic rollback on deployment failure
- **Deployment Strategy**: Strategy type (complete, incremental)

## Workflow

The deployment workflow follows these phases:

### 1. Pre-Deployment Validation

```yaml
- Validate Bicep syntax
- Check parameter file format
- Verify resource group exists
- Validate Azure credentials
- Check subscription access
- Review resource naming conventions
```

### 2. Arm Template Conversion

Bicep files are transpiled to ARM templates:

```bicep
param location string = resourceGroup().location
param environment string
param vmSize string = 'Standard_B2s'

var resourceNamePrefix = '${environment}-app'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: '${resourceNamePrefix}sa${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}
```

### 3. Parameter File Management

Parameter files define deployment-specific values:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": {
      "value": "eastus"
    },
    "environment": {
      "value": "prod"
    },
    "vmSize": {
      "value": "Standard_D2s_v3"
    }
  }
}
```

### 4. Deployment Validation

Before deployment, the agent validates:

```text
- Template syntax and schema compliance
- Parameter binding correctness
- Resource availability and quotas
- Naming conflicts with existing resources
- Circular dependencies between resources
- Cost implications
- Security policy compliance
```

### 5. Deployment Execution

The deployment is executed with monitoring:

```bash
az deployment group create \
  --resource-group <resource-group-name> \
  --template-file main.bicep \
  --parameters parameters.json \
  --no-wait
```

Deployment progress is tracked:

- Resource creation order
- Concurrent vs. sequential deployments
- Error detection and reporting
- Timeout handling

### 6. Bicep Module Composition

Complex deployments use modular Bicep:

```bicep
module vnet 'modules/vnet.bicep' = {
  name: 'vnetDeployment'
  params: {
    location: location
    environment: environment
    addressSpace: addressSpace
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

### 7. Rollback Strategies

The agent implements rollback mechanisms:

- **Complete Mode**: Deletes entire resource group on failure
- **Incremental Mode**: Retains successful resources, removes failed ones
- **Manual Rollback**: Provides rollback instructions for manual execution
- **Point-in-Time Recovery**: Redeploys previous known-good configuration

Rollback decision logic:

```text
If deployment fails:
  1. Check error severity (critical vs. recoverable)
  2. Determine affected resources
  3. Assess rollback feasibility
  4. Execute rollback strategy
  5. Verify rollback completion
  6. Generate incident report
```

### 8. Deployment Status Monitoring

Post-deployment verification includes:

- Resource provisioning status
- Resource health checks
- Connectivity validation
- Performance baseline establishment
- Cost monitoring setup
- Log aggregation configuration

## Output Format

The agent provides structured deployment results:

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
    "databaseConnectionString": "Server=prod-app-sql.database.windows.net;..."
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
  "affectedResources": [
    "vnet-001",
    "subnet-001"
  ]
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

## Model

**Recommended:** claude-sonnet-4.6
**Rationale:** Infrastructure orchestration, rollback decisions, and deployment risk assessment require structured reasoning
**Minimum:** gpt-5.4-mini

## Governance

This agent operates under the BaseCoat governance framework.

- **Issue-first**: Do not make code changes without a logged GitHub issue.
- **PRs only**: Never commit directly to `main`. Open a PR, self-approve if needed.
- **No secrets**: Never commit credentials, tokens, API keys, or sensitive data.
- **Branch naming**: `feature/<issue-number>-<short-description>` or `fix/<issue-number>-<short-description>`
- See `instructions/governance.instructions.md` for the full governance reference.
