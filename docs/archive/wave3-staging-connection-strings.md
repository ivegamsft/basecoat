# Basecoat Portal Staging - Connection Strings & Configuration

## Database Connection Details

### PostgreSQL RDS Instance

**Host**: basecoat-portal-db.XXXXXXXXXXXX.us-east-1.rds.amazonaws.com
**Port**: 5432
**Database**: postgres
**Username**: postgres
**Password**: [Stored in AWS Secrets Manager - see retrieval below]

### Connection String Examples

#### Standard Connection (Direct to RDS)

\\\
postgresql://postgres:PASSWORD@basecoat-portal-db.XXXXXXXXXXXX.us-east-1.rds.amazonaws.com:5432/postgres
\\\

#### Environment Variables (Python/Node.js)

\\\ash
export DB_HOST='basecoat-portal-db.XXXXXXXXXXXX.us-east-1.rds.amazonaws.com'
export DB_PORT='5432'
export DB_NAME='postgres'
export DB_USER='postgres'
export DB_PASSWORD='[from Secrets Manager]'
export DATABASE_URL='postgresql://postgres:PASSWORD@basecoat-portal-db.XXXXXXXXXXXX.us-east-1.rds.amazonaws.com:5432/postgres'
\\\

#### .env File

\\\
DB_HOST=basecoat-portal-db.XXXXXXXXXXXX.us-east-1.rds.amazonaws.com
DB_PORT=5432
DB_NAME=postgres
DB_USER=postgres
DB_PASSWORD=[from Secrets Manager]
\\\

### Retrieve Database Password

\\\ash
# Get connection details from AWS Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id basecoat-portal/db/password \
  --region us-east-1 \
  --query SecretString \
  --output text | jq '.'

# Output will show:
# {
#   \"username\": \"postgres\",
#   \"password\": \"ACTUAL_PASSWORD\",
#   \"engine\": \"postgres\",
#   \"host\": \"basecoat-portal-db.XXXXXXXXXXXX.us-east-1.rds.amazonaws.com\",
#   \"port\": 5432,
#   \"dbname\": \"postgres\"
# }
\\\

### Python Connection Example

\\\python
import psycopg2
import json
import boto3

# Retrieve credentials from Secrets Manager
secrets_client = boto3.client('secretsmanager', region_name='us-east-1')
secret = secrets_client.get_secret_value(SecretId='basecoat-portal/db/password')
credentials = json.loads(secret['SecretString'])

# Connect to database
conn = psycopg2.connect(
    host=credentials['host'],
    port=credentials['port'],
    user=credentials['username'],
    password=credentials['password'],
    database=credentials['dbname']
)

# Execute query
cursor = conn.cursor()
cursor.execute('SELECT version();')
print(cursor.fetchone())
cursor.close()
conn.close()
\\\

### Node.js Connection Example

\\\javascript
const { Client } = require('pg');
const AWS = require('aws-sdk');

const secretsManager = new AWS.SecretsManager({ region: 'us-east-1' });

async function connectToDatabase() {
  try {
    // Retrieve credentials
    const secret = await secretsManager.getSecretValue({
      SecretId: 'basecoat-portal/db/password'
    }).promise();
    
    const credentials = JSON.parse(secret.SecretString);
    
    // Connect
    const client = new Client({
      host: credentials.host,
      port: credentials.port,
      user: credentials.username,
      password: credentials.password,
      database: credentials.dbname
    });
    
    await client.connect();
    const result = await client.query('SELECT version()');
    console.log(result.rows);
    await client.end();
  } catch (error) {
    console.error('Connection failed:', error);
  }
}

connectToDatabase();
\\\

---

## Redis Cache Connection Details

### ElastiCache Redis Cluster

**Primary Endpoint**: basecoat-portal-redis.XXXXXXXXXXXX.ng.0001.use1.cache.amazonaws.com
**Port**: 6379
**Node Count**: 2 (with automatic failover)
**Auth Token**: [Stored in AWS Secrets Manager]

### Connection String Examples

#### Standard Connection

\\\
redis://basecoat-portal-redis.XXXXXXXXXXXX.ng.0001.use1.cache.amazonaws.com:6379
\\\

#### With Auth Token (if encryption enabled)

\\\
redis://:AUTH_TOKEN@basecoat-portal-redis.XXXXXXXXXXXX.ng.0001.use1.cache.amazonaws.com:6379
\\\

