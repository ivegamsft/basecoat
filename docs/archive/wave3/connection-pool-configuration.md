# Connection Pool Configuration & Testing Guide
## BaseCoat Portal Database v1.0

### Executive Summary

This guide provides pgBouncer connection pool configuration, setup procedures, load testing, and recovery validation for the Basecoat Portal staging RDS environment.

**Configuration Profile:** transaction mode
**Target Pool Size:** 25 connections per database
**Reserve Pool:** 5 connections
**Max Clients:** 1000 concurrent connections

---

## Part 1: Connection Pool Configuration

### 1.1 pgBouncer Installation

```bash
# Ubuntu/Debian
sudo apt-get install pgbouncer

# Or from source
wget https://pgbouncer.projects.pginfra.net/files/pgbouncer-1.21.0.tar.gz
tar xzf pgbouncer-1.21.0.tar.gz
cd pgbouncer-1.21.0
./configure
make
sudo make install
```

### 1.2 pgBouncer Configuration File

Create `/etc/pgbouncer/pgbouncer.ini`:

```ini
[databases]
basecoat_portal = host=staging-rds.aws.amazon.com port=5432 dbname=basecoat_portal

[pgbouncer]
; Connection pool settings
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
reserve_pool_size = 5
reserve_pool_timeout = 3

; Connection lifetime management
max_db_connections = 100
max_user_connections = 100
server_lifetime = 3600
server_idle_timeout = 600
server_connect_timeout = 5
server_login_retry = 3
query_timeout = 1800

; Authentication
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt

; Logging
log_connections = 1
log_disconnections = 1
log_pooler_errors = 1
logfile = /var/log/pgbouncer/pgbouncer.log

; Performance settings
tcp_keepalives_idle = 30
tcp_keepalives_interval = 30
tcp_keepalives_count = 5

; Admin interface
admin_users = postgres
stats_users = postgres
listen_port = 6432
listen_addr = 0.0.0.0
```

### 1.3 User Authentication File

Create `/etc/pgbouncer/userlist.txt`:

```
"postgres" "password_hash"
"app_user" "password_hash"
"readonly_user" "password_hash"
```

Generate password hashes:

```bash
# Use md5 for postgresql compatibility
echo -n "password" | md5sum

# Or use pgbouncer's built-in tool
pgbouncer -a -d /etc/pgbouncer/userlist.txt
```

### 1.4 Start pgBouncer Service

```bash
# Manual start
pgbouncer -d -c /etc/pgbouncer/pgbouncer.ini

# Or use systemd
sudo systemctl start pgbouncer
sudo systemctl enable pgbouncer

# Verify running
ps aux | grep pgbouncer
netstat -ln | grep 6432
```

---

## Part 2: Pool Mode Selection

### Transaction Mode (Recommended for this workload)

- **Description:** Connection returned to pool after each transaction
- **Overhead:** Low - minimal state held between transactions
- **Use Case:** Web applications, microservices, batch jobs
- **Connection Per Object:** Lower overhead
- **State Isolation:** Full isolation between clients

**Chosen for Basecoat Portal: YES**

```ini
pool_mode = transaction
```

### Session Mode (Alternative)

- **Description:** Connection held for entire client session
- **Use Case:** Long-running connections, interactive SQL clients
- **Connection Per Object:** One connection per client

```ini
pool_mode = session
```

### Statement Mode (Aggressive)

- **Description:** Connection returned after each statement
- **Use Case:** Very high concurrency, stateless workloads
- **Limitations:** Some features not supported (transactions, prepared statements)

```ini
pool_mode = statement
```

---

## Part 3: Connection Pool Parameters

### Pool Sizing Calculation

For Basecoat Portal:

```
Expected Peak Connections: 1000 concurrent users
Average Queries Per Second (QPS): 500
Query Duration (avg): 50ms
Required Connections: 500 * (50ms / 1000ms) = 25 connections

Formula:
connections_needed = expected_qps * average_query_duration_seconds
pool_size = connections_needed * 1.5 (with safety margin)
```

**Recommended Settings:**

