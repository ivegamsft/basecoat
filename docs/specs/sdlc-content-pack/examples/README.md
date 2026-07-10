# SDLC Content Pack Generator - Worked Examples

This directory contains worked examples of SDLC Content Pack bundles demonstrating
how the generator produces consistent, multi-artifact output for different SDLC
phases and entity types.

## Purpose

These examples serve as:

1. **Reference implementations** showing the expected bundle structure and content
2. **Validation fixtures** for quality gates and rubric scoring
3. **Training materials** for downstream teams adopting the skill
4. **Test cases** for bundle generation automation

## Examples Included

### example-plan-phase-sprint-planning.md

**Phase**: Plan

**Entity Type**: Workflow

**Audience**: Engineering

Demonstrates how the generator produces a complete bundle for sprint planning
guidance:

- **Diagram**: Flowchart showing scope → dependencies → mapping → capacity →
  publish decision gates
- **Click-Through**: Step-by-step walkthrough with review prompts at each gate
- **Video Script**: 90-second narration covering the same steps
- **Deck Outline**: Slide-by-slide breakdown for executive and team lead audiences

**Key Takeaway**: All four artifacts tell the same workflow story with the same
step sequence, but each tailored to its consumption context (reference diagram,
guided walkthrough, spoken narrative, presentation slides).

### example-validate-phase-code-review.md

**Phase**: Validate

**Entity Type**: Skill

**Audience**: Engineering

Demonstrates how the generator produces a complete bundle for code review
standardization:

- **Diagram**: Flowchart showing PR submission → automated checks → review → approval → merge gates
- **Click-Through**: Step-by-step code review process with decision points
- **Video Script**: 90-second narration showing reviewer perspective
- **Deck Outline**: Slides covering review types, expectations, and metrics

**Key Takeaway**: Even though this is a different phase and entity type than the
sprint planning example, the same orchestration contract applies: one bundle ID,
shared step list, consistent terminology across all artifacts.

## How to Use These Examples

### For Design Review

1. Read both examples end-to-end
2. Verify that each artifact independently tells the same workflow story
3. Check that terminology is consistent across all four outputs
4. Confirm handoff points and exit signals are clear in each artifact

### For Quality Gate Validation

1. Score each example against the rubric in `skills/sdlc-content-pack/eval.yaml`
2. Verify all completeness and consistency checks pass
3. Validate that human review checklist items are addressed
4. Use scores as reference for future bundle quality assessment

### For Downstream Team Onboarding

1. Share these examples with downstream team leads
2. Use as reference when teams create their own bundles
3. Ask: "Does your bundle follow the same pattern as these?"
4. Reference when answering "What should a good bundle look like?"

### For Tool Development

1. Use these examples as test fixtures for automation
2. Verify that any future rendering tools produce equivalent output
3. Ensure any schema extensions don't break these reference bundles
4. Archive for regression testing as the skill evolves

## Example Structure

Each example includes:

| Section | Purpose |
|---|---|
| Metadata | Bundle ID, phase, audience, maturity, entity type, constraints, sources |
| Diagram | Mermaid flowchart showing workflow path and decision gates |
| Click-Through | Ordered walkthrough steps with decision points and review prompts |
| Video Script | 60-120 second narration divided into scenes and timings |
| Deck Outline | Slide-by-slide outline with key points and proof points |
| Quality Report | Summary of rubric scores and validation results |
| Human Review Checklist | Items for downstream team to verify before adopting |
| Next Steps | Recommended actions after bundle is approved |

## Consistency Validation

These examples demonstrate the consistency model as an aspirational target:

1. **Core Steps Alignment**: Core workflow steps appear in all artifacts; diagram includes additional decision nodes not fully represented in narrative/deck
2. **Same Bundle ID**: **Bundle ID** appears in every artifact for traceability
3. **Similar Terminology**: Terminology used in the diagram is largely reused in the walkthrough, script, and deck (with some diagram-specific detail)
4. **Same Handoff Points**: Entry signal, exit signal, and approval gates are explicit in every artifact
5. **Same Audience Framing**: Though framed differently (diagram vs. narrative vs. slides), each artifact targets the same audience and serves the same purpose

**Future Refinement**: Tightening consistency (particularly around detailed decision nodes in diagrams vs. narrative focus) is a recommended enhancement for production bundles.

## Next Steps for Implementation

- [ ] Run these examples through the automated quality gates in `skills/sdlc-content-pack/eval.yaml`
- [ ] Distribute to the SDLC Content Pack working group for feedback
- [ ] Use as reference when creating the first production bundle
- [ ] Archive these examples in the pilot rollout guide for downstream teams
- [ ] Create additional examples for other phases (build, rollout, operate) as
      the skill matures

## Future Extensions

Future examples may include:

- **Build Phase**: Development task breakdown workflow
- **Rollout Phase**: Deployment and rollback coordination
- **Operate Phase**: On-call runbook and incident response
- **Multi-Domain**: Examples with security, compliance, or platform overlays
- **Specialized Entity Types**: Loops, agents, or domain-specific workflows
