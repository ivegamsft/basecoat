# Copilot Extension for BaseCoat — PRD & Architecture

## PRD: BaseCoat Manager Extension

### Problem Statement

BaseCoat has grown to 98 agents, 80 skills, 79 instructions, and 5 prompts.
Contributors struggle to:

1. **Discover** what already exists before creating duplicates
2. **Author** new assets with correct frontmatter, eval companions, and naming conventions
3. **Validate** changes without memorizing which scripts to run
4. **Govern** quality — vocabulary compliance, coverage gaps, stale assets
5. **Monitor** adoption — metrics, alerts, trend regressions

Today these tasks require CLI access, repo familiarity, and reading scattered docs.
A Copilot Extension surfaces all of this conversationally in any GitHub-integrated surface.

### Target Users

| Persona | Need |
|---------|------|
| **New contributor** | Discover existing assets, scaffold correctly on first try |
| **Experienced author** | Run validation, check coverage, get audit feedback |
| **Platform lead** | Monitor adoption metrics, spot regressions, enforce governance |
| **Reviewer** | Assess PR quality against BaseCoat conventions |

### Functional Requirements

#### P0 — Must Have

| ID | Capability | Description |
|----|-----------|-------------|
| F1 | Asset discovery | Search agents/skills/instructions/prompts by keyword, type, or tag |
| F2 | Asset details | Retrieve full content, frontmatter, and eval status for any asset |
| F3 | Validation | Run `validate-basecoat.ps1` and `run-tests.ps1` and return results |
| F4 | Metrics snapshot | Expose `get-latest-metrics`, `get-history`, `get-alerts` (existing MCP tools) |
| F5 | Scaffolding | Generate new agent/skill/instruction/prompt with correct structure |

#### P1 — Should Have

| ID | Capability | Description |
|----|-----------|-------------|
| F6 | Governance audit | Run vocabulary/syntax audits, report violations |
| F7 | Dependency graph | Show which agents reference which skills |
| F8 | Coverage report | Identify assets missing evals, instructions with no applyTo match |
| F9 | PR review assist | Check a PR diff against BaseCoat conventions |

#### P2 — Nice to Have

| ID | Capability | Description |
|----|-----------|-------------|
| F10 | Auto-fix suggestions | Propose frontmatter fixes, missing blank lines, etc. |
| F11 | Onboarding flow | Guided walkthrough for first-time contributors |
| F12 | Changelog generation | Summarize recent asset changes for release notes |

### Non-Functional Requirements

- **Latency**: Tool responses < 5s for read operations, < 30s for validation runs
- **Availability**: 99.5% uptime (stateless, scale-to-zero acceptable for cost)
- **Security**: GitHub App auth; only org members can invoke; no secrets in responses
- **Observability**: Structured logging, request tracing, error rate alerting

---

## Architecture Design

### Option A: Copilot SDK Agent

```text
+-----------------------------------------------------+
|  GitHub Copilot Chat (IDE / github.com / CLI)        |
+------------------------+----------------------------+
                         | Copilot Extension Protocol
                         v
+-----------------------------------------------------+
|  BaseCoat Extension Agent (Node.js / @github/copilot-sdk)  |
|                                                     |
|  +-----------+  +-----------+  +-----------+        |
|  | Tool:     |  | Tool:     |  | Tool:     |        |
|  | search    |  | validate  |  | scaffold  |        |
|  +-----------+  +-----------+  +-----------+        |
|  +-----------+  +-----------+  +-----------+        |
|  | Tool:     |  | Tool:     |  | Tool:     |        |
|  | metrics   |  | audit     |  | details   |        |
|  +-----------+  +-----------+  +-----------+        |
+------------------------+----------------------------+
                         |
          +--------------+--------------+
          v              v              v
   +------------+ +------------+ +------------+
   | GitHub API | | BaseCoat   | | Metrics    |
   | (repos,    | | Repo       | | (GH Pages) |
   |  PRs)      | | (clone)    | |            |
   +------------+ +------------+ +------------+
```

### Option B: Expand Existing MCP Server

Extend `mcp/basecoat-metrics/` with all new tools. Continue using it as an MCP
server consumed by VS Code / CLI. No Copilot Extension registration needed.

### Option C: Hybrid — MCP Server + Thin Extension Proxy (Recommended)

Register a Copilot Extension whose agent backend proxies to the existing MCP
server for read operations, adding only the Copilot SDK session management layer.
New write tools (scaffold, validate, create-pr) live in the Extension layer.

---

## Design Debate

### Extension (A) vs. MCP-only (B) vs. Hybrid (C)

| Criterion | A: Full Extension | B: MCP-only | C: Hybrid |
|-----------|------------------|-------------|-----------|
| **Reach** | Any Copilot surface (IDE, web, mobile, CLI) | VS Code + CLI only | Same as A |
| **Auth model** | GitHub App OAuth — org-scoped | Local machine token | GitHub App delegates to MCP |
| **Multi-user** | Yes, stateless per-request | Single-user local | Yes |
| **Existing code reuse** | Must rewrite tools in SDK format | 100% reuse | High reuse |
| **Deployment complexity** | New service + GH App registration | Already deployed | Two services |
| **Latency** | Direct (one hop) | Local (fastest) | Extra hop |