```ini
# Base pool size (25 connections per database)
default_pool_size = 25

# Reserve connections for bursts
reserve_pool_size = 5

# Maximum client connections (allow spikes)
max_client_conn = 1000

# Per-database limit
max_db_connections = 100

# Per-user limit
max_user_connections = 100

# Reserve pool timeout (wait time for available connection)
reserve_pool_timeout = 3
```

### Connection Timeout Settings

```ini
# Time to establish connection to backend
server_connect_timeout = 5

# How long to maintain idle connection
server_idle_timeout = 600

# How long to keep connection open
server_lifetime = 3600

# Client query timeout (1800s = 30 minutes)
query_timeout = 1800
```

### TCP Keepalive Settings

```ini
# Idle time before first probe
tcp_keepalives_idle = 30

# Interval between probes
tcp_keepalives_interval = 30

# Number of probes before disconnect
tcp_keepalives_count = 5
```

---

## Part 4: Connection Pool Monitoring

### Monitoring SQL Queries

```sql
-- Connect to pgBouncer admin console
psql -h localhost -p 6432 -U postgres -d pgbouncer

-- Show pool status
SHOW POOLS;
-- Output:
--  database      | user    | cl_active | cl_waiting | sv_active | sv_idle | sv_used | sv_tested | sv_login
-- ---------------+---------+-----------+------------+-----------+---------+---------+-----------+---------
--  basecoat_portal | postgres |        10 |          0 |         8 |       17 |       0 |        25 |       0

-- Show client connections
SHOW CLIENTS;

-- Show server connections
SHOW SERVERS;

-- Show statistics
SHOW STATS;

-- Reload configuration
RELOAD;

-- Resume paused pool
RESUME;
```

### Key Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| cl_active | Active client connections | Variable |
| cl_waiting | Clients waiting for connection | 0-5 |
| sv_active | Active server connections in use | 15-25 |
| sv_idle | Idle server connections | 5-15 |
| Connection wait time | Max time to get connection | <100ms |

### Monitoring Dashboard

```bash
# Monitor pool in real-time
watch -n 1 "psql -h localhost -p 6432 -U postgres -d pgbouncer -c 'SHOW POOLS;'"

# Monitor for connection issues
watch -n 1 "psql -h localhost -p 6432 -U postgres -d pgbouncer -c 'SHOW STATS;'"
```

### Log Monitoring

```bash
# Follow pgbouncer logs
tail -f /var/log/pgbouncer/pgbouncer.log

# Count connection events
grep -c "closing" /var/log/pgbouncer/pgbouncer.log

# Find slow queries
grep "closing" /var/log/pgbouncer/pgbouncer.log | grep duration
```

---

## Part 5: Load Testing Procedures

### Load Test 1: Basic Connection Pool Test

**Objective:** Verify pool handles expected load
**Tool:** pgbench (PostgreSQL benchmark tool)
**Duration:** 5 minutes
**Clients:** 50 concurrent connections

```bash
# Prepare database
pgbench -i -s 100 -h localhost -p 6432 -d basecoat_portal

# Run load test
pgbench -c 50 -j 10 -T 300 -h localhost -p 6432 -d basecoat_portal

# Expected Results:
# - TPS (transactions per second): 100-200
# - Avg latency: 250-500ms
# - Max latency: <2000ms
```

### Load Test 2: Sustained Load Test

**Objective:** Monitor pool stability under prolonged load
**Duration:** 30 minutes
**Clients:** 100 concurrent connections
**Query Mix:** 70% SELECT, 20% UPDATE, 10% INSERT

```bash
# Create custom pgbench script
cat > /tmp/workload.sql <<EOF
\set aid random(1, 100000 * :scale)
\set bid random(1, 1 * :scale)
\set tid random(0, 23)
\set delta random(-5000, 5000)
SELECT abalance FROM pgbench_accounts WHERE aid = :aid;
UPDATE pgbench_accounts SET abalance = abalance + :delta WHERE aid = :aid;
INSERT INTO pgbench_history (tid, bid, aid, delta, mtime) VALUES (:tid, :bid, :aid, :delta, CURRENT_TIMESTAMP);
EOF

# Run sustained load test
pgbench -c 100 -j 20 -T 1800 -f /tmp/workload.sql \
  -h localhost -p 6432 -d basecoat_portal

# Monitor during test
watch -n 5 "psql -h localhost -p 6432 -U postgres -d pgbouncer -c 'SHOW POOLS;'"
```

