# Basecoat Portal Staging - Pre/Post Deployment Checklist

## Pre-Deployment Verification Checklist

### Phase 1: AWS Account & Access (30 minutes before)

- [ ] AWS Account ID confirmed: _______________
- [ ] IAM user has permissions:
  - [ ] EC2 full access
  - [ ] RDS full access
  - [ ] ElastiCache full access
  - [ ] VPC full access
  - [ ] S3 full access (for state)
  - [ ] DynamoDB full access (for locks)
  - [ ] CloudWatch full access
  - [ ] IAM role creation permissions
  - [ ] Secrets Manager access
- [ ] AWS CLI configured: \ws sts get-caller-identity\ returns correct account
- [ ] AWS CLI default region set to us-east-1
- [ ] AWS credentials are NOT expired
- [ ] MFA enabled (if required by policy)

### Phase 2: Infrastructure Prerequisites (45 minutes before)

- [ ] S3 bucket created: basecoat-terraform-state-staging
  - [ ] Versioning enabled
  - [ ] Public access blocked
  - [ ] Encryption enabled
  - [ ] Tagging applied
- [ ] DynamoDB table created: basecoat-terraform-locks-staging
  - [ ] LockID attribute configured
  - [ ] Throughput provisioned (5 RCU, 5 WCU minimum)
  - [ ] Tagging applied
- [ ] CloudWatch log group created (optional): /aws/terraform/basecoat-portal

### Phase 3: Terraform Configuration (30 minutes before)

- [ ] Terraform version >= 1.5.0
  - Command: \	erraform version\
- [ ] AWS provider version ~> 5.0
  - Verify in versions.tf
- [ ] Backend configuration file created: terraform/backend-staging.tf
  - S3 bucket name correct
  - DynamoDB table name correct
  - Region set to us-east-1
  - Encryption enabled
- [ ] Terraform initialized with backend
  - [ ] \cd terraform && terraform init -backend-config=backend-staging.tf\
  - [ ] Verify output: \"Successfully configured the backend\"
  - [ ] State file exists in S3
- [ ] Terraform validated
  - [ ] \	erraform validate\ returns \"Success! The configuration is valid.\"

### Phase 4: Variable Review (20 minutes before)

Review \	erraform/environments/staging/terraform.tfvars\:

| Variable | Expected Value | Verified |
|----------|-----------------|----------|
| project_name | basecoat-portal | ☐ |
| environment | staging | ☐ |
| aws_primary_region | us-east-1 | ☐ |
| vpc_cidr | 10.0.0.0/16 | ☐ |
| database_instance_class | db.t3.small | ☐ |
| database_allocated_storage | 50 | ☐ |
| cache_instance_type | cache.t3.small | ☐ |
| enable_encryption_at_rest | true | ☐ |
| enable_monitoring | true | ☐ |

- [ ] All variables are appropriate for staging
- [ ] No production variables accidentally used
- [ ] Database password complexity adequate (generated automatically)
- [ ] Tags include owner information
- [ ] Cost tags correct for chargeback

### Phase 5: Security Review (15 minutes before)

- [ ] Security groups reviewed:
  - [ ] ALB: Only 80/443 from 0.0.0.0/0
  - [ ] App: Only from ALB SG + database/cache SG
  - [ ] Database: Only from app tier
  - [ ] Cache: Only from app tier
- [ ] Network ACLs reviewed (should be default permissive)
- [ ] VPC Flow Logs enabled for monitoring
- [ ] Encryption at rest enabled for RDS and ElastiCache
- [ ] Secrets Manager configured for password storage
- [ ] IAM roles follow least-privilege principle
- [ ] No hardcoded credentials in any files

### Phase 6: Backup & Recovery (10 minutes before)

- [ ] Current Terraform state backed up locally
  - Command: \	erraform state pull > state-backup-.json\
  - File saved: _______________
- [ ] Previous state versions accessible in S3
  - Verify: \ws s3api list-object-versions --bucket basecoat-terraform-state-staging\
