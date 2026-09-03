---
issue: 2980
title: "Add a forward migration-plan artifact standard (entry/exit/rollback per phase), adopting HVE modernization-plan pattern"
status: draft
author: ibuyspy
created: 2026-09-03
labels: ["documentation", "enhancement", "priority:low", "synthesize-spec"]
---

# Spec: Add a forward migration-plan artifact standard (entry/exit/rollback per phase), adopting HVE modernization-plan pattern

## Problem Statement

## Context

Comparing the two consumer repos migrating the **same** app (.NET Pet Shop 4.0 / MSPetShop4), the HVE consumer ships a durable, forward-looking **migration plan** artifact that basecoat has no equivalent of:

- `ibuypets-hve/docs/modernization-plan.md` — a phased roadmap with, per phase, explicit **entry criteria / work / exit criteria / rollback**, guiding principles ("never stop taking orders", strangler-fig not big-bang, reversibility at every step), a current-state vs target-state table per layer, and it **folds existing tracked issues into the phase where each is resolved** rather than keeping a parallel backlog.

basecoat, by contrast, produces an excellent **backward-looking** narrative (`ibuypets-v3/docs/prompts/ibuypets-v3-repo-story.md`) — what happened, what it cost, lessons — but there is no forward, reversible roadmap artifact. Several consequences trace to this absence:


## Why This Matters

*Not specified.*

## Scope

*Not specified.*

## Acceptance Criteria

- [ ] Implementation matches the scope defined above.
- [ ] Validation commands pass with no errors.
- [ ] PR references this spec.

## References

- PRD: `docs/prd/synthesized/issue-2980-add-a-forward-migration-plan-artifact-standard-entryexitroll.prd.md`
- Refs #2980
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/2980>
