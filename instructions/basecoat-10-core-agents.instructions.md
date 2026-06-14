---
description: "Use when creating, updating, or reviewing agent definitions. Covers naming, structure, required sections, skill pairing, capability-based routing, model policy, and testing."
applyTo: "agents/**/*.agent.md"
---

# Agent Authoring Standards

Use this instruction as the definitive guide for creating, modifying, or reviewing any agent in the basecoat framework.

## File Naming

- All agent files live in the `agents/` directory at the repository root.
- Use **kebab-case** with the `.agent.md` suffix: `backend-dev.agent.md`, `security-analyst.agent.md`.
- The file name must match the `name` field in the YAML frontmatter.
- Choose names that describe the **role**, not the task: `release-manager` (role) over `cut-release` (task).

## YAML Frontmatter

Every agent file must start with a YAML frontmatter block containing these fields:

```yaml
---
name: kebab-case-agent-name
description: "One-sentence description of the agent's purpose. Start with the role noun and state when to invoke it."
visibility: internal
tools: [read_file, write_file, list_dir, run_terminal_command, create_github_issue]
allowed_skills: [skill-name-a, skill-name-b]
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
handoffs:
  - label: Next Step
    agent: next-agent-name
    prompt: Continue from the output above. <specific instructions>
    send: false
---
```

| Field | Required | Notes |
|---|---|---|
| `name` | Yes | Must match the filename (without `.agent.md`). |
| `description` | Yes | One sentence. Begin with the role, end with trigger guidance ("Use when …"). |
| `tools` | Yes | Array of tool identifiers the agent needs. Enforced at runtime — the agent cannot call any tool not in this list. Follow least-privilege — include only tools the agent actually uses. |
| `allowed_skills` | No | Array of skill folder names the agent may invoke. When omitted, the agent inherits all available skills (legacy behavior). Use `allowed_skills: []` to block all skill invocations. When present, the runtime filters the `<available_skills>` list to this allow-list before injecting it into the agent context. |
| `capabilities` | Recommended | Capability profile used for routing policy: `reasoning_depth`, `tool_use`, `context_window`, `latency_profile`, `cost_tier`, `safety_level`. |
| `model_policy` | Recommended | Routing and fallback policy. Include `fallback: true` and `preferred_families` for safe defaults. |
| `pinned_model` | Conditional | Only for reproducibility/compliance, model-specific dependency, or strict compatibility constraints. |
| `pin_reason` | Conditional | Required when `pinned_model` is present. Explain why pinning is necessary. |
| `model` | Legacy | Allowed during migration for compatibility with existing assets and runtimes. |
| `handoffs` | No | Array of VS Code transition buttons rendered after each response. Each entry requires `label`, `agent`, and `prompt`. Set `send: false` to let the user review before the next agent runs. See `docs/agent-handoffs.md`. |

### Runtime Enforcement Semantics

- **`tools:` is a whitelist.** At runtime the agent session is restricted to exactly the tools declared. Any tool not listed is unavailable, regardless of what the parent session has enabled.
- **`allowed_skills:` is a filter.** The platform injects only the skills named in this list into `<available_skills>`. An agent with `allowed_skills: []` receives an empty skill catalog and must stop immediately if its workflow depends on a skill.
- **Capability-first policy applies by default.** New and updated agents should drive routing from `capabilities` and `model_policy`.
- **Pinned model policy is exception-only.** If `pinned_model` is used, `pin_reason` is mandatory and must document one of the approved pinning justifications.
- **Legacy model binding remains compatible.** Existing assets that rely on the `## Model` section and/or `model` frontmatter remain valid during migration.
- **`handoffs:` is declarative.** Handoff entries do not affect the agent's runtime behavior — they configure the VS Code UI to display transition buttons after the agent responds. The `agent` field must match the `name` field of an existing agent.

## Required Sections Checklist

Sections 1–8 are required. Omitting any of them is a review-blocking finding. Section 9 is optional but strongly recommended.

1. **Title** — H1 heading: `# <Role> Agent`.
2. **Purpose** — One to two sentences immediately below the title stating what the agent does and why it exists.
3. **Inputs** — Bulleted list of the information the agent expects before it begins work.
4. **Workflow** — Numbered step-by-step process. Each step starts with a bolded verb phrase. The final step must reference issue filing.
5. **Domain sections** — One or more H2 sections covering the agent's domain-specific standards, checklists, or reference tables (e.g., API Design Principles, OWASP Top 10 Review).
6. **GitHub Issue Filing** — Standard `gh issue create` template with labeled trigger conditions table. Agents must file issues inline — deferral is never acceptable.
7. **Model & Routing Policy** — Capability profile plus any pinned-model justification (see Capability-First Model Policy below).
8. **Output Format** — What the agent delivers: code, reports, filed issues, or structured artifacts. Must include reference to issue numbers in deliverables.
9. **Allowed Skills** *(optional but strongly recommended)* — Allow-list of skills the agent may invoke at runtime. See the Allowed Skills Section below.

## Allowed Skills Section

Every agent file **should** include an `## Allowed Skills` section. List each skill by folder name, one per line. If none, include `*(none)*`. An agent must not invoke skills not listed; stop and report blockers rather than searching unrelated skills.

See [`references/agents/skill-pairing.md`](references/agents/skill-pairing.md) for examples and multi-agent coordination rules.

## Capability-First Model Policy

Choose capabilities based on the agent's workload first, then pin only when justified.

| Workload Pattern | Capability Profile | Notes |
|---|---|---|
| Code-heavy implementation | `reasoning_depth: medium`, `tool_use: required`, `context_window: medium`, `latency_profile: balanced`, `cost_tier: medium`, `safety_level: standard` | Use family preferences for code-capable models; avoid hard pins unless needed. |
| Analysis and security review | `reasoning_depth: high`, `tool_use: required`, `context_window: large`, `latency_profile: balanced`, `cost_tier: medium`, `safety_level: strict` | Pin only for reproducible compliance baselines. |
| Architecture and design | `reasoning_depth: high`, `tool_use: optional`, `context_window: large`, `latency_profile: interactive`, `cost_tier: high`, `safety_level: standard` | Prefer families with strong long-horizon reasoning. |
| Planning and coordination | `reasoning_depth: low`, `tool_use: optional`, `context_window: small`, `latency_profile: interactive`, `cost_tier: low`, `safety_level: standard` | Prioritize low-latency and low-cost routing. |

- If `pinned_model` is used, include `pin_reason` and document the compatibility/compliance dependency in the body.
- Always include a fallback policy (`fallback: true`, `preferred_families`, optional `excluded_tiers`).
- During migration, legacy `model` values are still permitted; do not churn stable assets only to replace model IDs.

When pinning is required, add this block explicitly:

```yaml
pinned_model: claude-sonnet-4.6
pin_reason: "Compatibility with an established evaluation baseline."
```

## Reference Files

| File | Contents |
|---|---|
| [references/agents/skill-pairing.md](references/agents/skill-pairing.md) | Allowed Skills section format, agent-to-skill pairing, multi-agent coordination, token budget rules |
| [references/agents/lifecycle.md](references/agents/lifecycle.md) | Validation checklist, versioning, deprecation, minimal agent skeleton |
