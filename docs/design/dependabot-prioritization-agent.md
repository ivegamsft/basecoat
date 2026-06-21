# Dependabot Prioritization Agent Design

## Context

Issue: #1668  
Parent feature: #1736 (Wave 3)

Dependabot PRs currently arrive as an undifferentiated stream, which delays urgent security fixes and creates avoidable merge queue pressure.

## Problem Statement

- **Current behavior:** Dependabot updates are reviewed in arrival order, with limited risk-aware triage.
- **Symptom:** High-value security updates can wait behind low-risk routine updates.
- **Underlying cause:** No consistent scoring model, no merge/hold policy by risk tier, and no explicit conflict-resolution lane for dependency PRs.

## Design Goals

1. Prioritize dependency PRs using a deterministic score that is explainable in review comments.
2. Auto-merge only low-risk updates that satisfy strict validation gates.
3. Route medium/high-risk updates to explicit hold and escalation paths.
4. Keep merge queue throughput stable by batching routine updates.

## Non-Goals

- Replacing Dependabot itself.
- Auto-merging major version updates by default.
- Bypassing required CI or approval checks.

## Priority Model

The agent computes a score (0-100) and maps it to a tier.

| Signal | Weight | Scoring rule |
|---|---:|---|
| Security urgency | 0-40 | Critical/High CVE fix: 40, Medium: 25, Low: 10, none: 0 |
| Semver risk | 0-25 | Patch: 5, Minor: 12, Major: 25 |
| Dependency criticality | 0-20 | Runtime/prod-critical: 20, build/test tooling: 8, dev-only: 4 |
| Blast radius | 0-15 | Number of impacted packages/workflows and lockfile scope |

`priority_score = security + semver + criticality + blast_radius`

### Tier Mapping

| Tier | Score range | Default handling |
|---|---:|---|
| Tier 0 (Emergency) | 80-100 | Expedite, security lane, same-day review |
| Tier 1 (High) | 60-79 | Fast-track, reviewer required, merge when gates pass |
| Tier 2 (Standard) | 35-59 | Batch review cadence, merge when approved + gates pass |
| Tier 3 (Routine) | 0-34 | Batch auto-merge eligible if all auto-merge rules pass |

## Merge vs Hold Policy

### Auto-merge eligible

A Dependabot PR is auto-merge eligible only when all are true:

- Tier 3 and semver patch (or explicitly allowlisted minor).
- All required checks green (including dependency canary lane).
- No policy exceptions (ignore list, temporary freeze window, incident freeze).
- No merge conflicts.

### Hold required

Hold and require human decision when any are true:

- Tier 0/Tier 1, or any major version bump.
- CI flakiness repeats across retries in dependency canary lane.
- Security signal is ambiguous (for example, advisory exists but fix coverage unclear).
- Cross-workspace conflicts (same lockfile touched by multiple open dependency PRs).

## Conflict Resolution Strategy

When dependency PRs conflict, resolve by deterministic order:

1. Highest tier first (Tier 0 -> Tier 3).
2. Within tier, highest score first.
3. Security patch beats feature/minor updates.
4. Smaller blast radius first when score ties.

Resolution actions:

- Rebase lower-priority PRs onto merged higher-priority PR.
- Re-run canary + required checks after rebase.
- If repeated conflicts occur, collapse same-ecosystem routine updates into one batch PR.

## Agent Workflow

1. Intake Dependabot PR metadata (author, labels, changed manifests/lockfiles, CVE/advisory context).
2. Compute score and assign tier labels (`dep:tier0`..`dep:tier3`).
3. Post structured recommendation comment (merge now, hold, escalate).
4. Route to lane:
   - Tier 0/1 -> security-fast-track lane.
   - Tier 2 -> scheduled dependency review lane.
   - Tier 3 -> auto-merge lane when gates pass.
5. Enforce conflict strategy and update recommendation if score/tier changes after rebase.

## Observability

Track these metrics per sprint:

- Median time-to-merge by tier.
- Percentage of security PRs merged within SLA.
- Auto-merge success rate for Tier 3.
- Conflict recurrence rate for dependency PRs.
- Queue depth split by tier.

## Success Criteria

- [x] Priority tiers are defined and tied to deterministic scoring.
- [x] Merge vs hold policy is explicit and gate-based.
- [x] Conflict-resolution policy is deterministic.
- [x] Design artifact published for implementation planning.

## Implementation Handoff

1. Add/update workflow automation to compute score and apply tier labels.
2. Integrate tier policy into dependency-update-advisor outputs.
3. Add dashboards/queries for tier SLA and queue-depth tracking.
4. Pilot for one sprint, then tune weights using observed false-positive/false-hold rates.