- [ ] Rollback procedure documented
- [ ] Emergency contacts available
  - AWS Support: _______________
  - Infrastructure Lead: _______________
  - On-Call Engineer: _______________

### Phase 7: Team Notification (5 minutes before)

- [ ] Infrastructure team notified of deployment
- [ ] Deployment window communicated
- [ ] Expected downtime (if any): None (new environment)
- [ ] Backup plan acknowledged
- [ ] Rollback authority identified: _______________
- [ ] Post-deployment validation assigned to: _______________

### Phase 8: Final Sign-Off (Immediately before)

- [ ] All above checklist items completed ✓
- [ ] \	erraform plan\ output reviewed and approved
- [ ] Estimated resource count verified (45+ resources)
- [ ] Estimated cost acceptable: -315/month
- [ ] Resource names follow naming conventions
- [ ] Tags applied consistently
- [ ] No conflicts with existing infrastructure
- [ ] Deployment approved by: _______________ (Signature/Email)
- [ ] Deployment date/time: _______________
- [ ] Deployment operator: _______________

---

## Deployment Execution Checklist

### Step 1: Initialize Backend (Time: 0:00)

- [ ] Change directory: \cd terraform\
- [ ] Run init with backend config:
  \\\ash
  terraform init -backend-config=backend-staging.tf
  \\\
- [ ] Verify output mentions S3 backend
- [ ] Confirm \"Terraform has been successfully initialized\"
- [ ] Check S3 for state file: \ws s3 ls s3://basecoat-terraform-state-staging/\

**Completion Time**: 0:05
**Status**: ☐ Complete

### Step 2: Generate Plan (Time: 0:05)

- [ ] Generate Terraform plan:
  \\\ash
  terraform plan \
    -var-file=environments/staging/terraform.tfvars \
    -out=staging.tfplan
  \\\
- [ ] Review plan output for errors
- [ ] Count resources to create (should be ~45)
- [ ] Verify all major components included:
  - [ ] VPC
  - [ ] Subnets (2 public, 4 private)
  - [ ] Route tables & associations
  - [ ] Security groups (4 main + IAM roles)
  - [ ] RDS instance + parameter group + proxy
  - [ ] ElastiCache cluster + parameter group
  - [ ] ALB (if compute module includes)
  - [ ] CloudWatch resources
  - [ ] IAM resources
- [ ] Save plan file for recovery: \cp staging.tfplan staging.tfplan.backup\

**Completion Time**: 0:10
**Status**: ☐ Complete

### Step 3: Review & Approve Plan (Time: 0:10)

- [ ] Plan reviewed by: _______________
- [ ] Approver role: _______________
- [ ] Plan approved at: _______________
- [ ] Any issues found: 
  - Yes ☐ (describe): _____________________
  - No ☐
- [ ] If issues, remediation plan: _____________________
- [ ] Approval timestamp: _______________

**Completion Time**: 0:15
**Status**: ☐ Complete

### Step 4: Apply Terraform Configuration (Time: 0:15)

⚠️ **POINT OF NO RETURN**: Resources will be created

- [ ] Execute apply:
  \\\ash
  terraform apply staging.tfplan
  \\\
- [ ] Monitor output for errors
- [ ] Record start time: _______________
- [ ] Track progress:
  - [ ] VPC creation: ~1-2 min
  - [ ] Subnets & routing: ~1-2 min
  - [ ] RDS creation: ~5-8 min (Multi-AZ)
  - [ ] ElastiCache: ~3-5 min
  - [ ] Security groups: ~1-2 min
  - [ ] ALB: ~2-3 min (if included)
  - [ ] Monitoring: ~1-2 min
- [ ] Record end time: _______________
- [ ] Total deployment time: ___________ minutes
- [ ] Any warnings or errors noted: _____________________

**Expected Completion Time**: 0:35 (20 minutes deployment)
**Status**: ☐ Complete

### Step 5: Export Outputs (Time: 0:35)

