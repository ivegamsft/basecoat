# Basecoat Portal - Deployment Guide

## Quick Start

### 1. Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials
- Git for version control

### 2. Initialize Terraform

```bash
# Navigate to terraform directory
cd terraform

# Initialize with dev backend
terraform init -backend-config=environments/dev/backend.tf
```

### 3. Plan Deployment

```bash
# Validate configuration
terraform validate

# Plan development deployment
terraform plan -var-file=environments/dev/terraform.tfvars -out=dev.plan

# Review the plan output
```

### 4. Apply Deployment

```bash
# Apply the plan
terraform apply dev.plan

# Export outputs for reference
terraform output -json > outputs.json
```

## Environment-Specific Deployments

### Development

```bash
# Quick deployment for development
terraform apply -var-file=environments/dev/terraform.tfvars -auto-approve
```

### Staging

```bash
# Staged deployment with approval
terraform plan -var-file=environments/staging/terraform.tfvars -out=staging.plan
# Review plan...
terraform apply staging.plan
```

### Production

```bash
# Production requires manual approval gates
terraform plan -var-file=environments/prod/terraform.tfvars -out=prod.plan

# Manual review and approval process (documented in PRD)
terraform apply prod.plan
```

## Common Operations

### View Current State

```bash
terraform show
terraform output
```

### Scale Infrastructure

```bash
# Increase desired capacity
terraform apply -var-file=environments/prod/terraform.tfvars \
  -var='compute_desired_capacity=10'
```

### Update Variable

```bash
# Modify and re-apply
terraform apply -var-file=environments/prod/terraform.tfvars \
  -var='database_backup_retention_days=45'
```

## Troubleshooting

### Backend State Issues

```bash
# List state resources
terraform state list

# Show specific resource
terraform state show aws_db_instance.main

# Force unlock (only if stuck)
terraform force-unlock <LOCK_ID>
```

### Clean Up Resources

```bash
# Destroy all resources
terraform destroy -var-file=environments/dev/terraform.tfvars

# Destroy specific resource
terraform destroy -target=module.aws_compute -var-file=environments/dev/terraform.tfvars
```

## Support

For issues or questions, refer to the main documentation at `/docs/PORTAL_INFRASTRUCTURE_as_CODE_v1.md`
