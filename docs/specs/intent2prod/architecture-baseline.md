# Intent2Prod: Program Charter and Architecture Baseline

## Objective

The Intent-to-Production (Intent2Prod) control plane governs the full SDLC journey
from a high-level intent statement to a production-deployed, evidence-backed release.
It enforces governance, orchestrates multi-sprint execution, and provides rollback
contracts at every promotion gate.

## Intent Contract v1

Intent2Prod recognizes two primary intent types:

| Intent | Trigger | Use When |
|---|---|---|
| `ship-it` | `/ship-it <goal>` comment or workflow dispatch | Delivering a feature, fix, or enhancement end-to-end |
| `spec-2-prod` | Workflow dispatch with spec reference | Taking a written spec directly to production |

### Lifecycle States

```text
CREATED -> SCOPING -> IMPLEMENTING -> VALIDATING -> PROMOTING -> SHIPPED -> CLOSED
```

- **CREATED**: Control-plane parent issue and sprint child issues generated.
- **SCOPING**: Sprint 1 active; architecture, scope, and risk controls confirmed.
- **IMPLEMENTING**: Sprint 2 active; code merged, required gates passing.
- **VALIDATING**: Staged promotion in progress; evidence collected.
- **PROMOTING**: Release gate enforcement and staged rollout active.
- **SHIPPED**: All promotion gates passed; release evidence attached.
- **CLOSED**: Post-release learning captured; all child issues closed.

### Intent Parameters

| Field | Required | Description |
|---|---|---|
| `intent` | Yes | `ship-it` or `spec-2-prod` |
| `goal` | Yes | Clear objective statement |
| `target_repo` | Yes | `owner/repo` |
| `spec_ref` | No | Link to spec issue or doc |
| `risk_band` | Yes | `low`, `medium`, `high`, or `critical` |

## Control-Plane Architecture

```text
Intake Layer
  └── ship-it-intent-dispatch.yml
      └── dispatch-intent.ps1
          └── Creates: parent issue + 3 sprint issues

Orchestration Layer
  Sprint 1 (SCOPING)   — architecture, acceptance criteria, risk review
  Sprint 2 (IMPLEMENTING) — code changes, CI gates, PR merge
  Sprint 3 (CLOSEOUT)  — evidence capture, docs, post-release learnings

Governance Layer
  release-label-gate   — sprint/wave label required
  prd-spec-gate        — spec reference validated
  main-branch-protection-readiness-gate — branch hygiene

Evidence Layer
  test-results/ship-it/summary.json  — machine-readable summary
  test-results/ship-it/summary.md    — human-readable summary
  Sprint issue evidence sections     — PR links, validation runs, release notes
```

## Track Architecture

### Track A: Intent Contract and Dispatcher (#1853)

Implement the dispatcher that translates an intent statement into a governed
execution plan. Entry points: issue comment `/ship-it <goal>` and workflow dispatch.

**Deliverables:**

- `scripts/ship-it/dispatch-intent.ps1` (enhanced with contract validation)
- `docs/specs/intent2prod/intent-contract-v1.md`
- Workflow: `ship-it-intent-dispatch.yml` (updates for contract enforcement)

### Track B: Goal-Loop State Machine (#1857)

Build the multi-sprint orchestration engine that drives execution from SCOPING
through SHIPPED. Tracks sprint issue state, enforces exit criteria, and
transitions lifecycle state.

**Deliverables:**

- `scripts/ship-it/goal-loop-engine.ps1`
- State machine documented in `docs/specs/intent2prod/goal-loop-state-machine.md`

### Track C: PR/Merge/Branch Hygiene Automation (#1849)

Integrate automated branch hygiene checks into the control-plane loop.
Ensures branches are clean, rebased, and merge-ready before promotion.

**Deliverables:**

- `scripts/ship-it/branch-hygiene-check.ps1`
- Integration into `ship-it-intent-dispatch.yml` promotion gate

### Track D: Build-Break Detection and Auto-Recovery (#1856)

Detect build failures in sprint branches and trigger recovery workflows.
Surfaces root-cause diagnostics in the control-plane sprint issue.

**Deliverables:**

- `scripts/ship-it/build-break-detector.ps1`
- Workflow: `.github/workflows/ship-it-build-guard.yml`

### Track E: Release Gates and Staged Promotion Contract (#1848)

Enforce release gates at each promotion stage. Support staged rollout
with opt-in canary and blue/green modes.

**Deliverables:**

- `scripts/ship-it/release-gate-enforcer.ps1`
- `docs/specs/intent2prod/staged-promotion-contract.md`
- Workflow: `.github/workflows/ship-it-release-gate.yml`

### Track F: Artifact Completeness Contract (#1850)

Validate that all required artifacts (spec, docs, tests, runbook, release notes)
are present before closing the control-plane issue.

**Deliverables:**

- `scripts/ship-it/artifact-completeness-check.ps1`
- Integrated into Sprint 3 exit criteria validation

## Non-Goals

- Replacing existing branch protection rules or required CI checks.
- Bypassing human review for `risk_band: critical` PRs.
- Automated production deployment without a staged promotion gate.
- Managing infrastructure provisioning (handled by separate IaC workflows).

## Autonomy Bands (A0-A5)

| Band | Description | Approval Required |
|---|---|---|
| A0 | Fully human-gated | Every step needs human sign-off |
| A1 | Human-approved start, automated execution | Initial approval only |
| A2 | Automated with human checkpoints at gates | Gate approvals |
| A3 | Automated with exception escalation | Exception only |
| A4 | Fully automated, evidence-only | Post-hoc review |
| A5 | Autonomous with self-healing | Audit log only |

Default autonomy band for basecoat: **A2** (automated with human gate approvals for
promotion steps involving production environments).

## Rollout Plan

| Phase | Scope | Status |
|---|---|---|
| Phase 0 | basecoat: ship-it dispatch and sprint issue generation | Shipped (PR #1868-1871) |
| Phase 1 | basecoat: Track A-F implementation | This sprint |
| Phase 2 | wawkr canary onboarding (#1852) | Pending Phase 1 |
| Phase 3 | luxesite onboarding (#1851) | Pending Phase 2 |
| Phase 4 | work-tracker lane-aware onboarding (#1855) | Pending Phase 2 |

## Risk Controls

| Risk | Mitigation |
|---|---|
| Sprint 2 PRs break main branch | Required CI gates enforced; `release-label-gate` and `prd-spec-gate` block merge |
| Autonomy band misclassification | `risk_band` field required; `critical` triggers forced human review |
| Evidence gaps at closeout | Track F artifact completeness check blocks Sprint 3 close |
| Scope creep across tracks | Each track is an independent issue; cross-track dependencies explicit in dep map |

## Acceptance Criteria

- [ ] Architecture decision log approved and committed to `docs/specs/intent2prod/`
- [ ] Intent contract v1 schema versioned and documented
- [ ] Program milestones and track owners defined
- [ ] Rollout phases and dependencies mapped
