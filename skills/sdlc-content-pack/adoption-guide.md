# SDLC Content Pack Adoption Guide

## Purpose

Use this guide to pilot the SDLC content pack skill with one downstream team,
collect review feedback, and decide when the bundle format is ready for broader
reuse.

## Pilot Entry Criteria

- One workflow, skill, agent, or loop has a stable source of truth.
- A bundle owner can define the canonical `workflow_steps`.
- Reviewers are identified for content accuracy and handoff clarity.
- The team agrees to use markdown-first artifacts for the pilot.

## Recommended Pilot Sequence

1. Pick one candidate workflow with a clear SDLC phase and audience.
2. Gather source references such as specs, issues, skills, and agent docs.
3. Generate the first bundle with `generate-bundle.ps1`.
4. Score the draft against `eval.yaml`.
5. Capture edits, terminology drift, and missing handoff details.
6. Publish the revised bundle to the downstream team for live use.

## Roles

| Role | Responsibility |
|---|---|
| Bundle owner | Defines the request, canonical steps, and target audience |
| Reviewer | Checks accuracy, controls, and handoff clarity |
| Downstream team lead | Confirms the bundle is usable in onboarding or review |
| Maintainer | Incorporates pilot feedback into templates or rubric updates |

## Review Cadence

- **Draft review**: validate completeness and terminology consistency.
- **Pilot review**: confirm the bundle supports the real handoff conversation.
- **Retrospective review**: record what should become default guidance.

## Success Signals

- Reviewers approve the same terminology across all four artifacts.
- Downstream teams can use the bundle without rewriting the workflow story.
- Handoff owners and exit signals are clear during demos and onboarding.
- Pilot feedback results in small template adjustments instead of structural rework.

## Common Adjustments

- tighten the `workflow_steps` list when artifacts drift out of order
- add source references when reviewers need more traceability
- refine audience framing when the deck and video script need different emphasis
- extend the checklist when domain-specific controls appear repeatedly

## Exit Criteria

A pilot is ready to scale when:

1. at least one downstream team uses the bundle in a real review or onboarding flow
2. `eval.yaml` catches the most common quality gaps before human review
3. template edits are incremental, not structural
4. maintainers can explain how to create the next bundle in one pass
