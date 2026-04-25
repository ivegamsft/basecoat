# Model Optimization Guide

This guide provides model-per-role recommendations for all Basecoat agents.
Use it when configuring your AI framework to assign the right model tier
to each agent role — balancing quality, speed, and cost.

---

## Why Model Selection Matters

Basecoat ships agent `.md` files that are framework-agnostic. Most
frameworks default to a single model for all agents — often the cheapest
option. This causes systematic under-performance on high-stakes tasks
(security analysis, architecture design, complex codebase reasoning) and
over-spend on simple automation tasks (polling, routing, status checks).

Match the model tier to the cognitive demand of the task.

---

## Tier Definitions

| Tier | Use For | Cost Profile |
|------|---------|-------------|
| **Premium** | High-stakes decisions with lasting consequences: security, architecture, deep reasoning | Highest |
| **Standard** | Analysis, code generation, structured thinking with moderate context | Medium |
| **Fast** | Simple automation, routing, status checks, short context | Lowest |

---

## Recommended Models by Role

| Agent / Role | Recommended Model | Tier | Rationale |
|---|---|---|---|
| `architect` | `claude-opus-4.6` | Premium | Architecture decisions are high-stakes and difficult to reverse. Requires deep multi-step reasoning across system boundaries. |
| `security-analyst` | `claude-opus-4.6` | Premium | Security analysis must be thorough and accurate. False negatives have serious consequences. |
| `code-review` | `claude-sonnet-4.6` | Standard | Nuanced review of logic and patterns — needs good reasoning but not premium depth. |
| `researcher` | `claude-sonnet-4.6` | Standard | Analysis and synthesis across multiple sources; needs coherent reasoning. |
| `qa` | `claude-sonnet-4.6` | Standard | Structured thinking, edge case enumeration, test strategy — benefits from reliable reasoning. |
| `manual-test-strategy` | `claude-sonnet-4.6` | Standard | Test strategy requires structured analysis of risk and coverage. |
| `exploratory-charter` | `claude-sonnet-4.6` | Standard | Charters require creative but structured session design. |
| `strategy-to-automation` | `claude-sonnet-4.6` | Standard | Analyzes manual test patterns and maps to automation candidates. |
| `merge-coordinator` | `claude-sonnet-4.6` | Standard | Merge decisions with conflict resolution need reliable reasoning. |
| `sprint-planner` | `claude-sonnet-4.6` | Standard | Dependency graph construction and wave planning require coherent multi-step reasoning. |
| `retro-facilitator` | `claude-sonnet-4.6` | Standard | Retrospective synthesis benefits from nuanced pattern recognition. |
| `backend-dev` | `gpt-5.3-codex` | Standard | Code-optimized model; generates accurate API, service, and data access code. |
| `frontend-dev` | `gpt-5.3-codex` | Standard | Code-optimized model; produces idiomatic UI components and accessibility-compliant markup. |
| `middleware-dev` | `gpt-5.3-codex` | Standard | Code-optimized model; message contracts, integration patterns, and async code. |
| `data-tier` | `gpt-5.3-codex` | Standard | Code-optimized model; schemas, migrations, and parameterized query generation. |
| `config-auditor` | `claude-haiku-4.5` | Fast | Pattern matching against known config anti-patterns; short context, deterministic output. |
| `rollout-basecoat` | `claude-haiku-4.5` | Fast | Checklist execution and file operations; no complex reasoning required. |
| `new-customization` | `claude-haiku-4.5` | Fast | Template-driven file creation; straightforward structured output. |
| `project-onboarding` | `claude-sonnet-4.6` | Standard | Multi-step repo setup with sequential decisions and error handling. |
| `release-manager` | `claude-sonnet-4.6` | Standard | Release workflow requires accurate semver reasoning and multi-step sequencing. |
| `agent-watchdog` | `claude-haiku-4.5` | Fast | Simple process monitoring and kill decisions; no complex reasoning. |
| `sprint-demo` | `gpt-5.4-mini` | Fast | Routine automation — deck updates, recording uploads, meeting scheduling. |

---

## Model Section in Agent Files

Every agent `.md` file should include a `## Model` section immediately
after `## Inputs` (or after frontmatter if there are no Inputs):

```markdown
## Model

Recommended: <model-id>
Rationale: <one sentence explaining why this tier>
Minimum: <lowest-tier model that produces acceptable results>
```

### Example — premium tier agent

```markdown
## Model

Recommended: claude-opus-4.6
Rationale: Security analysis requires thorough, accurate reasoning; false
negatives have serious consequences.
Minimum: claude-sonnet-4.6
```

### Example — code-generation agent

```markdown
## Model

Recommended: gpt-5.3-codex
Rationale: Code-optimized model produces more accurate API and service code
than general-purpose models at the same cost tier.
Minimum: gpt-5.4-mini
```

### Example — fast/automation agent

```markdown
## Model

Recommended: claude-haiku-4.5
Rationale: Pattern matching and checklist execution require no complex
reasoning — fast and cheap is appropriate.
Minimum: claude-haiku-4.5
```

---

## Decision Framework

Use this decision tree to select a tier for a new agent:

```
Does the agent make high-stakes decisions that are hard to reverse?
  YES → Premium (claude-opus-4.6)
  NO  ↓

Does the agent write or review code?
  YES → Code-optimized Standard (gpt-5.3-codex)
  NO  ↓

Does the agent analyze, synthesize, or reason across multiple inputs?
  YES → Standard (claude-sonnet-4.6)
  NO  ↓

Does the agent execute a checklist, do simple routing, or run automation?
  YES → Fast (claude-haiku-4.5 or gpt-5.4-mini)
```

---

## Cost Attribution

To track model costs by agent role, tag API calls with the agent name:

```bash
# Example: metadata tagging in OpenAI-compatible APIs
--header "X-Agent-Role: backend-dev"
--header "X-Sprint: S7"
```

Framework-specific implementations vary. Consult your framework's
telemetry documentation for cost attribution patterns.

---

## Updating Agent Model Assignments

When a new model tier becomes available:

1. Update this table with the new model ID
2. Add a CHANGELOG entry
3. Update the `## Model` section of affected agent `.md` files in a single PR
4. Bump the `minor` version (new recommendation, backward-compatible)

Do not change model assignments without updating this guide and the
affected agent files in the same PR — keep them in sync.

---

## Source

Model tier recommendations derived from operational experience across
multiple sprints. Initial motivation:
`ivegamsft/app-migration-with-ai` — Sprint 2, where all agents defaulted
to Haiku and underperformed on security analysis and architecture design tasks.
Tracked in Basecoat issue #50.
