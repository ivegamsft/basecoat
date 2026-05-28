---
description: Deploy and manage Microsoft Fabric notebooks with CI/CD, lakehouse integration, governance, and production patterns.
applyTo: "**/*.ipynb", "**/*notebook*"
---

# Fabric Notebook Deployment

Production-ready patterns for Microsoft Fabric notebooks (formerly Synapse).

## Medallion Architecture for Notebooks

Structure notebooks into bronze (raw ingestion) → silver (transformation) → gold (analytics) layers:

```python
# bronze_ingest.ipynb
from fabric import FabricNotebook

# Raw data ingestion with lineage tracking
notebook = FabricNotebook()
lakehouse = notebook.get_lakehouse("my_workspace/my_lakehouse")

# Raw table (immutable, source-aligned)
raw_df = spark.read \
  .option("multiline", "true") \
  .json("/data/api-export-raw.json")

raw_df.write \
  .mode("overwrite") \
  .saveAsTable("bronze.api_events", 
    external=False,
    path=f"{lakehouse.mount_point}/bronze/api_events")

# Lineage: record source + timestamp
spark.sql("""
  INSERT INTO bronze.lineage_metadata
  SELECT 'api_events', current_timestamp(), 'https://api.example.com/v1/events'
""")
```

## Lakehouse Integration

Use Lakehouse shortcuts to organize data by domain.

```python
# silver_transform.ipynb
# Access bronze tables via shortcut
raw_events = spark.read.table("bronze.api_events")

# Apply transformations
silver_df = raw_events \
  .filter(col("timestamp") > "2024-01-01") \
  .select("event_id", "user_id", "event_type", "timestamp") \
  .withColumn("event_date", to_date(col("timestamp")))

# Write to silver with schema validation
silver_df.write \
  .mode("overwrite") \
  .option("mergeSchema", "false") \
  .saveAsTable("silver.events_cleaned")
```

## Testing in Notebooks

Embed test assertions for data quality.

```python
# Test helpers
def assert_no_nulls(df, column):
  null_count = df.filter(col(column).isNull()).count()
  assert null_count == 0, f"Found {null_count} nulls in {column}"

def assert_range(df, column, min_val, max_val):
  out_of_range = df.filter((col(column) < min_val) | (col(column) > max_val)).count()
  assert out_of_range == 0, f"Found {out_of_range} out-of-range values in {column}"

# Apply tests
assert_no_nulls(silver_df, "user_id")
assert_range(silver_df, "event_id", 1, 9999999)
assert silver_df.count() > 0, "No rows in silver table"
```

## CI/CD Integration

### Pipeline Orchestration (Data Factory / Synapse Pipeline)

```json
{
  "name": "FabricNotebookPipeline",
  "activities": [
    {
      "name": "RunBronzeNotebook",
      "type": "SynapseNotebook",
      "typeProperties": {
        "notebook": {
          "referenceName": "bronze_ingest",
          "type": "NotebookReference"
        },
        "parameters": {
          "timestamp": "@pipeline().TriggerTime",
          "environment": "prod"
        }
      }
    },
    {
      "name": "RunSilverNotebook",
      "type": "SynapseNotebook",
      "dependsOn": [{"activity": "RunBronzeNotebook", "dependencyConditions": ["Succeeded"]}],
      "typeProperties": {
        "notebook": {"referenceName": "silver_transform", "type": "NotebookReference"}
      }
    }
  ]
}
```

### Source Control (Git Integration)

Store notebooks in Git with `nbstripout` to remove execution metadata:

```bash
# .gitattributes
*.ipynb filter=jupyter_strip_notebook

# .git/config
[filter "jupyter_strip_notebook"]
  clean = jupyter nbconvert --to notebook --stdout | jq '{cells, metadata}'
  smudge = cat
```

## Governance & Monitoring

### Role-Based Access

```python
# Set Fabric item permissions via PySpark
from fabric import FabricItem

notebook = FabricItem("my_workspace/my_notebook")
notebook.grant_permission(
  principal="data-engineers@company.com",
  role="Contributor"
)
notebook.grant_permission(
  principal="analysts@company.com",
  role="Viewer"
)
```

### Audit Logging

Log all transformations for compliance.

```python
# Audit trail
spark.sql("""
  CREATE TABLE IF NOT EXISTS gold.audit_log AS
  SELECT 
    'silver_transform' as notebook_name,
    current_timestamp() as execution_time,
    current_user() as executed_by,
    'COMPLETED' as status
""")
```

## Performance Tuning

- **Shuffle partitions**: `spark.sql.shuffle.partitions = 200` (adjust per cluster)
- **Caching**: Use `.cache()` for reused DataFrames, `.unpersist()` to free memory
- **Partition pruning**: Add `year`, `month` columns for efficient filtering
- **AQE (Adaptive Query Execution)**: Enabled by default in Fabric; monitors partitions dynamically

## Error Handling & Retries

```python
import time
from functools import wraps

def retry_on_failure(max_attempts=3, backoff=2):
  def decorator(func):
    def wrapper(*args, **kwargs):
      for attempt in range(max_attempts):
        try:
          return func(*args, **kwargs)
        except Exception as e:
          if attempt == max_attempts - 1:
            raise
          wait_time = backoff ** attempt
          print(f"Attempt {attempt + 1} failed: {e}. Retrying in {wait_time}s...")
          time.sleep(wait_time)
    return wrapper
  return decorator

@retry_on_failure(max_attempts=3)
def load_external_data():
  return spark.read.format("csv").load("https://api.example.com/data.csv")
```

## MCP Fallback

If Fabric SDK unavailable, use REST API:

```python
import requests

FABRIC_API = "https://api.fabric.microsoft.com/v1"
ACCESS_TOKEN = "..."  # OAuth token

# Get lakehouse metadata
response = requests.get(
  f"{FABRIC_API}/workspaces/{workspace_id}/lakehouses/{lakehouse_id}",
  headers={"Authorization": f"Bearer {ACCESS_TOKEN}"}
)
lakehouse_data = response.json()
```

