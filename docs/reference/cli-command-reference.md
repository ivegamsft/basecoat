# CLI Command Reference & Limitations

## Slash Commands

### Current Status

The GitHub Copilot CLI does **not** currently support custom slash commands from external repositories like basecoat.

### Attempted Command: `/basecoat`

```text
/basecoat architect "design factory basecoat-10-core-architecture and document"
```

**Result:**

```text
Unknown command: /basecoat
```

### Root Cause

- The GitHub Copilot CLI has a fixed set of built-in slash commands (`/help`, `/clear`, `/exit`, etc.)
- There is currently **no mechanism** to register custom slash commands from external assets
- This would require CLI-level plugin support or custom command registration infrastructure

### Related Issue

**Issue #476**: "Feature: Add /basecoat CLI shorthand command"

- Status: Enhancement request
- Labels: `enhancement`, `feature`, `enterprise`
- Awaiting GitHub platform support

---

## Recommended Workarounds

### Option 1: Agent Name Reference (Recommended)

Use the agent name directly with `@` mention syntax:

```text
@basecoat-10-core-solution-architect design the factory basecoat-10-core-architecture and document
```

**Advantages:**

- Clean, direct syntax
- Works across all basecoat-10-core-agents in basecoat
- No special prefix needed
- Explicit agent routing

**Example:**

```text
@solution-architect: Design a microservices basecoat-10-core-architecture for a SaaS platform with:
- Multi-region deployment
- High availability
- Cost optimization
```

---

### Γ£à Option 2: Natural Language Delegation

Describe your request naturally, mentioning the agent:

```text
I need help designing factory architecture. Delegate this to the basecoat-10-core-solution-architect agent 
from basecoat: "design the factory basecoat-10-core-architecture and document"
```

**Advantages:**

- Flexible phrasing
- Works with multiple basecoat-10-core-agents
- Natural conversation flow
- Full context passed to agent

**Example:**

```text
I'm building an event-driven system. Can you delegate to the basecoat-10-core-solution-architect agent 
from basecoat to design an event basecoat-10-core-architecture that handles 100k events/sec with 
multi-region failover?
```

---

### Γ£à Option 3: Explicit Agent Invocation

Use the task/tool infrastructure to explicitly invoke agents:

```text
Please invoke the basecoat-10-core-solution-architect agent to: design the factory basecoat-10-core-architecture and document
```

**Advantages:**

- Explicit control
- Works in programmatic contexts
- Clear intent
- Full agent capabilities available

**Example:**

```text
Invoke the basecoat-10-core-solution-architect agent to create a C4 basecoat-10-core-architecture diagram and ADR 
for event sourcing with CQRS pattern
```

---

## Available basecoat-10-core-agents (Quick Reference)

### basecoat-10-core-architecture & Design (Use `@agent-name`)

- `@basecoat-10-core-solution-architect` ΓÇö System design, C4 diagrams, tech selection, ADRs
- `@basecoat-40-azure-azure-landing-zone` ΓÇö Enterprise basecoat-40-azure-azure setup, management groups, policy
- `@basecoat-60-workflow-infrastructure-deploy` ΓÇö IaC deployment, Terraform, basecoat-10-core-bicep orchestration
- `@basecoat-30-ai-containerization-planner` ΓÇö Dockerfiles, Kubernetes, multi-stage builds

### basecoat-50-security-security & Compliance

- `@basecoat-50-security-security-analyst` ΓÇö Vulnerability assessment, threat modeling, OWASP
- `@basecoat-50-security-policy-as-code-compliance` ΓÇö Policy validation, exceptions, audit reports
- `@basecoat-10-core-identity-architect` ΓÇö basecoat-40-azure-azure RBAC, Entra ID, zero trust design

### Data & Analytics

