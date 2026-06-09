---
description: "Persistent sprint template for backlog planning without recompilation"
---

# Sprint Template — Reusable Structure

This template enables sprint-planner agents to load backlog state once and reuse it across sessions, eliminating the ~39.5M token cost of re-planning from scratch.

**Usage**: Reference this template in agent startup: `/sprint-planner reference docs/templates/sprint-structure.md`

## Current Sprint Metadata

- **Sprint ID**: (auto-filled by planner)
- **Duration**: 2 weeks
- **Start**: (auto-filled)
- **Goals**: (updated per sprint)

## Backlog Categories

Use these sections to organize issues for consistent triaging:

### P1 Blockers (Release/Security)
**Criteria**: Blocks release, breaks production, or is a security fix.
- Template: `#NNNN: [fix|security] description (owner)`
- Typical: 0–3 issues per sprint

### P2 Medium (Features/Docs/Refactor)
**Criteria**: Improves experience, reduces technical debt, or enables future work.
- Template: `#NNNN: [docs|refactor|chore] description (team)`
- Typical: 8–15 issues per sprint

### P3 Low (Nice-to-have)
**Criteria**: Hygiene, cleanup, or optimization without blocking value delivery.
- Template: `#NNNN: [chore|docs] description (owner)`
- Typical: 0–5 issues per sprint

## Backlog Delta Pattern

Instead of re-listing 50+ issues, track **delta from prior sprint**:

```
## Changes from Prior Sprint

### Moved In (new priorities):
- #1234: (reason: higher priority discovered)
- #5678: (reason: blocker resolved, now unblocked)

### Moved Out (defer/complete):
- #9999: DONE in prior sprint
- #8888: Defer to future sprint (reason: lower priority, blocked on #1234)

### Reordered:
- #7777: Move up (reason: customer urgency)
- #6666: Move down (reason: lower impact than #1234)
```

This delta approach saves **~20M tokens** vs re-listing the entire backlog.

## Execution Board Pattern

Use this block to execute, not only plan:

```text
## Sprint Execution Board

### Wave 1 (policy/guardrails)
- [ ] #NNNN compact policy update
- [ ] #NNNN context payload reduction
- [ ] #NNNN delegation and batching defaults

### Wave 2 (runtime optimization)
- [ ] #NNNN model routing matrix
- [ ] #NNNN attachment canonical summary workflow

### Dependencies
- #NNNN depends on #NNNN
- #NNNN depends on #NNNN

### Definition of done
- [ ] PR merged for each wave
- [ ] Instructions updated
- [ ] Follow-up tracking issues closed or moved
```

## Sample Sprint (Reference)

**Sprint 31: Cost Optimization Focus**

### P1 Blockers:
- #1352: fix: Restore PRODUCTION_REPO_TOKEN permissions (owner: infra team)

### P2 Medium:
- #1362: Create persistent sprint template (owner: @ibuyspy)
- #1363: Add cost-tracking observability (owner: copilot-cli team)
- #1361: Efficiency target tracking (owner: @ibuyspy)
- #1337: Add USE FOR / DO NOT USE FOR scope docs (~40 agents)
- #1339: Downshift 20+ routine agents to gpt-5.4-mini
- #1338: Remove /basecoat skill refs (~45 agents)

### P3 Low:
- #1340: Commit .vscode/settings.json (owner: dev-env team)
- #1341: Add preflight template for long-run agents (docs)
- #1342: Improve sprint-closeout-auditor instructions (docs)
- #1336: Create routing decision tree (docs)

## Notes for Planner

- Bulk agent updates (#1337, #1339, #1338) can run in parallel via background agents
- Cost observability (#1363) requires CLI/infrastructure work; estimate 3-4 days
- Sprint template (#1362) unblocks future planning; prioritize for day 1
- Template refactor reduces session cost from 39.5M → ~15M tokens per plan

---

**How to Reference This Template in Future Sessions**:

Instead of:
```
I need to plan the next sprint. Here's the full backlog [170k chars of issue titles]...
```

Do:
```
/sprint-planner
See: docs/templates/sprint-structure.md
Apply delta from prior sprint: [issue list delta only, ~10 lines]
```

This pattern saves ~30M tokens per sprint-planning session.
