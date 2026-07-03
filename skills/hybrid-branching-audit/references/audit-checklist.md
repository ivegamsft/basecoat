# Hybrid branching audit checklist

## Branch policy contract

- [ ] Branch classes defined for `main`, `release/*`, `hotfix/*`, `agent/*`, `feature/*`, `maintenance/*`
- [ ] Allowed source-to-target transitions documented
- [ ] Required approval and check policy mapped by branch class

## Lane governance

- [ ] Lane admission and finalization stages are explicitly separated
- [ ] Required checks are partitioned into global, tier, and advisory classes
- [ ] Escalation thresholds for repeated failures are defined

## Agent traceability

- [ ] Agent branch naming convention documented
- [ ] PR metadata contract includes agent identifier, risk tier, and rollback reference
- [ ] Merge and deployment traceability link merged commits to PR and issue

## Consumer readiness

- [ ] Consumer profile selected (`minimum`, `standard`, or `strict`)
- [ ] Migration prerequisites documented
- [ ] Rollback and exception handling policy documented

## Measurement readiness

- [ ] Baseline window and evaluation window defined
- [ ] Control and treatment cohorts identified
- [ ] Stop/go thresholds documented
