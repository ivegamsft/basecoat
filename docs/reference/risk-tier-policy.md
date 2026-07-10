# Risk-Tier Autonomy Policy

This document defines the enforcement rules and decision criteria for applying Keep/Fix/Throttle governance across agent workflows and CI/CD pipelines.

## Purpose

The Risk-Tier Autonomy Policy ensures that:

1. **Autonomy is maximized** where safety is high (Tier 1–2: auto-execute, minimal approval)
2. **Safety is enforced** where risk is high (Tier 3–4: explicit approval, comprehensive validation)
3. **Governance is transparent** through consistent labeling, audit logging, and runbook references

---

## Tier Definitions & Enforcement

### Tier 1: Low-Risk (Auto-Execute, No Approval)

**Scope**: Read-only feedback, analysis comments, draft PRs.

**Examples**:

- Code analysis agents (CodeQL, linting feedback)
- Documentation suggestion agents
- Metric dashboards and reporting

**Enforcement Rules**:

| Rule | Implementation |
|------|-----------------|
| No file modifications | Agents restricted to read-only API scope (no write tokens) |
| No secret access | Exclude secrets from agent context; use public API only |
| No deployment | Draft PRs only; no merge capability |
| No approval required | Run unconditionally; log and report results |
| Timeout | None (run to completion) |
| Rollback | N/A (read-only, no state changes) |
| Audit | Log run ID, timestamp, input, output to `AUDIT_LOG.md` (monthly archive) |

**Label**: `tier:1-low-risk`

**Guardrails Checklist**:

```yaml
- [ ] Agent has no write access (API token is read-only)
- [ ] No secrets in agent context or hardcoded
- [ ] Max 1 output artifact (PR comment, report, or draft PR)
- [ ] No file deletes or force-writes
- [ ] Timeout not enforced (graceful completion)
- [ ] Runbook exists: docs/operations/agent-<name>-runbook.md
```

---

### Tier 2: Medium-Risk (Auto-Execute with Guardrails, PR Review)

**Scope**: Staging deployments, feature branch merges, non-critical labels.

**Examples**:

- Fleet deployment agents (staging environment only)
- Automated label management (sprint, area, feature tracking)
- Dependency update agents (feature branches)

**Enforcement Rules**:

| Rule | Implementation |
|------|-----------------|
| Approval required | ≥1 human PR review (GitHub PR review, not comment) |
| Scope restriction | Feature branch only (e.g., `feat/*`); no main/release merge |
| State changes | Permitted within scope (update labels, merge to feature branch) |
| Deployment scope | Staging environment only; no production access |
| Rollback | Automated health check (fail → automatic rollback) |
| Timeout | 2 hours (log warning at 1h; escalate at 2h) |
| Approval escalation | If not approved within 2h, create incident and notify on-call |
| Audit | Log request, approver, timestamp, state changes to `AUDIT_LOG.md` |

**Label**: `tier:2-medium-risk`

**Guardrails Checklist**:

```yaml
- [ ] Agent has limited write scope (feature branches, staging only)
- [ ] Secrets excluded or masked in logs
- [ ] Merge target is feature branch (not main/release)
- [ ] Deployment target is staging (not production)
- [ ] Health check runbook documented
- [ ] Timeout set to 2h with escalation logic
- [ ] Approver has write permission on target branch
- [ ] Runbook includes rollback procedure
```

**GitHub Workflow Example**:

```yaml
# Enforce Tier 2 governance in CI
- name: Check approval status
  if: github.event.workflow_run.conclusion == 'success'
  run: |
    approvals=$(gh pr view ${{ github.event.pull_request.number }} --json reviewDecisions)
    if [[ ! "$approvals" =~ "APPROVED" ]]; then
      echo "Tier 2: Awaiting review approval"
      exit 1
    fi

- name: Deploy to staging with 2h timeout
  timeout-minutes: 120
  run: |
    # Deploy logic here
    ./deploy.sh --target staging

- name: Health check & auto-rollback
  run: |
    if ! ./health-check.sh; then
      echo "Health check failed; rolling back..."
      ./rollback.sh
      exit 1
    fi
```

