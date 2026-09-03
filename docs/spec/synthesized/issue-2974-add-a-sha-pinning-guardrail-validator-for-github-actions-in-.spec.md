---
issue: 2974
title: "Add a SHA-pinning guardrail + validator for GitHub Actions in consumer workflows"
status: draft
author: ibuyspy
created: 2026-09-03
labels: ["enhancement", "security", "priority:medium", "synthesize-spec"]
---

# Spec: Add a SHA-pinning guardrail + validator for GitHub Actions in consumer workflows

## Problem Statement

basecoat SHA-pins the GitHub Actions in **its own** workflows (e.g. `actions/checkout@9c091bb…`, `actions/setup-python@5fda3b9…`) — good practice. But it ships **no guardrail requiring downstream/consumer workflows to do the same**, and it has no Actions equivalent of its existing container-image SHA-pin guardrail.

The result shows up in real consumers: `IBuySpy-Dev/ibuypets-v3` (a basecoat consumer) has **11 operational workflows (~2,230 lines)** using mutable tags like `actions/checkout@v4`. Mutable major-version tags are re-pointable by the action owner, which is a supply-chain and reproducibility risk. The sibling HVE framework already treats this as a first-class control (`owasp-cicd`, action-version consistency), and its consumer `ibuypets-hve` pins full SHAs (e.g. `actions/checkout@11bd719…`).

## Why This Matters

*Not specified.*

## Scope

*Not specified.*

## Acceptance Criteria

- [ ] Implementation matches the scope defined above.
- [ ] Validation commands pass with no errors.
- [ ] PR references this spec.

## References

- PRD: `docs/prd/synthesized/issue-2974-add-a-sha-pinning-guardrail-validator-for-github-actions-in-.prd.md`
- Refs #2974
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/2974>
