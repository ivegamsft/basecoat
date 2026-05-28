# Wave 3 Day 3 - Basecoat Portal Staging Environment Deployment Guide

## Executive Summary

This guide orchestrates the deployment of the **Basecoat Portal infrastructure to AWS Staging** environment. The deployment includes:

- **VPC & Networking**: Multi-AZ architecture with public/private/database subnets
- **Database Tier**: RDS PostgreSQL Multi-AZ with read replicas (100GB storage)
- **Cache Tier**: ElastiCache Redis cluster with automatic failover
- **Application Tier**: Auto-scaling compute layer (2-5 instances)
- **Monitoring**: CloudWatch dashboards and SNS alerts
- **Security**: Encryption at rest/transit, security groups, VPC isolation

**Infrastructure Components**: 45+ AWS resources
**Validation Status**: ✅ Configuration valid (terraform validate)
**Deployment Environment**: Staging (us-east-1)
**Timeline**: ~15-20 minutes for complete deployment

---

## Pre-Deployment Checklist

### 1. AWS Account Preparation

- [ ] AWS Account access (staging account)
- [ ] IAM user/role with Terraform permissions
- [ ] AWS CLI configured: \ws configure\
- [ ] Verify AWS credentials: \ws sts get-caller-identity\
- [ ] Appropriate AWS region: us-east-1

### 2. Terraform Backend Setup (S3 + DynamoDB)

**Important**: State management prevents concurrent modifications and enables recovery.

\\\ash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket basecoat-terraform-state-staging \
  --region us-east-1

# Enable versioning for state recovery
aws s3api put-bucket-versioning \
  --bucket basecoat-terraform-state-staging \
  --versioning-configuration Status=Enabled

# Block public access (security)
aws s3api put-public-access-block \
  --bucket basecoat-terraform-state-staging \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket basecoat-terraform-state-staging \
  --server-side-encryption-configuration \
  '{
    \"Rules\": [{
      \"ApplyServerSideEncryptionByDefault\": {\"SSEAlgorithm\": \"AES256\"}
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name basecoat-terraform-locks-staging \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1

# Tag resources
aws s3api put-bucket-tagging \
  --bucket basecoat-terraform-state-staging \
  --tagging 'TagSet=[{Key=Environment,Value=staging},{Key=ManagedBy,Value=terraform},{Key=Application,Value=basecoat-portal}]'
\\\

### 3. Required Software

- [ ] Terraform >= 1.5.0: \	erraform version\
- [ ] AWS CLI: \ws --version\
- [ ] PowerShell or Bash shell

### 4. Configuration Variables Review

All variables configured in \	erraform/environments/staging/terraform.tfvars\:

| Variable | Staging Value | Purpose |
|----------|---------------|---------|
| environment | staging | Environment identifier |
| vpc_cidr | 10.0.0.0/16 | VPC network block |
| database_instance_class | db.t3.small | PostgreSQL instance size |
| database_allocated_storage | 50 GB | Database volume |
| cache_instance_type | cache.t3.small | Redis instance size |
| compute_desired_capacity | 2 | Initial EC2 instances |
| backup_retention_days | 14 | RDS backup window |
| enable_encryption_at_rest | true | Encryption enabled |

---

## Step 1: Environment Initialization

### 1.1 Create Backend Configuration

Create \	erraform/backend-staging.tf\:

\\\hcl
terraform {
  backend \"s3\" {
    bucket         = \"basecoat-terraform-state-staging\"
    key            = \"staging/terraform.tfstate\"
    region         = \"us-east-1\"
    dynamodb_table = \"basecoat-terraform-locks-staging\"
    encrypt        = true
  }
}
\\\

### 1.2 Initialize Terraform with Backend

\\\ash
cd terraform
terraform init -backend-config=backend-staging.tf
\\\

Expected output:
\\\
Initializing the backend...
Successfully configured the backend \"s3\"!
Terraform has been successfully initialized!
\\\

### 1.3 Verify Backend

\\\ash
# Check S3 backend
aws s3 ls s3://basecoat-terraform-state-staging/

# Verify DynamoDB table created
aws dynamodb describe-table \
  --table-name basecoat-terraform-locks-staging \
  --region us-east-1 | jq '.Table.TableStatus'
\\\

---

## Step 2: Terraform Plan & Review

### 2.1 Validate Configuration

\\\ash
terraform validate
\\\

Expected: \Success! The configuration is valid.\

### 2.2 Generate Deployment Plan

\\\ash
terraform plan \
  -var-file=environments/staging/terraform.tfvars \
  -out=staging.tfplan
\\\

### 2.3 Review Resource Plan

The plan will create approximately **45+ AWS resources**:

#### Networking Resources (8)
- 1 x VPC (10.0.0.0/16)
- 1 x Internet Gateway
- 2 x Public Subnets (ALB tier)
- 2 x Private Subnets (Application tier)
- 2 x Private Subnets (Database tier)
- 2 x NAT Gateways
- 2 x Elastic IPs

#### Security Resources (6)
- 1 x ALB Security Group (allow 80, 443 from 0.0.0.0/0)
- 1 x Application Security Group (allow from ALB)
- 1 x Database Security Group (allow port 5432 from app)
- 1 x Cache Security Group (allow port 6379 from app)
- IAM roles and policies for VPC Flow Logs
- IAM roles for RDS Proxy

#### Data Layer Resources (8)
- 1 x RDS PostgreSQL Multi-AZ instance
- 1 x RDS Parameter Group
- 1 x RDS Read Replica
- 1 x RDS Proxy
- 1 x RDS Subnet Group
- 1 x Secrets Manager Secret (DB password)
- 2 x CloudWatch Log Groups (RDS logs)

#### Cache Layer Resources (6)
- 1 x ElastiCache Redis Replication Group
- 1 x ElastiCache Parameter Group
- 2 x CloudWatch Log Groups (slow-log, engine-log)
- 1 x SNS Topic (notifications)
- 1 x ElastiCache Subnet Group

#### Monitoring & Logging (8)
- Multiple CloudWatch Log Groups
- IAM role for VPC Flow Logs
- SNS topics for alerts

**Total Estimated AWS Costs (Staging)**:
- RDS db.t3.small Multi-AZ: ~\-120/month
- ElastiCache cache.t3.small: ~\-45/month
- EC2 t3.medium (2 instances): ~\-80/month
- NAT Gateway: ~\-35/month
- Storage (RDS 50GB): ~\-15/month
- Data transfer & misc: ~\-20/month

**Monthly Total**: ~\-315/month

---

## Step 3: Pre-Deployment Security Review

### 3.1 Security Group Rules Validation

\\\ash
# These will be created by Terraform - verify ingress rules:

# ALB Security Group: Allow public HTTP/HTTPS
# Inbound: 0.0.0.0/0:80, 0.0.0.0/0:443
# Outbound: All to application SG

# Application Security Group: Allow from ALB only
# Inbound: ALB SG:80, ALB SG:443, Cache SG:6379, DB SG:5432
# Outbound: DB SG:5432, Cache SG:6379, 0.0.0.0/0:443 (package downloads)

# Database Security Group: Allow from App only
# Inbound: App SG:5432
# Outbound: None required

# Cache Security Group: Allow from App only
# Inbound: App SG:6379
# Outbound: None required
\\\

### 3.2 Encryption Verification

- ✅ RDS: Encryption at rest enabled (KMS)
- ✅ ElastiCache: Encryption at rest + transit enabled
- ✅ Secrets Manager: Database password encrypted
- ✅ S3 Backend: AES256 encryption enabled

### 3.3 Network Isolation

- ✅ RDS: Private subnets only (not publicly accessible)
- ✅ ElastiCache: Private subnets only
- ✅ EC2 Instances: Private subnets with NAT gateway for outbound
- ✅ ALB: Public subnets, accepts public traffic

---

## Step 4: Deployment Execution

### 4.1 Apply Terraform Configuration

\\\ash
terraform apply staging.tfplan
\\\

**Timeline**:
- VPC creation: ~1-2 min
- Subnet/Route table creation: ~1-2 min
- RDS instance creation: ~5-8 min (Multi-AZ adds time)
- ElastiCache cluster: ~3-5 min
- Security groups & IAM: ~1-2 min
- Application Load Balancer: ~2-3 min
- Monitoring/CloudWatch: ~1-2 min

**Total deployment time**: ~15-20 minutes

### 4.2 Monitor Deployment Progress

\\\ash
# Watch Terraform output
terraform apply -var-file=environments/staging/terraform.tfvars

# Or check AWS console
aws ec2 describe-vpcs --filters Name=tag:Environment,Values=staging
aws rds describe-db-instances --filters Name=db-instance-id,Values=basecoat-portal-db
aws elasticache describe-replication-groups --filters Name=replication-group-status,Values=available
\\\

---

## Step 5: Post-Deployment Verification

### 5.1 Export Infrastructure Outputs

\\\ash
terraform output -json > staging-infrastructure-outputs.json
\\\

### 5.2 Verify All Resources Created

\\\ash
# VPC
aws ec2 describe-vpcs --filters Name=tag:Environment,Values=staging

# Subnets
aws ec2 describe-subnets --filters Name=tag:Environment,Values=staging