- [ ] Export infrastructure outputs:
  \\\ash
  terraform output -json > staging-infrastructure-outputs.json
  \\\
- [ ] Save outputs to shared location
- [ ] Key outputs extracted:
  - [ ] VPC ID: _______________
  - [ ] Database endpoint: _______________
  - [ ] Cache endpoint: _______________
  - [ ] ALB DNS: _______________
- [ ] Outputs shared with team: ☐ Yes ☐ No
- [ ] Connection strings generated: ☐ Yes ☐ No

**Completion Time**: 0:40
**Status**: ☐ Complete

---

## Post-Deployment Verification Checklist

### Phase 1: Resource Verification (15 minutes)

#### VPC & Networking

- [ ] VPC created:
  \\\ash
  aws ec2 describe-vpcs --filters Name=tag:Environment,Values=staging
  \\\
  - [ ] VPC ID: _______________
  - [ ] CIDR: 10.0.0.0/16 ✓
  - [ ] DNS hostnames enabled ✓
  - [ ] DNS support enabled ✓

- [ ] Subnets created (4 total):
  \\\ash
  aws ec2 describe-subnets \
    --filters Name=vpc-id,Values=vpc-XXXXXXXXXXXX
  \\\
  - [ ] Public Subnet 1 (AZ1): 10.0.10.0/24 ✓
  - [ ] Public Subnet 2 (AZ2): 10.0.11.0/24 ✓
  - [ ] Private Subnet 1 (AZ1): 10.0.1.0/24 ✓
  - [ ] Private Subnet 2 (AZ2): 10.0.2.0/24 ✓

- [ ] Internet Gateway created:
  \\\ash
  aws ec2 describe-internet-gateways \
    --filters Name=tag:Environment,Values=staging
  \\\
  - [ ] Attached to VPC ✓
  - [ ] IGW ID: _______________

- [ ] NAT Gateways created (2):
  \\\ash
  aws ec2 describe-nat-gateways \
    --filters Name=tag:Environment,Values=staging
  \\\
  - [ ] NAT Gateway 1 (AZ1): Available ✓
  - [ ] NAT Gateway 2 (AZ2): Available ✓
  - [ ] Elastic IPs allocated (2) ✓

- [ ] Route Tables created (3):
  \\\ash
  aws ec2 describe-route-tables \
    --filters Name=vpc-id,Values=vpc-XXXXXXXXXXXX
  \\\
  - [ ] Public route table (0.0.0.0/0 → IGW) ✓
  - [ ] Private route table AZ1 (0.0.0.0/0 → NAT1) ✓
  - [ ] Private route table AZ2 (0.0.0.0/0 → NAT2) ✓

- [ ] Flow Logs configured:
  \\\ash
  aws ec2 describe-flow-logs \
    --filters Name=resource-id,Values=vpc-XXXXXXXXXXXX
  \\\
  - [ ] Flow Logs enabled ✓
  - [ ] CloudWatch Logs destination ✓
  - [ ] 7-day retention ✓

#### Security Groups

- [ ] Security groups created (4 main):
  \\\ash
  aws ec2 describe-security-groups \
    --filters Name=tag:Environment,Values=staging
  \\\
  - [ ] ALB Security Group ✓
  - [ ] Application Security Group ✓
  - [ ] Database Security Group ✓
  - [ ] Cache Security Group ✓

- [ ] ALB SG rules verified:
  - [ ] Inbound: 0.0.0.0/0:80 ✓
  - [ ] Inbound: 0.0.0.0/0:443 ✓
  - [ ] Outbound: To App SG ✓

- [ ] App SG rules verified:
  - [ ] Inbound: From ALB SG:80/443 ✓
  - [ ] Inbound: From DB SG:5432 (reply) ✓
  - [ ] Inbound: From Cache SG:6379 (reply) ✓
  - [ ] Outbound: To DB SG:5432 ✓
  - [ ] Outbound: To Cache SG:6379 ✓
  - [ ] Outbound: 0.0.0.0/0:443 (HTTPS) ✓

