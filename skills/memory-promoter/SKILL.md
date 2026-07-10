---
name: memory-promoter
compatibility: [github-copilot-cli]
description: "Use when mining completed sessions and sprint summaries for reusable patterns that should be promoted into long-term team memory. USE FOR: extract recurring fix patterns, rank memory candidates by frequency and impact, produce contribution-ready memory payloads, filter ephemeral or secret content before memory submission. DO NOT USE FOR: writing production code, real-time troubleshooting during active debugging, or storing personal/project-sensitive data."
category: operations
metadata:
  category: operations
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# Memory Promoter Skill

Extract repeatable engineering patterns from session artifacts and format them into safe, high-signal memory candidates.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `memory-candidate-scorecard-template.md` | Scores candidate memories by frequency, impact, and reusability |
| `memory-payload-template.md` | Produces standardized contribution payloads for memory promotion |

## Agent Pairing

Use with `memory-promoter` agent. For data quality checks before submission, pair with `guidance-reviewer`.