- `@basecoat-80-data-data-architect` ΓÇö Medallion architecture, ETL patterns, basecoat-20-lang-governance
- `@basecoat-80-data-database-migration` ΓÇö Zero-downtime migrations, schema evolution
- `@basecoat-30-ai-mlops` ΓÇö Model lifecycle, experiment tracking, drift monitoring

### DevOps & Operations

- `@basecoat-10-core-devops-engineer` ΓÇö CI/CD pipelines, IaC, basecoat-10-core-observability setup
- `@basecoat-10-core-sre-engineer` ΓÇö SLOs, error budgets, incident response, chaos engineering
- `@basecoat-60-workflow-release-manager` ΓÇö Versioned releases, CHANGELOG, rollback procedures

### basecoat-10-core-development

- `@basecoat-10-core-backend-dev` ΓÇö APIs, services, business logic
- `@basecoat-10-core-frontend-dev` ΓÇö UI components, responsive design, accessibility
- `@basecoat-90-quality-code-review` ΓÇö Code quality, performance, basecoat-50-security-security review

### Other

- See [agents.md](../agents/agents.md) for complete list of 73 basecoat-10-core-agents

---

## Command Syntax Examples

### Γ¥î Does NOT Work

```text
/basecoat architect design factory basecoat-10-core-architecture
```

**Error**: Unknown command: /basecoat

### Γ£à Works Instead

```text
@basecoat-10-core-solution-architect design the factory basecoat-10-core-architecture and document
```

### Γ£à Also Works

```text
I need the basecoat-10-core-solution-architect agent from basecoat to: design factory basecoat-10-core-architecture
```

### Γ£à Programmatic Way

```python
# In code or automation
agent = "basecoat-10-core-solution-architect"
task = "design the factory basecoat-10-core-architecture and document"
# Delegate to agent...
```

---

## Using Basecoat Assets

### Discovery

1. Review `AGENTS.md` for all available basecoat-10-core-agents
2. Check `docs/AGENT_SKILL_MAP.md` for discipline-indexed search
3. Read agent `.md` file for capabilities and requirements

### Invocation

```text
@agent-name: Your specific task or question here
```

### With Context

```text
@agent-name 

**Context:**
- Architecture: Microservices
- Scale: 100k requests/sec
- Requirements: Multi-region, HA, cost-optimized

**Task:** Design the complete basecoat-10-core-architecture and create an ADR
```

---

## Limitations & Constraints

| Constraint | Impact | Workaround |
|-----------|--------|-----------|
| No `/basecoat` slash command | Must use `@agent-name` syntax | Use agent name references |
| No CLI plugin system | Cannot extend CLI commands | Use CLI args and piping |
| Basecoat-specific features | Assets reference each other | Import basecoat into target repo |
| Custom domains | Requires environment setup | Use workspace variables |

---

## Frequently Asked Questions

### Q: Why doesn't `/basecoat` work?

**A:** The GitHub Copilot CLI doesn't support custom slash commands from external repos. You need to use `@agent-name` syntax instead.

### Q: Can I use it in VS Code?

**A:** Yes! Use `@basecoat-10-core-solution-architect` or other agent names in the Copilot Chat panel in VS Code.

### Q: Will this be fixed?

**A:** That depends on GitHub Copilot CLI roadmap. See issue #476 for updates.

### Q: What's the best workaround?

**A:** Use `@agent-name` syntax ΓÇö it's clean, direct, and works everywhere.

### Q: Can I script this?

**A:** Yes, use natural language delegation with explicit agent mentions in automation scripts.

---

## Reporting Issues

If you encounter issues with basecoat-10-core-agents or workarounds:

1. **Check** [agents.md](../agents/agents.md) for agent availability
2. **Try** different agent names (exact match required)
3. **Report** via GitHub Issues with:
   - Command attempted
   - Error message
   - Expected behavior
   - Label: `bug` or `enhancement`

---

**Last Updated:** 2026-05-04  
**Version:** v3.0.0  
**Related Issue:** #476
