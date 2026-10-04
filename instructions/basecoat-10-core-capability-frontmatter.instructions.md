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
- Treat `reasoning_depth` only as task metadata. It must never be copied into the
  provider `reasoning_effort` field.
- Before emitting `reasoning_effort`, validate the selected model against
  `docs/reference/model-capabilities.json`. Omit the field for fixed-effort models.

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
- `model_policy.preferred_families`: ordered selectors; each is a canonical
  family token or an exact runtime model ID from
  `docs/reference/model-capabilities.json`
- `model_policy.excluded_tiers`: optional disallowed tiers
- `pinned_model`: optional explicit model identifier
- `pin_reason`: required when `pinned_model` is set

## Selector Normalization and Precedence

Use lowercase canonical family tokens: `claude`, `claude-fable`,
`claude-haiku`, `claude-opus`, `claude-sonnet`, `gemini`, `gpt`, `grok`,
`kimi`, or `mai-code`. The short aliases `sonnet`, `haiku`, and `opus` are
accepted by the normalization helper but are not valid in committed
frontmatter; write their `claude-*` canonical forms. Exact runtime model IDs
are case-sensitive in frontmatter and must exist in the capability catalog.

Resolve selectors in this order:

1. `pinned_model` takes precedence over all other selectors, requires a
   non-empty `pin_reason`, and is never substituted or given model fallback.
2. A local legacy `model` field remains authoritative during migration.
3. Otherwise, use local `model_policy.preferred_families` in declared order.
   With `fallback: true`, try each selector in sequence; with `fallback: false`,
   only the first selector is eligible.
4. Inherited selectors may be used only when explicitly supplied by the
   caller and no local `model` or `preferred_families` is declared. Parent
   agent models are not implicitly inherited.
5. If no selector is available, use the requested tier default, then the
   standard default when the tier is unknown.

Within a preferred selector, a family token describes a family and an exact
runtime model ID describes only that model; exact IDs are never reinterpreted
as family names. Unknown aliases and unsupported exact IDs fail validation.

## Compatibility and Migration

- Legacy `model` fields remain valid during migration.
- For existing assets, add capabilities first; remove direct model pins only when behavior is verified.
- Validation rollout should be staged: warn first, enforce later.
- Public GitHub support does not prove organization or user entitlement. Runtime
  routing must intersect the catalog with the authenticated Copilot model list.

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
  preferred_families: [claude-sonnet, gpt]
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
pinned_model: claude-sonnet-5
pin_reason: "Regulated audit baselines require reproducible output against approved evaluation fixtures."
---
```
