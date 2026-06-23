# SDLC Content Pack Generator Architecture Baseline

## Goal

The SDLC content pack generator produces SDLC-aligned content bundles that help
teams explain, review, and hand off delivery workflows across planning,
implementation, validation, and rollout phases. Each bundle is composed of four
artifact types:

- diagram
- click-through script
- video script
- deck outline

The generator must keep terminology, identifiers, and workflow steps consistent
across all artifacts in the same bundle.

## Problem Statement

Current workflow guidance is spread across specs, skills, agents, and sprint
artifacts. Downstream teams need a repeatable way to turn that source material
into content that is ready for onboarding, demo, review, and pilot rollout
without rewriting the same narrative for each audience.

## Scope

This baseline covers the initial control-plane scope for:

1. reusable content templates
2. bundle orchestration and package structure
3. quality gates and evaluation rubric
4. pilot onboarding guidance

It does not cover automated asset rendering to binary deliverables such as
PowerPoint files, videos, or image exports.

## Input Schema

Every bundle request should provide a normalized input contract.

| Field | Type | Description |
|---|---|---|
| `bundle_id` | string | Stable identifier used across artifacts and exported folders |
| `artifact_types` | string[] | Requested outputs: `diagram`, `click-through`, `video-script`, `deck` |
| `sdlc_phase` | string | Target phase such as `plan`, `build`, `validate`, `rollout`, or `operate` |
| `audience` | string | Primary consumer such as `engineering`, `leadership`, `field`, or `customer-success` |
| `maturity` | string | Content maturity such as `draft`, `pilot`, `standardized`, or `production-ready` |
| `constraints` | string[] | Limits such as timebox, review gates, localization, compliance, or tool restrictions |
| `source_refs` | string[] | Source specs, issues, skills, agents, or docs used to generate the bundle |
| `domain_overlay` | string | Optional domain extension key that adds domain-specific language or checks |

## Output Schema

Every generated bundle should emit a predictable folder structure and manifest.

| Output | Description |
|---|---|
| `manifest.json` | Bundle metadata, selected inputs, artifact list, and generation timestamp |
| `diagram.md` | Diagram source template populated with bundle terminology and flow nodes |
| `click-through.md` | Guided walkthrough with ordered steps, persona cues, and review notes |
| `video-script.md` | Narration-first script sized for a 60-120 second walkthrough |
| `deck.md` | Slide-by-slide outline with speaker intent and proof points |
| `quality-report.json` | Validation result, rubric scores, and review checklist status |

## Architecture Overview

The first implementation intentionally uses markdown-first assets and a simple
PowerShell orchestrator:

1. accept a normalized bundle request
2. resolve shared terminology and identifiers
3. populate each artifact template in generation order
4. run validation and rubric scoring
5. export a package folder for downstream editing and review

This keeps the first release easy to inspect, version, and adapt in-repo while
leaving room for later binary rendering or additional output channels.

## Artifact Generation Order

Generation order matters because later artifacts depend on the same narrative
spine and identifiers:

1. diagram
2. click-through script
3. video script
4. deck outline
5. quality report

The diagram establishes the workflow vocabulary, the click-through script
anchors the ordered steps, the video script compresses the same flow into a
spoken narrative, and the deck outline summarizes the same content for review
or onboarding.

## Consistency Model

The orchestration layer is responsible for enforcing:

- shared bundle identifier across every artifact
- one canonical list of workflow steps
- one canonical terminology map for phases, personas, and controls
- traceability from each artifact back to source references
- matching acceptance gates and handoff points in every artifact

## Extension Model

Domain overlays extend the baseline pack without changing the core contract.

Each overlay should be able to add:

- domain terminology and synonym mapping
- domain-specific constraints
- additional review checklist items
- optional artifact sections or prompts

The baseline implementation should treat overlays as additive metadata so the
same orchestration flow can serve workflows, skills, agents, loops, and future
domain packs.

