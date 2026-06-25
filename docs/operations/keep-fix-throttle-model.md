# Keep/Fix/Throttle Operating Model

This document defines the Keep/Fix/Throttle governance framework for balancing agent autonomy with safety and operational reliability.

## Overview

The Keep/Fix/Throttle model is a 3-tier approach to standardize proven patterns, prioritize recurring failures, and apply risk-based governance:

| Tier | Definition | Timeline | Owner | Success Measure |
|------|-----------|----------|-------|-----------------|
| **Keep** | Standardize patterns that consistently improve throughput | Ongoing | Product | Pattern adoption rate ≥80% |
| **Fix** | Prioritize recurring failure modes as first-class product work | 1–2 week cycle | Engineering | MTTR reduction ≥20% |
| **Throttle** | Apply risk-tier governance instead of broad restrictions | Per-deployment | Governance | Autonomy maintained while reducing incident rate ≥15% |

## Workstream Execution Tracker (Epic #1452)

The six execution workstreams are tracked as dedicated issues with explicit owners and measurable outcomes:

| Workstream | Tracker | Owner | Delivery signal |
|---|---|---|---|
| 1. Standardize proven patterns as defaults | [#2046](https://github.com/IBuySpy-Shared/basecoat/issues/2046) | @ibuyspy | ≥3 patterns promoted and adoption target met |
| 2. Reliability debt program for recurring failures | [#2047](https://github.com/IBuySpy-Shared/basecoat/issues/2047) | @ibuyspy | Top recurring failures fixed with MTTR/recurrence targets |
| 3. Tooling routing matrix (local/background/cloud/manual) | [#2048](https://github.com/IBuySpy-Shared/basecoat/issues/2048) | @ibuyspy | Routing defaults published and orchestration overhead reduced |
| 4. Risk-tier autonomy policy enforcement | [#2049](https://github.com/IBuySpy-Shared/basecoat/issues/2049) | @ibuyspy | Tier coverage + enforcement guardrails in place |
| 5. Weekly scorecard + trend reporting | [#2050](https://github.com/IBuySpy-Shared/basecoat/issues/2050) | @ibuyspy | Weekly scorecard cadence with trend classification |
| 6. 4-6 week adoption experiment and readout | [#2051](https://github.com/IBuySpy-Shared/basecoat/issues/2051) | @ibuyspy | Experiment complete with go/no-go readout |

### Workstream 5 delivery path

The weekly scorecard and trend readout pipeline is implemented with:

- Workflow: `.github/workflows/keep-fix-throttle-weekly-scorecard.yml`
- Generator: `scripts/keep-fix-throttle-weekly-scorecard.ps1`
- Runbook: `docs/operations/keep-fix-throttle-weekly-scorecard.md`
- Spec: `docs/spec/keep-fix-throttle-weekly-scorecard.spec.md`

### Baseline Snapshot (captured 2026-06-25)

The baseline below is captured before workstream rollout and used as the experiment start point.

| Metric | Baseline value | Collection window / source |
|---|---|---|
| Throughput proxy (merged PRs/day) | 10.0 | Last 30 days (`gh pr list`, capped at 300 results) |
| Workflow failure rate | 0.0% | Last 14 days (`gh run list`, capped at 500 runs) |
| Manual intervention proxy (approved merged PR share) | 100.0% | Last 30 days (`gh search prs review:approved`) |
| Open P0 incidents | 0 | Snapshot (`gh issue list --label P0-critical`) |
| Open P1 incidents | 1 | Snapshot (`gh issue list --label P1-high`) |
| P0/P1 incident creation rate | 7 in 30 days | Last 30 days (`gh issue list --search created:>=...`) |

## 1. Keep: Standardize Proven Patterns

Patterns that meet the "Keep" criteria are standardized as defaults and documented for reuse.

### Criteria for "Keep"

- **Consistency**: Successfully used in ≥3 independent contexts (agent types, workflows, repos)
- **Throughput**: Measurable improvement: ≥20% faster task completion or ≥30% reduction in manual intervention
- **Safety**: Zero critical failures (P0) over ≥2 weeks of production use
- **Documentation**: Runbook exists and covers prerequisites, decision points, and rollback steps

### "Keep" Tracking

Kept patterns are documented in:

- `docs/guides/kept-patterns/` — Consolidated runbooks for each pattern
- `docs/guides/kept-patterns/README.md` — Keep registry with adoption targets
- `docs/guides/keep-candidate-acceptance-checklist.md` — Promotion gates for future candidates
- `.github/instructions/workflow-conventions.instructions.md` — Embedded defaults
- `.github/instructions/cost-optimization.instructions.md` — Token-efficiency defaults and thresholds
- `docs/reference/governance-contract.md` — Standardized naming and labels

### Example: PR-Only Agent Pattern

**Pattern**: Agents with PR-only scope (no direct merges, no file edits outside PR context).

**Consistency**: Used in 5+ workflows (code-review-agent, security-analyst, release-impact-advisor, etc.).

**Throughput**: Reduces approval latency by 25% (reviewers see structured PR diff + agent comment).

**Safety**: Zero critical failures in 8 weeks; 1 low-severity false positive (already fixed).

**Documentation**: `docs/guides/agent-pr-safety-protocol.md` and `.github/workflows/code-review-agent.md`.

**Status**: ✅ KEEP (standardize as default for new agents).

### Current promoted defaults (Workstream 1, #2046)

1. **Phase-boundary compaction** (`/compact` between major phases).
2. **File-reference-only context loading** (no large instruction pastes).
3. **Single kickoff plus `/tasks` monitoring** (delta steering, no repeated orchestration restarts).

Each promoted default has a runbook under `docs/guides/kept-patterns/` and is
wired into default guidance under `.github/instructions/`.

---

## 2. Fix: Reliability Debt Program

Recurring failures are elevated to first-class product work with owners and measurable SLOs.

### Criteria for "Fix"

- **Recurrence**: Failure occurs ≥2 times per week across any agent or workflow over ≥2 consecutive weeks
- **Impact**: Blocks ≥1 team member or delays ≥1 release artifact by ≥4 hours
- **Root cause identifiable**: Issue can be traced to one of:
  - Configuration drift or undocumented assumption
  - Missing validation or guard clause
  - Dependency or external service failure
  - Race condition or timing issue

### "Fix" Workflow

1. **Triage**: Failure logged in `docs/operations/failure-pattern-consumer-process.md`
2. **Root cause analysis**: Owner assigned; analysis completed within 3 business days
3. **Fix committed**: Repair implemented and deployed; monitored for recurrence
4. **Validation**: Zero recurrence over ≥2 weeks; update runbook and guard rails
5. **Archive**: Documented in `docs/operations/failure-archive.md` with resolution details

For issue #2047 execution, enforce minimum-slice acceptance fields in
`docs/operations/failure-pattern-run-contract.md` (`top3_failures`,
`mttr_improvement_pct`, `recurrence_rate_2w_pct`).

### SLO Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| MTTR (Mean Time to Repair) | ≤24 hours | From first detection to fix deployed |
| Recurrence rate after fix | ≤10% | Same failure within 2 weeks post-fix |
| Owner assignment latency | ≤4 hours | From "Fix" decision to owner tagged |

### Example: Workflow Timeout on Long Test Suites

**Failure**: Tests timeout at 30 min, blocking deployments every 3–4 days.

**Root cause**: No adaptive timeout; suite runs slower on weekends.

**Fix**: Dynamic timeout based on historical percentile + 20% buffer.

**SLO tracking**: Deployed Wed. Zero timeouts in 2 weeks. Archived as resolved.

---

## 3. Throttle: Risk-Tier Autonomy Policy

Governance applied per risk tier rather than across-the-board restrictions; autonomy preserved for low-risk patterns.

### Risk Tiers

| Tier | Scope | Autonomy | Approval | Example |
|------|-------|----------|----------|---------|
| **Tier 1: Low risk** | Comments, suggestions, draft PRs | Full (auto-execute) | None | Code suggestion agent |
| **Tier 2: Medium risk** | Merges to feature branches, non-production labels | Constrained (auto-execute with guardrails) | PR review + 1 approval | Fleet deployment to staging |
| **Tier 3: High risk** | Merges to main/release, secret rotation, quota changes | Supervised (requires explicit approval) | Explicit approval + SLA verification | Production release, quota increase |
| **Tier 4: Critical risk** | Rollback, emergency maintenance, account-level changes | Manual only | Admin + on-call approval | Emergency prod hotfix, account settings |

### Throttle Governance Matrix

For each tier, governance rules define what is permitted:

#### Tier 1 Rules (Low Risk)

```yaml
# Example: Code suggestion agent
Tier: 1
Actions allowed:
  - Post PR comments (suggestions, analysis)
  - Create draft PRs (no merge)
  - Add labels (doc, refactor, review-me)
Approvals required: None
Timeout: N/A (runs to completion)
Rollback: N/A (read-only feedback)
Guardrails:
  - Comment length ≤500 chars
  - Max 1 draft PR per issue
  - No destructive operations (no file deletes, secret writes)
```

#### Tier 2 Rules (Medium Risk)

```yaml
# Example: Fleet deployment to staging
Tier: 2
Actions allowed:
  - Merge to feature branches
  - Deploy to staging
  - Update non-critical labels/milestones
Approvals required: PR review (≥1 human approval)
Timeout: 2 hours (requires escalation if not merged)
Rollback: Automated if health check fails
Guardrails:
  - No merge to main/release branches
  - Staging deployment only
  - Automated health check before cleanup
```

#### Tier 3 Rules (High Risk)

```yaml
# Example: Production release
Tier: 3
Actions allowed:
  - Merge to main (release branch only)
  - Production deployment
  - Quota increases up to 10% current value
Approvals required: Explicit approval + PRD/spec gate validation
Timeout: 4 hours (requires escalation + team discussion)
Rollback: Manual (operator must execute rollback.sh)
Guardrails:
  - Automated smoke tests pass
  - SLA verified (no ongoing incidents P0–P1)
  - Deployment artifact signed and scanned
```

#### Tier 4 Rules (Critical Risk)

```yaml
# Example: Emergency production hotfix
Tier: 4
Actions allowed:
  - Manual merge and deploy
  - Account-level configuration changes
  - Emergency data recovery
Approvals required: Admin + on-call approval
Timeout: Real-time (synchronous approval required)
Rollback: Manual by on-call; audit trail required
Guardrails:
  - Two-person rule
  - Post-incident runbook update
  - Audit log archived
```

---

## 4. Measuring Success

### Baseline Metrics (Captured Before Changes)

Before deploying any KFT workstreams, capture baseline:

| Metric | How to measure | Target |
|--------|-----------------|--------|
| Agent throughput (tasks/day) | GitHub Actions workflow run count | +20% within 30 days |
| Failure rate (% failed runs) | Failed workflow / total runs | ≤5% after 30 days |
| MTTR (hours) | Time from alert to fix deployed | ≤24 hours |
| Manual intervention frequency | PRs requiring manual approval | -30% for Tier 1–2 |
| Incident rate (P0–P1/month) | Critical issues affecting team | ≤2/month |

### Ongoing Monitoring

| Cadence | Metric | Owner | Action |
|---------|--------|-------|--------|
| Weekly | Agent success rate by tier | Engineering | Alert if >7% failure rate |
| Weekly | MTTR trend (rolling 2-week avg) | Engineering | Escalate if >24 hours |
| Bi-weekly | "Keep" pattern adoption | Product | Review low-adoption patterns |
| Monthly | Risk tier autonomy balance | Governance | Report autonomy vs safety tradeoff |
| Quarterly | Failure archive review | Governance | Archive resolved issues; identify trends |

---

## 5. Adoption Phases

### Phase 1: Establish Baseline (Week 1–2)

- Capture baseline metrics for all tiers
- Document current "Keep" patterns and "Fix" recurring failures
- Create governance matrix for risk tiers
- Communicate model to team

### Phase 2: Standardize "Keep" Patterns (Week 3–4)

- Promote 3–5 proven patterns to "Keep" status
- Update `.github/instructions/` with defaults
- Deploy runbooks for each kept pattern

### Phase 3: Launch "Fix" Program (Week 5–6)

- Assign owners to top 3 recurring failures
- Commit fixes for each failure
- Monitor recurrence rate

### Phase 4: Deploy Tier Governance (Week 7–8)

- Enforce throttle rules in CI/CD and agent workflows
- Enable audit logging for Tier 3–4 actions
- Monitor autonomy metrics weekly

### Phase 5: Measure & Iterate (Week 9+)

- Publish monthly readout (velocity, failure rate, autonomy balance)
- Gather team feedback on model effectiveness
- Adjust tiers or criteria based on feedback

---

## 6. Related Documentation

- `.github/instructions/workflow-conventions.instructions.md` — Workflow defaults and routing
- `docs/reference/risk-tier-policy.md` — Full governance matrix and enforcement rules
- `docs/operations/failure-pattern-consumer-process.md` — Failure triage workflow
- `docs/operations/operational-runbook.md` — Runbook template for kept patterns
- `docs/reference/governance-contract.md` — Label taxonomy and governance labels
- `docs/design/pr-only-agent-responsibility-model.md` — PR-only tiered responsibility design

---

## 7. Decision Tree

Use this tree to classify patterns and operations:

```text
Is this a documented pattern consistently improving throughput?
├─ Yes & meets "Keep" criteria → KEEP (standardize as default)
├─ No, is this a recurring failure?
   ├─ Yes (≥2x/week) & impacts team → FIX (assign owner, set SLO)
   └─ No → proceed to risk tier check
└─ Risk tier check:
   ├─ Tier 1 (read-only, draft PRs) → THROTTLE (auto-execute, no approval)
   ├─ Tier 2 (staging deploy, feature branch merge) → THROTTLE (auto-execute, PR review)
   ├─ Tier 3 (production merge, quota change) → THROTTLE (approval required, SLA check)
   └─ Tier 4 (emergency, account changes) → THROTTLE (manual + admin approval)
```

---

## Glossary

- **Pattern**: A repeatable, documented process or workflow (e.g., PR-only agent, auto-merge-on-approval)
- **Risk tier**: Category defining approval, timeout, and rollback rules
- **Autonomy**: Degree to which an agent or workflow executes without human intervention
- **Throttle**: To apply governance rules (approval, timeouts) based on risk tier
- **MTTR**: Mean Time To Repair — average time from failure detection to fix deployed
- **SLO**: Service Level Objective — target for reliability or performance
