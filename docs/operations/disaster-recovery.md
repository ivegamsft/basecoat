# Disaster Recovery Procedures

## Overview

This document outlines the procedures for recovering Basecoat Portal infrastructure in case of regional failure or data loss. The target RTO (Recovery Time Objective) is 4 hours and RPO (Recovery Point Objective) is 1 hour.

## Failover Architecture

### Primary Region: us-east-1
- Production database (master)
- Primary application servers
- Primary cache cluster

### Secondary Region: us-west-2
- Read-only database replica
- Warm standby application servers
- Secondary cache cluster (synchronized)

### DNS & Routing

Route53 health checks monitor primary region:
- Primary endpoint: `basecoat-portal.prod.example.com` (us-east-1)
- Secondary endpoint: `basecoat-portal-dr.prod.example.com` (us-west-2)

**Failover Policy**: Manual promotion (requires ~15 minutes notice before automatic)

---

## Scenario 1: Database Failure (RTO: 30 minutes, RPO: 5 minutes)

### Detection

```bash
# Alert: RDS health check fails
# CloudWatch Alarm: "database-cpu-high" triggers
# Error logs show "connection timeout" to database
```

### Immediate Actions (0-5 min)

1. **Assess damage**:
   ```bash
   # Check RDS status
   aws rds describe-db-instances \
     --db-instance-identifier basecoat-portal-db \
     --region us-east-1
   
   # Check replication status
   aws rds describe-db-instances \
     --db-instance-identifier basecoat-portal-db-read-replica \
     --region us-west-2
   ```

2. **Page on-call DBA** (automated via CloudWatch)

3. **Notify stakeholders**:
   - Engineering leads
   - On-call incident commander
   - Customer support team

### Mitigation (5-10 min)

**If primary is recoverable** (temporary issue):
```bash
# Restart database
aws rds reboot-db-instance \
  --db-instance-identifier basecoat-portal-db \
  --region us-east-1 \
  --apply-immediately
```

**If primary is unrecoverable** (hardware failure):
```bash
# Promote read replica
aws rds promote-read-replica \
  --db-instance-identifier basecoat-portal-db-read-replica \
  --region us-west-2
```

### Recovery (10-30 min)

1. **Update connection strings**:
   ```bash
   # Application connects to new primary
   # Via AWS Secrets Manager (auto-rotated)
   aws secretsmanager get-secret-value \
     --secret-id basecoat-portal/db/password \
     --region us-west-2
   ```

2. **Verify data integrity**:
   ```bash
   # Check replication lag
   aws rds describe-db-instances \
     --region us-west-2 | jq '.DBInstances[0].StatusInfos'
   
   # Run sanity checks
   psql -h new-db-endpoint -U postgres -d basecoat_db \
     -c "SELECT COUNT(*) FROM users; SELECT MAX(updated_at) FROM logs;"
   ```

3. **Create new read replica** (if needed):
   ```bash
   # Restore read replica in secondary region
   aws rds create-db-instance-read-replica \
     --db-instance-identifier basecoat-portal-db-read-replica-2 \
     --source-db-instance-identifier basecoat-portal-db \
     --region us-east-1
   ```

4. **Update DNS** (if necessary):
   ```bash
   # If application uses Route53 alias
   aws route53 change-resource-record-sets \
     --hosted-zone-id Z123456 \
     --change-batch file://dns-update.json
   ```

### Verification (30 min)

```bash
# Smoke tests
curl -i https://basecoat-portal.prod.example.com/health
curl -i https://basecoat-portal.prod.example.com/api/users/1

# Database query performance check
time psql -h new-endpoint -U postgres -d basecoat_db \
  -c "SELECT * FROM users LIMIT 10000;"

# Application error rate check
# Via CloudWatch dashboard: HTTPCode_Target_5XX_Count should be 0
```

---

## Scenario 2: Application Server Failure (RTO: 5 minutes, RPO: 0)

### Detection

```bash
# Alert: ALB unhealthy target count > 0
# CloudWatch: TargetResponseTime > 10s
# Multiple 5XX errors in error logs
```

### Immediate Actions (0-2 min)

1. **ASG automatically replaces unhealthy instance** (built-in):
   - Health check grace period: 300 seconds
   - Unhealthy instance terminated
   - New instance launched

2. **Monitor replacement**:
   ```bash
   aws autoscaling describe-auto-scaling-groups \
     --auto-scaling-group-names basecoat-portal-asg \
     --region us-east-1 | jq '.AutoScalingGroups[0].Instances'
   ```

### Recovery (2-5 min)

1. **Verify new instance health**:
   ```bash
   # CloudWatch: TargetHealthDescription shows "healthy"
   aws elbv2 describe-target-health \
     --target-group-arn arn:aws:elasticloadbalancing:... \
     --region us-east-1
   ```