---

### Tier 3: High-Risk (Approval Required, SLA Verification)

**Scope**: Production merges, quota increases, critical label updates.

**Examples**:

- Production release agents
- Quota increase requests (Azure AI, compute)
- Critical infrastructure label updates

**Enforcement Rules**:

| Rule | Implementation |
|------|-----------------|
| Approval required | Explicit approval via GitHub PR + PRD/spec intake evidence per `prd-spec-gate.yml` (high-change is blocking; risky-path-only findings are advisory) |
| Scope restriction | Main/release branches only; no feature branch bypass |
| SLA verification | Verify: no P0–P1 incidents active, uptime ≥99.5% last 7 days |
| State changes | Destructive (merge, release); require pre-deployment testing |
| Deployment scope | Production environment; full rollout |
| Rollback | Manual only; operator executes `rollback.sh` with audit record |
| Timeout | 4 hours (log warning at 2h; escalate at 4h for team discussion) |
| Audit | Log request, approvers, SLA check, state changes, rollback decision to permanent audit trail |
| Notification | Notify release channel + on-call before and after deployment |

**Label**: `tier:3-high-risk`

**Guardrails Checklist**:

```yaml
- [ ] PRD/spec intake evidence present (`prd-spec-gate.yml`): high-change PRs include both PRD and spec; risky-path-only PRs include at least one reference (advisory warning path, not hard block)
- [ ] SLA verified: no P0–P1 incidents, uptime ≥99.5%
- [ ] Merge target is main or release branch
- [ ] Smoke tests passed (mandatory)
- [ ] Deployment artifact signed (cosign or similar)
- [ ] Artifact scanned for vulnerabilities (trivy, snyk)
- [ ] Rollback procedure documented and tested
- [ ] On-call notified before deployment
- [ ] Approval timestamp recorded
- [ ] Timeout set to 4h with escalation to team
```

**GitHub Workflow Example**:

```yaml
# Enforce Tier 3 governance in release workflow
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment target'
        default: 'production'

jobs:
  verify-sla:
    runs-on: ubuntu-latest
    steps:
      - name: Check for active P0-P1 incidents
        run: |
          incidents=$(gh issue list --label "priority:critical,priority:high" --state open)
          if [[ -n "$incidents" ]]; then
            echo "❌ Active P0-P1 incidents detected. Blocking deployment."
            exit 1
          fi
          echo "✅ No active P0-P1 incidents"

      - name: Verify uptime
        run: |
          uptime=$(./check-uptime.sh --days 7)
          if (( $(echo "$uptime < 99.5" | bc -l) )); then
            echo "❌ Uptime below SLA threshold. Blocking deployment."
            exit 1
          fi
          echo "✅ Uptime verified: ${uptime}%"

  run-smoke-tests:
    runs-on: ubuntu-latest
    steps:
      - name: Execute smoke tests
        run: |
          ./tests/run-smoke-tests.ps1
          if [[ $? -ne 0 ]]; then
            echo "❌ Smoke tests failed. Blocking deployment."
            exit 1
          fi

  sign-artifact:
    runs-on: ubuntu-latest
    steps:
      - name: Sign release artifact
        run: |
          cosign sign-blob --key cosign.key dist/release.tar.gz > release.sig
          echo "✅ Artifact signed"

  scan-artifact:
    runs-on: ubuntu-latest
    steps:
      - name: Scan for vulnerabilities
        run: |
          trivy image dist/release:latest
          if [[ $? -ne 0 ]]; then
            echo "❌ Vulnerability scan failed. Blocking deployment."
            exit 1
          fi

  deploy-production:
    needs: [verify-sla, run-smoke-tests, sign-artifact, scan-artifact]
    runs-on: ubuntu-latest
    steps:
      - name: Notify on-call
        run: |
          gh issue comment ${{ github.event.issue.number }} --body "🚀 Deployment approved and starting. On-call notified."

      - name: Deploy with 4h timeout
        timeout-minutes: 240
        run: |
          ./deploy.sh --target production --artifact-sig release.sig

      - name: Post-deployment validation
        run: |
          ./tests/run-smoke-tests.ps1
          if [[ $? -ne 0 ]]; then
            echo "❌ Post-deployment smoke tests failed. Initiating rollback..."
            ./rollback.sh
            gh issue comment ${{ github.event.issue.number }} --body "⚠️ Post-deployment validation failed. Rollback executed."
            exit 1
          fi
          echo "✅ Deployment successful"
```

