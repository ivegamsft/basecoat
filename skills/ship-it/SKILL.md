---
name: ship-it
description: "Use when converting a delivery intent (`ship-it` or `spec-2-prod`) into a governed multi-sprint execution plan with live issue side effects. USE FOR: dispatching ship-it intents, creating tracked sprint issue bundles, enforcing risk-band governance checklists, and handing intent execution to orchestration agents. DO NOT USE FOR: direct production deployment without gates, ad hoc one-off bugfixes, or bypassing approval policies."
compatibility:
  - GHCP
category: workflow
visibility: public
metadata:
  category: workflow
  maturity: alpha
  audience:
    - developer
allowed-tools: []
---
# Ship-it Skill

Use this skill to start intent-driven delivery from a single goal statement and
turn it into a governed, trackable execution bundle.

## Shortcut Phrases

- ship it
- spec to prod
- start intent execution
- launch governed delivery loop

## Inputs

1. `intent`: `ship-it` or `spec-2-prod`
2. `goal`: short delivery objective
3. `target_repo`: `owner/repo`
4. `spec_ref` (optional): PRD/spec URL or path
5. `risk_band`: `low | medium | high | critical`

## Workflow

1. Validate the intent contract.
2. Dispatch `.github/workflows/ship-it-intent-dispatch.yml`.
3. Generate parent goal issue and sprint child issues with governance checklists.
4. Add labels for risk, intent, and control-plane tracking.
5. Hand off execution to `orchestrator` or `agentic-sdlc-autonomy`.

## Governance Rules

1. Never bypass required checks for high/critical risk goals.
2. Require explicit evidence links for spec, tests, rollout, and rollback.
3. Use serialized merges for release-affecting work.
4. Record state transitions and blockers in issue artifacts.

## Output

- Parent goal issue URL
- Child sprint issue URLs
- JSON summary artifact for automation and reporting
