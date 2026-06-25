---
name: session-optimization
description: "Use when reducing token spend, event count, or context bloat in long-running Copilot CLI sessions. USE FOR: apply phase-boundary compaction, enforce file-reference discipline, configure model routing for routine loops, track session efficiency metrics, detect expensive session antipatterns. DO NOT USE FOR: product feature implementation, infrastructure deployment, direct code changes."
compatibility:
  - GHCP
category: workflow
visibility: public
metadata:
  category: workflow
  maturity: stable
  audience:
    - developer
    - maintainer
allowed-tools: []
model_policy:
  fallback: true
  preferred_families:
    - gpt-5.4-mini
    - claude-haiku
  cost_tracking:
    budget_tier: low
    chargeback_tag: session-optimization
---

# Session Optimization Skill

Apply session hygiene patterns to reduce token cost, event count, and context bloat in long-running Copilot CLI sessions.

## Shortcut Phrases

- optimize session
- compact now
- check token status
- reduce context bloat
- session hygiene

## Phase-Boundary Compaction

Run `/compact` at each semantic phase boundary to drop stale context:

| Phase transition | Action |
|---|---|
| Triage to implementation | `/compact` — backlog context is no longer needed |
| Implementation to merge-waiting | `/compact` — code diff context is no longer needed |
| Merge-waiting to next phase | `/compact` — CI logs and merge state are transient |
| Domain pivot (sprint planning to release ops) | `/new` — reload only relevant references |

Target: < 150 events per phase; compact before reaching 400 events total.

## File-Reference Discipline

Never paste large blocks into chat. Use file references instead.

Instead of pasting a 170k-character skill or instruction file, write:

```text
See: skills/session-optimization/SKILL.md
See: .github/instructions/cost-optimization.instructions.md
```

Expected savings: ~300x tokens per pasted block.

## Model Routing for Routine Loops

| Work type | Default model | Upshift trigger |
|---|---|---|
| Status checks, PR hygiene, branch monitoring | gpt-5.4-mini or Haiku | Complex multi-system failure |
| File scans, lightweight triage | gpt-5.4-mini or Haiku | Architecture tradeoffs |
| Deep refactor, security, architecture | gpt-5.3-codex or stronger | N/A |

## Session Efficiency Metrics

Track per session:

- **Events**: target < 150 per phase; alert at > 400 in a single session.
- **Compact calls**: target >= 1 at each phase boundary.
- **Main-session tool calls**: target < 30 per phase; alert at > 70.
- **Pasted message size**: target < 10 KB per message; alert at > 100 KB.
- **Re-plan count**: target 1 per sprint; alert if > 1 indicates template reuse failure.

## Auto-Compaction Thresholds

| Metric | Warning | Action |
|---|---|---|
| Events | >= 400 | `/compact` immediately |
| Tokens | >= 50M | `/compact` or `/new` |
| Events | >= 500 | Critical — `/new` with canonical refs only |

## Output

- Session efficiency score
- Recommended action (compact, new, model downshift, file reference)
- Projected token savings
