# CLI Command Reference & Limitations

## Slash Commands

### Current Status
The GitHub Copilot CLI does **not** currently support custom slash commands from external repositories like basecoat.

### Attempted Command: `/basecoat`
```
/basecoat architect "design factory architecture and document"
```

**Result:**
```
Unknown command: /basecoat
```

### Root Cause
- The GitHub Copilot CLI has a fixed set of built-in slash commands (`/help`, `/clear`, `/exit`, etc.)
- There is currently **no mechanism** to register custom slash commands from external assets
- This would require CLI-level plugin support or custom command registration infrastructure

### Related Issue
📋 **Issue #476**: "Feature: Add /basecoat CLI shorthand command"
- Status: Enhancement request
- Labels: `enhancement`, `feature`, `enterprise`
- Awaiting GitHub platform support

---

## Recommended Workarounds

### ✅ Option 1: Agent Name Reference (Recommended)
Use the agent name directly with `@` mention syntax:

```
@solution-architect design the factory architecture and document
```

**Advantages:**
- Clean, direct syntax
- Works across all agents in basecoat
- No special prefix needed
- Explicit agent routing

**Example:**
```
@solution-architect: Design a microservices architecture for a SaaS platform with:
- Multi-region deployment
- High availability
- Cost optimization
```

---

### ✅ Option 2: Natural Language Delegation
Describe your request naturally, mentioning the agent:

```
I need help designing factory architecture. Delegate this to the solution-architect agent 
from basecoat: "design the factory architecture and document"
```

**Advantages:**
- Flexible phrasing
- Works with multiple agents
- Natural conversation flow
- Full context passed to agent

**Example:**
```
I'm building an event-driven system. Can you delegate to the solution-architect agent 
from basecoat to design an event architecture that handles 100k events/sec with 
multi-region failover?
```

---

### ✅ Option 3: Explicit Agent Invocation
Use the task/tool infrastructure to explicitly invoke agents:

```
Please invoke the solution-architect agent to: design the factory architecture and document
```

**Advantages:**
- Explicit control
- Works in programmatic contexts
- Clear intent
- Full agent capabilities available

**Example:**
```
Invoke the solution-architect agent to create a C4 architecture diagram and ADR 
for event sourcing with CQRS pattern
```

---

## Available Agents (Quick Reference)

### Architecture & Design (Use `@agent-name`)
- `@solution-architect` — System design, C4 diagrams, tech selection, ADRs
- `@azure-landing-zone` — Enterprise Azure setup, management groups, policy
- `@infrastructure-deploy` — IaC deployment, Terraform, Bicep orchestration
- `@containerization-planner` — Dockerfiles, Kubernetes, multi-stage builds

### Security & Compliance
- `@security-analyst` — Vulnerability assessment, threat modeling, OWASP
- `@policy-as-code-compliance` — Policy validation, exceptions, audit reports
- `@identity-architect` — Azure RBAC, Entra ID, zero trust design

### Data & Analytics
- `@data-architect` — Medallion architecture, ETL patterns, governance
- `@database-migration` — Zero-downtime migrations, schema evolution
- `@mlops` — Model lifecycle, experiment tracking, drift monitoring

### DevOps & Operations
- `@devops-engineer` — CI/CD pipelines, IaC, observability setup
- `@sre-engineer` — SLOs, error budgets, incident response, chaos engineering
- `@release-manager` — Versioned releases, CHANGELOG, rollback procedures

### Development
- `@backend-dev` — APIs, services, business logic
- `@frontend-dev` — UI components, responsive design, accessibility
- `@code-review` — Code quality, performance, security review

### Other
- See [AGENTS.md](../agents/AGENTS.md) for complete list of 73 agents

---

## Command Syntax Examples

### ❌ Does NOT Work
```
/basecoat architect design factory architecture
```
**Error**: Unknown command: /basecoat

### ✅ Works Instead
```
@solution-architect design the factory architecture and document
```

### ✅ Also Works
```
I need the solution-architect agent from basecoat to: design factory architecture
```

### ✅ Programmatic Way
```python
# In code or automation
agent = "solution-architect"
task = "design the factory architecture and document"
# Delegate to agent...
```

---

## Using Basecoat Assets

### Discovery
1. Review `AGENTS.md` for all available agents
2. Check `docs/AGENT_SKILL_MAP.md` for discipline-indexed search
3. Read agent `.md` file for capabilities and requirements

### Invocation
```
@agent-name: Your specific task or question here
```

### With Context
```
@agent-name 

**Context:**
- Architecture: Microservices
- Scale: 100k requests/sec
- Requirements: Multi-region, HA, cost-optimized

**Task:** Design the complete architecture and create an ADR
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
**A:** Yes! Use `@solution-architect` or other agent names in the Copilot Chat panel in VS Code.

### Q: Will this be fixed?
**A:** That depends on GitHub Copilot CLI roadmap. See issue #476 for updates.

### Q: What's the best workaround?
**A:** Use `@agent-name` syntax — it's clean, direct, and works everywhere.

### Q: Can I script this?
**A:** Yes, use natural language delegation with explicit agent mentions in automation scripts.

---

## Reporting Issues

If you encounter issues with agents or workarounds:

1. **Check** [AGENTS.md](../agents/AGENTS.md) for agent availability
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
