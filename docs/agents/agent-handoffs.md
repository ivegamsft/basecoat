# Agent Handoff Workflows

Agent handoffs are VS Code-native transitions that appear as buttons after an agent
response, letting users move to the next agent in a workflow with one click and a
pre-filled prompt. They turn a collection of independent agents into a guided,
multi-step workflow.

## How Handoffs Work

VS Code reads the `handoffs` array from an agent's YAML frontmatter. After each
response, it renders a button for each handoff entry. Clicking a button opens the
target agent with a pre-populated prompt, which the user can review and edit before
sending.

```yaml
handoffs:
  - label: "Button label shown to the user"
    agent: target-agent-name
    prompt: "Pre-filled prompt sent to the target agent."
    send: false
```

| Field | Required | Description |
|---|---|---|
| `label` | Yes | Text shown on the transition button |
| `agent` | Yes | `name` field of the target agent (matches filename without `.agent.md`) |
| `prompt` | Yes | Pre-filled context sent to the target agent |
| `send` | No | `false` (default) lets the user review/edit; `true` auto-sends immediately |

Use `send: false` for all BaseCoat handoffs. This lets the user review the
pre-filled context, make adjustments, and confirm intent before the next agent runs.

## Handoff UI vs. Sub-Agent Harness Contract

Handoffs and harness contracts solve different problems:

- `handoffs` is a VS Code UI transition mechanism (button + pre-filled prompt).
- The harness contract is the canonical machine-readable payload used by
  orchestrators when dispatching sub-agent work and validating responses.

When a handoff launches a workflow that includes sub-agent execution, use the
canonical contract in:

- `docs/agents/MULTI_AGENT_WORKFLOWS.md#canonical-sub-agent-harness-contract`

## Handoff Chains

The following chains are implemented across BaseCoat agents.

### Planning → Implementation

#### Product Manager → Sprint Planner

**Trigger:** Feature requirements and prioritized user stories are ready.

```text
product-manager ──► sprint-planner
```

| Button | Agent | Purpose |
|---|---|---|
| Plan Sprint | `sprint-planner` | Decompose stories into GitHub issues and a wave dependency map |

#### Solution Architect → Backend / Frontend Dev

**Trigger:** Architecture design (C4 diagrams, ADRs, API contracts) is complete.

```text
solution-architect ──► backend-dev
solution-architect ──► frontend-dev
```

| Button | Agent | Purpose |
|---|---|---|
| Start Backend Implementation | `backend-dev` | Implement service layer and API contracts from the architecture |
| Start Frontend Implementation | `frontend-dev` | Implement UI components following the architecture boundaries |

#### API Designer → Backend Dev

**Trigger:** OpenAPI spec is authored and governance checks pass.

```text
api-designer ──► backend-dev
```

| Button | Agent | Purpose |
|---|---|---|
| Implement API | `backend-dev` | Implement the OpenAPI contract (endpoints, schemas, error codes) |

#### Sprint Planner → Backend / Frontend Dev

**Trigger:** Sprint issues, wave dependency map, and acceptance criteria are created.

```text
sprint-planner ──► backend-dev
sprint-planner ──► frontend-dev
```

| Button | Agent | Purpose |
|---|---|---|
| Begin Backend Sprint Work | `backend-dev` | Implement backend issues from the sprint plan |
| Begin Frontend Sprint Work | `frontend-dev` | Implement frontend issues from the sprint plan |

### Review → Security

#### Code Review → Security Analyst

**Trigger:** Code review is complete and findings are prioritized.

```text
code-review ──► security-analyst
```

| Button | Agent | Purpose |
|---|---|---|
| Run Security Review | `security-analyst` | Evaluate new endpoints and data flows against OWASP Top 10 |

### Testing → Automation

#### Manual Test Strategy → Strategy-to-Automation

**Trigger:** Manual test strategy (decision rubric, charters, regression checklist) is complete.

```text
manual-test-strategy ──► strategy-to-automation
```

| Button | Agent | Purpose |
|---|---|---|
| Convert to Automation | `strategy-to-automation` | Map manual test paths to smoke tests, regression tiers, or agent specs |

#### Exploratory Charter → Strategy-to-Automation

**Trigger:** Exploratory testing sessions are complete and findings documented.

```text
exploratory-charter ──► strategy-to-automation
```

| Button | Agent | Purpose |
|---|---|---|
| Generate Automation Candidates | `strategy-to-automation` | Convert charter findings into filed automation candidate issues |

### Inventory → Modernization

#### App Inventory → Legacy Modernization

**Trigger:** Application inventory, dependency map, and migration complexity scoring are complete.

```text
app-inventory ──► legacy-modernization
```

| Button | Agent | Purpose |
|---|---|---|
| Start Migration | `legacy-modernization` | Apply the strangler fig pattern to high-complexity migration targets |

### Retrospective → Next Sprint

#### Retro Facilitator → Sprint Planner

**Trigger:** Sprint retrospective summary, action items, and improvement issues are logged.

```text
retro-facilitator ──► sprint-planner
```

| Button | Agent | Purpose |
|---|---|---|
| Plan Next Sprint | `sprint-planner` | Turn retrospective action items into sprint issues and a dependency map |

## Full Workflow Diagram

The complete guided workflow for a feature delivery cycle:

```text
product-manager
    └──► sprint-planner
              ├──► backend-dev ◄── api-designer
              └──► frontend-dev

solution-architect
    ├──► backend-dev
    └──► frontend-dev

code-review
    └──► security-analyst

manual-test-strategy
    └──► strategy-to-automation

exploratory-charter
    └──► strategy-to-automation

app-inventory
    └──► legacy-modernization

retro-facilitator
    └──► sprint-planner
```

## Adding Handoffs to an Agent

To add handoffs to an existing agent, insert a `handoffs` block in the YAML
frontmatter, after all other fields and before the closing `---`:

```yaml
---
name: my-agent
description: "Agent description."
model: claude-sonnet-4.6
tools: [read_file, write_file]
handoffs:
  - label: Next Step
    agent: next-agent
    prompt: Continue from the output above. <specific instructions for the next agent>
    send: false
---
```

### Prompt Writing Guidelines

- **Be specific.** Reference the output produced by the current agent (e.g., "the OpenAPI spec designed above", "the wave dependency map above").
- **Set scope.** Tell the next agent what to focus on. If handing off a subset of findings, name the subset.
- **Stay concise.** The prompt pre-fills the chat. Users can expand it; aim for 1–3 sentences.
- **Use `send: false`** for all BaseCoat handoffs so users can review before sending.

## References

- [VS Code Custom Agents — Handoffs](https://code.visualstudio.com/docs/copilot/customization/custom-agents)
- `docs/agents/MULTI_AGENT_WORKFLOWS.md` — parallel branch strategies and conflict avoidance
- `docs/agents/MULTI_AGENT_WORKFLOWS.md#canonical-sub-agent-harness-contract` — canonical sub-agent harness contract
- `docs/guides/token-optimization.md` — handoff template for context compression between agents
- `instructions/agents.instructions.md` — agent authoring standards including handoff conventions