- [ ] DB SG rules verified:
  - [ ] Inbound: From App SG:5432 ✓
  - [ ] No outbound required ✓

- [ ] Cache SG rules verified:
  - [ ] Inbound: From App SG:6379 ✓
  - [ ] No outbound required ✓

#### Database (RDS)

- [ ] RDS instance created:
  \\\ash
  aws rds describe-db-instances \
    --db-instance-identifier basecoat-portal-db
  \\\
  - [ ] Engine: PostgreSQL 15.3 ✓
  - [ ] Instance Class: db.t3.small ✓
  - [ ] Storage: 50 GB ✓
  - [ ] Multi-AZ: Enabled ✓
  - [ ] Publicly Accessible: False ✓
  - [ ] Status: Available ✓

- [ ] RDS Endpoint: _______________

- [ ] Backup configuration verified:
  - [ ] Automated backups: 14 days ✓
  - [ ] Backup window: 03:00-04:00 ✓
  - [ ] Backup retention: Available ✓

- [ ] Read replica created (if enabled):
  - [ ] Replica instance: basecoat-portal-db-read-replica ✓
  - [ ] Status: Available ✓

- [ ] RDS Proxy created:
  - [ ] Proxy name: basecoat-portal-proxy ✓
  - [ ] Engine family: POSTGRESQL ✓
  - [ ] Status: Available ✓

- [ ] Secrets Manager secret created:
  - [ ] Secret name: basecoat-portal/db/password ✓
  - [ ] Retrieved successfully ✓

#### Cache Layer (ElastiCache)

- [ ] ElastiCache cluster created:
  \\\ash
  aws elasticache describe-replication-groups \
    --replication-group-id basecoat-portal-redis
  \\\
  - [ ] Engine: Redis 7.0 ✓
  - [ ] Node Type: cache.t3.small ✓
  - [ ] Number of Nodes: 2 ✓
  - [ ] Multi-AZ: Enabled ✓
  - [ ] Automatic Failover: Enabled ✓
  - [ ] Status: Available ✓

- [ ] Cache endpoint (primary): _______________
- [ ] Cache endpoint (reader): _______________

- [ ] Parameter group created:
  - [ ] Family: redis7 ✓
  - [ ] Parameters configured ✓

- [ ] Encryption configured:
  - [ ] At-rest encryption: Enabled ✓
  - [ ] Transit encryption: Enabled ✓
  - [ ] Auth token generated ✓

- [ ] Snapshots configured:
  - [ ] Retention limit: 5 ✓
  - [ ] Snapshot window: 03:00-05:00 ✓

#### Monitoring & Logging

- [ ] CloudWatch Log Groups created:
  - [ ] /aws/vpc/flow-logs/basecoat-portal ✓
  - [ ] /aws/rds/postgres/... ✓
  - [ ] /aws/elasticache/basecoat-portal/slow-log ✓
  - [ ] /aws/elasticache/basecoat-portal/engine-log ✓

- [ ] CloudWatch Dashboards created:
  - [ ] basecoat-portal-rds-dashboard ✓
  - [ ] basecoat-portal-redis-dashboard ✓
  - [ ] basecoat-portal-alb-dashboard ✓
  - [ ] basecoat-portal-network-dashboard ✓

- [ ] CloudWatch Alarms created (if monitoring enabled):
  - [ ] RDS CPU >80% ✓
  - [ ] Cache Memory >80% ✓
  - [ ] ALB Error Rate >1% ✓
  - [ ] Database Connections >40 ✓

- [ ] SNS Topics created:
  - [ ] basecoat-portal-elasticache-notifications ✓

#### IAM Roles

- [ ] VPC Flow Logs IAM role created:
  - [ ] Role name: basecoat-portal-vpc-flow-logs-role ✓
  - [ ] Permissions to CloudWatch Logs ✓

- [ ] RDS Proxy IAM role created:
  - [ ] Role name: basecoat-portal-db-proxy-role ✓
  - [ ] Permissions to Secrets Manager ✓

