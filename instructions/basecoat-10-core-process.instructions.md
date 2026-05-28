---
description: "Use when planning sprints, triaging issues, managing pull requests, coordinating releases, or evaluating delivery health. Covers the end-to-end delivery lifecycle from intake through production release."
applyTo: "**/*"
---

# Delivery and Process Standards

Use this instruction for sprint planning, issue management, PR workflow, release
coordination, and cross-team collaboration.

## Sprint Cadence

- Two-week sprints; all ceremonies required unless cancelled with 24-hour notice.
- **Planning** (Day 1, 90 min): select and scope work; every committed issue must have AC, estimate, and assignee.
- **Standup** (daily, 15 min): completed / working on / blocked. Side discussions move to a thread.
- **Refinement** (Wed Week 1, 60 min): estimate, clarify, split upcoming stories.
- **Review** (last Fri, 60 min): demo to stakeholders.
- **Retro** (last Fri, 45 min): file `process-improvement` issues with owner and due date.
- See [sprint-ceremonies.md](references/process/sprint-ceremonies.md) for ceremony facilitation guides.

## Issue Lifecycle

```text
Triage → Backlog → Sprint → In Progress → In Review → Done
```

- Blocked issues get the `blocked` label plus a comment explaining the dependency.
- Issues inactive 14 days in Backlog are reviewed in refinement and re-prioritized or closed.
- See [issue-and-pr-workflow.md](references/process/issue-and-pr-workflow.md) for stage criteria, branch naming, commit conventions, review requirements, and merge strategy.

## Definition of Done

A work item is Done when:

- All acceptance criteria met; unit + integration tests written and passing.
- Coverage thresholds met (see `quality.instructions.md`).
- Security scan clean; documentation updated.
- PR reviewed and approved; squash-merged, branch deleted.
- Deployed to staging and verified; linked issue closed.

## Escalation SLAs

| Severity | First Response | Resolution |
|---|---|---|
| Critical — prod down | 30 min | 4 hours |
| High — major feature broken | 2 hours | 1 business day |
| Medium — degraded, workaround exists | 1 business day | Current sprint |
| Low — cosmetic | 2 business days | Next sprint |

- Missed SLAs escalate to team lead; missed resolution targets escalate to engineering manager with written summary.
- Post-incident: file `incident-review` issue within 48 hours.

## Release Process

Follow SemVer (`MAJOR.MINOR.PATCH`). Release steps:

1. Branch from `main`: `release/vX.Y.Z` — update CHANGELOG.
2. Run full test suite (unit, integration, e2e).
3. Tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"` — create GitHub Release.
4. Deploy via CI/CD pipeline; run smoke tests.
5. Merge release branch back to `main` if hotfixes were applied.

See [release-and-coordination.md](references/process/release-and-coordination.md) for hotfix process, cross-team contracts, dependency management, and delivery health metrics.

## Reference Files

| File | Contents |
|---|---|
| [sprint-ceremonies.md](references/process/sprint-ceremonies.md) | Ceremony facilitation, standup format, retro techniques |
| [issue-and-pr-workflow.md](references/process/issue-and-pr-workflow.md) | Issue stage criteria, branch naming, commit conventions, merge strategy |
| [release-and-coordination.md](references/process/release-and-coordination.md) | Release workflow, hotfix, cross-team contracts, health metrics |

## See Also

- `governance.instructions.md` — Contribution policies and review standards.
- `quality.instructions.md` — Coverage thresholds and quality gates.
