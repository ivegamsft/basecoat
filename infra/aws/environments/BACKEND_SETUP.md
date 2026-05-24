# Terraform Backend Configuration for AWS S3 + DynamoDB

This directory contains backend configurations for each environment.
Backend manages remote Terraform state, locking, and consistency.

## Available Backends

- **Local**: Development only (default)
- **S3 + DynamoDB**: Production (recommended)
- **Terraform Cloud**: Enterprise (optional)

## Option 1: S3 + DynamoDB Backend (Recommended)

### Prerequisites

```bash
# Create S3 bucket for state storage
aws s3api create-bucket \
  --bucket basecoat-terraform-state-prod \
  --region us-east-1 \
  --create-bucket-configuration LocationConstraint=us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket basecoat-terraform-state-prod \
  --versioning-configuration Status=Enabled

# Block public access
aws s3api put-public-access-block \
  --bucket basecoat-terraform-state-prod \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket basecoat-terraform-state-prod \
  --server-side-encryption-configuration \
  '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}
    }]
  }'

# Enable logging
aws s3api put-bucket-logging \
  --bucket basecoat-terraform-state-prod \
  --bucket-logging-status '{
    "LoggingEnabled": {
      "TargetBucket": "basecoat-terraform-state-logs",
      "TargetPrefix": "state-access-logs/"
    }
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name basecoat-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1

# Tag resources
aws s3api put-bucket-tagging \
  --bucket basecoat-terraform-state-prod \
  --tagging 'TagSet=[{Key=Environment,Value=prod},{Key=ManagedBy,Value=terraform},{Key=Application,Value=basecoat-portal}]'

aws dynamodb tag-resource \
  --resource-arn arn:aws:dynamodb:us-east-1:ACCOUNT_ID:table/basecoat-terraform-locks \
  --tags AttributeName=Environment,AttributeValue=prod AttributeName=ManagedBy,AttributeValue=terraform
```

### Configure Backend

Create `backend.tf` in the root terraform directory:

```hcl
terraform {
  backend "s3" {
    bucket         = "basecoat-terraform-state-prod"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "basecoat-terraform-locks"
    encrypt        = true
  }
}
```

Or for development (S3 without locking):

```hcl
terraform {
  backend "s3" {
    bucket = "basecoat-terraform-state-dev"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}
```

### Initialize with Backend

```bash
# First time: local state only
terraform init

# Migrate to S3 backend
terraform init -backend-config=backend.tf

# Answer "yes" to copy state
# Verify:
aws s3 ls s3://basecoat-terraform-state-prod/
```

---

## Option 2: Terraform Cloud Backend

### Setup

1. Create account at https://app.terraform.io
2. Generate API token: https://app.terraform.io/app/settings/tokens
3. Store token in `~/.terraformrc`:

```hcl
credentials "app.terraform.io" {
  token = "YOUR_API_TOKEN"
}
```

### Configure

Create `backend.tf`:

```hcl
terraform {
  cloud {
    organization = "your-org"
    
    workspaces {
      name = "basecoat-prod"
    }
  }
}
```

### Initialize

```bash
terraform init
# Follow prompts to create workspace
```

---

## Option 3: Local Backend (Development Only)

Default behavior - no additional configuration needed.

```bash
# State stored in terraform.tfstate (local)
terraform init
```

**⚠️ WARNING**: Do NOT use for production:
- No locking (concurrent modifications cause corruption)
- No versioning (can't recover previous states)
- Risk of accidental deletion
- No centralized state audit trail

---

## State Locking

When using S3 backend with DynamoDB:

```bash
# Lock is automatic during apply
terraform apply

# If lock is stuck:
terraform force-unlock <LOCK_ID>

# Monitor locks:
aws dynamodb scan \
  --table-name basecoat-terraform-locks \
  --region us-east-1
```

## State Inspection

```bash
# List all resources
terraform state list

# Show specific resource
terraform state show aws_db_instance.main

# Export JSON
terraform state pull > state-backup.json

# Dangerous: Migrate state between backends
terraform state mv aws_instance.old aws_instance.new
```

## Backup & Recovery

### Automated Backups (S3)

S3 versioning preserves previous states:

```bash
# List state versions
aws s3api list-object-versions \
  --bucket basecoat-terraform-state-prod \
  --prefix terraform.tfstate

# Restore previous version
aws s3api get-object \
  --bucket basecoat-terraform-state-prod \
  --key terraform.tfstate \
  --version-id ID_HERE \
  terraform.tfstate.backup
```

### Manual Backup

```bash
# Pull current state
terraform state pull > state-backup-$(date +%Y%m%d).json

# Push state (dangerous!)
terraform state push state-backup-DATE.json
```

## State Drift

```bash
# Detect infrastructure changes outside Terraform
terraform refresh

# Plan to sync state with infrastructure
terraform plan

# If drift detected, options:
# 1. Apply to reconcile (terraform apply)
# 2. Import untracked resources (terraform import)
# 3. Taint resource to rebuild (terraform taint)
```

## Security

### IAM Policy for Backend Access

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::basecoat-terraform-state-prod"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::basecoat-terraform-state-prod/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:*:table/basecoat-terraform-locks"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketVersioning"
      ],
      "Resource": "arn:aws:s3:::basecoat-terraform-state-prod"
    }
  ]
}
```

Restrict this policy per environment:
- Dev team: access to dev state only
- Prod team: access to prod state only
- CI/CD: all environments (with additional approval)

### State Contains Secrets

By default, sensitive data is stored in plaintext in state:

```bash
# Avoid storing secrets in state:
# 1. Use AWS Secrets Manager (recommended)
# 2. Use remote state encryption (S3 + KMS)
# 3. Use sensitive = true for outputs

# Review what's in state
terraform state show aws_db_instance.main | grep password

# Never commit state to git
echo "terraform.tfstate*" >> .gitignore
```

---

**Last Updated**: May 2024
**Backend Version**: 1.0