### Load Test 3: Spike Test

**Objective:** Verify pool recovers from traffic spikes
**Clients:** 500 concurrent (from 50)
**Duration:** 5 minutes spike, 5 minutes recovery

```bash
# Stage 1: Baseline (50 clients, 5 min)
pgbench -c 50 -j 10 -T 300 -h localhost -p 6432 -d basecoat_portal

# Stage 2: Spike (500 clients, 5 min)
pgbench -c 500 -j 50 -T 300 -h localhost -p 6432 -d basecoat_portal

# Stage 3: Recovery (50 clients, 5 min)
pgbench -c 50 -j 10 -T 300 -h localhost -p 6432 -d basecoat_portal

# Expected Results:
# - Spike TPS: Degradation acceptable (<20%)
# - Pool recovery: Complete within 30 seconds
# - No connection errors
```

### Load Test 4: Query Latency Test

**Objective:** Measure query latency under load
**Tool:** Custom script with timing

```bash
cat > /tmp/latency_test.sh <<'EOF'
#!/bin/bash
for i in {1..1000}; do
  {
    time psql -h localhost -p 6432 -d basecoat_portal \
      -c "SELECT COUNT(*) FROM scan_results WHERE severity = 'critical';"
  } 2>&1 &
done
wait
EOF

chmod +x /tmp/latency_test.sh
/tmp/latency_test.sh

# Analyze results
# Extract timing: grep "real" output
# P50 (median), P95, P99 latencies
```

---

## Part 6: Connection Pool Recovery Testing

### Failure Scenario 1: Backend Connection Loss

**Scenario:** RDS instance becomes unavailable

```bash
# Simulate by blocking connection
# In RDS security group: Block port 5432

# Observe pgBouncer behavior
watch -n 1 "psql -h localhost -p 6432 -U postgres -d pgbouncer -c 'SHOW SERVERS;'"

# Expected:
# - Connections marked as "closed" or "error"
# - Pool automatically retries (up to server_login_retry times)
# - New clients get error or connection timeout

# Recovery when RDS is back:
# - Unblock port 5432
# - pgBouncer auto-reconnects
# - Monitor SHOW SERVERS for "ok" status
```

### Failure Scenario 2: Connection Pool Exhaustion

**Scenario:** All connections in use, new client connects

```bash
# Create 25+ long-running queries (exhaust pool)
psql -h localhost -p 6432 -d basecoat_portal \
  -c "SELECT pg_sleep(60);" &  # Repeat 30 times

# New client connects:
psql -h localhost -p 6432 -d basecoat_portal

# Expected:
# - Client waits up to reserve_pool_timeout (3 seconds)
# - Pool queues request
# - Connection provided when available
# - Monitor: SHOW CLIENTS shows "waiting"
```

### Failure Scenario 3: Long-Running Query

**Scenario:** Query exceeds query_timeout

```bash
# Set up long query (exceeds query_timeout = 1800s)
psql -h localhost -p 6432 -d basecoat_portal \
  -c "SELECT pg_sleep(2000);"

# Expected:
# - Query killed after 1800 seconds
# - Connection returned to pool
# - Client receives timeout error
# - No connection leak
```

### Failure Scenario 4: Client Disconnection

**Scenario:** Client closes connection abruptly

```bash
# Simulate: Kill client process
# pgBouncer should handle gracefully

# Monitor: SHOW CLIENTS after kill
# Expected:
# - Connection cleaned up
# - No lingering client connections
# - Pool state remains stable
```

### Recovery Validation Checklist

```sql
-- After each failure scenario, verify:

-- 1. All connections healthy
SELECT COUNT(*) as healthy_connections
FROM (SELECT * FROM SHOW SERVERS WHERE state = 'ok') t;
-- Expected: All connections recovered

-- 2. Pool stats reset
SELECT total_requests, total_received, total_sent
FROM (SELECT * FROM SHOW STATS) t;
-- Expected: No spike in errors

-- 3. Query capability restored
SELECT COUNT(*) FROM organizations;
-- Expected: Query completes successfully
```

---

## Part 7: Operational Procedures

### Daily Operations

