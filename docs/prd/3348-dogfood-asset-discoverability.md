# PRD: Dogfood Asset Discoverability Inside BaseCoat

> **Status:** Draft (awaiting approval)
> **Issue:** #3348
> **Author:** Copilot
> **Target Version:** Next release
> **Last Updated:** 2026-09-13

## Problem Statement

BaseCoat authors the canonical `skills/`, `agents/`, `prompts/`, and
`instructions/` trees that it distributes to consumer repositories. Consumers
receive every asset because `sync.ps1` projects the canonical trees into the
Copilot-discoverable `.github/` layout. BaseCoat itself never runs that
projection against its own working tree, so none of its own skills, agents, or
prompts are discoverable by the Copilot CLI while working inside BaseCoat.

Observed live: invoking the `repo-cleanup` skill in a BaseCoat session returns
`Skill not found: repo-cleanup`, even though `skills/repo-cleanup/SKILL.md`
exists in the tree. The Copilot CLI loads skills and agents from `.github/` and
`$HOME/.copilot/`; BaseCoat populates neither locally.

The impact is not a missing convenience. When a governed procedure (a skill) is
invoked and not loaded, the agent does not fail loudly and stop — it
reconstructs the intent from memory and proceeds with the *name* of the governed
procedure but none of its guardrails. A `repo-cleanup:` sweep in the
bug-discovering session bypassed three documented guardrails (skipped the
mandatory dry-run/approval gate, used `git branch -D`, and ran bare
`git worktree prune`). Every security, release, and governance skill this repo
defines is therefore unenforced during local BaseCoat sessions — the repo that
defines the controls is the one repo not running them.

## Goals

- Make BaseCoat-authored skills, agents, and prompts resolve and load inside a
  BaseCoat session, so governed procedures run with their guardrails.
- Keep the canonical `skills/`, `agents/`, `prompts/` trees the single source of
  truth — no tracked duplication of ~1,000 files into `.github/`.
- Make the local install automatic for contributors (wired into bootstrap/dev
  setup) so discoverability does not depend on a manual, easily forgotten step.
- Keep the local install current with the canonical trees and detectable when
  stale.

## Non-Goals

