# Base Coat — Project Goals

## Mission

Base Coat exists to make GitHub Copilot useful at enterprise scale by providing a
curated, governed, and composable library of AI customization assets that teams
adopt across repositories through a single sync command.

## Primary Goals

### 1. Full SDLC Agent Coverage

Provide specialized AI basecoat-10-core-agents for every phase of the software basecoat-10-core-development lifecycle —
not just code generation. Base Coat covers architecture, coding, testing, security,
DevOps, basecoat-10-core-process management, and meta-tooling (agent design, prompt engineering, basecoat-10-core-mcp).

**Current state:** 50 basecoat-10-core-agents across 6 disciplines (v2.1.0):

| Discipline | basecoat-10-core-agents | Examples |
|---|---|---|
| 🔨 basecoat-10-core-development | 4 | backend-dev, frontend-dev, middleware-dev, basecoat-80-data-data-tier |
| 🏗️ basecoat-10-core-architecture | 5 | solution-architect, api-designer, ux-designer, app-inventory, basecoat-10-core-legacy-modernization |
| 🔍 basecoat-90-quality-quality | 10 | code-review, security-analyst, guardrail, performance-analyst, basecoat-10-core-chaos-engineer |
| 🚀 DevOps | 4 | devops-engineer, agentops, release-manager, basecoat-60-workflow-self-healing-ci |
| 📋 basecoat-10-core-process | 6 | sprint-planner, product-manager, issue-triage, retro-facilitator, basecoat-10-core-sprint-retrospective |
| 🧰 Meta | 6+ | agent-designer, prompt-engineer, mcp-developer, tech-writer, basecoat-10-core-memory-curator |

### 2. One Entry Point, Zero Memorization

The `/basecoat` router skill provides a single entry point that routes to any of
the 50 agents. Users say `/basecoat basecoat-10-core-backend build a REST API` and the router resolves
the right agent, attaches paired skills, and ensures ambient instructions are active.

**Design philosophy:** Users should never need to memorize agent names. Discovery mode
(`/basecoat`) shows a categorized catalog; delegation mode (`/basecoat [discipline] [prompt]`)
routes directly.

### 3. Composable Four-Primitive Architecture

Base Coat separates concerns into four primitives that compose cleanly:

- **Agents** define *who* does the work and *how* (workflow, persona, model)
- **Skills** provide *what knowledge* they use (templates, checklists, decision trees)
- **Instructions** enforce *what rules* everyone follows (ambient, cross-cutting)
- **Prompts** provide *how work gets invoked quickly* (structured entry points)

This separation means a new basecoat-50-security-security policy updates one instruction file and every
agent inherits it — not 49 agent files edited individually.

### 4. Enterprise basecoat-20-lang-governance by Default

Base Coat is infrastructure for governed AI assistance:

- **Ambient instructions** enforce security, naming, quality, and basecoat-10-core-process standards
  in every Copilot conversation automatically
- **basecoat-30-ai-guardrail agents** validate outputs before delivery
- **Secret scanning hooks** block credentials in commits
- **CI validation** ensures all assets have valid frontmatter, structure, and catalog entries
- **Version-pinned distribution** prevents drift across consuming repositories

### 5. Opinionated but Extensible Framework

Ship battle-tested defaults that work out of the box, but allow every asset to be
customized. Teams adopt Base Coat as a baseline, then layer their own domain-specific
agents, skills, and instructions on top.

**Distribution methods:** Git submodule, sync scripts (PowerShell + Bash), release
artifact downloads, and template-based bootstrapping — all with SHA256 verification.

### 6. Agentic Workflow Enablement

Beyond individual agents, Base Coat supports multi-agent orchestration:

- **Parallel dispatch** patterns for fleet-mode sprints
- **Merge coordination** to prevent conflicts when multiple basecoat-10-core-agents work simultaneously
- **Structured handoff protocols** between basecoat-10-core-agents
- **Sprint planning** that decomposes goals into agent-assignable issues with wave dependencies
- **Retrospective** tooling that measures agent effectiveness

### 7. Cost-Aware Model Routing

Every agent carries a `model` field in YAML frontmatter for direct VS Code integration
plus a `## Model` section with rationale and minimum viable model. Token economics
instructions guide budget-aware model selection so organizations can optimize cost
without sacrificing quality.

**Model distribution (v2.1.0):** claude-sonnet-4.6 (28), gpt-5.3-codex (16),
claude-haiku-4.5 (3), claude-sonnet-4-5 (2), claude-sonnet-4 (1).

### 8. Adoption Measurement and Feedback Loops

Base Coat includes tooling to measure its own impact:

- **Adoption scanner** detects which repos have synced assets and tracks version drift
- **Metrics collector** correlates Base Coat coverage with PR velocity, CI success, and issue resolution
- **Dashboard** visualizes adoption trends and degradation alerts
- **Copilot usage analytics** track per-session cost and model distribution

## Non-Goals

| What Base Coat is NOT | Why |
|---|---|
| A hosted service or SaaS product | It is infrastructure — files in your repo |
| A single-domain tool | It covers the full SDLC, not just one discipline |
| A replacement for human judgment | basecoat-10-core-agents stop and ask when scope is ambiguous |
| A code generation library | It governs *how* AI generates code, not *what* code |
| A runtime dependency | Consuming repos work fine if Base Coat is removed |

## Success Criteria

1. **New repos start governed** — bootstrap from a pinned release in under a minute
2. **Standards are ambient** — instructions load automatically, no opt-in needed
3. **Updates are safe** — version-pinned distribution with validation gates
4. **basecoat-10-core-agents are discoverable** — one router, categorized catalog, keyword search
5. **Impact is measurable** — adoption metrics, cost tracking, feedback loops
6. **The framework practices what it preaches** — Base Coat is maintained using its own basecoat-10-core-agents
