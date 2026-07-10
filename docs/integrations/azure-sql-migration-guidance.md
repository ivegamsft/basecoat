# SQL Server On-Premises to Azure SQL Migration Guidance

This document provides best practices for migrating SQL Server databases from on-premises to Azure SQL, including assessment, planning, and cutover strategies.

## Migration Assessment

### Database Compatibility

Assess your current SQL Server version and target Azure SQL capabilities:

| Feature | SQL 2016 | SQL 2019 | Azure SQL | Notes |
|---|---|---|---|---|
| Contained databases | Supported | Supported | Supported | Recommended for multi-tenancy |
| In-memory OLTP (Hekaton) | Limited | Full | Limited | Check Azure SQL tier |
| Query Store | Supported | Supported | Supported | Essential for performance tuning |
| Temporal tables | Supported | Supported | Supported | Track data changes over time |

### Workload Classification

Categorize databases by complexity:

- **Lift & Shift**: Minimal code changes, standard compatibility
- **Modernize**: Add cloud-native features (elastic pools, geo-replication)
- **Refactor**: Break monolith into microservices; use Azure SQL Database

### Performance Baselines

Before migration, capture production metrics:

- Query execution times (P50, P95, P99)
- CPU, memory, I/O utilization per database
- Connection pool size and frequency
- Backup/restore times
- Transaction throughput (TPS)

## Azure SQL Target Selection

### Azure SQL Database vs Managed Instance

| Aspect | SQL Database | Managed Instance |
|---|---|---|
| Deployment | Single DB or elastic pool | Fully managed VM instance |
| Compatibility | T-SQL subset (99%+) | Near 100% on-premises |
| Cost | Pay per database or eDTU | Higher, closer to on-prem |
| Multi-database | Elastic pools group DBs | All DBs on single instance |
| Integration | Native Azure services | Some limitations |

### Tier Selection Strategy

```
Single Database Tiers:
- DTU Model: Basic (5 DTU), Standard (10-3000 DTU), Premium (125-4000 DTU)
- vCore Model: General Purpose (2-80 vCore), Business Critical (2-80 vCore), Hyperscale (up to 128 vCore)

Elastic Pool: When managing 3+ databases with variable workloads
- Pool eDTU: 50-4000
- Per-database: 0-3000 eDTU
```

Right-size by analyzing:

- Peak CPU utilization across all databases
- Storage growth trajectory (1yr historical)
- Connection concurrency
- Expected growth in next 12 months

## Migration Approach

### Offline Migration (Minimal Downtime)

Best for single-database migrations where brief downtime acceptable:

1. Full backup of source database
2. Restore to Azure SQL
3. Validate schema and data integrity
4. Redirect application connection strings
5. Monitor for 24-48 hours
6. Decommission source

Downtime: 30 minutes to 2 hours

### Online Migration (Zero Downtime)

Use Azure Database Migration Service (DMS) for minimal application downtime:

```powershell
# Create migration project in DMS
$migrationProject = New-AzDataMigrationProject `
  -ResourceGroupName "prod-rg" `
  -ServiceName "mig-service" `
  -ProjectName "sql2019-to-sqldb" `
  -Location "East US 2" `
  -SourceType "SqlServer" `
  -TargetType "AzureSqlDatabase"

# Start migration task with CDC
New-AzDataMigrationTask `
  -ProjectName $migrationProject.Name `
  -ServiceName "mig-service" `
  -TaskName "migrate-orders-db" `
  -SourceConnection (New-AzDmsConnInfo -ServerType SqlServer ...) `
  -TargetConnection (New-AzDmsConnInfo -ServerType AzureSqlDatabase ...) `
  -MigrationType "Online"
```

Downtime: < 1 second during final sync

## Pre-Migration Validation

### Object Compatibility Check

```sql
-- Identify deprecated features
SELECT * FROM sys.databases 
WHERE name = 'YourDatabase' 
  AND compatibility_level < 150

-- Find deprecated syntax
DBCC CHECKDB (YourDatabase, NOINDEX)
```

### Connection String Updates

Update application connection strings:

```csharp
// Before: On-premises SQL Server
string connString = @"Server=sqlserver.company.local;Database=Orders;
  Integrated Security=true;Encrypt=false";

// After: Azure SQL with authentication
string connString = @"Server=orders-db.database.windows.net;
  Database=Orders;User Id=admin@orders-db;Password=<password>;
  Encrypt=true;TrustServerCertificate=false;
  Connection Timeout=30";
```