#### Environment Variables

\\\ash
export REDIS_HOST='basecoat-portal-redis.XXXXXXXXXXXX.ng.0001.use1.cache.amazonaws.com'
export REDIS_PORT='6379'
export REDIS_AUTH_TOKEN='[from Secrets Manager]'
export REDIS_URL='redis://:AUTH_TOKEN@basecoat-portal-redis.XXXXXXXXXXXX.ng.0001.use1.cache.amazonaws.com:6379'
\\\

### Python Connection Example

\\\python
import redis

# Connect to Redis
r = redis.Redis(
    host='basecoat-portal-redis.XXXXXXXXXXXX.ng.0001.use1.cache.amazonaws.com',
    port=6379,
    decode_responses=True
)

# Test connection
print(r.ping())  # Output: True

# Set and get values
r.set('test_key', 'test_value')
print(r.get('test_key'))  # Output: test_value
\\\

### Node.js Connection Example

\\\javascript
const redis = require('redis');

const client = redis.createClient({
  host: 'basecoat-portal-redis.XXXXXXXXXXXX.ng.0001.use1.cache.amazonaws.com',
  port: 6379,
  socket: {
    reconnectStrategy: (retries) => {
      const delay = Math.min(retries * 50, 500);
      return delay;
    }
  }
});

client.on('error', (err) => console.log('Redis Client Error', err));

await client.connect();
console.log(await client.ping()); // Output: PONG

await client.set('test_key', 'test_value');
console.log(await client.get('test_key')); // Output: test_value

await client.disconnect();
\\\

---

## Application Load Balancer (ALB)

### Endpoint Configuration

**DNS Name**: basecoat-portal-alb-XXXXXXXXXXXX.us-east-1.elb.amazonaws.com
**Protocol**: HTTPS (port 443)
**Certificate**: Self-signed (staging only - replace in production)
**Health Check Endpoint**: /health

### Connection Example

\\\ash
# Health check (via curl)
curl -k https://basecoat-portal-alb-XXXXXXXXXXXX.us-east-1.elb.amazonaws.com/health

# Expected response:
# HTTP/1.1 200 OK
# {\"status\": \"healthy\"}
\\\

### Environment Variables

\\\ash
export ALB_ENDPOINT='https://basecoat-portal-alb-XXXXXXXXXXXX.us-east-1.elb.amazonaws.com'
export APP_HEALTH_CHECK='\/health'
export APP_BASE_URL='\'
\\\

---

## Terraform Outputs

After deployment, retrieve outputs using:

\\\ash
# Get all outputs in JSON format
terraform output -json

# Get specific outputs
terraform output aws_infrastructure_summary

# Example output:
# {
#   \"vpc_id\": \"vpc-XXXXXXXXXXXX\",
#   \"database_endpoint\": \"basecoat-portal-db.XXXXXXXXXXXX.us-east-1.rds.amazonaws.com:5432\",
#   \"cache_endpoint\": \"basecoat-portal-redis.XXXXXXXXXXXX.ng.0001.use1.cache.amazonaws.com\",
#   \"load_balancer_dns\": \"basecoat-portal-alb-XXXXXXXXXXXX.us-east-1.elb.amazonaws.com\"
# }
\\\

---

## Connectivity Testing

### Test Database Connectivity (from Application Instance)

\\\ash
# Install PostgreSQL client
apt-get install postgresql-client  # Ubuntu/Debian
brew install postgresql             # macOS

# Connect to database
psql -h basecoat-portal-db.XXXXXXXXXXXX.us-east-1.rds.amazonaws.com \
     -U postgres \
     -d postgres

# Test query (at psql prompt)
SELECT version();
SELECT now();

# Expected: Should connect and return version/timestamp
\\\

### Test Cache Connectivity (from Application Instance)

\\\ash
# Install Redis client
apt-get install redis-tools  # Ubuntu/Debian
brew install redis           # macOS

# Connect to Redis
redis-cli -h basecoat-portal-redis.XXXXXXXXXXXX.ng.0001.use1.cache.amazonaws.com \
          -p 6379

# Test commands (at redis-cli prompt)
PING              # Should respond: PONG
SET mykey myvalue # Should respond: OK
GET mykey         # Should respond: myvalue

# Expected: All commands succeed
\\\

### Test ALB Health Check