# RDS Instance
aws rds describe-db-instances \
  --db-instance-identifier basecoat-portal-db

# ElastiCache Cluster
aws elasticache describe-replication-groups \
  --replication-group-id basecoat-portal-redis

# Security Groups
aws ec2 describe-security-groups \
  --filters Name=tag:Environment,Values=staging
\\\

### 5.3 Database Connectivity Test

\\\ash
# Retrieve database endpoint
DB_ENDPOINT=\

# Note: From within application tier or bastion host:
# psql -h \ -U postgres -d postgres

# Or use AWS Secrets Manager to retrieve connection details:
aws secretsmanager get-secret-value \
  --secret-id basecoat-portal/db/password \
  --region us-east-1
\\\

### 5.4 Redis Cache Connectivity Test

\\\ash
# Retrieve Redis endpoint
REDIS_ENDPOINT=\

# From application tier:
# redis-cli -h \ -p 6379 PING
# Should respond: PONG
\\\

### 5.5 CloudWatch Dashboard Verification

Dashboards created:
- \asecoat-portal-rds-dashboard\
- \asecoat-portal-redis-dashboard\
- \asecoat-portal-alb-dashboard\
- \asecoat-portal-network-dashboard\

\\\ash
aws cloudwatch list-dashboards --region us-east-1 | grep basecoat-portal
\\\

---

## Step 6: Monitoring & Alarms Setup

### 6.1 CloudWatch Alarms

The following alarms are automatically created:

#### RDS Alarms
- **CPU Utilization > 80%**: SNS notification
- **Disk Space > 80%**: SNS notification
- **Database Connections > 40**: SNS notification
- **IOPS > 3000**: SNS notification

#### ElastiCache Alarms
- **CPU Utilization > 75%**: SNS notification
- **Memory > 80%**: SNS notification
- **Evictions > 0**: SNS notification
- **Connection Count > 50**: SNS notification

#### ALB Alarms
- **Error Rate > 1%**: SNS notification
- **Unhealthy Hosts > 0**: SNS notification
- **Response Time > 1000ms**: SNS notification
- **Request Count > 10000/min**: SNS notification

### 6.2 SNS Email Notifications

Subscribe to SNS topics for alerts:

\\\ash
# List SNS topics
aws sns list-topics --region us-east-1

# Subscribe to alerts
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:basecoat-portal-elasticache-notifications \
  --protocol email \
  --notification-endpoint your-email@company.com \
  --region us-east-1
\\\

### 6.3 View Dashboards

Access CloudWatch dashboards:

\\\ash
# Get dashboard URLs (manual access)
# 1. AWS Console → CloudWatch → Dashboards
# 2. Select basecoat-portal-* dashboards
# 3. Monitor key metrics in real-time
\\\

---

## Connection Strings for Backend Team

After deployment completes, provide these connection details to the application team:

### PostgreSQL Connection String

\\\
# Standard connection (RDS instance)
postgresql://postgres:PASSWORD@ENDPOINT:5432/postgres

# Via RDS Proxy (recommended for connection pooling)
postgresql://postgres:PASSWORD@PROXY_ENDPOINT:5432/postgres

# Connection parameters
Host: <terraform output: database_endpoint>
Port: 5432
Username: postgres
Password: <stored in AWS Secrets Manager>
Database: postgres
\\\

### Redis Connection String

\\\
# Redis cluster connection
redis://PRIMARY_ENDPOINT:6379

# Connection parameters
Host: <terraform output: cache_endpoint>
Port: 6379
Auth Token: <if encryption enabled>

# Multiple nodes (if replication enabled):
redis-cluster://NODE1:6379,NODE2:6379
\\\

### Application Load Balancer

\\\
DNS Name: <terraform output: load_balancer_dns>
Health Check Endpoint: /health
Protocol: HTTPS (self-signed cert for staging)
\\\

---

## Troubleshooting Guide

### Issue: Terraform Plan Fails

**Error**: \Provider configuration missing\

**Solution**:
\\\ash
# Configure AWS credentials
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID=YOUR_KEY
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET
export AWS_REGION=us-east-1
\\\

### Issue: RDS Instance Creation Timeout

**Error**: \Error creating RDS instance, timeout\

**Solution**:
- Multi-AZ instances take 5-8 minutes
- Check AWS Console → RDS → Databases for progress
- Verify subnet group exists: \ws rds describe-db-subnet-groups\
- Check security group allows port 5432

### Issue: State Lock During Apply

**Error**: \Error acquiring the state lock\

**Solution**:
\\\ash
# Find lock ID
aws dynamodb scan \
  --table-name basecoat-terraform-locks-staging \
  --region us-east-1

# Force unlock (use with caution!)
terraform force-unlock LOCK_ID
\\\

