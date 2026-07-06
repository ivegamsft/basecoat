# Base Coat Agent & Skill Index

Complete reference guide for all GitHub Copilot agents and customization skills in the Base Coat framework.

## Quick Navigation

- [Agents by Discipline](#agents-by-discipline) — Browse by role/function
- [Skills by Domain](#skills-by-domain) — Browse by technology area
- [Agent-Skill Mappings](#agent-skill-mappings) — Find compatible skills for each agent
- [AIDL Portfolio Routing](#aidl-portfolio-routing) — Disambiguation and precedence rules
- [Alias Policy](#alias-policy) — Naming conventions and migration guidance
- [New to Base Coat?](#getting-started) — Start here

---

## Agents by Discipline

### Development (15 agents)

| Agent | Domain | Purpose |
|-------|--------|---------|
| agent-designer | AI/ML | Design multi-agent systems and orchestration patterns |
| backend-dev | Infrastructure | Backend development, APIs, databases |
| frontend-dev | Development | Frontend development, UI/UX patterns |
| full-stack-dev | Development | Full-stack application development |
| api-designer | Development | REST/GraphQL API design and specification |
| containerization-planner | Infrastructure | Container strategy and Docker/Kubernetes |
| dependency-lifecycle | Development | Dependency management and version upgrades |
| code-review | Quality | Code review and quality assessment |

### Architecture (12 agents)

| Agent | Domain | Purpose |
|-------|--------|---------|
| architecture-decision | Architecture | ADR creation and architectural patterns |
| ha-architect | Infrastructure | High-availability and resilience architecture |
| migration-architect | Architecture | Application migration strategy |
| azure-landing-zone | Cloud | Azure landing zone design |
| containerization-planner | Infrastructure | Container orchestration architecture |
| service-bus-architect | Cloud | Azure Service Bus topology design |

### DevOps & Infrastructure (14 agents)

| Agent | Domain | Purpose |
|-------|--------|---------|
| devops-engineer | DevOps | CI/CD, infrastructure, deployment automation |
| security-operations | Security | SOC operations, threat detection, incident response |
| penetration-test | Security | Penetration testing and security validation |
| production-readiness | Operations | Production readiness reviews, runbooks |
| ha-architect | Infrastructure | High-availability architectures |
| infrastructure-auditor | Security | Infrastructure compliance and security audit |

### Quality & Testing (8 agents)

| Agent | Domain | Purpose |
|-------|--------|---------|
| code-review | Quality | Code quality and peer review patterns |
| contract-testing | Quality | Consumer-driven contract testing |
| chaos-engineer | Quality | Chaos engineering and resilience testing |
| exploratory-charter | Quality | Test planning and exploratory testing |

### Data & AI (6 agents)

| Agent | Domain | Purpose |
|-------|--------|---------|
| dataops | Data | Data pipeline operations and management |
| data-tier | Data | Data architecture and design |
| agentops | AI/ML | Agent operations and monitoring |

### Process & Meta (5 agents)

| Agent | Domain | Purpose |
|-------|--------|---------|
| guardrail | Meta | Policy enforcement and guardrails |
| config-auditor | Meta | Configuration audit and compliance |
| app-inventory | Meta | Application portfolio and inventory |
| feedback-loop | Process | User feedback and insights collection |

---

## Skills by Domain

### Security (8 skills)

| Skill | Focus | Primary Use Case |
|-------|-------|-----------------|
| security-operations | Threat detection | SOC workflows, detection patterns, incident response |
| penetration-testing | Vulnerability assessment | OWASP testing, finding templates, remediation |
| api-security | API protection | JWT auth, RBAC, rate limiting, input validation |
| supply-chain-security | Software supply chain | SLSA, SBOM, Sigstore, provenance tracking |
| ha-resilience | System resilience | Multi-region HA, circuit breakers, error budgets |
| production-readiness | Production operations | PRR gates, incident runbooks, DRP scripts |
| contract-testing | E2E validation | Consumer-driven contracts, mutation testing |

### Infrastructure & Cloud (12 skills)

| Skill | Focus | Primary Use Case |
|-------|-------|-----------------|
| azure-container-apps | Serverless containers | ACA deployment, Dapr integration, scaling |
| service-bus-migration | Message migration | MSMQ→Azure Service Bus with hybrid bridge |
| environment-bootstrap | Infrastructure automation | Terraform, Bicep, Azure automation, Fabric SP setup |
| identity-migration | Identity management | ASP.NET Core Identity, Entra ID integration |
| ha-resilience | Resilience patterns | Multi-region, fault tolerance, chaos testing |

### Data & Observability (8 skills)

| Skill | Focus | Primary Use Case |
|-------|-------|-----------------|
| otel-instrumentation | Distributed tracing | OpenTelemetry setup, metrics, trace sampling |
| domain-driven-design | Architecture patterns | DDD, CQRS, event sourcing, aggregates |
| data-science | ML workflows | Notebooks, feature engineering, model training |

### Development & Tools (10 skills)

| Skill | Focus | Primary Use Case |
|-------|-------|-----------------|
| electron-apps | Desktop applications | Secure IPC, CSP, state management, packaging |
| fabric-notebooks | Analytics notebooks | Medallion architecture, builtin modules, CI/CD |
| basecoat | Framework routing | Agent discovery, delegation patterns |

### Quality & Testing (4 skills)

| Skill | Focus | Primary Use Case |
|-------|-------|-----------------|
| contract-testing | Test orchestration | Pact, Selenium E2E, mutation testing |
| production-readiness | Operations checklist | PRR template, incident runbook patterns |
| penetration-testing | Security testing | API security, OAuth testing, GraphQL testing |

---

## Agent-Skill Mappings

### Security Operations Agent

**Compatible Skills:**

- security-operations (primary)
- penetration-testing
- api-security
- contract-testing

### Backend-Dev Agent

**Compatible Skills:**

- api-security
- identity-migration
- contract-testing
- domain-driven-design
- otel-instrumentation

### DevOps-Engineer Agent

**Compatible Skills:**

- environment-bootstrap
- azure-container-apps
- ha-resilience
- supply-chain-security
- production-readiness
- otel-instrumentation

### Data-Tier Agent

**Compatible Skills:**

- domain-driven-design
- data-science
- otel-instrumentation

### HA-Architect Agent

**Compatible Skills:**

- ha-resilience (primary)
- domain-driven-design
- otel-instrumentation
- production-readiness

### Containerization-Planner Agent

**Compatible Skills:**

- azure-container-apps
- environment-bootstrap
- ha-resilience
- otel-instrumentation

---

## Getting Started

### For New Users

1. **Find an Agent** — Browse [Agents by Discipline](#agents-by-discipline) to find an agent for your role
2. **Explore Compatible Skills** — Check [Agent-Skill Mappings](#agent-skill-mappings) for complementary skills
3. **Read Skill Documentation** — Each skill in `skills/*/SKILL.md` contains detailed patterns and examples
4. **Use Agent Commands** — Access agents through GitHub Copilot (VS Code, Cursor, Windsurf, Claude Code)

### For Developers Extending Base Coat

**Adding a New Skill:**

1. Create `skills/{skill-name}/SKILL.md` with Agent Skills spec frontmatter
2. Include `name`, `title`, `description`, `compatibility`, `metadata`, `allowed-tools`
3. Add domain classification in `metadata.domain`
4. Update this index with new skill entry

**Adding a New Agent:**

1. Create `agents/{agent-name}.agent.md`
2. Include Agent Skills spec frontmatter
3. Define agent workflows and capabilities
4. Update this index with new agent entry

**Linking Agents to Skills:**

Use the `compatibility` field in skill frontmatter:

```yaml
compatibility: ["agent:backend-dev", "agent:data-tier"]
```

---

## Integration Paths

### VS Code Copilot

- Agents: Use `/` to access agents (e.g., `/backend-dev`)
- Skills: Auto-discovered from `.agents/skills/` per Agent Skills specification

### Cursor / Windsurf

- Access via `.agents/skills/` directory for skill discovery
- Full spec compliance enabled via `sync.ps1` / `sync.sh`

### Claude Code

- Agents: Native support via Agent Skills spec
- Skills: Discovered from `.agents/skills/` structure

---

## Statistics

- **Total Agents:** 56
- **Total Skills:** 45
- **Total Disciplines:** 6 (Development, Architecture, DevOps, Quality, Data/AI, Process/Meta)
- **Total Domains:** 8+ (security, infrastructure, identity, data, observability, quality, development, framework)

---

## AIDL Portfolio Routing

This section defines canonical routing precedence for agents in the AIDL portfolio that
share overlapping domains. Use it to resolve ambiguity when multiple agents could handle
a task.

### Routing Precedence Table

| Task | Primary Owner | Secondary | Tie-Break Rule |
|------|---------------|-----------|----------------|
| Create a new agent spec or skill scaffold | `agent-designer` | `new-customization` | Prefer `agent-designer` when routing rationale or task-shaping is required; use `new-customization` for simple asset scaffolding. |
| Validate a guidance file before commit | `guidance-reviewer` | — | Sole owner of content quality validation (lint, frontmatter schema, BaseCoat conventions). |
| Find missing instruction coverage in a repo | `instruction-auditor` | — | Sole owner of repo-level coverage gap analysis. Does not write files. |
| Audit an existing agent or skill spec quality | `agent-designer` (audit mode) | `agentops-audit` skill | Use `agent-designer` in `audit` mode; it delegates scoring to `agentops-audit` skill. |
| Write or revise governance contract docs | `governance-author` | `governance` skill | `governance-author` agent produces drafts; `governance` skill provides reference patterns. |
| Audit governance compliance of existing docs | `governance-auditor` | `governance` skill | `governance-auditor` agent reviews existing contracts; `governance` skill provides the rubric. |
| Define or audit project vocabulary/taxonomy | `lexicon` skill (direct) | `agent-designer` (for agent naming) | Use `lexicon` for project-wide term governance; use `agent-designer` only when naming affects routing. |

### disambiguation: guidance-reviewer vs instruction-auditor

These two agents are frequently confused. Key distinctions:

| Dimension | `guidance-reviewer` | `instruction-auditor` |
|-----------|---------------------|-----------------------|
| Scope | Single file content validation | Whole-repo coverage scan |
| Trigger | "Review this draft agent/skill/instruction" | "What instruction coverage am I missing?" |
| Output | Pass/fail verdict with line-level findings | Coverage table + sync commands |
| Writes files? | No | No |
| Category | quality | meta |
| Primary skill | `agent-design`, `agentops-audit` | `agent-design` |

### disambiguation: agent-designer vs new-customization

| Dimension | `agent-designer` | `new-customization` |
|-----------|-----------------|---------------------|
| Scope | Agent/skill authoring with routing rationale | Any customization asset (instruction, skill, agent, prompt) |
| Trigger | Spec creation, auditing, routing class recommendation | Simple scaffolding, choosing the right primitive |
| Output | Spec + routing profile + audit scorecard | Asset file + frontmatter |
| Model | gpt-5.3-codex (pinned for spec quality) | Default routing |

---

## Alias Policy

### Naming Convention

BaseCoat assets follow two file patterns. AIDL portfolio agents use a prefixed scheme;
general agents and all skills use bare names:

| Asset type | File pattern | `name` field | Example |
|------------|-------------|--------------|---------|
| AIDL agent (prefixed) | `agents/basecoat-NN-<category>-<name>.agent.md` | short name only (no prefix) | `name: agent-designer` |
| General agent (bare) | `agents/<name>.agent.md` | matches base filename | `name: backend-dev` |
| Skill | `skills/<name>/SKILL.md` | matches directory name | `name: agent-design` |
| Instruction | `instructions/<name>.instructions.md` | not required | — |

### Name Field Matching Rule

The `name` field in agent frontmatter must match the **short-name suffix** of the filename,
not the full prefixed filename. The prefix (`basecoat-NN-<category>-`) is used for filesystem
ordering and categorization only.

Example: `agents/basecoat-10-core-agent-designer.agent.md` → `name: agent-designer`

### Maturity Values

Valid values for `metadata.maturity` are:

| Value | Meaning |
|-------|---------|
| `alpha` | Early development, accepted for existing assets; prefer `experimental` for new work |
| `experimental` | Active development, breaking changes expected |
| `beta` | Stabilizing, minor breaking changes possible |
| `production` | Stable, semver-governed changes |

### Compatibility Aliases

The following compatibility alias formats are accepted:

| Format | Meaning | Example |
|--------|---------|---------|
| `GHCP` | GitHub Copilot (any surface) | `compatibility: [GHCP]` |
| `agent:<name>` | Consumed by a specific agent | `compatibility: [agent:agent-designer]` |
| `skill:<name>` | Depends on a specific skill | `compatibility: [skill:agent-design]` |

Platform-only compatibility (`GHCP` alone) is acceptable for skills with broad applicability.
Skills used by specific agents should add `agent:<name>` entries so the compatibility
graph is traversable.

### Migration Plan

Assets identified with frontmatter hygiene issues in this sprint:

| Asset | Issue | Status |
|-------|-------|--------|
| `basecoat-90-quality-guidance-reviewer.agent.md` | `maturity: alpha` → `experimental`; added `model_policy`; empty `compatibility` | Fixed in #1745 |
| `basecoat-50-security-instruction-auditor.agent.md` | `maturity: alpha` → `experimental`; `model:` contradiction; `category: security` → `meta`; emojis in body | Fixed in #1745 |
| `basecoat-10-core-agent-designer.agent.md` | Added `pinned_model` + `pin_reason` + `model_policy` (legacy `model:` retained for script compatibility) | Fixed in #1745 |
| `skills/agent-design/SKILL.md` | Missing `visibility`, `metadata`, agent `compatibility` | Fixed in #1745 |
| `skills/basecoat/SKILL.md` | Missing `visibility`, `metadata`; emojis in body | Fixed in #1745 |
| `skills/lexicon/SKILL.md` | Missing `visibility`, `metadata` | Fixed in #1745 |
| `guidance-reviewer.agent.eval.yaml` | Duplicate unprefixed eval file | Deleted in #1745 |
| `instruction-auditor.agent.eval.yaml` | Duplicate unprefixed eval file | Deleted in #1745 |
| `agent-designer.agent.eval.yaml` | Duplicate unprefixed eval file | Deleted in #1745 |

---

## Contributing

To update this index:

1. Edit this file with new agents/skills
2. Ensure Agent Skills spec compliance
3. Update `metadata` in agent/skill frontmatter
4. Run `pwsh scripts/validate-basecoat.ps1` to verify
5. Update the [AIDL Portfolio Routing](#aidl-portfolio-routing) section when adding agents that overlap with existing AIDL portfolio agents

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for detailed guidelines.

---

**Last Updated:** 2026-06-24
**Spec Version:** Agent Skills v1.0
**Maintainer:** Base Coat Team
