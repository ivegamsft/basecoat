# Governance Reference

This document defines how basecoat is maintained, how decisions are made, and what standards all contributors — human and AI — must follow.

---

## Decision-Making

### Principles

1. **Default to the issue tracker.** Decisions that affect behavior, structure, or standards belong in issues. Watercooler discussions don't age well.
2. **Ship iteratively.** Prefer small, scoped PRs over large monoliths.
3. **No undocumented exceptions.** If you deviate from a standard, document why in the PR or issue.
4. **Agents are first-class contributors.** AI agents follow the same process as humans. No shortcuts.

### Who Can Decide What

| Decision | Who Decides |
|---|---|
| New standard or instruction | Repo owner + 1 reviewer |
| New agent or skill | Issue + PR approval |
| Breaking change to existing standard | Issue required, explicit migration note |
| CI/CD changes | Repo owner |
| Governance changes (this document) | Issue required, must go through PR |

---

## Sprint Process

basecoat uses a sprint model aligned to GitHub milestones.

### Sprint Cadence

- **Sprint duration:** 2 weeks
- **Milestone format:** `Sprint N — <theme>`
- **Version cut:** at sprint close, if deliverables are complete

### Sprint Lifecycle

```text
Backlog → Sprint Planning → Active Sprint → Review → Release → Retrospective
```

1. **Backlog** — issues labeled with future sprint or `backlog`
2. **Sprint Planning** — issues assigned to the sprint milestone, prioritized
3. **Active Sprint** — work in progress; PRs open against `main`
4. **Review** — all PRs reviewed and merged; CI green
5. **Release** — version bumped, CHANGELOG updated, tag cut
6. **Retrospective** — brief notes in the milestone description or a `retro` issue

### Labels

| Label | Meaning |
|---|---|
| `sprint-N` | Assigned to Sprint N |
| `backlog` | Not yet sprint-assigned |
| `blocked` | Blocked by dependency |
| `spec-required` | Needs PRD/spec before work starts |
| `governance` | Governance-related change |
| `security` | Security-related change |
| `v1.0.0` | Targeting v1.0.0 release |

#### Asset Type Labels (Custom)

These labels identify the type of customization asset and enable discovery/filtering:

| Label | Meaning | File Location |
|---|---|---|
| `agent` | Copilot agent definition | `agents/*.agent.md` |
| `skill` | Reusable skill or template collection | `skills/*/SKILL.md` |
| `instruction` | Custom instruction file | `instructions/*.instructions.md` |
| `prompt` | Prompt template or starter | `prompts/*.prompt.md` |

**Usage:** Apply the asset type label to all issues related to creating, updating, or fixing that asset type. This enables filtering by asset type in issue discovery (e.g., `is:issue label:agent` to find all agent-related work).

#### Issue Type Labels

These labels classify the nature of the issue:

| Label | Meaning |
|---|---|
| `bug` | Unexpected behavior, error, or regression |
| `enhancement` | New feature request or improvement |
| `documentation` | Missing or incorrect documentation |
| `question` | Question or clarification request |
| `chore` | Maintenance, refactoring, or tech debt |
| `security` | Vulnerability or security concern |

#### Priority Labels

| Label | SLA | Criteria |
|---|---|---|
| `priority:high` | 1 hour | Blocking work, data loss risk, security breach |
| `priority:medium` | 4 hours | Major feature impact, significant user frustration |
| `priority:low` | 1 week | Cosmetic, nice-to-have, or minor improvement |

#### Approval Status Labels

| Label | Meaning |
|---|---|
| `approved` | Issue has been approved for implementation |
| `copilot-agent` | Issue is assigned to and being worked on by a Copilot agent |

#### Discovery Patterns

Common search patterns for issue discovery:

- `is:issue label:agent` — Find all agent-related issues
- `is:issue label:sprint-3 label:skill` — Find Sprint 3 skill work
- `is:issue label:bug label:priority:high` — Find high-priority bugs
- `is:issue label:blocked is:open` — Find open blocked issues
- `is:issue label:documentation` — Find documentation work

---

## Versioning

basecoat follows [Semantic Versioning 2.0.0](https://semver.org/).

```text
MAJOR.MINOR.PATCH
```

| Increment | When |
|---|---|
| `MAJOR` | Breaking change to consuming repo contract (file moves, schema breaks, removed required files) |
| `MINOR` | New agents, skills, instructions, templates, or non-breaking additions |
| `PATCH` | Bug fixes, typos, CI tweaks, documentation corrections |

### Version Files

- `version.json` — machine-readable current version
- `CHANGELOG.md` — human-readable history, one section per release
- Git tag: `vMAJOR.MINOR.PATCH`

### Release Steps

1. Update `version.json`
2. Update `CHANGELOG.md` — add new section, reference issues/PRs
3. Commit: `chore: bump version to vX.Y.Z`
4. Tag: `git tag vX.Y.Z`
5. Push tag: `git push origin vX.Y.Z`
6. GitHub Release created by `package-basecoat.yml` workflow

---

## Agent Standards

All AI agents that work in this repo — whether built into tooling or invoked externally — must follow these standards.

### Mandatory Rules for All Agents

1. **Issue-first.** No implementation without an issue. If none exists, create one.
2. **No secrets.** Never write credentials, tokens, keys, or PII to any file or commit.
3. **PR-only.** No direct commits to `main`. Create a branch, open a PR.
4. **Branch naming.** Follow `<type>/<issue-number>-<short-description>`.
5. **Stop and ask** when scope is ambiguous, when a decision affects other contributors, or when proceeding would cause irreversible change.
6. **Reference the issue** in every commit message and PR description.

### When an Agent Should Stop and Ask

- The issue is ambiguous or contradictory
- The change would modify `main` branch protection or CI/CD pipelines
- A secret or credential is needed to proceed
- The scope has expanded beyond the original issue
- A dependency (another PR, issue, or external service) is not ready

### When an Agent Can Proceed Without Asking

- The issue is clear and scoped
- All dependencies are resolved
- The change is additive (new files, new content)
- No secrets or sensitive data are involved
- CI checks will validate correctness

---

## What Requires an Issue vs. What Can Be Done Inline

### Always Requires an Issue

- New instruction file
- New agent definition
- New skill
- New template
- New documentation section (not just a fix)
- Any change to governance documents (this file, CONTRIBUTING.md, governance.instructions.md)
- CI/CD workflow changes
- Breaking changes of any kind

### Can Be Done Inline (No Issue Required)

- Typo fixes that do not change meaning
- Whitespace or formatting corrections
- Fixing a broken link
- Updating a version number as part of a release commit
- Minor clarifications to existing documentation (single sentence or less)

If in doubt, open an issue. It takes 30 seconds and creates a paper trail.

---

## Governance Documents Index

| File | Purpose |
|---|---|
| `CONTRIBUTING.md` | How to contribute — branch naming, commits, PRs, secrets |
| `docs/GOVERNANCE.md` | This file — decisions, sprints, versioning, agent standards |
| `instructions/governance.instructions.md` | AI agent instruction set — authoritative rules for agents |
| `docs/templates/PRD_TEMPLATE.md` | Product requirements doc template |
| `docs/templates/ISSUE_TEMPLATE.md` | Issue template for bugs and features |

---

## Amending Governance

Governance documents are not frozen. To change them:

1. Open an issue with the `governance` label
2. Describe what should change and why
3. Open a PR with the changes
4. Get at least one approval
5. Merge

No governance changes via direct commit. No exceptions.
