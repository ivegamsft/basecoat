---
description: "Comprehensive test suite for data workloads: medallion patterns, data quality validation, and convention-driven testing for bronze/silver/gold layers."
applyTo: "**/*.{py,sql,yml}"
---

# Data Workload Testing Convention

Conventions for validating data pipelines across medallion architecture layers. Tests must cover correctness, completeness, and convention compliance at each layer.

## Test Categories

Five required test categories for every data workload:

1. **Data Integrity** — schema validation, referential integrity, type consistency.
2. **Data Quality** — null rates, value ranges, uniqueness constraints.
3. **Convention Tests** — snake_case naming, partitioning compliance, table metadata.
4. **Medallion Layer Tests** — bronze immutability/lineage, silver documentation, gold SLA.
5. **Integration Tests** — bronze→silver propagation (≤5% dedup loss), silver→gold aggregation correctness.

## Quick Rules

- **Bronze:** Append-only. Must track `_source_system`, `_loaded_at`, `_file_path`.
- **Silver:** Cleaned and deduplicated. Must have dbt documentation and schema enforcement.
- **Gold:** Analytics-ready. All queries must complete in <5 seconds.
- **Null thresholds:** Define per-column. Primary keys allow 0%, optional fields allow ≤5%.
- **Naming:** All column names must be `snake_case`. Table names lowercase.
- **Partitioning:** Silver tables partitioned by `year`, `month`, `day`. Gold may use business date.
- **Metadata:** Every table must have `owner`, `description`, and `sla_latency_hours` properties.

## Target Metrics

| Metric | Target |
|---|---|
| Test coverage | >80% of tables |
| Data completeness | >99.5% |
| Gold query SLA | <5s |
| Pipeline freshness | <24h |

## Reference Files

| File | Contents |
|---|---|
| [data-quality-tests.md](references/data-workload-testing/data-quality-tests.md) | Schema, null rate, range, uniqueness, referential integrity, and convention tests |
| [layer-test-patterns.md](references/data-workload-testing/layer-test-patterns.md) | Bronze/silver/gold tests, integration tests, fixtures, CI/CD config |

## See Also

- `data-science.instructions.md` — Medallion architecture patterns and DuckDB.
- `testing.instructions.md` — General Python testing conventions (pytest, fixtures, CI).
