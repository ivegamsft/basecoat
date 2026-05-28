---
name: agentops-audit
description: "Audits agent definitions, routing configurations, and tool bindings. USE FOR: reviewing agent definitions for correctness, assessing tool routing logic, validating tool bindings, evaluating prompt quality, analyzing agent behavior consistency. DO NOT USE FOR: writing agents from scratch, designing agent architectures, implementing tools, general code review."
compatibility:
  editors:
    - vscode
    - cursor
  platforms:
    - github
metadata:
  category: "AI & Agents"
  tags: ["agents", "audit", "routing", "tools", "ai-ops"]
  maturity: "beta"
  audience: ["ai-engineers", "agent-developers", "platform-teams"]
allowed-tools: ["bash", "git", "grep", "find", "powershell"]
---

# Agent Operations Audit Skill

Comprehensive auditing of agent definitions, tool routing configurations, prompt quality, and agent behavior consistency.

## USE FOR

- Reviewing agent definition files for correctness and completeness
- Assessing tool routing logic and fallback strategies
- Validating tool bindings and parameter mapping
- Evaluating prompt quality, clarity, and instruction effectiveness
- Analyzing agent behavior consistency and expected outcomes
- Identifying missing tool bindings or incorrect routing
- Reviewing agent error handling and edge cases
- Assessing agent scope and tool permission boundaries
- Evaluating multi-agent coordination and handoff logic
- Creating structured audit findings with recommendations

## DO NOT USE FOR

- Writing agents from scratch (use agent development skills)
- Designing agent architectures
- Implementing tools (use tool development skills)
- General code review (use `code-review` skill)
- Backend development unrelated to agents

## Audit Checklist

- **Agent Definition**: Completeness, naming, documentation
- **Routing Logic**: Tool selection criteria, fallback handling, edge cases
- **Tool Bindings**: Correct mapping, parameter passing, error scenarios
- **Prompts**: Clarity, instructions, examples, consistency
- **Behavior**: Expected outcomes, edge cases, failure modes
- **Scope**: Tool permissions, boundary definitions, constraints
- **Error Handling**: Invalid inputs, tool failures, graceful degradation
- **Performance**: Response time, resource usage, efficiency
- **Documentation**: Agent purpose, tool descriptions, examples
- **Testing**: Routing scenarios, integration tests, edge cases

## Related Skills

- `agent-design` — Agent design and architecture
- `backend-audit` — Backend code quality assessment
- `api-audit` — API contract and tool interface audit