- Changing the consumer distribution mechanism (`sync.ps1` projection into a
  consumer's `.github/`), which already works.
- Changing the content, frontmatter, or behavior of any skill, agent, or prompt.
- Publishing new assets or altering the asset manifest contract.
- Providing discoverability for editors/clients other than the Copilot CLI
  (covered only incidentally if they read the same `.github/` layout).
- Projecting **consumer-facing shipped deliverables** (e.g. `azure-*`,
  `container-*`, `bom-*`, `s4-*`, app-dev skills) or `instructions/` into the
  ambient local session — these are excluded to bound context and covered by a
  full-catalog eval instead.
- Reading, copying, or committing a contributor's **personal `~/.copilot/`**
  skills, agents, or prompts. The projection source is the repository tree only;
  personal assets are never involved.

## User Personas and Use Cases

- **BaseCoat contributor / maintainer:** runs Copilot CLI sessions inside the
  BaseCoat repo and expects `skill:`/agent invocations of BaseCoat's own assets
  to resolve, so governed procedures (repo-cleanup, security, release) execute
  with their contracts instead of silently degrading.
- **Automation / agentic sessions inside BaseCoat:** invoke governed skills as
  part of ship-it and backlog flows and must get the enforced procedure, not a
  memory reconstruction.

## User Experience Summary

After a one-time bootstrap (or the first run of the dev-setup target), invoking
any BaseCoat-authored skill or agent inside a BaseCoat session resolves and
loads it. The canonical trees remain the only tracked copy; `git status` stays
clean (the projected copies are gitignored). A validation/self-check reports
when the local install is missing or stale and tells the contributor exactly
what to refresh.

## Functional Requirements

| ID | Requirement |
|---|---|
| FR1 | A local self-install projects a **curated dev-governance subset** of `skills/`, `agents/`, and `prompts/` (from the repository tree only) into the Copilot-discoverable `.github/` layout (and `.agents/skills/` for cross-client interop), reusing the consumer projection `sync.ps1` performs. |
| FR2 | The projected copies are **gitignored**; the canonical trees remain the single tracked source of truth. No ~1,000-file duplication is committed. |
| FR3 | The self-install is invoked automatically during contributor onboarding (bootstrap/dev-setup), so discoverability requires no separately remembered step. |
| FR4 | Re-running the self-install is idempotent and refreshes the projection to match the current canonical subset, removing projected assets that no longer exist canonically or have left the subset. |
| FR5 | A validation/self-check detects a missing or stale local install and reports the exact refresh command; it must not fail unrelated CI for the tracked tree. |
| FR6 | Invoking a representative BaseCoat-governance skill (e.g. `repo-cleanup`) inside a BaseCoat session resolves and loads it. |
| FR7 | The projection reads **only** the repository tree and never `~/.copilot/`; a shipped-deliverable asset (e.g. `azure-landing-zone`) and `instructions/` are not projected into the ambient session. |

## Non-Functional Requirements

- **No tracked drift:** the mechanism must not introduce a duplicate-copy drift
  class of tracked files (the failure mode already tracked for distributed
  workflow copies).
- **Cross-platform:** must work on the supported contributor platforms
  (Windows + Unix) and in CI where the check runs.
- **Deterministic:** the projection is a pure function of the canonical trees;
  re-running produces the same result.

## Success Metrics

- Invoking `repo-cleanup` (and a sampled set of governed skills) inside a fresh,
  bootstrapped BaseCoat clone resolves the skill: 0 `Skill not found` for
  BaseCoat-authored assets.
- Zero tracked files added under the projected `.github/skills`,
  `.github/agents`, `.github/prompts` paths (gitignored).
- The staleness self-check flags an out-of-date local install in test.

## Constraints and Assumptions

- The Copilot CLI discovers skills/agents from the `.github/` layout (and
  `$HOME/.copilot/`); projecting the canonical trees there is sufficient for
  discovery.
- Directory symlinks/junctions are unreliable across Windows/CI/git, so a
  gitignored copy is preferred over a symlink projection.
- `sync.ps1` already contains the canonical projection logic to reuse.

## Risks and Open Questions

- **Stale local copies:** a gitignored copy can drift from the canonical trees
  between refreshes. Mitigation: idempotent refresh wired into bootstrap plus a
  staleness self-check (FR4, FR5). Open question: should the check run on every
  session start, on a pre-commit hook, or only in CI/dev-setup?
- **`.github/` collisions:** BaseCoat already tracks a small set of repo-meta
  `.github/instructions/*` files. The projection must not clobber or shadow
  tracked repo-meta files. Open question: confirm the exact set of tracked
  `.github/` paths to exclude from (or reconcile with) the projection.
- **Ignoring projected paths vs. tracked assets:** the gitignore rules must
  ignore only the projected copies, not any tracked `.github/` content.
- **Discovery-path assumptions:** confirmation that the CLI reads repo-local
  `.github/skills` and `.github/agents` as trusted config in the BaseCoat
  working directory (per `/add-dir` semantics).

## Dependencies

- `sync.ps1` projection logic (`skills`/`prompts`/`instructions` → `.github/`,
  `skills` → `.agents/skills`, `agents` → `.github/agents`).
- `scripts/bootstrap-basecoat.ps1` onboarding flow (self-install wiring).
- Repository validation/test harness (`scripts/validate-basecoat.ps1`,
  `tests/run-tests.ps1`) for the staleness self-check.

## Rollout and Adoption Plan

1. Land the self-install script + gitignore rules + bootstrap wiring behind the
   spec's implementation plan.
2. Document the one-line refresh command in contributor onboarding.
3. Add the staleness self-check to validation.
4. Verify discoverability in a fresh clone before closing #3348.

## References

- Spec: `docs/spec/3348-dogfood-asset-discoverability.md`
- Issue #3348
- `sync.ps1` (consumer projection reused by the self-install)
- `docs/archive/repo_history/2026-05-01-story-of-basecoat.md` (prior
  consumer-only fix of the same discoverability failure mode)