---

### Tier 4: Critical-Risk (Manual Only, Admin Approval)

**Scope**: Emergency hotfixes, account-level changes, emergency maintenance.

**Examples**:

- Emergency production hotfix (bypass all CI, requires admin approval)
- Account-level configuration changes (service principal secrets, RBAC)
- Emergency data recovery or disaster recovery

**Enforcement Rules**:

| Rule | Implementation |
|------|-----------------|
| Approval required | Admin + on-call approval (both must explicitly approve) |
| Scope restriction | Manual only; no automation; real-time synchronous approval |
| Pre-approval checklist | Declare incident scope, estimated impact, rollback plan |
| Execution | On-call executes action (not automated); witness required |
| Rollback | Manual by on-call; must be executed within 1 hour if needed |
| Timeout | Real-time (approval must be synchronous; no batch processing) |
| Audit | Complete audit trail: who approved, when, what changed, why, rollback decision |
| Post-incident | Runbook update required within 24h to prevent recurrence |
| Notification | All-hands notification of action taken (during business hours); incident channel notification (24/7) |

**Label**: `tier:4-critical-risk`

**Guardrails Checklist**:

```yaml
- [ ] Incident declared with severity and impact scope
- [ ] Rollback plan documented and tested (before approval)
- [ ] Admin approval obtained (recorded in GitHub issue/comment)
- [ ] On-call approval obtained (recorded in Slack/incident channel)
- [ ] Two-person verification (requester and executor are different)
- [ ] Pre-execution readiness check completed
- [ ] Action executed manually (no automation)
- [ ] Rollback decision documented (approved/declined)
- [ ] Full audit trail archived
- [ ] Post-incident runbook update completed within 24h
```

**Manual Execution Template**:

```bash
#!/bin/bash
# Tier 4 manual action execution template

set -e
INCIDENT_ID=$1
ADMIN_APPROVER=$2
ON_CALL_APPROVER=$3

# Verify approvals
echo "Verifying approvals for incident: $INCIDENT_ID"
gh issue comment $INCIDENT_ID --body "🔒 Tier 4: Awaiting dual approval (Admin + On-Call)"

# Wait for approvals (manual process)
read -p "Admin approver name: " ADMIN_NAME
read -p "On-call approver name: " ONCALL_NAME

# Log approvals
echo "[$(date)] Admin approval: $ADMIN_NAME" >> audit.log
echo "[$(date)] On-call approval: $ONCALL_NAME" >> audit.log

# Execute action with witness
echo "⚠️  EXECUTING TIER 4 ACTION FOR: $INCIDENT_ID"
echo "Witness: $ONCALL_NAME"
echo "Rollback plan: <documented>"

# Real action here
# ./emergency-action.sh $INCIDENT_ID

# Log execution
echo "[$(date)] Action executed by $ONCALL_NAME" >> audit.log

# Verify rollback readiness
read -p "Rollback executed? (yes/no): " ROLLBACK_DECISION
echo "[$(date)] Rollback decision: $ROLLBACK_DECISION" >> audit.log

# Archive audit
gh issue comment $INCIDENT_ID --body "✅ Tier 4 action complete. Audit trail: audit.log"
```

---

## Decision Matrix

