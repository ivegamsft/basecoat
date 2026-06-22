# Issue and PR Workflow

## Issue Stage Definitions

| Stage | GitHub State | Criteria to Enter | Criteria to Exit |
|---|---|---|---|
| **Triage** | Open, no project | New issue filed | Labeled, estimated, accepted or rejected |
| **Backlog** | Open, project board | Triaged and accepted | Selected for a sprint |
| **Sprint** | Open, sprint milestone | Committed in planning, has assignee | Assignee moves to In Progress |
| **In Progress** | Open, `in-progress` label | Assignee actively working | PR opened and linked |
| **In Review** | Open, linked PR | PR passes CI, reviewer assigned | PR approved and merged |
| **Done** | Closed | PR merged, deployment verified | Issue auto-closed or manually closed |

## Active Project and Feature Links

- **Sprint 37 - CI/CD Guardrails**: <https://github.com/orgs/IBuySpy-Shared/projects/7>
- **CI/CD Remaining Gaps (legacy/backlog board)**: <https://github.com/orgs/IBuySpy-Shared/projects/5>
- **Feature tracker — Publish and environment-guardrail stabilization**: <https://github.com/IBuySpy-Shared/basecoat/issues/1719>
- **Feature tracker — Deployment pipeline recovery (portal, extension, terraform)**: <https://github.com/IBuySpy-Shared/basecoat/issues/1720>

## Branch Naming

Pattern: `<type>/<issue-number>-<short-description>`

| Type | Use |
|---|---|
| `feat/` | New features, content, agents, skills |
| `fix/` | Bug fixes, correctness corrections |
| `chore/` | Tooling, config, dependency updates |
| `docs/` | Documentation-only changes |
| `refactor/` | Code restructuring with no behavior change |
| `security/` | Security-related changes |

**Examples:** `feat/43-user-search-api`, `fix/17-null-ref-on-login`, `chore/88-upgrade-eslint`

## Commit Conventions

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>(<scope>): <short summary>

<optional body>

<optional footer>
```

- **type**: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `ci`
- **scope**: module or area affected (`auth`, `api`, `ui`, `db`)
- **summary**: imperative mood, lowercase, no period, max 72 characters
- Breaking changes: add `BREAKING CHANGE:` in footer or `!` after the type

## PR Review Requirements

- Every PR requires at least one approving review from a non-author team member.
- PRs touching security-sensitive code require approval from the security-analyst agent.
- PRs touching CI/CD or infrastructure require approval from the devops agent.
- All review comments must be resolved or explicitly deferred (with tracking issue) before merge.
- Self-merge is permitted only when the repo policy explicitly allows it (solo maintainer repos).

## Merge Strategy

- **Squash merge** for all feature and fix branches — keeps `main` history linear.
- **Merge commit** only for long-lived integration branches needing preserved commit history.
- Delete the source branch after merge.
- Every merge to `main` must pass all CI checks. No force-pushes to `main`.

## Label Taxonomy

| Label | Purpose |
|---|---|
| `triage` | Newly opened, not yet classified |
| `backlog` | Accepted, awaiting sprint selection |
| `in-progress` | Actively being worked |
| `blocked` | Cannot proceed — add comment with reason |
| `cross-team` | Depends on another team's deliverable |
| `process-improvement` | Retro action item |
| `incident-review` | Post-incident root-cause analysis |
| `approved` | Approved for Copilot coding agent |
| `copilot-agent` | Assigned to Copilot coding agent |