2. **Investigate root cause**:
   ```bash
   # Download system logs from failed instance
   aws ec2 get-console-output --instance-id i-xxxxx
   
   # Check application logs in CloudWatch
   aws logs tail /aws/basecoat-portal/application --follow
   ```

### Mitigation (if systemic failure)

```bash
# If all instances are failing, consider:
# 1. Deploy new AMI version
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name basecoat-portal-asg \
  --launch-template LaunchTemplateName=basecoat-portal-v2,Version=\$Latest

# 2. Increase desired capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name basecoat-portal-asg \
  --desired-capacity 10

# 3. Fail over to secondary region
# (Documented in Scenario 4)
```

---

## Scenario 3: Cache Failure (RTO: 10 minutes, RPO: 0)

### Detection

```bash
# Alert: Cache eviction rate > 0
# Application error: "redis: connection refused"
```

### Immediate Actions (0-3 min)

1. **Check cache replication group**:
   ```bash
   aws elasticache describe-replication-groups \
     --replication-group-id basecoat-portal-cache \
     --region us-east-1
   ```

2. **If single node failure**:
   ```bash
   # Automatic failover (enabled)
   # Monitor: ReplicationGroupDescription shows new primary
   ```

### Recovery (3-10 min)

1. **Verify failover**:
   ```bash
   aws elasticache describe-replication-groups \
     --replication-group-id basecoat-portal-cache | \
     jq '.ReplicationGroups[0].MemberClusters'
   ```

2. **Restore from snapshot** (if data loss):
   ```bash
   # Create snapshot
   aws elasticache create-snapshot \
     --replication-group-id basecoat-portal-cache \
     --snapshot-name basecoat-snapshot-$(date +%s)
   
   # Restore from snapshot
   aws elasticache restore-from-cluster-snapshot \
     --cache-cluster-id basecoat-cache-restore \
     --snapshot-name basecoat-snapshot-xxxxx
   ```

3. **Warm up cache**:
   ```bash
   # Pre-load frequently accessed data
   # Application-level logic or manual script
   python scripts/cache-warmup.py
   ```

---

## Scenario 4: Regional Failure (RTO: 4 hours, RPO: 1 hour)

### Detection

```
# Multiple services unavailable:
# - Database connection timeout
# - ALB returning 503 errors
# - AWS API calls returning region unavailable
```

### Phase 1: Assessment (0-15 min)

1. **Confirm region outage**:
   ```bash
   # Check AWS Health dashboard
   # https://phd.aws.amazon.com
   
   # Or test directly
   aws ec2 describe-instances --region us-east-1 2>&1 | head -20
   ```

2. **Verify secondary region is operational**:
   ```bash
   aws ec2 describe-instances --region us-west-2
   aws rds describe-db-instances --region us-west-2
   aws elasticache describe-replication-groups --region us-west-2
   ```

3. **Declare disaster** (Incident Commander):
   - Notify all on-call staff
   - Open war room / conference bridge
   - Start incident timeline

### Phase 2: Failover (15-120 min)

#### Step 1: Promote Secondary Database

```bash
# Promote read replica to standalone
aws rds promote-read-replica \
  --db-instance-identifier basecoat-portal-db-read-replica \
  --region us-west-2

# Wait for promotion to complete (5-10 min)
# Monitor status
watch -n 10 'aws rds describe-db-instances \
  --db-instance-identifier basecoat-portal-db-read-replica \
  --region us-west-2 | jq ".DBInstances[0].DBInstanceStatus"'
```

#### Step 2: Update Application Configuration

```bash
# Update environment variables in ASG launch template
aws ec2 create-launch-template-version \
  --launch-template-name basecoat-lt \
  --source-version \$Latest \
  --launch-template-data '{
    "UserData": "ZWNobyAiREJfSE9TVD1uZXctdXMtd2VzdC0yLWVuZHBvaW50IiA+IC9ldGMvZW52"
  }' \
  --region us-west-2
```

#### Step 3: Launch Secondary Application Stack

```bash
# Create new ASG in secondary region
terraform apply -var-file=environments/prod/terraform.tfvars \
  -var='aws_primary_region=us-west-2' \
  -var='compute_desired_capacity=5'

# Or use pre-provisioned ASG with desired_capacity=0
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name basecoat-portal-asg-dr \
  --desired-capacity 5 \
  --region us-west-2

# Wait for instances to become healthy (3-10 min)
```

#### Step 4: Update DNS Routing