## Track Breakdown

| Track | Issue | Deliverable |
|---|---|---|
| Planning baseline | #1879 | Architecture baseline, scope, acceptance mapping |
| Template library | #1844 | Reusable templates for diagram, click-through, video script, and deck |
| Orchestration pipeline | #1847 | Bundle generation order, consistency rules, and export package structure |
| Quality gates | #1846 | Validation rules, artifact rubric, and human review checklist |
| Pilot rollout guide | #1843 | Onboarding and adoption guidance for downstream teams |
| Implementation sprint | #1880 | Integrated skill assets and required quality gates |
| Closeout sprint | #1881 | Final docs, evidence, and lessons learned |
| Parent control plane | #1878 | Sprint rollup, merge sequencing, and completion evidence |

## Acceptance Criteria Mapping

| Acceptance area | Baseline expectation | Owning issue |
|---|---|---|
| Artifact coverage | Bundle supports diagram, click-through, video script, and deck outputs | #1844 |
| Input contract | Request schema captures artifact type, SDLC phase, audience, maturity, and constraints | #1879 |
| Output contract | Package structure is deterministic and includes validation output | #1847 |
| Consistency | Shared terminology, steps, and identifiers are enforced across artifacts | #1847 |
| Quality gates | Completeness, SDLC alignment, and handoff clarity are scored and reviewable | #1846 |
| Extensibility | Domain overlays can extend content without forking the core workflow | #1879 |
| Adoption | Downstream teams have a pilot guide and onboarding path | #1843 |

## Planned Package Structure

```text
skills/sdlc-content-pack/
├── SKILL.md
├── adoption-guide.md
├── eval.yaml
├── generate-bundle.ps1
└── templates/
    ├── click-through-template.md
    ├── deck-template.md
    ├── diagram-template.md
    └── video-script-template.md
```

## Assumptions

- Markdown is the system of record for generated content in the first release.
- Human review remains part of the release path for downstream team adoption.
- The first orchestration script can be basic as long as it establishes the
  generation contract, ordering, and export structure.

## Implementation Status

| Area | Status | Notes |
|---|---|---|
| Sprint 1 planning baseline | Complete | Scope, architecture, and acceptance mapping merged in PR #1956 |
| Sprint 2 skill implementation | Complete | `skills/sdlc-content-pack/` added in PR #1962 with templates, eval, orchestration, and inventory refresh |
| Sprint 3 closeout and onboarding | Complete | Onboarding guidance and pilot adoption assets added for downstream rollout |

## Final Delivered Assets

| Path | Status | Purpose |
|---|---|---|
| `skills/sdlc-content-pack/SKILL.md` | Delivered | Routing contract, workflow, guardrails, and onboarding entry point |
| `skills/sdlc-content-pack/templates/diagram-template.md` | Delivered | Reusable workflow diagram template |
| `skills/sdlc-content-pack/templates/click-through-template.md` | Delivered | Ordered walkthrough template |
| `skills/sdlc-content-pack/templates/video-script-template.md` | Delivered | Short-form narration template |
| `skills/sdlc-content-pack/templates/deck-template.md` | Delivered | Review and handoff deck outline |
| `skills/sdlc-content-pack/eval.yaml` | Delivered | Quality gates, rubric, and review checklist |
| `skills/sdlc-content-pack/generate-bundle.ps1` | Delivered | Basic bundle orchestration and export script |
| `skills/sdlc-content-pack/adoption-guide.md` | Delivered | Pilot rollout guide for downstream teams |

## Closeout Notes

- The first release is intentionally markdown-first so teams can inspect and
  adapt artifacts in-repo before converting them into richer media.
- The orchestration contract now standardizes bundle identifiers, workflow
  steps, source references, and handoff expectations across every artifact.
- The adoption path assumes human review remains part of the rollout loop for
  pilot teams before the skill is treated as a standardized asset.
