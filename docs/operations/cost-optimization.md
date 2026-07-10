# Cost Estimation & Optimization

## Detailed Cost Breakdown by Component

### 1. Database Layer

**Production (db.r6i.xlarge + read replica)**:
- RDS Multi-AZ Primary: $1,800/month
- RDS Read Replica (db.r6i.large): $900/month
- Storage (200GB @ $0.23/GB): $46/month
- Backup Storage (30-day retention): $100/month
- **Total Database**: $2,846/month

**Staging (db.t3.small)**:
- RDS Primary: $150/month
- Read Replica: $100/month
- Storage: $15/month
- Backup: $20/month
- **Total**: $285/month

**Development (db.t3.micro)**:
- RDS Primary: $30/month
- Storage: $5/month
- Backup: $5/month
- **Total**: $40/month

### 2. Compute Layer

**Production**:
- On-Demand (3 @ t3.large): $900/month
- Spot Instances (2 @ t3.large, 70% discount): $270/month
- Data Transfer (Out): $500/month
- ALB: $300/month
- **Total**: $1,970/month

**Staging**:
- On-Demand (1 @ t3.medium): $200/month
- Spot (1 @ t3.medium): $30/month
- Data Transfer: $50/month
- ALB: $300/month
- **Total**: $580/month

**Development**:
- On-Demand (1 @ t3.small): $20/month
- Data Transfer: $10/month
- ALB: $300/month
- **Total**: $330/month

### 3. Caching Layer

**Production (cache.r6g.xlarge, 3 nodes)**:
- Node cost: $0.658/hour × 3 × 730 = $1,443/month
- Reserved Instance 1-year: $960/month (-33%)
- **Effective**: $960/month

**Staging (cache.t3.small, 2 nodes)**:
- Cost: $0.054/hour × 2 × 730 = $79/month

**Development (cache.t3.micro, 1 node)**:
- Cost: $0.015/hour × 1 × 730 = $11/month

### 4. Storage Layer

**Production**:
- S3 Storage: $300/month
- Cross-region replication: $200/month
- **Total**: $500/month

**Staging**:
- S3 Storage: $50/month

**Development**:
- S3 Storage: $5/month

### 5. Networking & Security

**Production**:
- NAT Gateway: $45/month × 2 = $90/month
- VPC Flow Logs: $20/month
- WAF: $150/month
- **Total**: $260/month

**Staging**:
- NAT Gateway: $45/month
- VPC Flow Logs: $10/month
- WAF: $150/month
- **Total**: $205/month

**Development**:
- NAT Gateway: $45/month
- **Total**: $45/month

### 6. Monitoring & Logging

**Production**:
- CloudWatch (logs, metrics, dashboards): $50/month
- Custom metrics: $5/month
- **Total**: $55/month

**Staging**: $30/month
**Development**: $10/month

## Monthly Cost Summary

| Environment | Database | Compute | Cache | Storage | Network | Monitoring | **Total** |
|-------------|----------|---------|-------|---------|---------|-----------|----------|
| Development | $40 | $330 | $11 | $5 | $45 | $10 | **$441** |
| Staging | $285 | $580 | $79 | $50 | $205 | $30 | **$1,229** |
| Production | $2,846 | $1,970 | $960 | $500 | $260 | $55 | **$6,591** |
| **Total (All)** | **$3,171** | **$2,880** | **$1,050** | **$555** | **$510** | **$95** | **$8,261** |

## Cost Optimization Strategies

### 1. Reserved Instances (20-50% savings)

```bash
# Calculate optimal mix
# Production baseline: 3 on-demand + 2 spot
# Year 1 Cost without RI: $23,640
# Year 1 Cost with 1-yr RI (3 instances): $15,700
# Savings: $7,940 (33%)
```

### 2. Spot Instances (70% discount)

Current configuration uses:
- 70% Spot instances for non-critical workloads
- 30% On-Demand for baseline reliability
- 2-3 Spot pools to tolerate interruptions
- **Annual Savings**: ~$17,000

### 3. Storage Lifecycle Policies

```hcl
# Transition to cheaper storage classes
0-30 days: STANDARD ($0.023/GB)
30-60 days: STANDARD-IA ($0.0125/GB) → -46% cost
60+ days: GLACIER ($0.004/GB) → -83% cost
180+ days: EXPIRATION → -100% cost

# For 100GB dataset:
# STANDARD (30 days): $2.30
# STANDARD-IA (30 days): $1.24
# GLACIER (120 days): $0.48
# **Monthly average**: $0.67 (vs $2.30) → 70% savings
```

### 4. Right-Sizing Recommendations

**Current Production**: db.r6i.xlarge (32 vCPU, 256GB)
- If CPU utilization < 20% and memory < 30%, downgrade to db.r6i.large (8 vCPU, 64GB)
- Monthly savings: $900/month

**Recommendation**: Monitor for 2 weeks, then rightsize if utilization permits

### 5. Data Transfer Optimization

**Current**: ~$500/month (mostly outbound)
- Use CloudFront CDN for static content (-$200/month)
- Implement VPC endpoints for S3 access (-$50/month)
- **Potential Savings**: $250/month

## Cost Monitoring & Alerts

### AWS Budgets

```bash
# Create budget alert
aws budgets create-budget \
  --budget '{ 
    "BudgetName": "Basecoat-Portal-Monthly",
    "BudgetLimit": { "Amount": "7000", "Unit": "USD" },
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }'
```

### Cost Anomaly Detection

Enable AWS Cost Anomaly Detection:
- Monitors daily costs
- Alerts on 10%+ variance
- Machine learning-based baseline

### Monthly Review Process

1. **Week 1**: Generate cost report from AWS Cost Explorer
2. **Week 2**: Review by Finance & Engineering leads
3. **Week 3**: Implement optimizations
4. **Week 4**: Validate and update budget

## Projected Savings (12-month horizon)

| Strategy | Effort | Savings |
|----------|--------|---------|
| Reserve 3 prod instances (1-yr) | Low | $7,940 |
| Storage lifecycle policies | Low | $600/month × 12 = $7,200 |
| CDN for static content | Medium | $2,400 |
| Database right-sizing | Medium | $10,800 |
| Compute consolidation | High | $5,000 |
| **Total Potential Savings** | - | **~$33,340** |

**Current 12-month cost**: $99,132
**Optimized cost**: $65,792
**Savings**: 34%