```bash
# Update Route53 to point to secondary region
aws route53 change-resource-record-sets \
  --hosted-zone-id Z123456 \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "basecoat-portal.prod.example.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z1234US-WEST",
          "DNSName": "basecoat-alb-dr.us-west-2.elb.amazonaws.com",
          "EvaluateTargetHealth": false
        }
      }
    }]
  }'

# DNS propagation: 30 seconds - 5 minutes
```

#### Step 5: Verify Failover

```bash
# Test connectivity
curl -i https://basecoat-portal.prod.example.com/health

# Check response time
time curl https://basecoat-portal.prod.example.com/api/users

# Monitor application metrics
aws cloudwatch get-metric-statistics \
  --namespace "AWS/ApplicationELB" \
  --metric-name HTTPCode_Target_5XX_Count \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

### Phase 3: Stabilization (120-180 min)

1. **Monitor error rates**:
   - Target 5XX rate < 0.1%
   - Latency p99 < 2 seconds
   - Cache hit rate > 80%

2. **Verify data consistency**:
   ```bash
   # Check recent data
   psql -h new-primary -U postgres -d basecoat_db \
     -c "SELECT COUNT(*) as user_count FROM users WHERE created_at > now() - interval '1 hour';"
   
   # Compare with expected values
   ```

3. **Restore degraded services**:
   - Background jobs (async workers)
   - Real-time notifications
   - Batch processes

### Phase 4: Communication

**T+0min**: Incident declared
- Notify status page: "Investigating"

**T+30min**: Failover initiated
- Update status page: "Performing maintenance"

**T+120min**: Failover complete
- Update status page: "Operational (secondary region)"

**T+240min**: Primary region recovered
- Begin data sync back to primary
- Update status page: "Recovering"

**T+360min**: Return to primary (or keep on secondary)
- Flip DNS back to primary (if recovered)
- Update status page: "Recovered"

---

## Scenario 5: Data Loss / Corruption (RTO: 4-24 hours, RPO: 1 hour)

### Examples

- Accidental deletion of critical tables
- Data corruption from buggy deployment
- Security breach with malicious data modification

### Recovery Steps

1. **Immediate**: Isolate affected database
   ```bash
   # Stop application access
   # Create snapshot for forensics
   aws rds create-db-snapshot \
     --db-instance-identifier basecoat-portal-db \
     --db-snapshot-identifier basecoat-forensics-$(date +%s)
   ```

2. **Restore from point-in-time backup**:
   ```bash
   # RDS automatic backups go back 35 days
   # Find last good backup time
   aws rds describe-db-instances \
     --db-instance-identifier basecoat-portal-db | \
     jq '.DBInstances[0].LatestRestorableTime'
   
   # Restore to point 1 hour ago
   aws rds restore-db-instance-to-point-in-time \
     --source-db-instance-identifier basecoat-portal-db \
     --target-db-instance-identifier basecoat-portal-db-restored \
     --restore-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
     --region us-east-1
   ```

3. **Verify restored data**:
   ```bash
   # Connect to restored database
   psql -h basecoat-portal-db-restored.cxxx.us-east-1.rds.amazonaws.com \
     -U postgres -d basecoat_db
   
   # Run queries to verify
   SELECT COUNT(*) FROM users;
   SELECT * FROM audit_log WHERE action='DELETE' ORDER BY created_at DESC LIMIT 10;
   ```

4. **Failover to restored database**:
   ```bash
   # Update application to connect to restored DB
   # Update Secrets Manager endpoint
   
   # Rename original to backup, restored to primary
   # aws rds modify-db-instance for endpoint update
   ```

5. **Post-incident review**:
   - Root cause analysis
   - Update backup procedures
   - Implement additional safeguards (e.g., deletion protection)

---

## Testing & Validation

### Monthly Failover Drill

**Schedule**: First Monday of month, 2 AM UTC

**Procedure**:
1. Promote secondary database replica
2. Launch secondary region ASG
3. Update DNS to secondary
4. Run smoke tests
5. Revert to primary

**Success Criteria**:
- Failover completes within 60 minutes
- All smoke tests pass
- Error rate < 0.5% during transition
- RTO < 4 hours verified

**Post-drill**:
- Document any issues
- Update runbook
- Share findings with team

### Quarterly Full DR Test

**Scope**: Simulate complete primary region failure

**Duration**: 4 hours

**Participants**: Full incident response team

**Outcomes**: Updated RTO/RPO estimates

---

## Escalation Path

| Issue | Severity | Escalation |
|-------|----------|-----------|
| Single unhealthy host | P3 | On-call engineer |
| Multiple service errors | P2 | On-call manager + engineering leads |
| Regional outage | P1 | VP Engineering + Incident Commander + all on-call |
| Data loss confirmed | Critical | CEO + Legal + Customer Success |

---

**Last Updated**: May 2024
**Version**: 1.0
**Next Review**: November 2024
