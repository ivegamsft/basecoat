# Dependency and impact checklist for hybrid branching rollout

## Policy dependencies

- [ ] Branch policy matrix finalized
- [ ] Required checks per branch class finalized
- [ ] Exception and emergency override policy finalized

## Workflow dependencies

- [ ] Lane admission and finalization workflow contracts defined
- [ ] CI preflight and guardrail contracts available
- [ ] Agent PR metadata contract available

## Governance dependencies

- [ ] Ownership model for branch policy and lane operations assigned
- [ ] Escalation policy for repeated failures defined
- [ ] Audit cadence and scorecard ownership assigned

## Consumer dependencies

- [ ] Consumer profile taxonomy published
- [ ] Migration runbook and rollback guidance prepared
- [ ] Minimal vs strict profile controls documented

## Impact areas to score

- [ ] Throughput impact
- [ ] Reliability impact
- [ ] Governance and compliance impact
- [ ] Operational load impact
- [ ] Change management impact
