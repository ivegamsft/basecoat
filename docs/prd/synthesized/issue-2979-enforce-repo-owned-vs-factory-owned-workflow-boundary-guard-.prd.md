---
issue: 2979
title: "Enforce repo-owned vs factory-owned workflow boundary + guard against retirement outages"
status: draft
author: ibuyspy
created: 2026-09-03
labels: ["enhancement", "governance", "priority:medium", "synthesize-spec"]
---

# PRD: Enforce repo-owned vs factory-owned workflow boundary + guard against retirement outages

## Problem Statement

## Context

The basecoat consumer `ibuypets-v3` suffered its single largest self-inflicted outage because the framework does not enforce a boundary between **repo-owned** operational workflows and **factory/basecoat-owned** orchestration scaffolding.

From `ibuypets-v3/docs/prompts/ibuypets-v3-repo-story.md`, Phase 5 ("The Workflow Retirement Mistake"):

- Issue #127 / PR #128 — *"mark ibuypets-v3 complete and retire factory workflows"* — merged, removing most of `.github/workflows/*.yml` on the premise the migration was done and the factory onboarding scaffolding could be retired with it.
- Fallout **the same day**: NuGet restore broke (#129), dependency submission MSB4249 recurred (#131), CodeQL needed reconciliation (#133, still open), Dockerfiles left dangling (#134), stale sync PRs began failing Database CI/CD daily (#135), **branch protection was found completely absent on `main`** (#136), Dependabot config referenced a retired ecosystem (#137).

## Why This Matters

*Not specified.*

## Scope

*Not specified.*

## Success Criteria

- [ ] The implementation addresses the stated problem.
- [ ] The acceptance criteria are validated before release.

## References

- Refs #2979
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/2979>
