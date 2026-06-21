---
description: "Agent and skill development conventions, frontmatter requirements, visibility tagging, and evaluation coverage"
applyTo: "agents/**/*,skills/**/*"
---

# Agent & Skill Development

## Agent Frontmatter

All agents require:

```yaml
name: string (required)
description: string (required) — Include USE FOR: [3-5 cases] and DO NOT USE FOR: [3 anti-patterns]
visibility: basic|specialized|advanced|internal (required)
allowed_skills: [list] (optional)
capabilities: (recommended for new/updated assets)
  reasoning_depth: none|low|medium|high
  tool_use: required|optional|none
  context_window: small|medium|large
  latency_profile: interactive|balanced|batch
  cost_tier: low|medium|high
  safety_level: standard|strict
model_policy: (recommended when model behavior matters)
  fallback: true
  preferred_families: [family-a, family-b]
  excluded_tiers: [tier-a] # optional
  upshift: # optional, recommended for non-trivial agents
    allowed: true
    owner: runtime|orchestrator|human
    max_tier: reasoning|premium
    triggers: [complexity, safety_risk, repeated_failures, low_confidence]
  cost_tracking: # optional, recommended for production workflows
    budget_tier: low|standard|high
    chargeback_tag: string
pinned_model: string (optional; only for justified pinning)
pin_reason: string (required when pinned_model is set)
model: string (legacy compatibility; allowed during migration)
```

### Capability-First Policy

- Prefer capability fields and `model_policy` over hardcoded model identifiers.
- Keep a pinned model only when one of these applies:
  - reproducibility or compliance requirement
  - known model-specific behavior dependency
  - strict compatibility constraint
- If `pinned_model` is present, `pin_reason` is required.
- New and updated assets should include a safe fallback policy (`fallback: true` and preferred families).
- If `upshift.allowed` is true, define explicit `owner` and `triggers` so model shifts are deterministic.
- Prefer `owner: runtime` for automatic upshift rules; use `owner: human` only for regulated/high-risk flows.
- For assets used in long-running or production workflows, include `cost_tracking` fields for per-agent spend attribution.
- Legacy `model` fields remain valid during migration; do not force bulk rewrites.

### Visibility Tags

- `visibility: basic` — Everyday workflows (issue-triage, sprint-planner, code-review)
- `visibility: specialized` — Direct-target jobs (build-triage, branch-hygiene, ci-audit)
- `visibility: advanced` — Complex orchestration (escalation-router, orchestrator)
- `visibility: internal` — MCP/infrastructure only (mcp-developer, agentops)

## Skill Frontmatter

All skills require:

```yaml
name: string (required)
description: string (required) — USE FOR: [trigger cases]
compatibility: string (required)
visibility: public|private (optional, defaults to public)
capabilities: (optional, recommended for model-sensitive skills)
model_policy: (optional)
  fallback: true
  preferred_families: [family-a, family-b]
  upshift:
    allowed: true
    owner: runtime|orchestrator|human
    max_tier: reasoning|premium
    triggers: [complexity, safety_risk, repeated_failures, low_confidence]
  cost_tracking:
    budget_tier: low|standard|high
    chargeback_tag: string
pinned_model: string (optional; requires pin_reason)
pin_reason: string (required when pinned_model is set)
```

## Evaluation Coverage

All agents must have a companion `<agent>.agent.eval.yaml` file.
All skills must have a companion `eval.yaml` in the skill directory.

Run `pwsh tests/run-tests.ps1` to validate coverage.
