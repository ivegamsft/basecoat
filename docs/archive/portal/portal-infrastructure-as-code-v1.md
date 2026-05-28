# Basecoat Portal Infrastructure as Code (IaC) v1.0

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Terraform Project Structure](#terraform-project-structure)
4. [Core Modules](#core-modules)
5. [Environment Configurations](#environment-configurations)
6. [Deployment Procedures](#deployment-procedures)
7. [Cost Optimization](#cost-optimization)
8. [Disaster Recovery](#disaster-recovery)
9. [Security Implementation](#security-implementation)
10. [Monitoring & Alerts](#monitoring--alerts)
11. [Cost Estimates](#cost-estimates)
12. [Troubleshooting](#troubleshooting)

---

## Overview

The Basecoat Portal infrastructure is designed to support **1000+ concurrent users** with high availability, disaster recovery, and multi-region deployment across AWS, Azure, and GCP cloud providers. This Infrastructure as Code (IaC) solution automates deployment, scaling, and security management.

### Key Features

- **Multi-Cloud Support**: AWS, Azure, GCP templates included
- **High Availability**: Multi-AZ/zone deployment with automatic failover
- **Disaster Recovery**: RTO < 4 hours, RPO < 1 hour
- **Auto-Scaling**: Dynamic scaling based on CPU, memory, and request count
- **Security First**: Encryption at rest/transit, least-privilege IAM, VPC isolation
- **Cost Optimized**: Spot instances, reserved capacity, storage lifecycle policies
- **Fully Automated**: Terraform orchestration with CI/CD integration

---

## Architecture

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Internet / CDN                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                        ┌─────▼─────┐
                        │  WAF / DDoS│
                        └─────┬─────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
   ┌────▼───┐           ┌────▼───┐           ┌────▼───┐
   │Primary │           │Secondary           │Tertiary│
   │Region  │           │Region              │Region  │
   └────┬───┘           └────┬───┘           └────┬───┘
        │                    │                    │
   ┌────▼────────────────────▼────────────────────▼────┐
   │         Application Layer (Auto-Scaling)         │
   │  • ALB / Load Balancer                           │
   │  • ECS/AKS/GKE Containers                        │
   │  • Auto-Scaling Group (1-20 instances)           │
   └────┬────────────────────────────────────────────┘
        │
   ┌────▼──────────────────────────────────────────────┐
   │         Data Layer (Multi-AZ)                    │
   │  • PostgreSQL RDS (Multi-AZ)                     │
   │  • Read Replicas for scaling                     │
   │  • RDS Proxy for connection pooling              │
   └────┬──────────────────────────────────────────────┘
        │
   ┌────▼──────────────────────────────────────────────┐
   │         Caching Layer (Redis)                    │
   │  • ElastiCache / Azure Cache / Cloud Memorystore │
   │  • Multi-node for HA                             │
   │  • Automatic failover enabled                    │
   └────────────────────────────────────────────────────┘

Parallel Infrastructure:
   ┌──────────────────────┐    ┌──────────────────────┐
   │   Storage (S3/etc)   │    │   Secrets Manager    │
   │  • Encryption at rest│    │  • KMS encrypted     │
   │  • Versioning        │    │  • Auto-rotation     │
   │  • Lifecycle rules   │    │  • Audit logging     │
   └──────────────────────┘    └──────────────────────┘

Monitoring & Security:
   ┌──────────────────────┐    ┌──────────────────────┐
   │  Monitoring/Logging  │    │    Security Groups   │
   │  • CloudWatch        │    │  • WAF rules         │
   │  • Application       │    │  • IAM policies      │
   │    Insights          │    │  • VPC Flow Logs     │
   └──────────────────────┘    └──────────────────────┘
```

---

## Terraform Project Structure

```
terraform/
├── versions.tf                 # Provider configuration & version constraints
├── variables.tf                # Input variables (common across all clouds)
├── main.tf                     # Root module orchestration
├── outputs.tf                  # Root-level outputs
├── terraform.tfvars            # Default variable values
│
├── aws/                        # AWS-specific modules
│   ├── main.tf                # AWS root module
│   ├── variables.tf
│   ├── outputs.tf
│   ├── vpc.tf                 # VPC, subnets, routing
│   ├── security_groups.tf     # Security groups
│   └── iam.tf                 # IAM roles & policies
│
├── azure/                      # Azure-specific modules
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── network.tf             # Virtual Network
│   ├── storage.tf             # Storage accounts
│   └── keyvault.tf            # Key Vault
│
├── gcp/                        # GCP-specific modules
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── network.tf             # VPC Network
│   ├── compute.tf             # Compute resources
│   └── secrets.tf             # Secret Manager
│
├── modules/                    # Reusable Terraform modules
│   ├── networking/
│   │   ├── main.tf            # VPC, subnets, NAT gateways
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── database/
│   │   ├── main.tf            # PostgreSQL RDS, Multi-AZ, read replicas
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── compute/
│   │   ├── main.tf            # ALB, Auto-Scaling Group, EC2
│   │   ├── user_data.sh       # Instance initialization script
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── caching/
│   │   ├── main.tf            # ElastiCache Redis, replication group
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── storage/
│   │   ├── main.tf            # S3 buckets, encryption, lifecycle
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── secrets/
│   │   ├── main.tf            # Secrets Manager, KMS, rotation
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── security/
│   │   ├── main.tf            # Security groups, IAM roles
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── monitoring/
│       ├── main.tf            # CloudWatch logs, dashboards, alarms
│       ├── variables.tf
│       └── outputs.tf
│
└── environments/               # Environment-specific configurations
    ├── dev/
    │   ├── terraform.tfvars    # Dev overrides (minimal resources)
    │   └── backend.tf          # Dev state backend
    │
    ├── staging/
    │   ├── terraform.tfvars    # Staging overrides (prod-like)
    │   └── backend.tf          # Staging state backend
    │
    └── prod/
        ├── terraform.tfvars    # Prod overrides (maximum resources)
        └── backend.tf          # Prod state backend
```

---

## Core Modules

### 1. Networking Module (`modules/networking/`)

**Purpose**: VPC, subnets, NAT gateways, routing tables

**Key Resources**:
- VPC with configurable CIDR block
- Public subnets (for ALB, NAT gateways)
- Private subnets (for EC2, database, cache)
- NAT gateways for private subnet outbound access
- Internet Gateway for public subnet internet access
- VPC Flow Logs for network monitoring

**Usage**:
```hcl
module "aws_networking" {
  source = "./modules/networking"
  project_name = "basecoat-portal"
  environment = "prod"
  vpc_cidr = "10.0.0.0/16"
  private_subnets_cidr = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets_cidr = ["10.0.10.0/24", "10.0.11.0/24"]
}
```

**Outputs**:
- `vpc_id`: VPC identifier
- `private_subnet_ids`: List of private subnet IDs
- `public_subnet_ids`: List of public subnet IDs
- `database_subnet_group_name`: RDS subnet group

---

### 2. Database Module (`modules/database/`)

**Purpose**: PostgreSQL RDS with Multi-AZ, read replicas, connection pooling

**Key Features**:
- PostgreSQL 15.3 with Multi-AZ deployment
- Automated backups (30-day retention in prod)
- Read replicas for scaling read workloads
- RDS Proxy for connection pooling
- Secrets Manager integration for password rotation
- Encryption at rest with KMS
- IAM database authentication

**Usage**:
```hcl
module "aws_database" {
  source = "./modules/database"
  project_name = "basecoat-portal"
  instance_class = "db.r6i.xlarge"
  allocated_storage = 200
  backup_retention_days = 30
  multi_az = true
  enable_read_replicas = true
}
```

**Scaling Strategy**:
- Master: db.r6i.xlarge (32 vCPUs, 256GB memory)
- Read replicas: db.r6i.large (8 vCPUs, 64GB memory)
- Connection pooling: RDS Proxy (1000 connections)

---

### 3. Compute Module (`modules/compute/`)

**Purpose**: ALB, Auto-Scaling Group, EC2 instances

**Key Features**:
- Application Load Balancer (ALB) with health checks
- Auto-Scaling Group with dynamic scaling policies
- Spot instances for cost optimization
- CloudWatch agent for custom metrics
- Instance role with Secrets Manager access

**Scaling Policy**:
- Scale UP: CPU > 70% for 2 consecutive periods (5 min)
- Scale DOWN: CPU < 30% for 2 consecutive periods (5 min)
- Cool down: 5 minutes between scaling actions

**Usage**:
```hcl
module "aws_compute" {
  source = "./modules/compute"
  instance_type = "t3.large"
  min_size = 3
  max_size = 20
  desired_capacity = 5
  enable_cost_optimization = true
  spot_instance_pools = 3
}
```

---

### 4. Caching Module (`modules/caching/`)

**Purpose**: Redis ElastiCache with automatic failover

**Key Features**:
- Redis 7.0 cluster with multi-node
- Automatic failover (Multi-AZ)
- Encryption in transit & at rest
- Auth token for secure access
- Slowlog & engine log delivery to CloudWatch
- Snapshot & restore for data persistence

**High Availability**:
- Primary + 2 replicas (3 nodes total)
- Automatic failover on primary failure
- Read replicas for load distribution

---

### 5. Storage Module (`modules/storage/`)

**Purpose**: S3 buckets with encryption, versioning, lifecycle

**Key Features**:
- S3 bucket with AES-256/KMS encryption
- Versioning enabled (for audit trails)
- Lifecycle rules (transition to GLACIER after 60 days)
- Public access blocked
- MFA delete protection
- Server-side encryption enforced via bucket policy

**Lifecycle Strategy**:
- 0-30 days: STANDARD
- 30-60 days: STANDARD-IA
- 60+ days: GLACIER
- 180+ days: EXPIRATION

---

### 6. Secrets Module (`modules/secrets/`)

**Purpose**: KMS, Secrets Manager, automatic rotation

**Key Features**:
- KMS key for encryption at rest
- Secrets Manager for API keys, encryption keys
- Lambda-based automatic rotation (30-day cycle)
- Audit logging for all secret access

---

### 7. Security Module (`modules/security/`)

**Purpose**: Security groups, IAM roles, VPC isolation

**Security Groups**:
- **ALB SG**: Allows HTTP/HTTPS from 0.0.0.0/0
- **Application SG**: Allows port 8080 from ALB SG, SSH from VPC
- **Database SG**: Allows port 5432 from Application SG
- **Cache SG**: Allows port 6379 from Application SG

**IAM Policies**:
- Application role: Read from Secrets Manager, CloudWatch PutMetrics
- Database proxy role: Decrypt secrets with KMS
- S3 access: GetObject, PutObject on specific buckets

---

### 8. Monitoring Module (`modules/monitoring/`)

**Purpose**: CloudWatch logs, dashboards, alarms

**Key Metrics**:
- Database: CPU, connections, read/write latency
- Cache: CPU, evictions, replication lag
- Application: CPU, target response time, error rates
- ALB: HTTP 4XX/5XX counts, request latency

**Alarms** (with SNS notifications):
- Database CPU > 80%
- Database connections > 800
- Cache evictions > 100
- ALB 5XX errors > 10 (per period)
- ASG unhealthy instances > 0

---

## Environment Configurations

### Development (Dev)

**Resource Sizing**:
- Database: db.t3.micro (2 vCPUs, 1GB)
- Compute: t3.small (2 vCPUs, 2GB), 1-3 instances
- Cache: cache.t3.micro (single node)

**Cost**: ~$150-200/month

**High Availability**: Single AZ only

**Backups**: 7-day retention

**Monitoring**: Basic metrics only

### Staging

**Resource Sizing**:
- Database: db.t3.small (2 vCPUs, 2GB), Multi-AZ
- Compute: t3.medium (2 vCPUs, 4GB), 2-5 instances
- Cache: cache.t3.small (2 nodes, Multi-AZ)

**Cost**: ~$800-1,200/month

**High Availability**: Multi-AZ with automatic failover

**Backups**: 14-day retention

**Monitoring**: Full monitoring with dashboards

### Production (Prod)

**Resource Sizing**:
- Database: db.r6i.xlarge (32 vCPUs, 256GB), Multi-AZ + read replicas
- Compute: t3.large (2 vCPUs, 8GB), 3-20 instances (with Spot)
- Cache: cache.r6g.xlarge (3 nodes, Multi-AZ)

**Cost**: ~$5,000-8,000/month

**High Availability**: Multi-region with cross-region read replicas

**Backups**: 30-day retention

**Monitoring**: Full monitoring with alerting & tracing

---

## Deployment Procedures

### Prerequisites

1. **Install Terraform** (>= 1.5.0):
   ```bash
   terraform version
   ```

2. **Configure AWS CLI**:
   ```bash
   aws configure
   aws sts get-caller-identity
   ```

3. **Clone Repository**:
   ```bash
   git clone https://github.com/IBuySpy-Shared/basecoat.git
   cd basecoat/terraform
   ```

### Development Deployment

```bash
# Initialize Terraform (one-time)
terraform init -backend-config=environments/dev/backend.tf

# Validate configuration
terraform validate

# Plan deployment
terraform plan -var-file=environments/dev/terraform.tfvars -out=dev.plan

# Review plan output for changes

# Apply deployment
terraform apply dev.plan

# Export outputs
terraform output -json > dev-outputs.json
```

### Staging Deployment

```bash
terraform init -backend-config=environments/staging/backend.tf
terraform plan -var-file=environments/staging/terraform.tfvars -out=staging.plan
terraform apply staging.plan
```

### Production Deployment

```bash
terraform init -backend-config=environments/prod/backend.tf

# Plan (requires manual review)
terraform plan -var-file=environments/prod/terraform.tfvars -out=prod.plan

# Manual approval process:
# 1. Review prod.plan
# 2. Create GitHub PR with plan output
# 3. Require 2+ approvals
# 4. Run terraform apply

terraform apply prod.plan
```

### Terraform State Management

**Backend Configuration** (AWS S3):
```hcl
terraform {
  backend "s3" {
    bucket         = "basecoat-portal-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "basecoat-portal-locks"
  }
}
```

**State Locking**:
- DynamoDB table `basecoat-portal-locks` prevents concurrent modifications
- Auto-unlock after 30 minutes (in case of hung process)

---

## Cost Optimization

### Reserved Capacity Strategy

**Database**:
- 1-year reserved instance: 33% discount
- 3-year reserved instance: 50% discount

**Compute**:
- On-Demand: 5% (baseline for unpredictable spikes)
- Spot Instances: 70% (cost-optimized, 2-3 pools for interruption tolerance)
- Reserved: 25% (1-year term for baseline load)

### Cost Reduction Strategies

1. **Auto-Scaling**: Scale down to 1 instance during off-hours
2. **Storage Lifecycle**: Transition to GLACIER after 60 days (-70% cost)
3. **Spot Instances**: Use for non-critical workloads (-70% vs On-Demand)
4. **Connection Pooling**: RDS Proxy reduces connections (-20% database cost)
5. **Cache Optimization**: Right-size based on hit ratio

### Monthly Cost Estimates

| Component | Dev | Staging | Prod |
|-----------|-----|---------|------|
| Database | $40 | $120 | $1,200 |
| Compute | $30 | $250 | $2,500 |
| Cache | $15 | $80 | $600 |
| Storage | $5 | $50 | $300 |
| Data Transfer | $10 | $50 | $500 |
| Monitoring | $5 | $20 | $50 |
| **Total** | **$105** | **$570** | **$5,150** |

---

## Disaster Recovery

### RTO & RPO Targets

- **RTO** (Recovery Time Objective): < 4 hours
- **RPO** (Recovery Point Objective): < 1 hour

### Multi-Region Setup

**Primary Region**: us-east-1
**Secondary Region**: us-west-2

**Data Replication**:
- Database: Read replicas in secondary region
- S3: Cross-region replication (enabled)
- DNS: Route53 geolocation routing

### Failover Procedure

1. **Detect Failure** (CloudWatch alarm):
   ```bash
   # ALB health check fails
   # Database primary becomes unreachable
   ```

2. **Promote Secondary**:
   ```bash
   # Promote RDS read replica to standalone
   aws rds promote-read-replica \
     --db-instance-identifier basecoat-portal-db-read-replica
   ```

3. **Update DNS**:
   ```bash
   # Route53 automatically redirects to secondary region
   # (Requires manual update if primary region completely down)
   ```

4. **Verify & Test**:
   ```bash
   # Test application connectivity
   curl https://secondary.basecoat-portal.com/health
   
   # Verify database replication lag
   aws rds describe-db-instances --db-instance-identifier basecoat-portal-db
   ```

### DR Testing Schedule

- **Monthly**: Failover to secondary region
- **Quarterly**: Full DR drill (validate recovery time)
- **Annually**: Update DR runbook based on lessons learned

---

## Security Implementation

### Network Security

1. **VPC Isolation**:
   - Public subnets: ALB only
   - Private subnets: EC2, RDS, Redis
   - No direct internet access for application servers

2. **WAF Rules**:
   - Rate limiting (100 req/5 min per IP)
   - SQL injection pattern matching
   - Cross-site scripting (XSS) prevention
   - Geo-blocking (block non-US/EU IPs)

3. **VPC Flow Logs**:
   - Monitor accepted/rejected traffic
   - Send to CloudWatch for analysis

### Data Encryption

1. **Encryption in Transit**:
   - TLS 1.2+ for all external connections
   - HTTPS-only ALB listener

2. **Encryption at Rest**:
   - RDS: AES-256 with KMS
   - S3: AES-256 with KMS
   - Redis: Redis AUTH token

### IAM & Access Control

1. **Least Privilege**:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": "secretsmanager:GetSecretValue",
         "Resource": "arn:aws:secretsmanager:*:*:secret:basecoat-portal/*"
       }
     ]
   }
   ```

2. **Service-to-Service Auth**:
   - Application role assumes database role
   - Secrets Manager provides temporary credentials

3. **Audit Logging**:
   - CloudTrail: All API calls
   - VPC Flow Logs: All network traffic
   - CloudWatch: Application events

---

## Monitoring & Alerts

### Key Dashboards

1. **Infrastructure Dashboard**:
   - Database: CPU, memory, connections, replication lag
   - Cache: CPU, memory, evictions, hit ratio
   - Compute: CPU, memory, instance count, health status

2. **Application Dashboard**:
   - Request rate (requests/sec)
   - Error rate (5XX / total requests)
   - Latency (p50, p95, p99)
   - Dependency health (database, cache)

3. **Cost Dashboard**:
   - Daily spend by service
   - Reserved vs Spot utilization
   - Storage usage & growth trend

### Alert Rules

| Metric | Threshold | Action |
|--------|-----------|--------|
| Database CPU | > 80% | Page on-call |
| Database Connections | > 800 | Auto-scale connection pool |
| Cache Evictions | > 0 | Page on-call |
| ALB 5XX Errors | > 10/min | Page on-call |
| Application Latency | p99 > 5s | Scale up compute |
| Storage > Quota | > 90% | Increase quota |

---

## Troubleshooting

### Common Issues

1. **Database Connection Timeout**:
   ```bash
   # Check security group
   aws ec2 describe-security-groups --group-ids sg-xxxxx
   
   # Test connectivity
   psql -h basecoat-portal-db.cxxxxx.us-east-1.rds.amazonaws.com \
        -U postgres -d postgres
   ```

2. **ASG Instances Not Launching**:
   ```bash
   # Check EC2 capacity
   aws ec2 describe-spot-price-history --instance-types t3.large
   
   # Check launch template
   aws ec2 describe-launch-templates --launch-template-names basecoat-lt
   ```

3. **Slow Database Queries**:
   ```bash
   # Enable slow query log (> 1 sec)
   aws rds modify-db-parameter-group \
     --db-parameter-group-name basecoat-postgres-params \
     --parameters ParameterName=log_min_duration_statement,ParameterValue=1000,ApplyMethod=immediate
   ```

### Support & Escalation

1. **Infrastructure Team**: Terraform, AWS resources
2. **DevOps Team**: CI/CD, deployment automation
3. **Security Team**: IAM, encryption, compliance
4. **On-Call Runbook**: `/docs/runbooks/`

---

## References

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws)
- [AWS Best Practices](https://aws.amazon.com/architecture/well-architected/)
- [PostgreSQL Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Disaster Recovery Planning](https://aws.amazon.com/disaster-recovery/)
- [Cost Optimization](https://aws.amazon.com/cost-optimization/)

---

**Last Updated**: May 5, 2024
**Version**: 1.0
**Author**: Infrastructure Team (Basecoat Portal)
**Status**: Production Ready
