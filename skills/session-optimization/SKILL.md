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

Apply session hygiene to reduce token cost, event count, and context bloat.

## Shortcut Phrases

- optimize session
- compact now
- check token status
- reduce context bloat
- session hygiene

## Phase-Boundary Compaction

Run `/compact` at each phase boundary:

| Phase transition | Action |
|---|---|
| Triage to implementation | `/compact` |
| Implementation to merge-waiting | `/compact` |
| Merge-waiting to next phase | `/compact` |
| Domain pivot | `/new` |

Target: <150 events per phase; compact before 400 total.

## File-Reference Discipline

Never paste large blocks into chat. Use file references:

```text
See: skills/session-optimization/SKILL.md
See: .github/instructions/cost-optimization.instructions.md
```

Expected savings: ~300x tokens per pasted block.

## Session Efficiency Metrics

Track per session:

- **Events**: target <150 per phase; alert at >400.
- **Compact calls**: target >=1 per phase boundary.
- **Main-session tool calls**: target <30 per phase.
- **Pasted message size**: target <10KB per message.

## Auto-Compaction Thresholds

| Metric | Warning | Action |
|---|---|---|
| Events | >= 400 | `/compact` immediately |
| Tokens | >= 50M | `/compact` or `/new` |
| Events | >= 500 | Critical — `/new` with canonical refs only |

## Output

- Session efficiency score
- Recommended action (compact, new, downshift, file reference)
- Projected token savings
