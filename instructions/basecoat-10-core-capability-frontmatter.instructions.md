---
description: "Use when authoring or reviewing agent and skill frontmatter with capability-first routing, justified model pinning, and safe fallback policy."
applyTo: "agents/**/*.agent.md,skills/**/SKILL.md"
---

# Capability-First Frontmatter Policy

Use this instruction to prefer capability-based routing over hardcoded model names.

## Policy

- Preserve existing frontmatter keys unless they are redundant or conflicting.
- Prefer capability fields over specific model IDs for new and updated assets.
- Keep explicit model pinning only when one of the following is true:
  - reproducibility or compliance requirements
  - known model-specific behavior dependency
  - strict compatibility constraints
- If `pinned_model` is present, `pin_reason` is required.
- Include safe fallback policy for model selection.

## Capability Fields

Use these normalized values:

- `reasoning_depth`: `none` | `low` | `medium` | `high`
- `tool_use`: `required` | `optional` | `none`
- `context_window`: `small` | `medium` | `large`
- `latency_profile`: `interactive` | `balanced` | `batch`
- `cost_tier`: `low` | `medium` | `high`
- `safety_level`: `standard` | `strict`

## Model Policy Fields

- `model_policy.fallback`: `true` for safe fallback behavior
- `model_policy.preferred_families`: ordered family preferences
- `model_policy.excluded_tiers`: optional disallowed tiers
- `pinned_model`: optional explicit model identifier
- `pin_reason`: required when `pinned_model` is set

## Compatibility and Migration

- Legacy `model` fields remain valid during migration.
- For existing assets, add capabilities first; remove direct model pins only when behavior is verified.
- Validation rollout should be staged: warn first, enforce later.

## Canonical Example (Capability-First)

```yaml
name: example-agent
description: "Use when coordinating a bounded workflow across multiple files."
capabilities:
  reasoning_depth: medium
  tool_use: required
  context_window: medium
  latency_profile: balanced
  cost_tier: medium
  safety_level: standard
model_policy:
  fallback: true
  preferred_families: [claude-sonnet, gpt-5]
---
```

## Canonical Example (Pinned With Justification)

```yaml
name: regulated-audit-agent
description: "Use when producing reproducible audit artifacts for regulated workflows."
capabilities:
  reasoning_depth: high
  tool_use: required
  context_window: large
  latency_profile: batch
  cost_tier: high
  safety_level: strict
model_policy:
  fallback: true
  preferred_families: [claude-sonnet]
  excluded_tiers: [low]
pinned_model: claude-sonnet-4.6
pin_reason: "Regulated audit baselines require reproducible output against approved evaluation fixtures."
---
```
