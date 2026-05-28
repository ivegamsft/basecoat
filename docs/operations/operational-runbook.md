# Operational Runbook

## Common Tasks & Procedures

### Table of Contents
- [Scaling Operations](#scaling-operations)
- [Database Operations](#database-operations)
- [Application Deployment](#application-deployment)
- [Monitoring & Debugging](#monitoring--debugging)
- [Maintenance Windows](#maintenance-windows)

---

## Scaling Operations

### 1. Increase Application Capacity (Production)

**Scenario**: Traffic spike detected, need to handle 3000 concurrent users

**Steps**:

```bash
# 1. Check current capacity
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names basecoat-portal-asg \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize,Instances[*].[InstanceId,LifecycleState]]'

# Output example:
# [3, 5, 20, [["i-001...", "InService"], ["i-002...", "InService"], ...]]

# 2. Set new desired capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name basecoat-portal-asg \
  --desired-capacity 12

# 3. Monitor scale-up progress
watch -n 30 'aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names basecoat-portal-asg \
  --query "AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState]" | grep -c InService'

# 4. Verify ALB target health
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:...:targetgroup/basecoat-portal/...

# 5. Monitor application metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average,Maximum

# Expected: Response time remains < 500ms with new capacity
```

**Success Criteria**:
- All new instances show "InService" in ALB
- Response time p99 < 500ms
- Error rate < 0.1%
- CPU utilization across fleet < 60%

### 2. Scale Down Application (Post-Traffic Spike)

```bash
# 1. Set reduced capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name basecoat-portal-asg \
  --desired-capacity 3

# 2. Monitor drain time (90 seconds max)
watch -n 10 'aws elbv2 describe-target-health \
  --target-group-arn ... | grep -c "Deregistering\|InService"'

# 3. Verify no dropped connections
# Check application logs for incomplete requests
aws logs tail /aws/basecoat-portal/application --follow --grep "ERROR"
```

### 3. Database Connection Scaling

**Scenario**: Database connection pool exhausted (> 800 connections)

```bash
# 1. Check connection usage
psql -h basecoat-portal-db.cxxx.us-east-1.rds.amazonaws.com \
  -U postgres -d basecoat_db \
  -c "SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;"

# 2. Increase RDS Proxy max connections
terraform apply -var-file=environments/prod/terraform.tfvars \
  -var='rds_proxy_max_connections=200'

# 3. Update application connection pool size
# Edit application config or Secrets Manager parameter
aws secretsmanager update-secret \
  --secret-id basecoat-portal/db/pool \
  --secret-string '{"pool_size":50,"max_overflow":20}'

# 4. Verify connection health
psql -h proxy-endpoint ... \
  -c "SELECT count(*) FROM pg_stat_activity WHERE state='active';"
```

---

## Database Operations

### 1. Create Manual Backup

```bash
# Create snapshot
aws rds create-db-snapshot \
  --db-instance-identifier basecoat-portal-db \
  --db-snapshot-identifier basecoat-backup-$(date +%Y%m%d-%H%M%S)

# Monitor snapshot creation
watch -n 30 'aws rds describe-db-snapshots \
  --db-snapshot-identifier basecoat-backup-... \
  --query "DBSnapshots[0].[PercentProgress,Status]"'

# Expected: 100% Complete
```

### 2. Point-in-Time Recovery

```bash
# List recovery points
aws rds describe-db-instances \
  --db-instance-identifier basecoat-portal-db \
  --query 'DBInstances[0].[LatestRestorableTime,AvailabilityZone]'

# Restore to specific point (e.g., 1 hour ago)
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier basecoat-portal-db \
  --target-db-instance-identifier basecoat-portal-db-restored \
  --restore-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --availability-zone us-east-1a

# Wait for restore (~10 minutes)
watch -n 30 'aws rds describe-db-instances \
  --db-instance-identifier basecoat-portal-db-restored \
  --query "DBInstances[0].DBInstanceStatus"'

# Test data
psql -h basecoat-portal-db-restored.cxxx.us-east-1.rds.amazonaws.com \
  -U postgres -d basecoat_db \
  -c "SELECT COUNT(*) FROM users; SELECT MAX(updated_at) FROM audit_log;"

# Rename for failover (after validation)
# aws rds modify-db-instance --db-instance-identifier basecoat-portal-db-restored \
#   --new-db-instance-identifier basecoat-portal-db
```

### 3. Database Parameter Tuning

```bash
# Create custom parameter group
aws rds create-db-parameter-group \
  --db-parameter-group-name basecoat-prod-params \
  --db-parameter-group-family postgres15 \
  --description "Production tuned parameters"

# Modify parameters
aws rds modify-db-parameter-group \
  --db-parameter-group-name basecoat-prod-params \
  --parameters "ParameterName=shared_buffers,ParameterValue={DBParameterGroupName=basecoat-prod-params,ApplyMethod=pending-reboot}"

# Apply to database
aws rds modify-db-instance \
  --db-instance-identifier basecoat-portal-db \
  --db-parameter-group-name basecoat-prod-params \
  --apply-immediately
```

### 4. Read Replica Promotion

```bash
# Promote read replica to standalone
aws rds promote-read-replica \
  --db-instance-identifier basecoat-portal-db-read-replica \
  --backup-retention-period 30

# Monitor promotion
watch -n 10 'aws rds describe-db-instances \
  --db-instance-identifier basecoat-portal-db-read-replica \
  --query "DBInstances[0].DBInstanceStatus"'

# After promotion, update application connection
aws secretsmanager update-secret \
  --secret-id basecoat-portal/db/endpoint \
  --secret-string "basecoat-portal-db-read-replica.cxxx.us-east-1.rds.amazonaws.com"
```

---

## Application Deployment

### 1. Blue/Green Deployment

```bash
# 1. Create new launch template version
aws ec2 create-launch-template-version \
  --launch-template-name basecoat-lt \
  --source-version \$Latest \
  --launch-template-data '{
    "ImageId":"ami-0c123456789abcdef",
    "UserData":"base64_encoded_script"
  }'

# Get new version number
NEW_VERSION=$(aws ec2 describe-launch-template-versions \
  --launch-template-name basecoat-lt \
  --query 'LaunchTemplateVersions[0].VersionNumber')

# 2. Create new ASG with new template (blue)
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name basecoat-portal-asg-blue \
  --launch-template LaunchTemplateName=basecoat-lt,Version=$NEW_VERSION \
  --min-size 3 \
  --max-size 20 \
  --desired-capacity 3 \
  --vpc-zone-identifier subnet-xxx,subnet-yyy,subnet-zzz

# 3. Wait for new instances to become healthy
watch -n 20 'aws elbv2 describe-target-health \
  --target-group-arn ... | grep -c InService'

# 4. Update load balancer to route to new ASG
aws elbv2 modify-target-group \
  --target-group-arn ... \
  --target-group-name basecoat-portal-blue

# 5. Verify traffic (monitor error rate)
watch -n 10 'aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --period 60 \
  --statistics Sum'

# 6. Delete old ASG (after 5-10 min monitoring)
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name basecoat-portal-asg \
  --force-delete
```

### 2. Canary Deployment (10% traffic)

```bash
# 1. Create new ASG with updated version
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name basecoat-portal-asg-canary \
  --launch-template LaunchTemplateName=basecoat-lt,Version=$NEW_VERSION \
  --desired-capacity 1

# 2. Register new instances with ALB target group at 10% weight
aws elbv2 register-targets \
  --target-group-arn ... \
  --targets Id=i-canary-instance-id,Port=80,Weight=10

# 3. Monitor canary metrics (1 hour)
watch -n 60 'aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --statistics Sum'

# Expected: Error rate same as existing traffic

# 4a. If successful: increase to 50%, then 100%
# 4b. If issues: drain and terminate canary ASG
aws autoscaling detach-instances \
  --auto-scaling-group-name basecoat-portal-asg-canary \
  --should-decrement-desired-capacity
```

### 3. Rollback Deployment

```bash
# 1. Identify previous working version
aws ec2 describe-launch-template-versions \
  --launch-template-name basecoat-lt \
  --query 'LaunchTemplateVersions[*].[VersionNumber,CreateTime]' \
  --sort-by create-time | head -5

# 2. Update ASG to use previous template
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name basecoat-portal-asg \
  --launch-template LaunchTemplateName=basecoat-lt,Version=2

# 3. Replace running instances
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name basecoat-portal-asg \
  --preferences '{"MinHealthyPercentage":50,"InstanceWarmup":300}'

# 4. Monitor instance refresh
watch -n 20 'aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-name basecoat-portal-asg \
  --query "InstanceRefreshes[0].[PercentageComplete,Status]"'
```

---

## Monitoring & Debugging

### 1. High CPU Alert Response

```bash
# 1. Identify affected instances
aws ec2 describe-instances \
  --filters "Name=tag:aws:autoscaling:groupName,Values=basecoat-portal-asg" \
  --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress,State.Name]'

# 2. Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum \
  --dimensions Name=AutoScalingGroupName,Value=basecoat-portal-asg

# 3. Check application logs
aws logs tail /aws/basecoat-portal/application --follow --since 30m | head -50

# 4. Options:
#   a) Scale up (covered in scaling section)
#   b) Investigate memory leak
#   c) Check for runaway queries
#   d) Deploy code fix
```

### 2. High Memory Usage (Database)

```bash
# 1. Connect to database
psql -h basecoat-portal-db.cxxx.us-east-1.rds.amazonaws.com \
  -U postgres -d basecoat_db

# 2. Check active queries
SELECT pid, query, query_start, wait_event FROM pg_stat_activity 
WHERE state = 'active' 
ORDER BY query_start DESC;

# 3. Kill long-running query (if needed)
SELECT pg_terminate_backend(pid) FROM pg_stat_activity 
WHERE query_start < now() - interval '1 hour' 
AND state = 'active';

# 4. Check table bloat
SELECT schemaname, tablename, 
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

# 5. Run ANALYZE to update statistics
ANALYZE;

# 6. Upgrade RDS instance class if needed
aws rds modify-db-instance \
  --db-instance-identifier basecoat-portal-db \
  --db-instance-class db.r6i.2xlarge \
  --apply-immediately
```

### 3. Cache Eviction Issues

```bash
# 1. Check ElastiCache metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name Evictions \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum \
  --dimensions Name=ReplicationGroupId,Value=basecoat-portal-cache

# 2. If evictions > 0, check memory usage
aws elasticache describe-replication-groups \
  --replication-group-id basecoat-portal-cache \
  --query 'ReplicationGroups[0].[CacheNodeType,AutomaticFailover,EngineVersion]'

# 3. Options:
#   a) Scale up node type
#   b) Add more nodes
#   c) Implement cache eviction policy
#   d) Optimize application cache usage

# 4. Scale up cache
aws elasticache modify-replication-group \
  --replication-group-id basecoat-portal-cache \
  --cache-node-type cache.r6g.xlarge \
  --apply-immediately
```

### 4. Database Connection Pool Exhaustion

```bash
# 1. Check connection count
psql -h basecoat-portal-db.cxxx.us-east-1.rds.amazonaws.com \
  -U postgres -d basecoat_db \
  -c "SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname ORDER BY count DESC;"

# 2. Identify connection hogs
SELECT application_name, client_addr, state, query_start, query 
FROM pg_stat_activity 
ORDER BY query_start DESC LIMIT 20;

# 3. Kill idle connections (if safe)
SELECT pg_terminate_backend(pid) FROM pg_stat_activity 
WHERE state = 'idle' 
AND query_start < now() - interval '30 minutes';

# 4. Increase connection pool
terraform apply -var-file=environments/prod/terraform.tfvars \
  -var='rds_proxy_max_connections=300'

# 5. Check RDS Proxy status
aws rds describe-db-proxies \
  --db-proxy-name basecoat-portal-proxy \
  --query 'DBProxies[0].[Status,MaxConnectionsPercent,SessionPinningFilters]'
```

---

## Maintenance Windows

### 1. Scheduled Database Maintenance

**Window**: Sunday 2-4 AM UTC

```bash
# 1. Update maintenance window
aws rds modify-db-instance \
  --db-instance-identifier basecoat-portal-db \
  --preferred-maintenance-window sun:02:00-sun:04:00

# 2. Notify stakeholders via status page
# 3. Monitor during window
aws rds describe-db-instances \
  --db-instance-identifier basecoat-portal-db \
  --query 'DBInstances[0].[DBInstanceStatus,PendingModifiedValues]'

# 4. After completion, verify
psql -h endpoint -U postgres -d basecoat_db -c "SELECT version();"
```

### 2. Certificate Renewal

```bash
# 1. Check certificate expiration
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:...:certificate/xxx

# 2. Request new certificate (if > 30 days remaining)
# Already managed by Terraform if using ACM

# 3. Update ALB listener
aws elbv2 modify-listener \
  --listener-arn arn:aws:elasticloadbalancing:... \
  --certificates CertificateArn=arn:aws:acm:...

# 4. Verify SSL handshake
openssl s_client -connect basecoat-portal.prod.example.com:443 -showcerts
```

### 3. Security Patch Application

```bash
# 1. Create new AMI with patches
# Build process outside this script
# Deploy new version using Blue/Green deployment (see section above)

# 2. Verify patches applied
aws ec2 describe-instances \
  --instance-ids i-xxx \
  --query 'Reservations[0].Instances[0].ImageId'

# 3. Check OS version
# SSH to instance and run: cat /etc/os-release
```

---

## Emergency Procedures

### SEV-1: Complete Service Down

```bash
# 1. Declare incident
# Notify: VP Eng, on-call manager, customer success

# 2. Assess what's down
curl -v https://basecoat-portal.prod.example.com/health
aws elbv2 describe-target-health --target-group-arn ...
aws rds describe-db-instances --db-instance-identifier ...

# 3. Check AWS status page
# https://phd.aws.amazon.com

# 4. If regional outage, initiate DR failover
# See: docs/DISASTER_RECOVERY.md - Scenario 4

# 5. If application code issue, rollback
# See: Application Deployment - Rollback section

# 6. Status updates every 15 minutes
# Update status page, notify stakeholders
```

### SEV-2: Data Inconsistency

```bash
# 1. Isolate database
# Stop application writes (temporarily)

# 2. Check replication lag
aws rds describe-db-instances \
  --db-instance-identifier basecoat-portal-db-read-replica \
  --query 'DBInstances[0].StatusInfos'

# 3. Take snapshot for forensics
aws rds create-db-snapshot \
  --db-instance-identifier basecoat-portal-db \
  --db-snapshot-identifier forensics-$(date +%s)

# 4. Query affected data
psql -h endpoint -U postgres -d basecoat_db \
  -c "SELECT * FROM audit_log WHERE action='DELETE' ORDER BY created_at DESC LIMIT 20;"

# 5. Restore from point-in-time backup
# See: Database Operations - Point-in-Time Recovery

# 6. Validate data consistency
# Compare record counts, checksums across replicas
```

---

**Last Updated**: May 2024
**Document Version**: 1.0
**Owner**: Infrastructure Team
