# AIDL Portfolio Operator Playbook

This playbook describes day-to-day operation of portfolio management under AIDL framing.

## Operating Model

1. BaseCoat defines guardrails and evaluates policy conformance.
2. GitHub Projects tracks state, ownership, risk, and execution evidence.
3. Operators run with rules-first automation and actions for complex integration.

## Role Responsibilities

| Role | Primary concerns | Core artifacts |
| --- | --- | --- |
| Product/Portfolio | prioritization, roadmap, backlog quality | Roadmap view, Backlog view |
| Engineering | build/review/release flow | Sprint view, PR queue |
| SRE | reliability and incident closure loop | Incident view, Maintenance view |
| Security/Governance | policy and control conformance | Security view, Audit reports |

## Core Daily Workflow

1. Review blocked/high-risk items.
2. Triage new issues and incidents.
3. Validate guardrail state transitions.
4. Ensure PRs are linked to tracked work.
5. Route incidents to remediation work when needed.

## Sprint Ceremonies

### Planning

Conducted by: Portfolio, Engineering, SRE leads
Cadence: Sprint start (bi-weekly or sprint-specific)
Duration: 2 hours

- [ ] **Backlog quality**: Run issue-triage agent on new items; confirm labeling, priority, and scope clarity
- [ ] **Capacity and commitment**: Validate sprint capacity (headcount, skill availability); confirm capacity constraints
- [ ] **High-risk controls**: Audit `Risk=High` and `Guardrail State=Block` items; ensure mitigations are scoped
- [ ] **Dependencies**: Flag cross-team and external dependencies; confirm ownership and communication
- [ ] **SRE readiness**: Review maintenance debt and on-call rotation; confirm support availability

### Mid-Sprint Checkpoints

Conducted by: Engineering, SRE leads
Cadence: Mid-sprint sync (1x per sprint)
Duration: 1 hour

- [ ] **Flow and bottlenecks**: Review PR queue, review latency, cycle time; identify blockers
- [ ] **Incident-to-backlog latency**: Check incident ingestion lag; verify remediation items are queued
- [ ] **Guardrail state**: Scan for new `Guardrail State=Block` or `Guardrail State=Warn` items; trigger escalation if needed
- [ ] **Waiver usage and expiry**: Review active waivers; flag items expiring within 5 days
- [ ] **Learning capture**: Check for `Learning Capture=Candidate` items; triage and promote as needed

### Sprint Closeout

Conducted by: Portfolio, Engineering, SRE, Security leads
Cadence: Sprint end
Duration: 1.5 hours

- [ ] **Done criteria verification**: Audit completed items against DoD (testing, documentation, acceptance criteria)
- [ ] **Release readiness**: Run release-readiness-chair agent; confirm all governance checks pass
- [ ] **Spillover and carry-forward**: Review unfinished items; assign carry-forward owners; document spillover reasons
- [ ] **Metrics and trends**: Collect velocity, cycle time, incident counts; compare to SLA
- [ ] **Learning capture**: Review all candidates; promote accepted ones to memory artifacts

### Retrospective

Conducted by: Full delivery team
Cadence: End of sprint (or after release)
Duration: 1 hour

- [ ] **What went well**: Capture successes and process improvements
- [ ] **What did not go well**: Triage blockers; categorize by type (tooling, process, dependency, skill gap)
- [ ] **Action items**: Create issues for process improvements; assign owners and due dates
- [ ] **Metrics review**: Compare actual vs projected velocity, incident impact, on-time delivery
- [ ] **Knowledge capture**: Promote high-impact learnings to decision logs and guidance artifacts

## Rules vs Actions Policy

Use Project Rules for:

1. Auto-add and basic routing
2. Label-to-field mapping
3. Common status transitions

Use Actions for:

1. Cross-repo aggregation
2. External monitoring and incident ingestion
3. Memory promotion pipelines
4. Complex conditional workflows

## Required Project Baseline

## Required fields

`Status`, `Type`, `Priority`, `Iteration`, `Area`, `Effort`, `Risk`, `Guardrail State`, `SRE Impact`, `Runbook Link`, `Learning Capture`

## Required views

1. Sprint Delivery
2. Backlog
3. PR and Review Queue
4. Security and High Risk
5. Incidents and Reliability
6. Maintenance and Audit
7. Learning and Memory
8. Roadmap

## Incident-to-Backlog Routing

When an incident is opened or escalated:

