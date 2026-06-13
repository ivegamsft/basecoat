---
name: cross-stack-modernization
description: "Language-agnostic modernization guidance for incrementally replacing legacy applications using strangler fig, ACLs, and risk scoring. USE FOR: plan legacy app modernization strategy, choose rewrite versus refactor versus replace, design strangler fig migration, sequence service extraction by dependency risk, decide database-first or UI-first migration. DO NOT USE FOR: greenfield system design, minor bug fixes in one service, container-only deployment setup."
compatibility: GHCP
---

# Cross-Stack Modernization

Language-agnostic patterns for incrementally modernizing legacy applications: strangler fig,
anti-corruption layer (ACL), risk scoring, and dependency extraction sequencing.

## Reference Files

| File | Contents |
|------|----------|
| [`references/workflow.md`](references/workflow.md) | Decision matrix, strangler fig steps, ACL pattern, DB-first vs UI-first, risk scoring, extraction sequencing |
| [`references/examples.md`](references/examples.md) | Risk scoring example, nginx strangler fig routing, TypeScript ACL adapter |

## Strategy Decision (Quick Reference)

| Criterion | Refactor | Strangler fig | Full rewrite |
|-----------|----------|---------------|-------------|
| Test coverage | > 60 % | 30–60 % | < 30 % |
| Time horizon | Weeks | Months | Quarters |
| Risk tolerance | Low | Medium | High |