```bash
# 1. Check pool health
psql -h localhost -p 6432 -U postgres -d pgbouncer -c "SHOW POOLS;" | tee /tmp/pool_status.txt

# 2. Verify no stuck connections
psql -h localhost -p 6432 -U postgres -d pgbouncer -c "SHOW CLIENTS;" | grep -v idle

# 3. Review error logs
grep ERROR /var/log/pgbouncer/pgbouncer.log | tail -20

# 4. Monitor resource usage
vmstat 1 5  # CPU and memory
netstat -an | grep 6432 | wc -l  # Connection count
```

### Weekly Operations

```bash
# 1. Full connection pool statistics
psql -h localhost -p 6432 -U postgres -d pgbouncer -c "SHOW STATS;" > /tmp/weekly_stats.txt

# 2. Check for connection leaks
SELECT COUNT(*) FROM (SELECT * FROM SHOW CLIENTS WHERE state = 'active') t;
# Should be stable week-to-week

# 3. Verify authentication is working
psql -h localhost -p 6432 -U postgres -d basecoat_portal -c "SELECT 1;" || echo "Auth failed"

# 4. Test failover if applicable
# Switch to replica and verify pool reconnects
```

### Monthly Operations

```bash
# 1. Performance review
# Analyze latency trends from logs

# 2. Configuration tuning
# Review and adjust pool_size based on metrics

# 3. Load test (in staging)
# Run full load test suite

# 4. Documentation update
# Update this guide based on operational learnings
```

### Emergency Procedures

#### Restart pgBouncer

```bash
# Graceful restart (existing connections drain)
pgbouncer -R -c /etc/pgbouncer/pgbouncer.ini

# Force restart (existing connections closed)
sudo systemctl restart pgbouncer

# Verify restart
sleep 5
psql -h localhost -p 6432 -U postgres -d pgbouncer -c "SHOW POOLS;"
```

#### Reload Configuration

```bash
# Without restarting connections
psql -h localhost -p 6432 -U postgres -d pgbouncer
pgbouncer=> RELOAD;

# Verify new configuration
psql -h localhost -p 6432 -U postgres -d pgbouncer -c "SHOW CONFIG;" | grep pool_size
```

#### Reset Pool

```bash
# Disconnect all clients and reset
psql -h localhost -p 6432 -U postgres -d pgbouncer
pgbouncer=> PAUSE;
pgbouncer=> RESUME;

# Verify clean state
psql -h localhost -p 6432 -U postgres -d pgbouncer -c "SHOW POOLS;"
```

---

## Part 8: Performance Tuning

### Identify Bottlenecks

```sql
-- Find slow queries going through pool
SELECT * FROM (SHOW STATS) stats
WHERE avg_latency_ms > 100;

-- Identify connections with high wait time
SELECT * FROM (SHOW CLIENTS) clients
WHERE wait_time > 1000;
```

### Optimization Strategies

1. **Reduce pool_size if mostly idle:**
   ```ini
   default_pool_size = 15  # Reduced from 25
   ```

2. **Increase pool_size if queuing observed:**
   ```ini
   default_pool_size = 35  # Increased from 25
   ```

3. **Adjust server_idle_timeout for long-running workloads:**
   ```ini
   server_idle_timeout = 900  # 15 minutes instead of 10
   ```

4. **Enable connection multiplexing for transaction mode:**
   ```ini
   pool_mode = transaction
   # Allows reusing same connection for different clients
   ```

---

## Success Criteria

Connection pool deployment is successful when:

- ✓ All 50 concurrent connections handled without queuing
- ✓ Average latency < 100ms under load
- ✓ P99 latency < 500ms
- ✓ Zero connection errors over 24 hours
- ✓ Recovery from failures < 30 seconds
- ✓ 100% of queries complete successfully
- ✓ No connection leaks after 7 days uptime
- ✓ Pool metrics stable day-to-day

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| High cl_waiting | Pool too small | Increase default_pool_size |
| Connection refused | No available connections | Check max_client_conn, increase if needed |
| Slow queries | Pool contention | Reduce pool_size or optimize queries |
| Connection leak | Zombie clients | Restart pgBouncer, increase client_idle_timeout |
| Auth failures | Wrong userlist.txt | Regenerate password hashes, reload config |
