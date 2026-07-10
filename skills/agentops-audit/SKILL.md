---
name: agentops-audit
compatibility: [github-copilot-cli]
description: "Audits and improves agent/skill specs with a scored rubric and routing rationale. USE FOR: scoring spec quality, identifying concrete fixes, producing revised specs, validating cost/latency fit, generating routing profiles. DO NOT USE FOR: implementing product features, unrelated code review, infrastructure deployment."
category: agent-development

metadata:
  category: agent-development
  domain: agent-development
  maturity: production
  audience:
    - maintainer
    - prompt-engineer
allowed-tools:
  - bash
  - git
  - gh
visibility: public
---
# Agent Operations Audit Skill

Audit agent or skill specifications and produce an actionable scorecard, risk list, and revised spec.

## USE FOR

- Scoring existing specs using a 0-5 rubric
- Finding ambiguity, safety gaps, and tool-policy issues
- Recommending concrete, prioritized fixes
- Producing a revised spec with measurable success criteria
- Generating routing rationale and estimated turn profile
- Supporting `audit` and `create_and_audit` flows in `agent-designer`

## DO NOT USE FOR

- Writing product application code
- Infrastructure deployment and operations
- General-purpose code review outside agent/skill definitions

## Required Scoring Dimensions (0-5)

- `clarity`
- `safety_compliance`
- `tool_correctness`
- `ambiguity_handling`
- `cost_latency_fit`
- `eval_readiness`

## Audit Deliverables

- `scorecard`
- `risks`
- `concrete_fixes`
- `revised_spec`

## Output Contract

Always include:

1. **Task-shaping classification** (`execution_mode`, `estimated_turns`, `tool_profile`, `uncertainty`)
2. **Routing profile**:
   - `recommended_class`: `Fast | Balanced | Deep | Tool-Strict`
   - `rationale`
   - `estimated_turns`: `1 | 2-3 | 4+`
   - `risk_mitigations`
3. **Artifacts**:
   - `audit_report`
   - `agent_spec` when a revised or regenerated spec is produced

## Guardrails

- Do not assume model family names are portable across providers.
- Prefer measurable success criteria over subjective language.
- Escalate when constraints conflict (for example: fast + deep reasoning + lowest cost).

## Related Skills

- `agent-design` — authoring and scaffolding agent/skill assets
