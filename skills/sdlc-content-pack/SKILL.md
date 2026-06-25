---
name: sdlc-content-pack
description: "USE FOR: generating SDLC-aligned content bundles (diagrams, click-through scripts, video scripts, decks) for workflows, skills, agents, and loops across SDLC phases. DO NOT USE FOR: code generation, PR reviews, deployment automation."
compatibility: ">=1.0"
visibility: public
category: workflow
metadata:
  category: workflow
  maturity: beta
  audience:
    - developer
    - program-manager
allowed-tools: []
---
# SDLC Content Pack

Generate one SDLC-aligned content bundle for a workflow, skill, agent, or loop.
Keep terms, ordered steps, and handoff points consistent across all artifacts.

## Workflow

1. Normalize the request into one bundle contract.
2. Resolve canonical terms, step order, and identifiers.
3. Generate artifacts in this order: diagram, click-through, video script, deck.
4. Run checklist/rubric gates before handoff.

## Guardrails

- Keep one canonical step list across all artifacts.
- Use the same bundle identifier, SDLC phase, and audience labels everywhere.
- Surface handoff points and approval gates explicitly.
- Prefer markdown-first outputs for versioned review.
