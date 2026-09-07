---
issue: 3134
title: "warn-rules W02/W05: 17 agents missing USE FOR/DO NOT USE FOR, 8 skills with thin negative eval coverage"
status: draft
author: ibuyspy
created: 2026-09-07
labels: ["priority:low", "chore", "needs-prd", "synthesize-spec"]
---

# Spec: warn-rules W02/W05: 17 agents missing USE FOR/DO NOT USE FOR, 8 skills with thin negative eval coverage

## Problem Statement

Running the `sheen-onboard` Phase 4 audit (`scripts/warn-rules.ps1`) against a consumer repo (`IBuySpy-Dev/chairpoint-devops`, basecoat `v4.2.0`) surfaces 25 warnings against basecoat-sourced assets (agents + skills deployed under `.github/agents/` and `.github/skills/` from `IBuySpy-Shared/basecoat.git`).

Filed from downstream audit: IBuySpy-Dev/chairpoint-devops#222 (parent: IBuySpy-Dev/chairpoint-devops#221).

The audit identified:

- W02 `description-overlap`: 17 agents missing explicit `USE FOR:` and
  `DO NOT USE FOR:` routing guidance.
- W05 `eval-coverage`: eight skills with zero or thin adjacent-domain negative
  scenarios.

## Why This Matters

BaseCoat-sourced assets are deployed into downstream repositories. When metadata
or eval coverage is thin upstream, every consumer sees the same advisory
warnings but cannot safely fix generated copies locally. The remediation needs
to be repeatable, surgical, and validated in BaseCoat before downstream sync.

## Scope

Implement targeted metadata and eval hygiene for the assets listed in #3134.

1. Update these agent frontmatter descriptions with explicit routing clauses:
   - `agentic-sdlc-autonomy.agent.md`,
   - `basecoat-10-core-change-isolation-architect.agent.md`,
   - `basecoat-10-core-exploratory-charter.agent.md`,
   - `basecoat-10-core-merge-coordinator.agent.md`,
   - `basecoat-10-core-new-customization.agent.md`,
   - `basecoat-10-core-product-manager.agent.md`,
   - `basecoat-10-core-prompt-coach.agent.md`,
   - `basecoat-10-core-prompt-engineer.agent.md`,
   - `basecoat-10-core-solution-architect.agent.md`,
   - `basecoat-10-core-strategy-to-automation.agent.md`,
   - `basecoat-10-core-tech-writer.agent.md`,
   - `basecoat-10-core-ux-designer.agent.md`,
   - `basecoat-20-lang-dotnet-modernization-advisor.agent.md`,
   - `basecoat-40-azure-azure-landing-zone.agent.md`,
   - `basecoat-60-workflow-data-pipeline.agent.md`,
   - `basecoat-80-data-data-integrity.agent.md`,
   - `basecoat-90-quality-manual-test-strategy.agent.md`.
2. Add at least one adjacent-domain negative scenario to these skill evals:
   - `agentic-sdlc-autonomy/eval.yaml`,
   - `delivery-autopilot/eval.yaml`,
   - `onboarding-telemetry/eval.yaml`,
   - `session-analysis/eval.yaml`,
   - `session-optimization/eval.yaml`,
   - `ship-it/eval.yaml`,
   - `ship-it-control-loop/eval.yaml`,
   - `workflow-parallelization/eval.yaml`.
3. Preserve existing intent. New `USE FOR:` clauses should describe when the
   asset is the right router target; `DO NOT USE FOR:` clauses should name
   adjacent domains that should route elsewhere.
4. Avoid broad rewrites. Keep frontmatter valid YAML and avoid increasing agent
   descriptions beyond budget unless unavoidable.
5. Run targeted warn-rules validation against the changed assets plus the
   standard BaseCoat validation.

## Validation Plan

- Run `scripts/warn-rules.ps1` before and after the implementation, or run an
  equivalent targeted invocation if the script supports path filtering.
- Run `scripts/validate-basecoat.ps1`.
- If eval schema validation has a separate targeted test, run it for the eight
  changed skill eval files.

## Failure Handling

- If a description cannot fit routing clauses within the recommended token
  budget, keep correctness over budget and record the remaining budget warning.
- If a skill already has one negative scenario but warn-rules still flags it,
  add an adjacent-domain negative that exercises the actual routing boundary
  instead of a generic unrelated request.
- If downstream audit output and current BaseCoat file names diverge, update the
  currently checked-in BaseCoat asset and document any missing/renamed asset in
  the PR.

## Acceptance Criteria

- [ ] All 17 targeted agent descriptions include `USE FOR:` and `DO NOT USE
  FOR:` clauses.
- [ ] All eight targeted skill eval files include adjacent-domain negative
  coverage.
- [ ] Targeted warn-rules output no longer reports the listed W02/W05 findings,
  or the PR documents any intentionally deferred finding.
- [ ] Changes are limited to targeted agent metadata, skill evals, and directly
  related documentation.
- [ ] Validation commands pass with no errors.
- [ ] PR references this spec.

## References

- PRD: `docs/prd/synthesized/issue-3134-warn-rules-w02w05-17-agents-missing-use-fordo-not-use-for-8-.prd.md`
- Refs #3134
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3134>