### Identity and Access Configuration

Use managed identities to eliminate hardcoded credentials:

```csharp
// Azure App Service with managed identity
var credential = new DefaultAzureCredential();
var tokenProvider = new DefaultAzureCredentialTokenProvider();

using (SqlConnection conn = new SqlConnection("Server=.database.windows.net;Database=Orders;"))
{
    conn.AccessToken = tokenProvider.GetToken(
        new TokenRequestContext(scopes: new[] { "https://database.windows.net/.default" }))
        .Token;
    conn.Open();
    // Execute queries
}
```

Configure Azure SQL firewall rules:

```powershell
# Allow Azure services
New-AzSqlServerFirewallRule `
  -ServerName "orders-db" `
  -ResourceGroupName "prod-rg" `
  -FirewallRuleName "AllowAzureServices" `
  -StartIpAddress "0.0.0.0" `
  -EndIpAddress "0.0.0.0"

# Allow app service IP
New-AzSqlServerFirewallRule `
  -ServerName "orders-db" `
  -ResourceGroupName "prod-rg" `
  -FirewallRuleName "AllowAppService" `
  -StartIpAddress "20.45.67.89" `
  -EndIpAddress "20.45.67.89"
```

## Post-Migration Optimization

### Query Performance Tuning

Leverage Query Store to identify slow queries:

```sql
-- Top 10 queries by total execution time
SELECT TOP 10
    q.query_id,
    qt.query_sql_text,
    SUM(rs.avg_duration * rs.execution_count) AS total_duration_ms,
    MAX(rs.max_duration) AS max_duration_ms,
    SUM(rs.execution_count) AS exec_count
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_runtime_stats rs ON q.query_id = rs.query_id
WHERE database_id = DB_ID()
GROUP BY q.query_id, qt.query_sql_text
ORDER BY total_duration_ms DESC
```

Add indexes where needed:

```sql
-- Analyze missing indexes
SELECT migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) AS improvement_measure,
  mid.equality_columns, mid.inequality_columns, mid.included_columns
FROM sys.dm_db_missing_index_details mid
JOIN sys.dm_db_missing_index_groups_stats migs ON mid.index_handle = migs.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY improvement_measure DESC
```

### Backup and Restore Strategy

Configure automatic backups and geo-replication:

```powershell
# Enable geo-replication for disaster recovery
New-AzSqlDatabaseSecondary `
  -ServerName "orders-db" `
  -DatabaseName "Orders" `
  -PartnerServerName "orders-db-geo" `
  -ResourceGroupName "prod-rg"

# Monitor replication lag
Get-AzSqlDatabaseReplicationLink `
  -ServerName "orders-db" `
  -DatabaseName "Orders" `
  -ResourceGroupName "prod-rg" | 
  Select-Object ReplicationState, ReplicationLag
```

### Monitoring and Alerting

Set up Azure Monitor alerts for common issues:

```powershell
# Alert when CPU exceeds 80%
$actionGroup = Get-AzActionGroup -ResourceGroupName "prod-rg" -Name "DBA-Team"
$metric = New-AzMetricAlertRuleV2 `
  -Name "HighCPU-Orders-DB" `
  -ResourceGroupName "prod-rg" `
  -TargetResourceId "/subscriptions/.../resourceGroups/prod-rg/providers/Microsoft.Sql/servers/orders-db/databases/Orders" `
  -MetricName "cpu_percent" `
  -Operator GreaterThan `
  -Threshold 80 `
  -WindowSize 00:05:00 `
  -Frequency 00:01:00 `
  -ActionGroup $actionGroup.Id
```

## Base Coat Assets

- Agent: `agents/azure-cloud-migrate.agent.md`
- Skill: `skills/azure-migrate/`
- Instruction: `instructions/zero-trust-identity.instructions.md`

## References

- [Azure SQL Database Documentation](https://docs.microsoft.com/azure/azure-sql/)
- [SQL Server to Azure SQL Assessment](https://docs.microsoft.com/sql/dma/dma-overview)
- [Azure Database Migration Service](https://docs.microsoft.com/azure/dms/)
- [Query Store for Performance Troubleshooting](https://docs.microsoft.com/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store)