Use this matrix to classify an operation and apply the correct tier:

```text
Operation Classification Decision Tree
├─ Read-only (no state changes)?
│  └─ Yes → Tier 1 (auto-execute, no approval)
├─ Non-production changes only (staging, feature branch)?
│  ├─ Approve automatically?
│  │  └─ No, requires review → Tier 2 (PR review, 2h timeout)
├─ Production merge or critical state change?
│  ├─ Routine (e.g., weekly release)?
│  │  └─ → Tier 3 (SLA check, explicit approval, smoke tests)
│  ├─ Emergency (e.g., P0 hotfix)?
│  │  └─ → Tier 4 (manual, admin + on-call approval)
└─ Account-level or destructive?
   └─ → Tier 4 (manual only)
```

---

## Compliance Tracking

### Tier Assignment

Every workflow and agent must be tagged with its tier:

```yaml
# .github/workflows/example.yml
name: Example Workflow
on: [pull_request]

env:
  RISK_TIER: "2"  # or 1, 3, 4

jobs:
  enforce-tier:
    runs-on: ubuntu-latest
    steps:
      - name: Validate tier governance
        run: |
          TIER=${{ env.RISK_TIER }}
          if [[ "$TIER" == "2" ]]; then
            # Enforce PR review requirement
            approvals=$(gh pr view ${{ github.event.pull_request.number }} --json reviewDecisions)
            [[ "$approvals" =~ "APPROVED" ]] || exit 1
          fi
```

### Audit Logging

Centralized audit trail for all tier actions:

**Location**: `docs/operations/AUDIT_LOG.md` (monthly archive to `AUDIT_LOG_YYYY-MM.md`)

**Format**:

```markdown
## 2026-06-14

### Tier 1: Code Analysis Agent
- Time: 14:30 UTC
- Run ID: ca_v1_20260614_1430_a1b2c3d4e5f6
- Status: ✅ Complete
- Output: Flagged 3 linting issues, 1 security concern (low)

### Tier 2: Staging Fleet Deploy
- Time: 16:45 UTC
- Request: Deploy v3.42.1 to staging
- Approvers: alice, bob
- Status: ✅ Deployed, health check passed
- Rollback: Not required

### Tier 3: Production Release
- Time: 09:00 UTC
- Release: v3.42.0
- SLA verified: ✅ No P0-P1, uptime 99.8%
- Smoke tests: ✅ Passed
- Status: ✅ Deployed
- Rollback: Not required

### Tier 4: Emergency Hotfix
- Time: 23:15 UTC
- Incident: P1 - API auth failure
- Approvers: admin@company, oncall@company
- Action: Deployed security patch (commit abc1234)
- Status: ✅ Complete
- Rollback decision: Not required
- Post-incident: Runbook updated 2026-06-15 10:00 UTC
```

---

## Enforcement Integration

### GitHub Actions Integration

Tier enforcement is integrated into CI/CD pipelines via:

1. **Tier tags** in workflow files (`env.RISK_TIER`)
2. **Status checks** that validate tier requirements before merge
3. **Audit logging** in GitHub issue comments and centralized logs
4. **Timeout enforcement** via GitHub Actions `timeout-minutes`

### Workflow Examples

See `.github/workflows/` for examples:

- **Tier 1**: `code-review-agent.yml`, `security-analyst.yml`
- **Tier 2**: `auto-approve-cloud-agent-workflows.yml`, `auto-enlist.yml`
- **Tier 3**: `release.yml`, `publish-to-production.yml`
- **Tier 4**: Manual actions (not automated; see emergency procedures)

---

## Related Documentation

- `docs/operations/keep-fix-throttle-model.md` — Overall framework (Keep/Fix/Throttle)
- `docs/operations/operational-runbook.md` — Runbook template for each tier
- `.github/instructions/workflow-conventions.instructions.md` — Workflow defaults
- `docs/reference/governance-contract.md` — Governance labels and taxonomy
