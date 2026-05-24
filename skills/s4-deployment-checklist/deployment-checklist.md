# S4 Deployment Checklist

Use this checklist before moving an S4 cutover to production.

## Readiness

- [ ] Shadow-mode soak completed and verified
- [ ] Rollback path is documented and testable
- [ ] Monitoring dashboards and alerts are configured
- [ ] On-call has reviewed the cutover plan
- [ ] Team briefing has been sent

## Go / No-Go

- [ ] Validation results meet the gate criteria
- [ ] Open risks are understood and accepted
- [ ] Rollback owners are assigned
- [ ] Cutover window and comms plan are confirmed

## Post-Cutover

- [ ] Smoke checks passed
- [ ] Error rate and latency are within expected bounds
- [ ] Rollback materials remain ready until the soak window ends
