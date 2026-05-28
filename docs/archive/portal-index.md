# Basecoat Portal Infrastructure Documentation Index

## Quick Navigation

### 📋 Getting Started

**New to this infrastructure?** Start here:
1. [terraform/README.md](../terraform/README.md) - Overview & quick start
2. [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - Step-by-step deployment
3. [BACKEND_SETUP.md](../terraform/environments/BACKEND_SETUP.md) - Configure state management

### 📚 Core Documentation

**Architecture & Design**:
- [PORTAL_INFRASTRUCTURE_as_CODE_v1.md](./PORTAL_INFRASTRUCTURE_as_CODE_v1.md) - Complete architecture (10+ pages)
- [INFRASTRUCTURE_DELIVERY_SUMMARY.md](./INFRASTRUCTURE_DELIVERY_SUMMARY.md) - Project completion summary

**Operations**:
- [OPERATIONAL_RUNBOOK.md](./OPERATIONAL_RUNBOOK.md) - Common procedures (scaling, troubleshooting, maintenance)
- [DISASTER_RECOVERY.md](./DISASTER_RECOVERY.md) - Failover procedures & recovery strategies

**Financial**:
- [COST_OPTIMIZATION.md](./COST_OPTIMIZATION.md) - Cost analysis & optimization strategies

---

## Documentation by Role

### 👨‍💼 DevOps Engineer / Platform Engineer

**Learn first**:
1. terraform/README.md - Understand structure
2. DEPLOYMENT_GUIDE.md - Deploy environments
3. OPERATIONAL_RUNBOOK.md - Common operations

**Reference**:
- DISASTER_RECOVERY.md - Emergency procedures
- BACKEND_SETUP.md - State management
- terraform/modules/*/main.tf - Implementation details

**Key Procedures**:
- Deploy dev/staging/prod environments
- Scale application capacity
- Database maintenance & backups
- Monitor alarms & dashboards
- Incident response & failover

### 💻 Software Developer / Backend Engineer

**Learn first**:
1. terraform/README.md - Architecture overview
2. PORTAL_INFRASTRUCTURE_as_CODE_v1.md - Infrastructure components
3. OPERATIONAL_RUNBOOK.md - Development procedures

**Reference**:
- terraform/modules/compute/ - Application servers
- terraform/modules/database/ - Database configuration
- terraform/modules/secrets/ - Credential management

**Key Tasks**:
- Connect to development database
- Access application logs
- Deploy code updates
- Test infrastructure changes

### 📊 Engineering Manager / Tech Lead

**Learn first**:
1. INFRASTRUCTURE_DELIVERY_SUMMARY.md - Project overview
2. PORTAL_INFRASTRUCTURE_as_CODE_v1.md - Architecture
3. COST_OPTIMIZATION.md - Financial impact

**Reference**:
- DISASTER_RECOVERY.md - Risk assessment
- OPERATIONAL_RUNBOOK.md - Team procedures
- terraform/environments/ - Environment configurations

**Key Concerns**:
- HA/DR capabilities (RTO < 4h, RPO < 1h)
- Cost projections ($8.1k/month, $61k/year optimized)
- Security posture (encryption, VPC isolation, IAM)
- Deployment automation (CI/CD ready)

### 🔐 Security Officer / Compliance

**Learn first**:
1. PORTAL_INFRASTRUCTURE_as_CODE_v1.md - Security section
2. terraform/modules/security/ - Security groups & IAM
3. OPERATIONAL_RUNBOOK.md - Audit trail procedures

**Reference**:
- terraform/modules/secrets/ - Key management
- terraform/modules/monitoring/ - Logging & audit
- DISASTER_RECOVERY.md - Data protection

**Key Focus**:
- Encryption at rest (KMS) & in transit (TLS)
- VPC isolation & security groups
- IAM least-privilege policies
- Audit logging & VPC Flow Logs
- Secret rotation & key management

---

## File Structure Reference

```
.
├── docs/                                    # This directory
│   ├── INFRASTRUCTURE_DELIVERY_SUMMARY.md  # Project completion
│   ├── PORTAL_INFRASTRUCTURE_as_CODE_v1.md # Architecture (10+ pages)
│   ├── DEPLOYMENT_GUIDE.md                 # Deployment procedures
│   ├── DISASTER_RECOVERY.md                # Failover procedures
│   ├── OPERATIONAL_RUNBOOK.md              # Common operations
│   ├── COST_OPTIMIZATION.md                # Cost analysis
│   └── INDEX.md                            # This file
│
├── terraform/                              # Terraform root
│   ├── README.md                           # Quick start guide
│   ├── versions.tf                         # Provider configuration
│   ├── variables.tf                        # Input variables
│   ├── main.tf                             # Module orchestration
│   ├── outputs.tf                          # Output values
│   ├── terraform.tfvars                    # Default values
│   │
│   ├── modules/                            # Reusable modules
│   │   ├── networking/main.tf              # VPC, subnets, routing
│   │   ├── database/main.tf                # PostgreSQL RDS
│   │   ├── compute/main.tf                 # ALB, ASG, EC2
│   │   ├── caching/main.tf                 # Redis ElastiCache
│   │   ├── storage/main.tf                 # S3 buckets
│   │   ├── secrets/main.tf                 # KMS, Secrets Manager
│   │   ├── security/main.tf                # Security groups, IAM
│   │   └── monitoring/main.tf              # CloudWatch, alarms
│   │
│   └── environments/                       # Environment configs
│       ├── dev/terraform.tfvars            # Development (minimal)
│       ├── staging/terraform.tfvars        # Staging (prod-like)
│       ├── prod/terraform.tfvars           # Production (maximum)
│       └── BACKEND_SETUP.md                # Backend configuration
│
└── .github/workflows/
    └── terraform-deploy.yml                # CI/CD pipeline
```

---

## Key Metrics

| Metric | Dev | Staging | Prod |
|--------|-----|---------|------|
| **Monthly Cost** | $400 | $1,200 | $6,500 |
| **RTO** | N/A | 4 hours | 4 hours |
| **RPO** | N/A | 1 hour | 1 hour |
| **Database** | t3.micro | t3.small | r6i.xlarge |
| **Compute** | 1-3 | 2-5 | 3-20 |
| **Backup Days** | 7 | 14 | 30 |
| **Multi-AZ** | No | Yes | Yes |
| **Read Replicas** | No | No | Yes |

---

## Common Procedures

### Deploy Application Update
See: [OPERATIONAL_RUNBOOK.md](./OPERATIONAL_RUNBOOK.md) → Application Deployment

### Increase Capacity
See: [OPERATIONAL_RUNBOOK.md](./OPERATIONAL_RUNBOOK.md) → Scaling Operations

### Database Backup
See: [OPERATIONAL_RUNBOOK.md](./OPERATIONAL_RUNBOOK.md) → Database Operations

### Regional Failover
See: [DISASTER_RECOVERY.md](./DISASTER_RECOVERY.md) → Scenario 4

### Emergency Response
See: [OPERATIONAL_RUNBOOK.md](./OPERATIONAL_RUNBOOK.md) → Emergency Procedures

---

## Important Contacts

**Infrastructure Issues**:
- Email: infrastructure@example.com
- Slack: #infrastructure
- On-Call: PagerDuty (escalate for SEV-1/2)

**Escalation**:
- SEV-1 (Down): VP Engineering + On-Call Manager
- SEV-2 (Degraded): Engineering Leads + On-Call
- Critical: CEO + Legal + Customer Success

---

## Maintenance Schedule

| Task | Frequency | Owner | Reference |
|------|-----------|-------|-----------|
| DR Drill | Monthly | DevOps | DISASTER_RECOVERY.md |
| Security Audit | Quarterly | Security | PORTAL_INFRASTRUCTURE_as_CODE_v1.md |
| Cost Review | Semi-annual | Finance | COST_OPTIMIZATION.md |
| Provider Updates | Annually | DevOps | terraform/README.md |
| Certificate Renewal | 60 days before expiry | DevOps | OPERATIONAL_RUNBOOK.md |

---

## FAQ

**Q: How do I deploy to production?**
A: See [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) or [terraform/README.md](../terraform/README.md)

**Q: What's the monthly cost?**
A: $8,100/month (~$61,200/year optimized). See [COST_OPTIMIZATION.md](./COST_OPTIMIZATION.md)

**Q: What happens if a region fails?**
A: Manual failover to us-west-2 in < 4 hours. See [DISASTER_RECOVERY.md](./DISASTER_RECOVERY.md)

**Q: How do I scale up quickly?**
A: Auto-scaling or manual capacity increase in < 10 minutes. See [OPERATIONAL_RUNBOOK.md](./OPERATIONAL_RUNBOOK.md)

**Q: Is data encrypted?**
A: Yes, at rest (KMS) and in transit (TLS 1.2+). See [PORTAL_INFRASTRUCTURE_as_CODE_v1.md](./PORTAL_INFRASTRUCTURE_as_CODE_v1.md)

**Q: Where is state stored?**
A: S3 + DynamoDB (production recommended). See [BACKEND_SETUP.md](../terraform/environments/BACKEND_SETUP.md)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | May 2024 | Initial delivery - complete AWS infrastructure, multi-cloud structure |

---

**Last Updated**: May 2024
**Document**: INDEX.md
**Status**: ✅ Complete