1. **Triage by incident-responder agent**: Classify severity, estimate MTTR, identify primary affected system.
2. **Create or link remediation issue**:
   - Title: `[Incident] <root cause> — remediation for <affected system>`
   - Labels: `type:incident-remediation`, and `priority:P0`, `priority:P1`, `priority:P2`, or `priority:P3` depending on severity (P0 = Critical, P1 = High, P2 = Medium, P3 = Low)
   - Link issue to incident in Projects
3. **Set portfolio fields**:
   - `Type`: `Incident` or `Incident Remediation`
   - `Priority`: Critical, High, Medium, or Low
   - `Risk`: Critical, High, Medium, or Low
   - `SRE Impact`: None, Latency, Availability, Error Rate, or Capacity
   - `Guardrail State`: Pass, Warn, Block, or Waived
   - `Runbook Link`: `docs/operations/operational-runbook.md` (or path to specific playbook section)
   - `Learning Capture`: None, Candidate, or Promoted
4. **Route to engineering or SRE**: Assign owner; set Iteration for sprint placement
5. **Track closure**: Update `Learning Capture=Candidate` and run retrospective
6. **Verify recurrence**: In next incident, check if same root cause has remediation item; if yes, measure remediation lag

### Example: Database Query Performance Incident

```text
Incident created: 2024-03-15T14:22Z
- Symptom: API p99 latency spiked to 5s, recovery within 2h
- Root Cause: Missing index on frequently-scanned column
- Severity: P2 (Medium)
- SLO Impact: Near-miss (SLO was 95th pct <2s)

Remediation Issue created:
- Title: [Incident] Missing index on user_accounts.created_at — remediation
- Labels: type:incident-remediation, priority:P1, area:data-tier
- Portfolio fields:
  - Type: Incident Remediation
  - Priority: High
  - Risk: High
  - SRE Impact: Latency (if it recurs)
  - Guardrail State: Warn
  - Runbook Link: `docs/operations/operational-runbook.md`
  - Iteration: Sprint 38 (placed in planning)

Resolution:
- Index added in Sprint 38
- Query perf verified in staging
- Learned in retrospective: "Add query plan analysis to CI gate"
```

## Learning and Memory Promotion Workflow

Learning capture flows from sprint retrospectives to permanent BaseCoat guidance:

1. **Identify candidates**: In retrospective, mark items with `Learning Capture=Candidate`.
2. **Evaluate quality**: Assess recurrence (has this problem appeared >2x?), impact (did it affect multiple teams?), and generalizability (can other teams reuse the solution?).
3. **Promote to memory**: High-quality candidates move to `Learning Capture=Promoted` and are authored into guidance:
   - **Decision Log**: Process or policy decisions (file in `docs/decisions/`)
   - **Runbook**: Operational procedures (file in `docs/operations/`)
   - **Instruction**: Reusable guidance (file in `.github/instructions/`)
   - **Skill**: Multi-step workflow (file in `skills/<name>/`)
   - **Agent**: Complex agentic workflow (file in `agents/`)
4. **Track adoption**: Measure how often teams reference the artifact; refine based on feedback.

### Example: CI Flakiness Learning

```text
Retrospective: Sprint 37
- Candidate: "Flaky database migration test in CI gate"
- Recurrence: Yes (3rd time this quarter)
- Impact: 3 teams affected; delayed 5 PRs
- Quality: High

Decision to promote:
- Created: docs/decisions/2024-03-db-migration-test-flakiness-root-cause.md
- Root cause: Race condition in test cleanup
- Mitigation: Use deterministic test sequencing and cleanup barriers
- Decision: All database migration tests must use TestContainers with isolation

Action items:
- Update CI gate to enforce new pattern (Instruction)
- Create reusable test fixture (Skill)
- Document in onboarding guide (update docs/getting-started.md)

Outcome:
- Flaky database test failures reduced to 0 in Sprint 38
- Learning Capture=Promoted
```

## Governance and Audit

Quarterly audit cycle ensures operator playbook alignment with actual practice:

- **Month 1**: Review [`aidl-portfolio-audit-suite.md`](aidl-portfolio-audit-suite.md); capture conformance gaps
- **Month 2**: Root-cause analysis on gaps; update playbook and governance
- **Month 3**: Validate improvements; measure conformance trend

Audit triggers playbook updates when:

- New escalation pattern emerges (e.g., repeated guardrail blocks)
- Agent/skill changes require workflow changes
- Incident class increases (e.g., new failure mode)
- Team feedback indicates playbook mismatch

## Escalation Triggers

1. `Guardrail State=Block` on release-critical item.
2. High-severity incident without remediation owner.
3. Expired waiver still in active use.
4. Conformance score in red state.

## Terminology and Canonical Lexicon

All playbook terminology aligns with the BaseCoat canonical lexicon and AIDL framing:

- **Guardrail State**: Control compliance status (Pass, Warn, Block, Waived). Drives escalation triggers. Tracked in [Guardrail GitHub Project](https://github.com/orgs/IBuySpy-Shared/projects/7).
- **Risk**: Business risk classification (Critical, High, Medium, Low). Informs triage priority and SRE allocation.
- **SRE Impact**: Operational blast radius (None, Latency, Availability, Error Rate, Capacity). Filters on-call routing.
- **Iteration**: Sprint or release cycle. Drives planning cadence and board filtering.
- **Runbook Link**: Direct reference to `docs/operations/operational-runbook.md` or specific playbook section.
- **Learning Capture**: State indicator (None, Candidate, Promoted) for knowledge extraction.
- **Conformance Score**: Portfolio-wide policy adherence percentage; red (<80%), yellow (<95%), green (>=95%).

## Agent and Skill Integration

This playbook delegates to BaseCoat specialist agents and skills at key workflow points:

| Workflow | Agent/Skill | Trigger | Output |
| --- | --- | --- | --- |
| Intake & Triage | [`issue-triage`](https://github.com/IBuySpy-Shared/basecoat/blob/main/agents/basecoat-10-core-issue-triage.agent.md) | New issues, unclassified backlog | Priority, labels, type, SLA |
| Sprint Planning | [`sprint-planner`](https://github.com/IBuySpy-Shared/basecoat/blob/main/agents/basecoat-10-core-sprint-planner.agent.md) | Planning ceremony start | Sprint scope, dependency map, risk summary |
| PR/Review Gates | [`release-audit`](https://github.com/IBuySpy-Shared/basecoat/blob/main/skills/release-audit/SKILL.md) | PR review gate trigger | Conformance pass/fail, waiver decision |
| Release Readiness | [`release-readiness-chair`](https://github.com/IBuySpy-Shared/basecoat/blob/main/agents/basecoat-60-workflow-release-readiness-chair.agent.md) | Sprint closeout, release prepare | Release checklist, gate decisions, rollback plan |
| Incident Response | [`incident-responder`](https://github.com/IBuySpy-Shared/basecoat/blob/main/agents/basecoat-60-workflow-incident-responder.agent.md) | Incident creation, escalation | Triage, mitigation, post-incident learning |
| Learning Capture | [`feedback-loop`](https://github.com/IBuySpy-Shared/basecoat/blob/main/agents/basecoat-10-core-feedback-loop.agent.md) | Retrospective or closeout | Memory artifact promotion, decision log updates |

## GitHub Visibility and Status Transparency

All portfolio state must remain visible in GitHub Projects and community channels:

### Public Status Views

- **Sprint Roadmap**: 90-day outlook; updated at planning, visible to all stakeholders
- **Incident Status**: Open incidents and SLAs; published to `#incidents` channel
- **Release Gate Status**: Current conformance score, waiver tracking; published to release PR
- **Retrospective Outcomes**: Action items and process changes; visible in sprint planning review

### Escalation Transparency

When guardrails trigger escalation, updates must flow through:

1. GitHub Projects status field
2. Issue labels and assignees
3. Release notes and changelog
4. Operational runbook linked in issue

### Data Integrity

All portfolio state must meet these standards:

- **Consistency**: Project fields and GitHub issue fields must align (no orphaned state)
- **Currency**: Last update timestamp on all issues; stale items flagged for triage
- **Auditability**: All state changes are Git-trackable (in YAML or JSON version control)
- **Testability**: Portfolio metrics are reproducible; conformance scores are deterministic

## References

1. `docs/spec/aidl-portfolio-management.spec.md`
2. `docs/operations/aidl-portfolio-audit-suite.md`
3. `docs/operations/aidl-portfolio-posture-assessment.md`
4. `docs/operations/aidl-sre-feedback-loop.md`
5. `docs/operations/branch-protection-enforcement.md`
6. `docs/operations/merge-queue-enforcement.md`
7. `docs/operations/operational-runbook.md`
