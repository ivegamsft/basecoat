# DataOps — Detail Reference

## Data Quality Standards

- Validate schema compatibility on every ingest and transform boundary.
- Check required fields, type stability, null-rate thresholds, uniqueness, and referential integrity for critical joins.
- Define freshness SLAs per dataset; alert when expected delivery windows are missed.
- Use anomaly detection on row counts, distribution changes, outlier rates, and business-critical metrics.
- Treat silently degraded data as a production incident even when jobs complete successfully.

## Lineage Standards

- Maintain source → transformation → destination lineage for every production dataset.
- Capture ownership, update cadence, and downstream consumers alongside lineage metadata.
- Prefer automated lineage extraction from orchestration tooling over manually maintained docs.
- Preserve column-level lineage for sensitive, regulated, or model-critical fields where supported.
- Use lineage to drive impact analysis before changing schemas, schedules, or transformation logic.

## Governance Standards

- Classify datasets by sensitivity and business criticality.
- Apply least-privilege access controls to raw, curated, and serving layers.
- Retention and deletion policies must be explicit, automated where possible.
- Mask, tokenize, or remove sensitive fields before sharing outside approved trust boundaries.
- Governance exceptions require: owner, expiry date, and remediation plan.

## Pipeline Orchestration Standards

- Define DAGs declaratively under version control.
- Every task: explicit upstream dependencies, retry policy, timeout, and alerting behavior.
- Tasks must be idempotent so retries and backfills do not corrupt downstream state.
- Backfills require documented scope, ordering, and resource safeguards.
- Production pipelines must expose run status, duration, failure reason, and last successful completion.

## Data Contract Standards

- Contracts must define: schema, field semantics, allowed nullability, freshness, ownership, deprecation policy.
- Producers must announce breaking changes before release with migration window.
- Contract tests should run in CI or pre-deploy checks whenever schemas or transformations change.
- If a contract is missing, treat the integration as high risk and document the gap immediately.

## Drift Detection Standards

- Schema drift: added, removed, renamed, reordered, or type-changed fields.
- Value drift: categorical distribution changes, numeric shifts, null spikes, business rule violations.
- Volume drift: row-count changes, duplicate spikes, missing partitions, late-arriving data.
- Dataset-specific thresholds to avoid alert fatigue from normal seasonality or growth.

## GitHub Issue Filing

```bash
gh issue create \
  --title "[DataOps Gap] <short description>" \
  --label "tech-debt,dataops" \
  --body "## DataOps Gap Finding

**Category:** <quality gap | lineage gap | governance gap | orchestration gap | contract gap | drift gap>
**File:** <path>

### Description
<what was found and why it is a risk>

### Recommended Fix
<concise recommendation>

### Acceptance Criteria
- [ ] <criterion>"
```

| Finding | Labels |
|---|---|
| Missing schema validation or freshness checks | `tech-debt,dataops,data-quality` |
| Lineage cannot trace production dataset to source | `tech-debt,dataops,lineage` |
| Sensitive data lacks classification or access controls | `tech-debt,dataops,governance,security` |
| Pipeline missing dependency definitions or failure alerts | `tech-debt,dataops,orchestration` |
| Integration lacks explicit data contract | `tech-debt,dataops,contracts` |
| Breaking schema change can reach consumers undetected | `tech-debt,dataops,contracts,reliability` |
| Drift monitoring absent for model-critical data | `tech-debt,dataops,drift,mlops` |
