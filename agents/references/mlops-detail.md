# MLOps — Detail Reference

## Model Lifecycle Stages

1. **Development** — training, iteration, and hyperparameter tuning happen here. Track every experiment and data version so promising candidates can advance without ambiguity.
2. **Validation** — run the automated test suite, quality gates, and bias checks before promotion. Validation must confirm reproducibility, policy compliance, and operational readiness.
3. **Staging** — exercise shadow mode, A/B testing, or canary deployment before full release. Staging should approximate production traffic and failure modes as closely as possible.
4. **Production** — send full traffic only after staged quality gates pass. Production requires monitoring, alerting, rollback readiness, and documented ownership.
5. **Retirement** — deprecate the model gracefully, migrate traffic to its successor, and archive the lifecycle record. Retired models remain discoverable for audit and lineage needs.

## Experiment Management Standards

- Track model architecture, hyperparameters, training data version, metrics, artifacts, code revision, and environment specification for every run.
- Compare experiments side by side on the key metrics that matter for promotion, including quality, latency, and cost.
- Reproduce every experiment from logged metadata without relying on undocumented local state.
- Promote only experiments that satisfy validation gates and registry requirements.
- Preserve links between experiment runs, registry versions, deployed endpoints, and post-deployment monitoring signals.

## Model Registry and Lineage

- Every registry entry must have a unique version, immutable artifact reference, owner, approval state, and training lineage.
- Lineage must connect model version to source code revision, feature pipeline, training data version, evaluation results, and serving package.
- Registry metadata must include intended use, constraints, known risks, and retirement or successor information when applicable.
- Never promote a model that lacks provenance, evaluation evidence, or rollback instructions.

## Deployment Patterns

- Use blue-green deployment when cutover must be reversible with minimal downtime.
- Use canary releases with automatic rollback when a new model must prove quality under partial traffic.
- Use shadow mode when the candidate model should receive production traffic without serving responses yet.
- Use feature flags to route traffic by model version, tenant, cohort, or experiment group.
- Prefer immutable model packages and environment-specific configuration over rebuilding artifacts per environment.

## Production Monitoring Standards

- Monitor model quality metrics such as accuracy, F1, and task-specific business KPIs.
- Monitor serving performance, including inference latency, throughput, error rate, GPU utilization, and memory pressure.
- Detect data drift by tracking input distribution shift against the training baseline.
- Detect prediction drift by tracking output distribution shift and confidence changes over time.
- Define alerts for quality regression, resource exhaustion, drift thresholds, and failed rollouts.
- Feed monitoring signals back into lifecycle decisions so rollback, retraining, or retirement happens deliberately.

## Reproducibility and Governance

- Every experiment must record the full environment specification, including dependency versions, runtime, hardware profile, and configuration.
- Training data versions must be immutable or snapshot-referenced so results can be reproduced later.
- Quality, bias, and policy checks must be automated and attached to the lifecycle record.
- Model cards, evaluation summaries, and rollout decisions should be stored alongside registry metadata whenever the platform supports it.
- Reproducibility is not optional: if a result cannot be recreated, it cannot be promoted.

## Integration Boundaries

- Work with AgentOps for operational lifecycle state, approvals, and rollout coordination.
- Work with the telemetry framework for metrics, traces, dashboards, and alerts.
- Work with DataOps for upstream data quality, schema changes, and drift investigation.
- Escalate ownership gaps when lifecycle responsibilities across MLOps, DataOps, and operations teams are unclear.

## GitHub Issue Filing

File a GitHub Issue immediately when any of the following are discovered. Do not defer. Use the shared command template in `agents/references/issue-filing-pattern.md` with:

- **Title prefix:** `[MLOps Gap]`
- **Base labels:** `tech-debt,mlops`
- **Category options:** `<missing lineage | unreproducible experiment | missing quality gate | unsafe rollout | monitoring gap | drift gap | data versioning gap | ownership gap>`
- **File:** `<path/to/file-or-system>`

| Finding | Labels |
|---|---|
| Experiment cannot be reproduced from logged metadata | `tech-debt,mlops` |
| Model version missing lineage or registry metadata | `tech-debt,mlops` |
| Validation lacks automated quality, bias, or safety gates | `tech-debt,mlops,responsible-ai` |
| Deployment has no rollback or traffic-shaping strategy | `tech-debt,mlops,devops` |
| Production model has no drift detection or monitoring | `tech-debt,mlops,observability` |
| Data versioning does not support traceable training inputs | `tech-debt,mlops,data-quality` |
| Ownership between MLOps, DataOps, and operations is unclear | `tech-debt,mlops` |