\\\ash
# From any network with access to staging VPC
curl -k https://basecoat-portal-alb-XXXXXXXXXXXX.us-east-1.elb.amazonaws.com/health

# Expected response (200 OK):
# {\"status\": \"healthy\"}
\\\

---

## AWS CLI Quick Reference

### Retrieve Infrastructure Details

\\\ash
# VPC information
aws ec2 describe-vpcs --filters Name=tag:Environment,Values=staging

# RDS instance details
aws rds describe-db-instances \
  --db-instance-identifier basecoat-portal-db \
  --region us-east-1

# ElastiCache cluster details
aws elasticache describe-replication-groups \
  --replication-group-id basecoat-portal-redis \
  --region us-east-1

# ALB details
aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --query 'LoadBalancers[?LoadBalancerName==\asecoat-portal-alb\]'

# Security groups
aws ec2 describe-security-groups \
  --filters Name=tag:Environment,Values=staging \
  --region us-east-1
\\\

### Check Monitoring Status

\\\ash
# List CloudWatch dashboards
aws cloudwatch list-dashboards --region us-east-1

# List CloudWatch alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix basecoat-portal \
  --region us-east-1

# Get RDS metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=basecoat-portal-db \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Average \
  --region us-east-1
\\\

---

## Configuration File Templates

### Docker .env File

\\\
# Database Configuration
DATABASE_HOST=basecoat-portal-db.XXXXXXXXXXXX.us-east-1.rds.amazonaws.com
DATABASE_PORT=5432
DATABASE_NAME=postgres
DATABASE_USER=postgres
DATABASE_PASSWORD=[from AWS Secrets Manager]

# Cache Configuration
CACHE_HOST=basecoat-portal-redis.XXXXXXXXXXXX.ng.0001.use1.cache.amazonaws.com
CACHE_PORT=6379
CACHE_AUTH_TOKEN=[from AWS Secrets Manager]

# Application Configuration
APP_ENV=staging
APP_DEBUG=true
APP_LOG_LEVEL=info

# ALB Configuration
ALB_ENDPOINT=https://basecoat-portal-alb-XXXXXXXXXXXX.us-east-1.elb.amazonaws.com
HEALTH_CHECK_ENDPOINT=/health

# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=[ACCOUNT_ID]
\\\

### Kubernetes ConfigMap & Secret Example

\\\yaml
---
# ConfigMap for non-sensitive configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: basecoat-portal-config
  namespace: staging
data:
  DB_HOST: basecoat-portal-db.XXXXXXXXXXXX.us-east-1.rds.amazonaws.com
  DB_PORT: \"5432\"
  DB_NAME: postgres
  CACHE_HOST: basecoat-portal-redis.XXXXXXXXXXXX.ng.0001.use1.cache.amazonaws.com
  CACHE_PORT: \"6379\"
  APP_ENV: staging
  AWS_REGION: us-east-1

---
# Secret for sensitive configuration
apiVersion: v1
kind: Secret
metadata:
  name: basecoat-portal-secrets
  namespace: staging
type: Opaque
stringData:
  DB_PASSWORD: [from AWS Secrets Manager]
  CACHE_AUTH_TOKEN: [from AWS Secrets Manager]
  AWS_SECRET_ACCESS_KEY: [AWS credentials]
\\\

---

## Support & Troubleshooting

### Connection Issues

**Problem**: Cannot connect to database
- Verify security group allows port 5432 from application tier
- Check RDS instance status (should be \"available\")
- Verify database password is correct (check Secrets Manager)
- Confirm application is in correct VPC/subnet

**Problem**: Cannot connect to Redis
- Verify security group allows port 6379 from application tier
- Check cache cluster status (should be \"available\")
- If encryption enabled, verify auth token is provided

**Problem**: ALB endpoint not responding
- Check ALB target group health (should be \"healthy\")
- Verify security group allows traffic from client
- Check application logs in CloudWatch
- Verify application is listening on correct port

### Performance Issues

**Database Performance**
- Monitor RDS CPU, memory, IOPS in CloudWatch
- Check query logs in CloudWatch Logs
- Consider increasing instance size (db.t3.medium+)
- Enable query result caching via Redis

**Cache Performance**
- Monitor ElastiCache CPU, memory, evictions
- Check eviction count (should be 0 or low)
- If high evictions, increase instance size
- Use connection pooling (Redis Proxy available)

---

**Document Version**: 1.0
**Last Updated**: 2024
