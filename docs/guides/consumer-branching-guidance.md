# Consumer Repository Branching Guidance

<!-- Addresses #2140 — hybrid flow adoption for consumer repositories -->

## Overview

This guide helps consumer repository teams adopt the hybrid branching strategy
used in BaseCoat without inheriting its full operational complexity.

Choose the profile that best matches your team size and release cadence, then
apply only the branch protections and workflow templates listed for that profile.

## Consumer Profiles

### Profile A: Small Team (1–5 contributors)

**Branch set**:

- `main` — production-ready code, protected
- `dev` — integration branch (optional for very small teams)
- Feature branches: `<user>/<short-description>`

**Branch protections**:

| Branch | Rule |
|--------|------|
| `main` | Require 1 reviewer, require CI pass, no direct push |
| `dev` | Require CI pass |

**Recommended workflow**: Trunk-based with short-lived feature branches. Merge to
`main` (or `dev`) within 1–3 days of opening a PR.

**Minimum viable setup**: Protect `main` with 1 required reviewer and at least one
required status check. No `dev` branch required.

**Strict setup**: Protect both `main` and `dev`. Enable stale review dismissal on
`main`. Require branches to be up to date before merging.

---

### Profile B: Regulated Team

**Branch set**:

- `main` — production, protected with required reviewers and audit trail
- `release/vX.Y` — release stabilization branches
- `hotfix/<description>` — emergency fixes targeted at `main`
- Feature branches: `<user>/<ticket>-<description>`

**Branch protections**:

| Branch | Rule |
|--------|------|
| `main` | Require 2 reviewers, require CI pass, signed commits, no force push |
| `release/*` | Require 1 reviewer, require CI pass |

**Recommended workflow**: GitFlow-lite. Feature branches merge to `main`; release
branches cut from `main` for stabilization; hotfixes merge directly to `main` and
cherry-picked to open release branches as needed.

**Minimum viable setup**: Protect `main` with 2 reviewers, signed commits, and
no force push. Create `release/` branches only at freeze time.

**Strict setup**: Add `release/*` protection rule, require linear history on `main`,
enable deployment environments with required approvers for production.

---

### Profile C: High-Throughput Team (many contributors, frequent releases)

**Branch set**:

- `main` — always deployable
- `lane/<feature>` — parallel feature lanes
- `hotfix/<description>` — emergency fixes

**Branch protections**:

| Branch | Rule |
|--------|------|
| `main` | Require CI pass, merge queue enabled, no direct push |
| `lane/*` | Require CI pass |

**Recommended workflow**: Trunk-based with merge queue. Each `lane/<feature>`
represents a parallel workstream; individual contributors open PRs against the
lane, not directly against `main`.

**Minimum viable setup**: Enable merge queue on `main` with at least one required
CI check. No lane branches required initially — start with direct feature branches
and add lanes as throughput demands it.

**Strict setup**: Enable auto-merge on PRs that pass CI, require up-to-date branches
before merge, and enforce squash-merge policy to keep `main` history linear.

---

## Migration Guide

### From single-branch to hybrid profile

1. **Assess current state** — count active branches, note team size and release cadence.
2. **Select target profile** — A, B, or C above.
3. **Apply branch protections** — use GitHub Settings > Branches or the
   `branch-protection-enforce.yml` workflow (see `docs/reference/branch-protection.md`).
4. **Update CI/CD** — adjust workflow `on.push.branches` and `on.pull_request.branches`
   triggers to match the new branch set.
5. **Rename active feature branches** — adopt the new naming convention for any
   in-flight branches; stale branches (no activity in 30+ days) can be deleted.
6. **Update CONTRIBUTING.md** — document the chosen profile and naming conventions
   for new contributors.

### Rollout Checklist

- [ ] Profile selected and documented in team `CONTRIBUTING.md`
- [ ] Branch protections configured per profile
- [ ] CI workflows updated for new branch patterns
- [ ] Team notified of new naming conventions
- [ ] Stale branches cleaned up (no activity in 30+ days)
- [ ] First sprint run under new model validated

---

## Anti-Patterns

| Anti-Pattern | Problem | Recommended Fix |
|---|---|---|
| Long-lived feature branches (>2 weeks) | Merge conflicts compound | Break into smaller PRs; target 1–3 day branch lifetimes |
| Direct pushes to `main` | Bypasses review and CI | Enable branch protection with no direct push |
| Unlimited branch proliferation | Navigation confusion, stale refs | Enforce naming conventions and a cleanup policy |
| Copying the full BaseCoat lane model | Operational overhead disproportionate for small teams | Use Profile A instead |
| Separate `develop` and `staging` branches | Long-lived divergence from `main` | Collapse to a single integration branch or use environments |

---

## Troubleshooting

### "My branch is constantly behind main"

Run `git fetch origin && git rebase origin/main` at the start of each coding
session. Enable the "Require branches to be up to date" protection on `main` to
surface this earlier.

### "Too many merge conflicts"

Your feature branch is too long-lived. Split the work into smaller, focused PRs
that each merge within 1–3 days. Rebase frequently rather than accumulating divergence.

### "CI fails on merge but not on branch"

The merged state is not being tested. Enable merge queue (Profile C) or squash-merge
policy so the integrated state is always the artifact that CI validates.

### "We need an audit trail but Profile B feels heavy"

Start with Profile A's protections and add signed commits plus stale-review dismissal.
That combination satisfies most audit requirements without the full GitFlow-lite overhead.

---

## References

- Related issue: #1661 (consumer-distribution initiative)
- Related: Sprint 40 hybrid branching design cluster
- `docs/reference/branch-protection.md` — branch protection baseline and enforcement
- `docs/guides/consumer-sync.md` — syncing BaseCoat assets into a consumer repository
