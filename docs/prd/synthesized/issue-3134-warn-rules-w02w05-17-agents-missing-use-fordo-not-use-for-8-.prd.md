---
issue: 3134
title: "warn-rules W02/W05: 17 agents missing USE FOR/DO NOT USE FOR, 8 skills with thin negative eval coverage"
status: draft
author: ibuyspy
created: 2026-09-07
labels: ["priority:low", "chore", "needs-prd", "synthesize-spec"]
---

# PRD: warn-rules W02/W05: 17 agents missing USE FOR/DO NOT USE FOR, 8 skills with thin negative eval coverage

## Problem Statement

Running the `sheen-onboard` Phase 4 audit (`scripts/warn-rules.ps1`) against a consumer repo (`IBuySpy-Dev/chairpoint-devops`, basecoat `v4.2.0`) surfaces 25 warnings against basecoat-sourced assets (agents + skills deployed under `.github/agents/` and `.github/skills/` from `IBuySpy-Shared/basecoat.git`).

Filed from downstream audit: IBuySpy-Dev/chairpoint-devops#222 (parent: IBuySpy-Dev/chairpoint-devops#221).

The warnings fall into two categories:

- W02 `description-overlap`: 17 agents are missing explicit `USE FOR:` and
  `DO NOT USE FOR:` routing guidance.
- W05 `eval-coverage`: eight skills have no or thin adjacent-domain negative
  eval coverage.

## Why This Matters

These warnings come from a downstream consumer repo, so the fixes need to land
upstream in BaseCoat. Missing positive/negative routing guidance makes agent
selection less predictable, and thin negative eval coverage makes it harder to
prove skills decline adjacent out-of-scope requests.

The audit is advisory today, but unresolved warnings create noisy downstream
onboarding results and weaken confidence in generated BaseCoat assets.

## Scope

In scope:

- Add `USE FOR:` and `DO NOT USE FOR:` clauses to the 17 listed agent
  descriptions while preserving their existing meaning and token budgets where
  practical.
- Add at least one adjacent-domain negative scenario to each of the eight
  listed skills with insufficient negative coverage.
- Keep changes surgical: do not rewrite agent behavior, skill implementation,
  or unrelated metadata.
- Run the repository validation and warn-rules checks that cover the changed
  assets.

Out of scope:

- Making W02/W05 blocking in CI.
- Redesigning the warn-rules taxonomy.
- Bulk rewriting agents or skills that were not listed by the downstream audit.

## Success Criteria

- [ ] The 17 listed agents include explicit `USE FOR:` and `DO NOT USE FOR:`
  clauses.
- [ ] The eight listed skills each include adjacent-domain negative eval
  coverage.
- [ ] `scripts/warn-rules.ps1` no longer reports the W02/W05 findings described
  in this issue for the targeted assets.
- [ ] Downstream consumers can sync the updated BaseCoat assets instead of
  patching generated copies locally.

## References

- Refs #3134
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3134>