**Recommendation: Option C (Hybrid)**

Rationale:

- The MCP server already has 7 tools (metrics + asset search). Rewriting is waste.
- A thin Extension proxy adds Copilot surface reach without duplicating logic.
- New write-oriented tools (scaffold, validate) live in the Extension layer since
  they need GitHub API access for PR creation.
- If the SDK matures to support MCP backends natively, the proxy collapses to config.

### Repo Clone vs. GitHub API for Asset Access

| Approach | Pros | Cons |
|----------|------|------|
| Shallow clone at startup | Fast local reads, run scripts natively | Stale data, disk, cold start |
| GitHub Contents API | Always fresh, no disk | Rate limits, no script execution |
| Hybrid (API for reads, Actions for scripts) | Best of both | More moving parts |

**Recommendation: GitHub Contents API for reads + dispatch GitHub Actions for validation.**

This keeps the Extension stateless (no clone needed) and leverages existing CI for
heavy validation, returning results via check-run or workflow artifact.

### Scaffolding: Server-side vs. Client-side

- **Server-side**: Extension generates files, creates a PR via GitHub API. User reviews.
- **Client-side**: Extension returns file templates; user applies locally.

**Recommendation: Server-side (PR creation)** for the Extension surface (github.com chat).
For IDE, return workspace edits. Support both via a `mode` parameter on the scaffold tool.

### Counter-argument: Is the Extension Layer Worth It?

The Copilot SDK is pre-1.0 and the Extension ecosystem is still maturing. If the
primary users are developers already in VS Code, the MCP server alone covers 90%
of use cases without the overhead of GitHub App registration, OAuth flows, and a
proxy layer. The Extension adds value mainly for the github.com chat surface and
mobile — worth building only if those surfaces have meaningful adoption in your org.

---

## Security Considerations

- Extension GitHub App needs `contents:read`, `pull_requests:write`, `actions:write`
- No `contents:write` on main — scaffolding always goes through PRs
- Rate-limit tool invocations per user (10 req/min default)
- Sanitize all user inputs before passing to script execution

---

## Proposed Tool Inventory

| Tool | Source | Description |
|------|--------|-------------|
| `search-assets` | MCP (exists) | Keyword search across all asset types |
| `get-asset-details` | MCP (exists) | Full content of any asset file |
| `get-latest-metrics` | MCP (exists) | Current adoption snapshot |
| `get-history` | MCP (exists) | Historical trend data |
| `get-alerts` | MCP (exists) | Active degradation alerts |
| `validate` | Extension (new) | Dispatch validation workflow, return results |
| `scaffold` | Extension (new) | Generate new asset with correct structure |
| `audit-governance` | Extension (new) | Run vocabulary/syntax audit on an asset |
| `check-coverage` | Extension (new) | Report eval/instruction coverage gaps |
| `create-pr` | Extension (new) | Create PR from scaffolded assets |

---

## Observability: What's Working and What's Not

### Telemetry Stack

| Layer | What it tells you | How |
|-------|-------------------|-----|
| **SDK built-in** | Session traces, tool invocations, latency, errors | OpenTelemetry hooks in `@github/copilot-sdk` — export to Azure Monitor / App Insights |
| **GitHub Copilot usage API** | Acceptance rates, active users, seat utilization | `GET /orgs/{org}/copilot/usage` — weekly snapshots |
| **Extension-level logging** | Which tools fired, input/output, error rates | Structured JSON logs in Container Apps → Log Analytics |
| **Intent match failures** | When the Extension is invoked but no tool matches | Log unmatched prompts; review weekly for description gaps |

### Key Metrics to Track

- **Tool invocation rate** — which tools are actually used vs. registered
- **Intent-to-tool match rate** — % of user prompts that correctly route to a tool
- **Error rate per tool** — surface broken tools quickly
- **Latency p50/p95** — especially for validation dispatches
- **Fallback rate** — how often the agent gives a generic response instead of using a tool

### Debugging Misroutes

When intents don't map correctly:
1. Log the raw user prompt + the tool the SDK selected (or "none")
2. Compare against tool descriptions — refine wording
3. Track in a `misroutes.jsonl` file or table for weekly review

---

## Asset Discovery: Exposing Tools, Skills, and Agents

The Extension must make the full BaseCoat inventory queryable:

### Manifest-Driven Discovery

Generate `asset-manifest.json` (already exists at repo root) on every commit via CI.
The Extension reads this manifest at startup — no filesystem scan needed at runtime.

```json
{
  "agents": [{ "name": "api-designer", "description": "...", "path": "agents/api-designer.agent.md" }],
  "skills": [{ "name": "azure-container-apps", "description": "...", "path": "skills/azure-container-apps/SKILL.md" }],
  "instructions": [...],
  "prompts": [...]
}
```

