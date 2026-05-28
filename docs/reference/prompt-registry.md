# Prompt Registry Specification

Defines a centralized, versioned registry for prompts used across Base Coat agents and skills. The registry standardizes prompt discovery, rollout, deprecation, rollback, and auditability without forcing prompt text to live inline inside runtime code.

> **Tracking:** Issue [#116](https://github.com/IBuySpy-Shared/basecoat/issues/116)

---

## Overview

A prompt registry provides one authoritative place to manage every prompt used across agents, skills, and runtime integrations.

It should support:

- centralized registration for all prompts used across agents and skills
- semantic versioning using `major.minor.patch`
- a deprecation lifecycle of `active` → `deprecated` → `retired`
- audit trails showing who changed a prompt, when, and why
- operational controls for A/B testing, rollback, and safe promotion

Instead of embedding prompt text inline, agents should reference a stable prompt ID. Runtime resolution then maps that ID to a concrete version based on policy.

---

## Registry Goals

The registry exists to make prompt changes predictable and reversible.

Key outcomes:

- prompt changes become reviewable artifacts instead of hidden inline edits
- multiple versions can coexist safely during rollout and evaluation
- deprecated prompts can warn before removal instead of disappearing abruptly
- runtime systems can pin, test, or migrate prompts deliberately
- prompt usage can be audited after incidents or regressions

---

## Registry Schema

A portable registry can be represented as structured metadata plus prompt content stored in versioned files.

```yaml
prompts:
  - id: "code-review-system"
    version: "2.1.0"
    status: "active"            # active | deprecated | retired
    description: "System prompt for code review agent"
    author: "team-platform"
    created: "2026-03-15"
    deprecated_at: null
    sunset_date: null
    replacement: null            # ID of successor prompt
    tags: ["code-review", "quality"]
    model_compatibility: ["claude-*", "gpt-*"]
    token_budget: 1500
    content_path: "prompts/code-review/system-v2.1.md"
```

### Required Fields

| Field | Purpose |
|------|---------|
| `id` | Stable identifier referenced by agents and skills |
| `version` | Semantic version for this prompt revision |
| `status` | Lifecycle state: `active`, `deprecated`, or `retired` |
| `description` | Short explanation of prompt purpose |
| `author` | Team or owner responsible for the prompt |
| `created` | Registration date for this version |
| `tags` | Discovery labels such as domain or workflow |
| `model_compatibility` | Supported model families or exact models |
| `token_budget` | Maximum intended prompt token footprint |
| `content_path` | Location of the prompt body in source control |

### Optional Lifecycle Fields

| Field | Purpose |
|------|---------|
| `deprecated_at` | Date the prompt entered deprecated status |
| `sunset_date` | Earliest allowed retirement date |
| `replacement` | Successor prompt ID for migration guidance |

### Schema Notes

- `id` should remain stable across versions of the same prompt family.
- `version` should be unique within a given `id`.
- `status` controls runtime behavior, not just documentation.
- `retired` prompts should no longer resolve in runtime lookups, even if their metadata remains in an audit history.
- `content_path` should point to immutable prompt content for that exact version.

---

## Version Policy

Prompt versions use semantic versioning.

| Change Type | Example | Meaning |
|-------------|---------|---------|
| Patch | `2.1.0` → `2.1.1` | Typo fixes, wording clarifications, or formatting changes with no intended behavioral change |
| Minor | `2.1.0` → `2.2.0` | New capabilities or instructions added in a backward-compatible way |
| Major | `2.1.0` → `3.0.0` | Breaking behavioral change that can alter outputs materially and requires testing |

### Versioning Rules

- Patch versions should not require downstream retesting beyond routine smoke checks.
- Minor versions must include a short change log describing what capability was added.
- Major versions should be treated as new behavior and validated with targeted evals before promotion.
- Only one version per prompt ID should be the default active target at a time unless an explicit experiment is running.

---

## Deprecation Lifecycle

Every prompt version should move through an explicit lifecycle.

### 1. Active

`Active` is the current recommended state.

Behavior:

- eligible for default runtime resolution
- eligible for new agent and skill integrations
- should have current eval coverage and owner accountability

### 2. Deprecated

`Deprecated` means the prompt still works but should not be newly adopted.

Behavior:

- existing callers may continue using it temporarily
- runtime should log a warning whenever it is resolved
- registry metadata must include `deprecated_at`, `sunset_date`, and `replacement`
- migration guidance should point consumers to the successor prompt or version

### 3. Retired

`Retired` means the prompt is no longer available for active use.

Behavior:

- default resolution must fail with a clear error
- pinned calls must also fail clearly once retirement takes effect
- error messages should point to the replacement prompt when one exists
- the retired record may remain in audit storage, but it should be removed from active runtime listings and resolution

### Lifecycle Timeline

1. A prompt starts as `active`.
2. When superseded, it is marked `deprecated`.
3. It remains deprecated for a minimum of 30 days before retirement.
4. After the sunset date, it becomes `retired`.
5. A migration path must always be provided before retirement proceeds.

### Deprecation Example

```text
Prompt code-review-system@2.1.0 is deprecated and will retire on 2026-06-30.
Use code-review-system@3.0.0 instead.
```

### Retirement Example

```text
Prompt code-review-system@2.1.0 has been retired and is no longer available.
Replacement: code-review-system@3.0.0.
```

---

## Registry Operations

A registry implementation should expose a small set of consistent operations.

| Operation | Purpose |
|-----------|---------|
| `prompt_get(id, version?)` | Retrieve a prompt by ID and optional version; default to the latest active version |
| `prompt_list(tag?, status?)` | Browse prompts by tag and lifecycle state |
| `prompt_register(id, version, content)` | Add a new prompt version to the registry |
| `prompt_deprecate(id, version, replacement, sunset_date)` | Mark a version deprecated and define its migration target |
| `prompt_retire(id, version)` | Remove a prompt version from active runtime use |

### `prompt_get(id, version?)`

- If `version` is omitted, return the latest active version.
- If the requested version is deprecated, return it with a warning.
- If the requested version is retired, fail with a replacement hint.
- If no active version exists, fail clearly instead of guessing.

### `prompt_list(tag?, status?)`

- Support browsing by one or more tags.
- Support filtering by lifecycle state.
- Default views should exclude retired prompts unless explicitly requested for audit purposes.

### `prompt_register(id, version, content)`

- Require complete metadata, including owner, token budget, and model compatibility.
- Reject duplicate `id + version` pairs.
- Require at least one eval scenario before registration completes.
- Require a change log for minor and major versions.

### `prompt_deprecate(id, version, replacement, sunset_date)`

- Set status to `deprecated`.
- Record `deprecated_at` automatically.
- Enforce a minimum sunset date at least 30 days in the future.
- Require a valid replacement prompt ID or documented migration exception.

### `prompt_retire(id, version)`

- Allow retirement only after the sunset date.
- Remove the prompt from default runtime resolution.
- Preserve enough metadata for historical audits.
- Return an actionable error that points callers to the replacement.

---

## Quality Controls

Prompt registration should be gated by quality checks rather than treated as a file drop.

### Required Controls

- every prompt must have at least one eval scenario before registration
- token budget must be declared up front and enforced
- model compatibility must be explicitly maintained
- a change log is required for all minor and major versions

### Recommended Review Checks

| Control | Why It Matters |
|---------|----------------|
| Eval scenario exists | Prevents untested prompts from becoming active |
| Token budget declared | Reduces silent context bloat and runtime truncation |
| Compatibility matrix updated | Avoids using prompts on unsupported model families |
| Change log attached | Makes behavioral drift reviewable |
| Owner identified | Ensures there is a responsible maintainer |

### Eval Expectations

At minimum, each prompt version should define:

- one representative success scenario
- one regression-sensitive scenario for existing behavior
- expected outcome criteria or rubric

Major versions should add comparison evals against the prior active version before promotion.

---

## Integration

The registry is only useful if runtime systems resolve prompts consistently.

### Agent and Skill References

Agents should reference prompts by stable ID rather than embedding prompt text inline.

Example:

```yaml
system_prompt_id: "code-review-system"
```

Benefits:

- prompt behavior can evolve without editing every caller
- rollbacks are centralized
- prompt provenance stays auditable

### Runtime Resolution

Runtime systems should resolve prompt references using this policy:

1. agent requests prompt ID
2. registry resolves the latest active version
3. runtime loads prompt content from `content_path`
4. runtime enforces token budget and compatibility before use

### Version Pinning

Agents may pin a specific version when determinism matters.

Example:

```yaml
system_prompt:
  id: "code-review-system"
  version: "2.1.0"
```

Use pinning for:

- controlled rollouts
- reproducible evals
- workflows that cannot tolerate prompt drift during validation

### A/B Testing

The registry should support routing a percentage of traffic to an experimental version.

Example policy:

```yaml
routing:
  prompt_id: "code-review-system"
  control: "2.1.0"
  candidate: "2.2.0"
  split:
    control: 90
    candidate: 10
```

A/B testing should:

- preserve stable IDs while varying resolved versions
- record which version served each request
- support immediate rollback to the control version
- avoid promoting a candidate until eval and traffic data are acceptable

### Rollback

Rollback should be operationally cheap.

A safe registry design allows teams to:

- switch default resolution back to the prior active version
- preserve audit history of the failed rollout
- keep experimental versions out of general traffic until re-approved

---

## Migration Guide

Teams moving from inline prompts to a registry should migrate incrementally.

### From Inline Prompts to Registry

1. Extract the inline prompt into a dedicated prompt file.
2. Assign a stable prompt ID.
3. Register the extracted prompt in the registry.
4. Update the caller to reference the ID instead of embedding content.
5. Add eval coverage before marking the prompt active.

### Version Existing Prompts

For prompts that already exist but are not versioned:

1. capture the current production prompt as `1.0.0`
2. register it with owner, compatibility, and token budget metadata
3. treat subsequent edits as semantic version changes

### Promotion Guidance

Before promoting a new prompt to `active`:

- verify eval coverage exists
- confirm token budget stays within declared limits
- update the compatibility matrix
- attach the required change log for minor or major changes
- define a rollback target if the new version regresses

---

## Recommended Runtime Behavior

A robust implementation should follow these defaults:

| Concern | Recommended Behavior |
|--------|----------------------|
| Default lookup | Latest active version |
| Deprecated lookup | Return prompt plus warning |
| Retired lookup | Fail with replacement message |
| Minimum deprecation window | 30 days |
| Active default count per ID | One, unless explicit experiment routing is enabled |
| Audit retention | Keep metadata and change history even after retirement |

---

## Related References

- [`docs/HOOKS.md`](HOOKS.md) — lifecycle patterns for agent execution
- [`docs/../architecture/multi-agent-orchestration-patterns.md`](../architecture/multi-agent-orchestration-patterns.md) — agent orchestration and coordination patterns
- [`docs/../guides/MODEL_OPTIMIZATION.md`](../guides/MODEL_OPTIMIZATION.md) — model selection and compatibility considerations
- Issue [#116](https://github.com/IBuySpy-Shared/basecoat/issues/116) — tracking issue for prompt registry specification
