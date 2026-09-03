---
issue: 2973
title: "Add an A/B eval gate for the always-on HRM/TRM/memory cognitive layer (or demote it)"
status: draft
author: ibuyspy
created: 2026-09-03
labels: ["enhancement", "priority:medium", "synthesize-spec"]
---

# PRD: Add an A/B eval gate for the always-on HRM/TRM/memory cognitive layer (or demote it)

## Problem Statement

basecoat's headline differentiator is a "cognitive architecture" — HRM (hierarchical reasoning / execution) and TRM (reflexion) — shipped as **always-on** instructions (`basecoat-10-core-hrm-execution`, `basecoat-10-core-trm-reflexion`, plus `memory-index`). Together these are a large slice of the ~40k always-on token tax paid on every turn.

basecoat already has serious eval infrastructure: per-agent `agents/*.agent.eval.yaml`, and workflows `behavioral-eval.yml`, `extension-intent-routing-eval.yml`, `harness-change-eval-gate.yml`. **But that harness is pointed at agents, not at the always-on cognitive layer.** The justification for HRM/TRM currently rests on a research write-up (`docs/research/TRM-HRM-investigation.md`), not on a repeatable A/B eval showing the layer earns its per-turn cost. This is exactly the "evidence-required" bar that the sibling HVE framework enforces for its own standards.

## Why This Matters

*Not specified.*

## Scope

*Not specified.*

## Success Criteria

- [ ] The implementation addresses the stated problem.
- [ ] The acceptance criteria are validated before release.

## References

- Refs #2973
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/2973>