### User-Facing Tools

| Tool | Purpose |
|------|---------|
| `search-assets` | Full-text keyword search across names + descriptions |
| `list-assets` | Filter by type, tag, or visibility |
| `get-asset-details` | Return full markdown content of any asset |
| `get-dependencies` | Which agents reference which skills (graph query) |

---

## Testing Strategy

### Unit Tests (Tool Logic)

- Mock GitHub API responses and MCP server calls
- Assert each tool returns expected schema for given inputs
- Framework: Jest or Vitest (matches existing MCP server setup)

### Integration Tests (SDK Wiring)

- Use SDK session replay: record a conversation, replay tool invocations
- Verify tool registration, parameter validation, error handling
- Run against a local instance of the Extension

### Eval Tests (Intent Matching Quality)

Critical for this project. Test that natural language prompts route to the correct tool:

```yaml
# evals/search-assets.eval.yaml
- prompt: "What agents do we have for API design?"
  expected_tool: search-assets
  expected_params:
    query: "API design"
    type: "agent"

- prompt: "Show me the full content of the architecture skill"
  expected_tool: get-asset-details
  expected_params:
    path: "skills/architecture/SKILL.md"

- prompt: "Run validation on the repo"
  expected_tool: validate
```

### End-to-End Tests

- Spin up Extension locally, send prompts via SDK test client
- Assert full response flow (tool selected → invoked → response rendered)
- Run in CI on every PR to the Extension code

### Regression Testing

- Maintain a golden set of 50+ prompt→tool mappings
- CI fails if any mapping regresses (tool description change broke routing)

---

## Intent Routing Optimization

This is the highest-leverage design area. If descriptions are poor, the Extension
becomes a dumb passthrough that never activates the right tool.

### How Intent Matching Works

1. User prompt enters the Copilot agent runtime
2. The SDK matches the prompt against registered tool **descriptions**
3. Best-matching tool is invoked with extracted parameters
4. If no tool scores above threshold → generic LLM response (bad)

### Optimization Strategies

#### 1. Description Engineering (Most Important)

Write tool descriptions as if they're the **user's voice**, not the developer's:

```typescript
// BAD — developer-centric
"Queries the asset manifest for matching entries"

// GOOD — user-intent-centric
"Search for BaseCoat agents, skills, instructions, or prompts by keyword.
Use when asking 'what do we have for X?' or 'find skills related to Y'."
```

#### 2. Include Trigger Phrases

Add example phrasings directly in the description:

```typescript
description: `Run the BaseCoat validation suite (validate-basecoat.ps1 and run-tests.ps1).
Triggers: "validate the repo", "run tests", "check if my changes pass",
"is the repo healthy?", "lint basecoat"`
```

#### 3. Use Synonyms and Alternate Terms

```typescript
description: `Create a new BaseCoat asset (agent, skill, instruction, or prompt)
with correct frontmatter, directory structure, and eval companion.
Also known as: scaffold, generate, bootstrap, initialize, stub out, add new.`
```

#### 4. Negative Routing (Exclude Mismatches)

```typescript
description: `...
Do NOT use for: modifying existing assets, running audits, or viewing metrics.`
```

#### 5. Parameter Descriptions as Routing Hints

```typescript
parameters: {
  type: {
    description: "Asset type: 'agent', 'skill', 'instruction', or 'prompt'"
  },
  query: {
    description: "Keyword to search for (e.g., 'security', 'API', 'azure', 'testing')"
  }
}
```

#### 6. Skill/Agent Activation Shortcuts

For BaseCoat's own skills/agents that should be directly invocable:

- Register them as **aliases** in the Extension manifest
- Map known skill names to direct invocation (e.g., "use the api-designer agent" → fetch and display that agent's content)
- Maintain a `shortcuts.json` mapping common phrases to tools

#### 7. Continuous Improvement Loop

```
User prompt → Tool selected → User feedback (thumbs up/down)
                                      ↓
                              Log to misroutes table
                                      ↓
                          Weekly review → refine descriptions
```

### Description Template for Every Tool

```typescript
server.tool(
  "tool-name",
  [
    "One-sentence summary of what this does.",
    "Use when: <2-3 example user intents>.",
    "Also known as: <synonyms>.",
    "Do NOT use for: <common mismatches>."
  ].join(" "),
  { /* params */ },
  handler
);
```

---

## Next Steps

1. Register GitHub App for the Extension
2. Scaffold Extension project using `@github/copilot-sdk`
3. Implement thin proxy to existing MCP server for read tools
4. Add new write tools (scaffold, validate-dispatch, create-pr)
5. Write eval suite (50+ prompt→tool golden mappings) before launch
6. Instrument OpenTelemetry for invocation tracking
7. Deploy to Azure Container Apps alongside existing MCP server
8. Run 2-week pilot with 5 contributors, collect misroute data
9. Refine tool descriptions based on pilot telemetry