**Completion Time**: Phase 1 (15 minutes)
**Status**: ☐ Complete

### Phase 2: Connectivity & Functionality Testing (20 minutes)

#### Database Connectivity

- [ ] Database endpoint is resolvable:
  \\\ash
  nslookup basecoat-portal-db.XXXXXXXXXXXX.us-east-1.rds.amazonaws.com
  \\\
  - [ ] Returns valid IP address ✓

- [ ] Database accessible from application tier:
  - [ ] Launch test EC2 in private subnet
  - [ ] \psql -h <RDS_ENDPOINT> -U postgres -d postgres\
  - [ ] Result: ☐ Connected ☐ Failed (issue: _______________)

- [ ] Database NOT accessible from internet:
  - [ ] Test from public network (if possible)
  - [ ] Result: ☐ Connection refused (expected) ☐ Connected (issue!)

#### Cache Connectivity

- [ ] Cache endpoint is resolvable:
  \\\ash
  nslookup basecoat-portal-redis.XXXXXXXXXXXX.ng.0001.use1.cache.amazonaws.com
  \\\
  - [ ] Returns valid IP address ✓

- [ ] Cache accessible from application tier:
  - [ ] Launch test EC2 in private subnet
  - [ ] \edis-cli -h <CACHE_ENDPOINT> -p 6379 PING\
  - [ ] Result: ☐ PONG ☐ Failed (issue: _______________)

- [ ] Cache NOT accessible from internet:
  - [ ] Test from public network (if possible)
  - [ ] Result: ☐ Connection refused (expected) ☐ Connected (issue!)

#### Monitoring & Metrics

- [ ] CloudWatch dashboards display data:
  - [ ] RDS metrics visible (CPU, memory, connections) ✓
  - [ ] Cache metrics visible (CPU, memory) ✓
  - [ ] ALB metrics visible (if ALB deployed) ✓
  - [ ] Network metrics visible ✓

- [ ] VPC Flow Logs recording:
  - [ ] \ws logs tail /aws/vpc/flow-logs/basecoat-portal --follow\
  - [ ] Logs appearing ✓

- [ ] SNS topics ready for alerts:
  - [ ] \ws sns list-subscriptions-by-topic --topic-arn <ARN>\
  - [ ] Ready for subscription ✓

**Completion Time**: Phase 2 (20 minutes)
**Status**: ☐ Complete

### Phase 3: Security & Compliance Validation (10 minutes)

- [ ] No resources publicly accessible:
  \\\ash
  aws ec2 describe-network-interfaces \
    --filters Name=association.public-ip,Values=* \
    --query 'NetworkInterfaces[?Attachment.InstanceOwnerId!=\mazon\]'
  \\\
  - [ ] Only ALB in public subnets (expected) ✓

- [ ] RDS not publicly accessible:
  \\\ash
  aws rds describe-db-instances \
    --db-instance-identifier basecoat-portal-db \
    --query 'DBInstances[0].PubliclyAccessible'
  \\\
  - [ ] Returns: false ✓

- [ ] ElastiCache not publicly accessible:
  - [ ] No public endpoint ✓

- [ ] Security groups restricting traffic properly:
  - [ ] ALB accepts public traffic only on 80/443 ✓
  - [ ] App accepts traffic only from ALB, DB, Cache ✓
  - [ ] DB accepts traffic only from App tier ✓
  - [ ] Cache accepts traffic only from App tier ✓

- [ ] Encryption validated:
  - [ ] RDS storage encrypted ✓
  - [ ] ElastiCache storage encrypted ✓
  - [ ] ElastiCache transit encryption enabled ✓
  - [ ] Secrets Manager encrypting passwords ✓

- [ ] IAM roles follow least privilege:
  - [ ] VPC Flow Logs role: Only CloudWatch Logs permissions ✓
  - [ ] RDS Proxy role: Only Secrets Manager access ✓

