# Data Architect — Technology Patterns Detail

Supporting detail for [`agents/basecoat-80-data-data-architect.agent.md`](../basecoat-80-data-data-architect.agent.md).

## Technology Patterns

### Data Warehouse (Cloud-Native)

```sql
-- Bronze: Raw ingestion
CREATE EXTERNAL TABLE bronze.source_events (
  event_id STRING,
  event_timestamp TIMESTAMP,
  event_data STRING,
  _loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
USING PARQUET
LOCATION '/mnt/data/bronze/events/'
PARTITIONED BY (_loaded_at);

-- Silver: Cleaned and validated
CREATE TABLE silver.events (
  event_id STRING NOT NULL,
  event_timestamp TIMESTAMP NOT NULL,
  user_id STRING NOT NULL,
  session_id STRING,
  event_type STRING,
  event_properties MAP<STRING, STRING>,
  _dw_loaded_at TIMESTAMP,
  _dw_updated_at TIMESTAMP
)
PARTITIONED BY (year INT, month INT, day INT)
CLUSTERED BY (user_id, event_type) INTO 64 BUCKETS;

-- Gold: Analytics-ready
CREATE TABLE gold.daily_user_events AS
SELECT
  DATE(event_timestamp) AS event_date,
  user_id,
  event_type,
  COUNT(*) AS event_count,
  COUNT(DISTINCT session_id) AS session_count
FROM silver.events
WHERE event_timestamp >= DATE_SUB(CURRENT_DATE, 90)
GROUP BY 1, 2, 3;
```

### ETL/ELT with dbt

```yaml
# dbt_project.yml
name: 'analytics'
version: '1.0.0'
config-version: 2

models:
  bronze:
    +materialized: table
    +schema: bronze

  silver:
    +materialized: table
    +schema: silver
    +pre-hook: "{{ log('Running data quality checks...') }}"

  gold:
    +materialized: view
    +schema: gold

tests:
  - dbt_expectations.expect_column_values_to_not_be_null
  - dbt_utils.equal_rowcount
```

## Monitoring & Observability

```python
# Data quality framework
import dbt_utils

def check_data_quality(df, table_name):
    checks = {
        'row_count': df.shape[0] > 0,
        'null_rate': df.isnull().sum().sum() / (df.shape[0] * df.shape[1]) < 0.05,
        'schema_match': list(df.columns) == expected_schema[table_name]
    }
    return all(checks.values()), checks
```

## Common Challenges

| Challenge | Solution |
| --- | --- |
| Data latency | Implement real-time stream processing (Kafka, Event Hubs) alongside batch |
| Data quality drift | Automated validation gates, anomaly detection |
| Access complexity | Federated governance with domain teams owning their layers |
| Cost explosion | Implement data lifecycle, tier by frequency/cost |
| Governance sprawl | Centralized metadata store (Apache Atlas, Collibra) |

## References

- [Databricks Medallion Architecture](https://www.databricks.com/en-blog/medallion-architecture-a-proven-approach-to-data-and-ai)
- [dbt Guide to Stakeholder Management](https://docs.getdbt.com/docs/guides/stakeholder-management)
- [Azure Data Lake Storage Best Practices](https://learn.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-best-practices)
