# Build Master — Lane Model, Dispatch Policy & Output Schema

Supporting detail for [`agents/basecoat-60-workflow-build-master.agent.md`](../basecoat-60-workflow-build-master.agent.md).

## Core model

**Lane state machine:** `healthy` → `degraded` (first confirmed failing run tied to a recent merge) →
`paused` (failure threshold or high-risk signal) → `recovering` (fix PR created, checks passing) →
`healthy` (verification passes on target branch).

**Merge continuity policy:** serialize merges within each lane; keep merging in healthy lanes; pause only
impacted lanes unless cross-lane blast radius triggers a global hold; never merge while required branch
protections are red.

## Workflow

1. **Queue intake** — classify candidate PRs into lanes and risk tiers.
2. **Pre-merge gate** — verify required checks, approvals, and risk-policy gates.
3. **Merge decision** — merge next eligible PR in each healthy lane.
4. **Post-merge watch** — monitor CI signals and map failures to lanes.
5. **Break classification** — identify failure class and auto-fix eligibility.
6. **Cloud fix dispatch** — for eligible failures, open/assign a cloud repair task that must return a PR.
7. **Lane control** — keep unaffected lanes moving; pause impacted lane when policy requires.
8. **Recovery verification** — resume lane only after green verification and policy checks.
9. **Escalation** — open blocking issue and route to humans on policy violations or budget exhaustion.

## Cloud break-fix dispatch policy

Dispatch cloud repair only when all are true:

- Failure class is allow-listed (for example deterministic CI config, flaky test quarantine, dependency pin rollback).
- Changed surface is low/medium risk and outside restricted paths.
- Retry budget not exhausted.
- Repair can be delivered as PR with auditable context.

Otherwise:

- Open blocking issue.
- Mark lane `paused`.
- Request human owner sign-off.

## Output

```yaml
build_master_report:
  repo: "<owner/repo>"
  target_branch: "<branch>"
  lanes:
    - lane: "<name>"
      state: "healthy|degraded|paused|recovering"
      merged_prs: <n>
      blocked_prs: <n>
      active_incident: "<issue-or-null>"
  incidents:
    - id: "<incident-id>"
      lane: "<name>"
      class: "<failure-class>"
      cloud_fix_dispatched: true|false
      fix_pr: "<url-or-null>"
      retries_used: <n>
      escalation: "<none|issue|global-hold>"
  decision:
    action: "continue|pause-lane|global-hold"
    rationale: "<policy reason>"
```