- [ ] Network isolation verified:
  - [ ] Database in private subnets only ✓
  - [ ] Cache in private subnets only ✓
  - [ ] NAT gateways for outbound from private tier ✓

**Completion Time**: Phase 3 (10 minutes)
**Status**: ☐ Complete

### Phase 4: Final Documentation & Handoff (10 minutes)

- [ ] Deployment summary created:
  - [ ] Resource count verified (45+) ✓
  - [ ] Cost estimate calculated (-315/month) ✓
  - [ ] Deployment time recorded (___ minutes) ✓

- [ ] Terraform state backed up:
  - [ ] Local backup: \	erraform state pull > state-backup-FINAL.json\ ✓
  - [ ] S3 versioning verified ✓

- [ ] Connection strings generated and shared:
  - [ ] Database: _______________
  - [ ] Cache: _______________
  - [ ] ALB: _______________

- [ ] Infrastructure outputs documented:
  - [ ] staging-infrastructure-outputs.json created ✓
  - [ ] Shared with team ✓

- [ ] Team notifications sent:
  - [ ] Infrastructure team notified ✓
  - [ ] Application team provided connection strings ✓
  - [ ] Operations team updated with monitoring links ✓

- [ ] Post-deployment follow-up scheduled:
  - [ ] 24-hour health check scheduled ✓
  - [ ] 7-day capacity review scheduled ✓
  - [ ] 30-day cost audit scheduled ✓

**Completion Time**: Phase 4 (10 minutes)
**Status**: ☐ Complete

---

## Deployment Sign-Off

### Deployment Details

- **Deployment Date**: _______________
- **Deployment Time Started**: _______________
- **Deployment Time Ended**: _______________
- **Total Duration**: ___________ minutes
- **Deployed By**: _______________
- **Approved By**: _______________
- **Witnessed By**: _______________

### Environment Details

- **AWS Account ID**: _______________
- **Region**: us-east-1
- **Environment**: Staging
- **Infrastructure Code Version**: _______________

### Resource Counts

- **Total Resources Created**: ___ (expected: 45+)
- **VPC Resources**: ___ (expected: 8+)
- **Database Resources**: ___ (expected: 8+)
- **Cache Resources**: ___ (expected: 6+)
- **Monitoring Resources**: ___ (expected: 8+)
- **Security/IAM Resources**: ___ (expected: 6+)

### Issues & Resolutions

**Any issues encountered?**: ☐ Yes ☐ No

If yes, describe:
1. Issue: _____________________
   Resolution: _____________________
   Status: ☐ Resolved ☐ Ongoing

2. Issue: _____________________
   Resolution: _____________________
   Status: ☐ Resolved ☐ Ongoing

### Post-Deployment Status

- [ ] All resources created successfully
- [ ] All connectivity tests passed
- [ ] Security validation completed
- [ ] Monitoring and alerts configured
- [ ] Documentation complete
- [ ] Team handoff completed
- [ ] No critical issues remaining

**DEPLOYMENT STATUS**: ☐ ✅ SUCCESSFUL ☐ ⚠️ PARTIAL ☐ ❌ FAILED

---

## Rollback Procedures (If Needed)

If deployment fails or issues are discovered:

### Immediate Rollback

\\\ash
# Destroy all resources
terraform destroy \
  -var-file=environments/staging/terraform.tfvars

# Answer \"yes\" to confirm destruction
\\\

- [ ] Rollback initiated at: _______________
- [ ] Rollback completed at: _______________
- [ ] Duration: ___________ minutes
- [ ] All resources destroyed: ☐ Yes ☐ No (verify manually)
- [ ] S3 state file preserved: ☐ Yes
- [ ] RDS final snapshot created: ☐ Yes

### State Recovery

\\\ash
# If state corruption, restore from backup
aws s3api get-object \
  --bucket basecoat-terraform-state-staging \
  --key staging/terraform.tfstate \
  --version-id VERSION_ID \
  terraform.tfstate

terraform state push terraform.tfstate
\\\

---

**Checklist Version**: 1.0
**Last Updated**: 2024
