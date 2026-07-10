# Agent Runtime Enforcement

How basecoat agents achieve parity with the platform's built-in agents through
tool binding, skill allow-listing, model binding, and optional subprocess isolation.

---

## Problem: Prompt-Only vs. Subprocess Parity

Default built-in agents (`explore`, `task`, `general-purpose`, `code-review`) are
runtime-enforced subprocesses. The platform gives them exactly the tools listed and
nothing else — they cannot wander.

Basecoat custom agents were historically **prompt-only personas**. The `tools:` field
was documentation, not enforcement. At runtime the agent inherited whatever the parent
session had, plus the entire unfiltered skill catalog. This caused:

- Agents invoking unrelated skills before stopping
- Agents failing silently when a required tool was absent from the parent session
- Model selection being ignored in favor of the session default

The fields and behaviors described in this document close that gap.

---

## Tool Binding (`tools:`)

```yaml
tools: [read_file, write_file, run_terminal_command, create_github_issue]
```

**Enforcement behavior:**

- The agent session is restricted to exactly the tools declared.
- Any tool not in the list is unavailable, regardless of what the parent session has enabled.
- If the agent attempts to call an unlisted tool, the call is rejected at the platform boundary.

**Authoring rules:**

- Follow the principle of least privilege. Include only tools the agent's workflow actually calls.
- Do not add tools "just in case" — every extra tool adds prompt overhead and expands the attack surface.
- See `instructions/basecoat-10-core-tool-minimization.instructions.md` for detailed guidance on tool auditing.

---

## Skill Allow-List (`allowed_skills:`)

```yaml
allowed_skills: [basecoat, security, backend-dev]
```

**Enforcement behavior:**

- The platform filters the global `<available_skills>` list down to only the skills named here before injecting it into the agent's context.
- An agent with `allowed_skills: []` receives an empty skill catalog. If its workflow requires a skill, it must stop and report the gap rather than invoking unrelated skills.
- If `allowed_skills` is omitted, the agent inherits the full skill catalog (legacy behavior). New agents should always declare this field.

**Authoring rules:**

- Name only the skill folder names (the directory names under `skills/`), not the full path.
- Every name in `allowed_skills` must correspond to an existing directory under `skills/`.
- Use `allowed_skills: []` for agents that are fully self-contained — they never invoke skills.
- Validate skill names as part of pre-merge testing (see `tests/agent-integration-tests.ps1`).

**Example — no skills needed:**

```yaml
---
name: guardrail
tools: [read_file, list_dir, run_terminal_command]
allowed_skills: []
---
```

**Example — scoped to specific skills:**

```yaml
---
name: security-analyst
tools: [read_file, list_dir, run_terminal_command, create_github_issue]
allowed_skills: [security, basecoat]
---
```

---

## Model Binding (`## Model`)

The `## Model` section in an agent file is **binding**, not advisory.

```markdown
## Model

**Recommended:** claude-sonnet-4.6
**Rationale:** Goal decomposition and dependency mapping require deep reasoning
**Minimum:** claude-haiku-4.5
```

**Enforcement behavior:**

- The platform uses the **Recommended** model identifier as the actual model when the agent is invoked.
- The **Minimum** model is used as a fallback when the recommended model is unavailable.
- Model identifiers must exactly match the platform's model registry (e.g., `claude-sonnet-4.6`, `gpt-5.3-codex`).

**Authoring rules:**

- Always provide both `**Recommended:**` and `**Minimum:**` with exact model identifiers.
- Provide a one-line `**Rationale:**` to document why the model was chosen.
- See the Model Selection Guide in `instructions/basecoat-10-core-agents.instructions.md` for per-role recommendations.

---

## Subprocess Isolation

Subprocess isolation spawns the agent in an isolated subprocess — similar to how the
platform's built-in `task` and `explore` agents work. This provides:

- A clean context window with no parent-session history
- Injected tools restricted to the agent's `tools:` list
- Injected skill catalog restricted to the agent's `allowed_skills:` list
- Model bound to the agent's `## Model` recommendation

### Opting Into Subprocess Isolation

Add the `isolation: subprocess` field to the agent's YAML frontmatter:

```yaml
---
name: sprint-planner
description: "Goal-to-issues decomposition. Use when planning a sprint."
tools: [run_terminal_command, read_file, write_file, create_github_issue]
allowed_skills: [basecoat]
isolation: subprocess
---
```

When `isolation: subprocess` is set:

1. The platform spawns a fresh subprocess for every invocation of the agent.
2. The subprocess receives only the tools and skills declared in frontmatter.
3. The subprocess has no access to parent-session context, history, or environment variables unless explicitly passed as inputs.
4. On completion, the subprocess returns its output to the parent session as a structured result.

### When to Use Subprocess Isolation

| Situation | Use Subprocess? |
|---|---|
| Agent modifies files or issues — side effects matter | Yes |
| Agent does read-only analysis and returns a report | Optional |
| Agent is a lightweight filter or validator | No |
| Agent is a long-running orchestrator that spawns other agents | No — use fan-out pattern instead |
| Agent shares state with a parent workflow mid-session | No |

### Subprocess Isolation vs. Default Behavior

| Property | No Isolation (default) | Subprocess Isolation |
|---|---|---|
| Tool access | Restricted to `tools:` | Restricted to `tools:` |
| Skill catalog | Filtered by `allowed_skills:` | Filtered by `allowed_skills:` |
| Model | Bound to `## Model` | Bound to `## Model` |
| Context | Shares parent session | Fully isolated |
| Parent history visible | Yes | No |
| Cost | Low | Higher (new subprocess overhead) |

---

## Comparison: Built-In Agents vs. Basecoat Agents

| Property | Built-In Agents | Basecoat Agents (enforced) |
|---|---|---|
| Tool access | Hardcoded by runtime | Declared in `tools:`, enforced at runtime |
| Skill catalog | N/A (no skills) | Filtered by `allowed_skills:` |
| Model | Assigned per type | Bound to `## Model` recommendation |
| Invocation | Subprocess with injected tools | Session-scoped or subprocess (opt-in) |
| Session isolation | Always isolated | Isolated with `isolation: subprocess` |

---

## Validation

Use the integration test suite to verify enforcement metadata before merging:

```powershell
pwsh tests/agent-integration-tests.ps1
```

Tests include:

- `tools:` is present and is a valid YAML array
- `allowed_skills:` if present, is a valid YAML array (empty array is valid)
- All skill names in `allowed_skills` correspond to directories under `skills/`
- `## Model` section is present with `**Recommended:**` and `**Minimum:**` entries

---

## References

- `instructions/basecoat-10-core-agents.instructions.md` — authoritative agent authoring standards
- `instructions/basecoat-10-core-tool-minimization.instructions.md` — tool audit checklist
- `agents/basecoat-10-core-agent-designer.agent.md` — agent design workflow and frontmatter conventions
- `tests/agent-integration-tests.ps1` — automated validation suite
- `docs/agents/MULTI_AGENT_WORKFLOWS.md#canonical-sub-agent-harness-contract` — canonical orchestrator↔sub-agent task and response packet contract
