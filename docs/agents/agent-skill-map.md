# Base Coat Agent & Skill Index

Complete reference guide for all 56 GitHub Copilot agents and 45 customization skills in the Base Coat framework.

## Quick Navigation

- [Agents by Discipline](#agents-by-discipline) — Browse by role/function
- [Skills by Domain](#skills-by-domain) — Browse by technology area
- [Agent-Skill Mappings](#agent-skill-mappings) — Find compatible skills for each agent
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

## Contributing

To update this index:
1. Edit this file with new agents/skills
2. Ensure Agent Skills spec compliance
3. Update `metadata` in agent/skill frontmatter
4. Run `pwsh scripts/validate-basecoat.ps1` to verify

See [CONTRIBUTING.md](https://github.com/IBuySpy-Shared/basecoat/blob/main/CONTRIBUTING.md) for detailed guidelines.

---

**Last Updated:** 2026-05-02  
**Spec Version:** Agent Skills v1.0  
**Maintainer:** Base Coat Team
