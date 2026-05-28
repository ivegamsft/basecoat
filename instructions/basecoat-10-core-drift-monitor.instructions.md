---
description: Infrastructure-as-Code drift detection and remediation strategies
applyTo: "**/*.tf,**/*.bicep,**/infra/**"
---

# Drift Monitor Instruction

## Overview

Infrastructure drift occurs when your deployed cloud resources diverge from their Infrastructure-as-Code (IaC) definitions. This instruction provides guidance on detecting, analyzing, and remediating drift in Terraform and Azure Bicep deployments using Terraform plan analysis, Azure Resource Graph queries, and automated detection strategies.

## Drift Detection Methods

### Terraform Plan Analysis

Use `terraform plan` to identify differences between your current IaC definitions and actual deployed infrastructure:

```bash
terraform plan -out=tfplan
terraform show tfplan
```

This comparison reveals:

- Resources that exist in code but not in state
- Resources in state but missing from code
- Properties that differ between definition and deployment
- New resources requiring creation
- Resources marked for destruction

### Azure Resource Graph Queries

Query your deployed resources using Azure Resource Graph to verify compliance with IaC definitions:

```text
Resources
| where type =~ 'microsoft.compute/virtualmachines'
| project name, location, properties.hardwareProfile.vmSize, tags
```

Compare the results against your Terraform or Bicep source to identify unauthorized changes, missing tags, or configuration deviations.

## Comparing Deployed State vs Source

### State File Analysis

Examine your Terraform state file to see what infrastructure was last recorded as deployed:

```bash
terraform state list
terraform state show resource.name
```

Compare state outputs against current code:

```bash
terraform plan -detailed-exitcode
```

Exit codes:

- `0`: No changes
- `1`: Error
- `2`: Changes detected (drift)

### Azure Deployment History

Review deployment history in Azure to track what was deployed and when:

```bash
az deployment sub list --output table
az deployment sub show --name deployment-name
```

Check resource metadata for last modification timestamps to identify unexpected changes.

## Drift Remediation Strategies

### Strategy 1: Update IaC to Match Deployment

If the deployed state is correct and preferable, update your code:

```bash
terraform apply -refresh-only
terraform plan
```

Then update the `.tf` files to match the desired state and commit changes.

### Strategy 2: Redeploy to Match IaC

If IaC is the source of truth, redeploy to correct drift:

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

This approach ensures deployed infrastructure matches code definitions exactly.

### Strategy 3: Targeted Resource Updates

For partial drift, target specific resources:

```bash
terraform apply -target=resource.name
```

Or use Azure CLI to modify individual resources while planning full IaC updates:

```bash
az resource update --resource-group rg-name --name resource-name \
  --resource-type Microsoft.Compute/virtualMachines --set properties.tags.owner=value
```

## Scheduled Drift Checks

### Automated Detection with CI/CD

Add drift detection to your pipeline to run on a schedule:

```yaml
trigger:
  schedule:
    - cron: '0 6 * * *'
      displayName: Daily drift check
      branches:
        include:
          - main

steps:
  - script: terraform plan -detailed-exitcode
    continueOnError: true
  - script: |
      if [ $? -eq 2 ]; then
        echo "Drift detected!"
        exit 1
      fi
```

### Local Monitoring

Run drift checks locally before deployments:

```bash
#!/bin/bash
terraform plan -out=tfplan
PLAN_EXIT=$?

if [ $PLAN_EXIT -eq 2 ]; then
  echo "Warning: Infrastructure drift detected"
  echo "Review the plan above and reconcile differences"
  exit 1
fi
```

## Alerting on Unexpected Changes

### Azure Policy Monitoring

Create Azure Policy definitions to alert when resources deviate from expected configurations:

```json
{
  "type": "Microsoft.Authorization/policyDefinitions",
  "name": "enforce-tag-compliance",
  "properties": {
    "policyType": "Custom",
    "mode": "All",
    "displayName": "Enforce required tags",
    "description": "Ensures all resources have required tags",
    "policyRule": {
      "if": {
        "field": "tags",
        "exists": "false"
      },
      "then": {
        "effect": "audit"
      }
    }
  }
}
```

### Activity Log Alerts

Set up alerts to notify on unauthorized resource modifications:

```bash
az monitor metrics alert create \
  --resource-group rg-name \
  --name drift-alert \
  --scopes /subscriptions/{subId}/resourceGroups/{rgName} \
  --condition "total ResourceModifications > 5"
```

### Change Tracking Integration

Enable Change Tracking and Inventory to monitor configuration changes:

```bash
az vm extension set \
  --resource-group rg-name \
  --vm-name vm-name \
  --name ChangeTracking-Linux \
  --publisher Microsoft.Azure.Automation \
  --version 0.4
```

## Best Practices

- Run `terraform plan` before every deployment to verify drift status
- Include drift detection in your CI/CD pipeline as a required check
- Document approved drift exceptions and maintain a drift registry
- Review Azure Resource Graph queries weekly for unauthorized changes
- Use resource tags to enforce organizational standards and detect violations
- Keep terraform state files in remote backends (Azure Blob Storage, Terraform Cloud)
- Use state locking to prevent concurrent modifications
- Implement role-based access control (RBAC) to limit who can modify infrastructure
- Maintain immutable audit trails of all infrastructure changes