### Issue: Insufficient AWS Resources

**Error**: \InsufficientInstanceCapacity\

**Solution**:
- Staging uses small instance types (t3.small, t3.medium)
- Rarely exceeds capacity, but if it does:
- Try different availability zone
- Reduce desired capacity temporarily

---

## Rollback Procedures

### Quick Rollback (Destroy All Resources)

**⚠️ CAUTION**: This deletes all infrastructure!

\\\ash
# Review what will be destroyed
terraform plan -destroy \
  -var-file=environments/staging/terraform.tfvars

# Destroy infrastructure
terraform destroy \
  -var-file=environments/staging/terraform.tfvars
\\\

### Selective Rollback (Destroy Specific Resources)

\\\ash
# Remove only RDS instance (keep VPC, caching, etc)
terraform destroy \
  -target=aws_db_instance.main \
  -var-file=environments/staging/terraform.tfvars

# Remove only cache layer
terraform destroy \
  -target=aws_elasticache_replication_group.main \
  -var-file=environments/staging/terraform.tfvars
\\\

### State Recovery

\\\ash
# Backup current state
terraform state pull > state-backup-\.json

# Restore previous state from S3
aws s3api list-object-versions \
  --bucket basecoat-terraform-state-staging \
  --prefix staging/terraform.tfstate

# Restore specific version
aws s3api get-object \
  --bucket basecoat-terraform-state-staging \
  --key staging/terraform.tfstate \
  --version-id VERSION_ID \
  terraform.tfstate

# Refresh state to match infrastructure
terraform refresh
\\\

---

## Scaling Procedures

### Scale Database (RDS)

\\\ash
# Update terraform.tfvars
# database_instance_class = \"db.t3.medium\"

# Apply changes (requires downtime)
terraform apply -var-file=environments/staging/terraform.tfvars
\\\

### Scale Compute (Auto-Scaling Group)

\\\ash
# Update desired capacity
# compute_desired_capacity = 4

terraform apply -var-file=environments/staging/terraform.tfvars
\\\

### Scale Cache (ElastiCache)

\\\ash
# Update number of nodes
# cache_num_cache_nodes = 3

# Apply changes (brief rebalancing required)
terraform apply -var-file=environments/staging/terraform.tfvars
\\\

---

## Documentation Artifacts

The following documentation is included in this deployment package:

1. **WAVE3_DAY3_STAGING_DEPLOYMENT_GUIDE.md** (this file)
2. **STAGING_INFRASTRUCTURE_OUTPUTS.json** (auto-generated after apply)
3. **STAGING_SECURITY_VALIDATION_REPORT.md** (security groups & rules)
4. **STAGING_NETWORKING_ARCHITECTURE.md** (VPC topology diagram)
5. **STAGING_CONNECTION_STRINGS.md** (application team reference)
6. **STAGING_DEPLOYMENT_CHECKLIST.md** (pre/post deployment checks)

---

## Support & Escalation

### Pre-Deployment Questions
- Review Infrastructure Code: \	erraform/docs/PORTAL_INFRASTRUCTURE_as_CODE_v1.md\
- Terraform Best Practices: \	erraform/DEPLOYMENT_GUIDE.md\
- AWS Architecture: \	erraform/environments/BACKEND_SETUP.md\

### During Deployment Issues
1. Check AWS CloudTrail for API errors
2. Review CloudFormation events (Terraform uses CloudFormation under hood)
3. Verify IAM permissions: \ws iam get-user\
4. Check resource quotas: \ws service-quotas list-service-quotas --service-code ec2\

### Post-Deployment Validation
- Verify all resources in AWS Console
- Test connectivity from application tier
- Confirm CloudWatch dashboards display metrics
- Validate alarm SNS notifications

---

## Sign-Off & Deployment Record

**Deployment Date**: [TO BE FILLED]
**Deployed By**: [DEPLOYER NAME]
**Approval**: [APPROVER NAME]
**Environment**: Staging
**AWS Account ID**: [ACCOUNT_ID]
**Region**: us-east-1

**Infrastructure Summary**:
- VPC CIDR: 10.0.0.0/16
- Public Subnets: 2 (ALB tier)
- Private Subnets: 4 (App + DB tier)
- RDS Instance: db.t3.small, 50GB storage, Multi-AZ
- Redis Cluster: cache.t3.small, 2 nodes, automatic failover
- Compute: t3.medium, 2-5 instances (auto-scaling)
- Monitoring: CloudWatch dashboards + SNS alerts enabled

**Post-Deployment Status**: ✅ Ready for integration testing

---

**Last Updated**: 2024
**Document Version**: 1.0
**Approval Status**: Pending Deployment
