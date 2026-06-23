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

Generate a consistent content bundle for one delivery workflow, skill, agent, or
loop. The bundle keeps terminology, ordered steps, and handoff points aligned
across every artifact.

## Inputs

| Field | Required | Notes |
|---|---|---|
| `bundle_id` | Yes | Stable identifier reused across files and folders |
| `artifact_types` | Yes | Any of `diagram`, `click-through`, `video-script`, `deck` |
| `sdlc_phase` | Yes | `plan`, `build`, `validate`, `rollout`, or `operate` |
| `audience` | Yes | Primary consumer for the bundle |
| `maturity` | Yes | `draft`, `pilot`, `standardized`, or `production-ready` |
| `workflow_steps` | Yes | Canonical ordered steps shared by every generated artifact |
| `constraints` | No | Timebox, compliance, review, or tooling constraints |
| `source_refs` | No | Specs, issues, skills, agents, or docs that anchor the content |
| `domain_overlay` | No | Additive domain-specific terminology or checks |

## Outputs

| File | Purpose |
|---|---|
| `templates/diagram-template.md` | Workflow map and decision points |
| `templates/click-through-template.md` | Ordered walkthrough for demos and review |
| `templates/video-script-template.md` | 60-120 second narration script |
| `templates/deck-template.md` | Slide outline for handoff and onboarding |
| `eval.yaml` | Quality gates, rubric, and human review checklist |
| `generate-bundle.ps1` | Basic orchestration script for bundle export |

## Workflow

1. Normalize the request into one bundle contract.
2. Resolve canonical terminology, workflow steps, and identifiers.
3. Generate artifacts in this order: diagram, click-through, video script, deck.
4. Run the rubric and checklist before downstream handoff.
5. Export one review-ready package folder per bundle.

## Guardrails

- Keep one canonical step list across all artifacts.
- Use the same bundle identifier, SDLC phase, and audience labels everywhere.
- Surface handoff points and approval gates explicitly.
- Prefer markdown-first outputs that can be versioned and edited in-repo.

## Onboarding Guide

1. Start with one pilot workflow and define a canonical `workflow_steps` list.
2. Run `generate-bundle.ps1` to export a first draft bundle.
3. Review the draft against `eval.yaml` before sharing it downstream.
4. Tailor the templates for the target audience without changing core terms.
5. Use `adoption-guide.md` for rollout, review cadence, and ownership guidance.
