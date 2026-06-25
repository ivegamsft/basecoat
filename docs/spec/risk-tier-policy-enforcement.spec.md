# Risk-Tier Policy Enforcement — Technical Specification

**Feature**: Risk-Tier Autonomy Policy (Epic #1452, Workstream 4)  
**Issue**: [#2049](https://github.com/IBuySpy-Shared/basecoat/issues/2049)  
**Scope**: Enforcement guardrails, workflow classification, and approval gating for Tier 1–4 actions  
**Status**: Design  
**Created**: 2026-06-25

## Overview

This spec defines the technical implementation of risk-tier governance enforcement, including:

1. **Approval routing** — Gate workflows based on tier classification
2. **Timeout enforcement** — Escalate if approval pending beyond tier timeout
3. **Audit logging** — Record all Tier 3–4 actions with timestamps and actors
4. **Label validation** — Enforce `risk-tier:N` labels on all in-scope workflows
5. **Rollback automation** — Provide tier-specific rollback procedures

## Success Criteria

- [ ] All high-risk workflows tagged with `risk-tier:N` label (coverage = 100%)
- [ ] Approval gating enforced for Tier 3–4 actions (PR gate blocks merge if missing approval)
- [ ] Timeout escalation implemented for Tier 2–3 (alerts after timeout period)
- [ ] Audit logging captures all Tier 3–4 actions (complete audit trail)
- [ ] Policy-to-workflow mapping document published and reviewed
- [ ] Incident rate for Tier 3–4 actions measured and baselined

## Design

### 1. Workflow Classification (Tier Assignment)

#### 1.1 Classification Process

Each workflow must be classified into exactly one tier:

```text
Inputs:
- Workflow name
- Workflow description (from .md file or YAML comments)
- Workflow actions (reads/writes/deploys)
- Environment affected (staging/production/account-level)
- Rollback capability (reversible? documented?)

Decision tree:
1. Is it read-only or draft-only? → Tier 1
2. Does it affect feature branches or staging? → Tier 2
3. Does it affect production or involve quota changes? → Tier 3
4. Is it emergency or account-level? → Tier 4
5. Unclassified → Default to Tier 3
```

#### 1.2 Classification Output

For each workflow, document:

```yaml
workflow: <name>
tier: <1|2|3|4>
rationale: <brief reason for tier assignment>
examples:
  - <action 1>
  - <action 2>
approval_required: <true|false>
approval_timeout_policy: <none|8h|4h|sync>
audit_required: <true|false>
rollback_procedure: <link to runbook or "N/A">
```

### 2. Label Enforcement

#### 2.1 Label Schema

All in-scope workflow changes must carry exactly one label from this set:

```text
risk-tier:1  (Tier 1: Read-only, auto-execute)
risk-tier:2  (Tier 2: Feature branch, PR review)
risk-tier:3  (Tier 3: Production, explicit approval)
risk-tier:4  (Tier 4: Critical, two-person rule)
```

Applied to:

- PRs and issues that modify GitHub workflow files (`.github/workflows/*.yml`)
- Agents and skills that perform actions
- Issues requesting risky operations
- PRs that contain risky changes

#### 2.2 Label Validation

Enforce via GitHub issue templates and PR templates:

```text
- [ ] Assign a single risk-tier label (risk-tier:1/2/3/4)
- [ ] If Tier 3+, provide PRD and spec links
- [ ] If Tier 4, confirm on-call coverage
```

### 3. Approval Gating

#### 3.1 Tier 1 Gating

- **Gate**: None (auto-execute)
- **Action**: Workflow runs immediately on trigger
- **Log**: Record execution in audit log

#### 3.2 Tier 2 Gating

- **Gate**: PR review required (1 approval)
- **Action**: PR cannot merge without approval
- **Timeout**: Alert if pending >8 hours
- **Implementation**: GitHub branch protection rule

#### 3.3 Tier 3 Gating

- **Gate**: Explicit approval required
- **Prerequisites**:
  - PRD and spec links in PR description (prd-spec-gate.yml)
  - Automated tests passed
  - No P0/P1 incidents open
- **Action**: PR cannot merge without approval
- **Timeout**: Alert if pending >4 hours; escalate to team lead
- **Implementation**: GitHub PR approval + custom workflow check

#### 3.4 Tier 4 Gating

- **Gate**: Two-person rule (admin + on-call)
- **Prerequisites**:
  - Emergency ticket or incident linked
  - Full justification in PR body
  - On-call engineer explicitly approves
- **Action**: Cannot proceed without both approvals
- **Timeout**: Synchronous (no async queue); must complete in real-time
- **Implementation**: Custom approval workflow + Slack notification

### 4. Timeout Enforcement

#### 4.1 Tier 2 Timeout (8 hours)

```yaml
# Workflow: .github/workflows/tier2-approval-timeout.yml
trigger: pull_request
check:
  - Get last approval timestamp
  - If pending >8 hours:
    - Add "approval-timeout" label
    - Post comment: "Approval pending >8 hours. Please review or escalate."
    - Notify code owner
```

#### 4.2 Tier 3 Timeout (4 hours)

```yaml
# Workflow: .github/workflows/tier3-approval-timeout.yml
trigger: pull_request
check:
  - Get last approval timestamp
  - If pending >4 hours and not approved:
    - Add "approval-timeout" label
    - Post comment: "Approval pending >4 hours. Escalating to [team-lead]."
    - Notify team lead
    - Flag for daily standup
```

### 5. Audit Logging

#### 5.1 Tier 3–4 Audit Trail

All Tier 3–4 actions must log:

```json
{
  "timestamp": "2026-06-25T10:30:00Z",
  "action": "production_deploy",
  "tier": 3,
  "actor": "github-actions[bot]",
  "approver": "alice@example.com",
  "approval_timestamp": "2026-06-25T10:25:00Z",
  "workflow": "publish-to-production",
  "pr_number": 12345,
  "result": "success|failure",
  "details": "Deployed v3.15.0 to production"
}
```

#### 5.2 Audit Log Storage

- **Location**: `reports/audit-trail-tier3-4.jsonl` (append-only)
- **Retention**: 1 year minimum
- **Access**: Read-only for compliance and RCA
- **Compliance**: GDPR-compliant; PII redacted

### 6. Workflow Mapping Document

Create `docs/operations/risk-tier-workflow-mapping.md` with:

```markdown
# Risk-Tier Workflow Classification

| Workflow | Tier | Rationale | Rollback |
|----------|------|-----------|----------|
| issue-triage.yml | 1 | Read-only analysis | N/A |
| pr-validation.yml | 2 | Tests + staging validation | Revert commit |
| publish-to-production.yml | 3 | Production deploy | Manual by operator |
| emergency-hotfix.yml | 4 | Emergency production fix | Manual by on-call + audit |
| ... | ... | ... | ... |
```

## Implementation Phases

### Phase 1: Documentation & Classification (Week 1)

- [ ] Publish `docs/reference/risk-tier-policy.md` (governance matrix)
- [ ] Publish `docs/spec/risk-tier-policy-enforcement.spec.md` (this spec)
- [ ] Create `docs/operations/risk-tier-workflow-mapping.md` (workflow classification)

### Phase 2: Label Enforcement (Week 2)

- [ ] Add `risk-tier:N` labels to all GitHub workflows
- [ ] Update issue templates to include tier label selection
- [ ] Update PR template to require PRD/spec for Tier 3+

### Phase 3: Approval Gating (Week 3)

- [ ] Implement Tier 2 PR review gate (branch protection rule)
- [ ] Implement Tier 3 approval gate (workflow + GitHub checks)
- [ ] Implement Tier 4 two-person approval gate
- [ ] Wire prd-spec-gate.yml to tier labels

### Phase 4: Timeout Enforcement (Week 4)

- [ ] Implement Tier 2 timeout alerts (8 hours)
- [ ] Implement Tier 3 timeout alerts (4 hours)
- [ ] Wire to Slack notifications and escalation playbook

### Phase 5: Audit Logging (Week 5)

- [ ] Implement Tier 3–4 audit trail logging
- [ ] Create audit log viewer dashboard
- [ ] Wire to compliance and RCA workflows

## Rollback Procedures by Tier

### Tier 1 Rollback

No rollback needed (read-only, no state change).

### Tier 2 Rollback

1. Author or code owner initiates revert: `git revert <commit>`
2. PR review required for revert (same as original change)
3. Merge revert to feature branch

### Tier 3 Rollback

1. On-call engineer receives alert
2. Execute rollback runbook: `./rollback.sh --version <prior-version>`
3. Verify rollback via smoke tests
4. Document in runbook why rollback occurred

### Tier 4 Rollback

1. On-call engineer + admin execute together (two-person rule)
2. Execute custom rollback procedure for emergency (e.g., restore from backup)
3. Archive full audit trail of actions taken
4. Create RCA ticket for post-incident review

## Monitoring and Metrics

### Weekly Metrics

- Total workflows by tier (trend)
- Approval rate by tier (% requiring approval that completed on time)
- Timeout incidents by tier

### Monthly Metrics

- Incident rate for Tier 3–4 actions (target: ≤15% reduction)
- Rollback count by tier (trend, target: <5% for Tier 2–3)
- MTTR by tier (mean time to repair; target: <24 hours for Tier 3)

### Compliance Metrics

- Workflow tier label coverage (target: 100%)
- PRD/spec gate pass rate (target: 100% for Tier 3+)
- Audit trail completeness for Tier 4 (target: 100%)

## Testing Strategy

### Unit Tests

- [ ] Tier classification logic (decision tree)
- [ ] Label validation (exactly one tier label)
- [ ] Timeout calculation (pending time > threshold)

### Integration Tests

- [ ] PR gate blocks merge on missing approval
- [ ] Timeout alert fires after threshold
- [ ] Audit log entry created for Tier 3+ action
- [ ] Tier 4 requires both approvals before proceeding

### E2E Tests

- [ ] Tier 1 workflow executes without approval
- [ ] Tier 2 workflow requires PR review; blocks without it
- [ ] Tier 3 workflow requires explicit approval + PRD/spec
- [ ] Tier 4 workflow requires two-person approval + async check

## Risk & Mitigation

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Tier misclassification | Reduced autonomy or increased incidents | Weekly classification audit; escalation procedure for edge cases |
| Timeout alert spam | Alert fatigue; ignored alerts | Configure threshold based on typical approval time; team owns SLO |
| Audit log storage bloat | Cost and performance degradation | Compress logs monthly; archive to cold storage after 1 year |
| Tier 4 two-person rule bottleneck | Slow emergency response | Pre-identify on-call rota; have pre-approved emergency procedures |

## Open Questions

1. Should emergency escalation allow async approval (Slack thread) or require real-time sync?
   - **Decision**: Real-time sync required for Tier 4 (no async queueing).

2. What is the approval SLA for Tier 3?
   - **Decision**: 4-hour timeout; escalate to team lead if pending.

3. Who can approve Tier 3 vs Tier 4 actions?
   - **Decision**: TBD per team policy; recommend repo owner for Tier 3, on-call for Tier 4.

---

## References

- [Epic #1452: Keep/Fix/Throttle Operating Model](https://github.com/IBuySpy-Shared/basecoat/issues/1452)
- [Issue #2049: Workstream 4 — Enforce Risk-Tier Autonomy Policy](https://github.com/IBuySpy-Shared/basecoat/issues/2049)
- [docs/operations/keep-fix-throttle-model.md](../operations/keep-fix-throttle-model.md)
- [.github/workflows/prd-spec-gate.yml](../../.github/workflows/prd-spec-gate.yml)
