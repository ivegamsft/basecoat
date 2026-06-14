# Create a Custom Agent for Your Scenario

This guide helps repository consumers design an agent for their specific app,
workflow, and use case without copying BaseCoat internals blindly.

## 1. Start with the right primitive

Before creating an agent, confirm you need one:

| Need | Use |
|---|---|
| Reusable recipe or checklist | Skill |
| Cross-cutting coding rules | Instruction |
| Multi-step orchestration, role behavior, handoffs | Agent |

If your use case is mostly a checklist, start with a skill and add an agent
only when role-driven orchestration is needed.

## 2. Define your scenario contract

Write this down first. It becomes your frontmatter and workflow.

| Field | Example |
|---|---|
| User outcome | "Ship a safe canary release for payments API" |
| Inputs | service name, env, release window, rollback target |
| Boundaries | no prod writes without approval; no secret access |
| Tools needed | `bash`, `git`, `terraform` |
| Skills needed | `devops`, `security` |
| Output | release plan, risk list, rollback steps, issue links |

## 3. Scaffold from existing templates

Use the agent-design assets instead of writing from scratch:

- `skills/agent-design/agent-template.md`
- `agents/basecoat-10-core-agent-designer.agent.md`

Also reuse the closest existing agent and narrow scope from there.

## 4. Author frontmatter with least privilege

Start from this baseline and adjust:

```yaml
---
name: my-scenario-agent
description: "One-line purpose with clear USE FOR and DO NOT USE FOR triggers."
type: task
compatibility: ["VS Code", "Cursor", "Windsurf", "Claude Code"]
metadata:
  category: "Workflow"
  tags: ["release", "risk", "automation"]
  maturity: "beta"
  audience: ["engineers"]
  model_tier: "balanced"
  task_phase: "test"
  interaction_type: "autonomous"
allowed-tools: ["bash", "git"]
visibility: basic
model: gpt-5.3-codex
allowed_skills: []
color: gray
handoffs: []
trigger: Use for detailed trigger conditions in Use For section below.
---
```

Guidance:

- Include only tools and skills the workflow actually needs.
- Prefer `allowed_skills: []` unless skill invocation is required.
- Keep description trigger phrases explicit and testable.

## 5. Write workflow sections that map to real execution

At minimum include:

- `## Inputs`
- `## Workflow`
- `## Output Format`
- `## Model` with `Recommended`, `Rationale`, and `Minimum`

Each workflow step should produce an observable output (file, report, issue, or
decision), not just general advice.

## 6. Add evaluation coverage

For every agent, add its eval companion file:

- `agents/<agent-name>.agent.eval.yaml`

`tests/run-tests.ps1` enforces eval file coverage for agents and skills.

## 7. Validate locally before PR

```powershell
pwsh scripts/validate-basecoat.ps1
pwsh tests/run-tests.ps1
```

## 8. Example prompt for consumers

Use this with `@agent-designer` to generate a first draft:

```text
Create a new agent for <your scenario>.
Use case: <your app and workflow>.
Inputs: <list>.
Must do: <required behavior>.
Must not do: <constraints>.
Tools allowed: <list>.
Skills allowed: <list or none>.
Output format: <expected deliverable>.
```

## 9. Anti-patterns to avoid

- Creating an agent when a skill is enough.
- Broad tool lists ("just in case").
- Vague triggers ("help with development").
- Missing eval file.
- Missing constraints for high-risk actions.

## 10. Domain starter blueprints (chaos, performance, security)

Consumers can clone these known BaseCoat patterns and adapt to their app.

| Scenario | Start from agent | Optional paired skill |
|---|---|---|
| Chaos / resilience | `agents/basecoat-10-core-chaos-engineer.agent.md` | `skills/ha-resilience/SKILL.md` |
| Performance | `agents/basecoat-10-core-performance-analyst.agent.md` | `skills/performance-profiling/SKILL.md` |
| Security audit | `agents/basecoat-50-security-security-analyst.agent.md` | `skills/security/SKILL.md` |

Additional blueprints:

| Scenario | Start from agent | Optional paired skill |
|---|---|---|
| API design | `agents/basecoat-10-core-api-designer.agent.md` | `skills/api-design/SKILL.md` |
| Backend implementation | `agents/basecoat-10-core-backend-dev.agent.md` | `skills/backend-dev/SKILL.md` |
| Frontend implementation | `agents/basecoat-10-core-frontend-dev.agent.md` | `skills/frontend-dev/SKILL.md` |
| DevOps delivery | `agents/basecoat-10-core-devops-engineer.agent.md` | `skills/devops/SKILL.md` |
| SRE operations | `agents/basecoat-10-core-sre-engineer.agent.md` | `skills/observability/SKILL.md` |
| Data tier and schema | `agents/basecoat-80-data-data-tier.agent.md` | `skills/data-tier/SKILL.md` |
| Identity and access | `agents/basecoat-10-core-identity-architect.agent.md` | `skills/azure-identity/SKILL.md` |
| Release orchestration | `agents/basecoat-60-workflow-release-manager.agent.md` | `skills/release-notes/SKILL.md` |
| Incident response | `agents/basecoat-60-workflow-incident-responder.agent.md` | `skills/security-operations/SKILL.md` |
| Manual test strategy | `agents/basecoat-90-quality-manual-test-strategy.agent.md` | `skills/manual-test-strategy/SKILL.md` |
| Contract testing | `agents/basecoat-10-core-contract-testing.agent.md` | `skills/contract-testing/SKILL.md` |
| GitHub security posture | `agents/basecoat-50-security-github-security-posture.agent.md` | `skills/github-security-posture/SKILL.md` |

Use this adaptation pattern:

1. Copy the closest agent to a new name in your consumer repo.
2. Rewrite `description` trigger phrases for your domain and app.
3. Reduce `allowed-tools` and `allowed_skills` to least privilege.
4. Replace workflow steps with your environment-specific controls.
5. Add eval file and run validation before PR.

Starter prompt for `@agent-designer`:

```text
Create a custom <chaos|performance|security> agent for our app.
Base it on <source agent path>.
Our scenario: <business workflow and app context>.
Required inputs: <list>.
Constraints: <what it must never do>.
Allowed tools: <list>.
Allowed skills: <list or none>.
Expected output: <report/plan/checklist format>.
```

## Related references

- `docs/agents/agents.md`
- `docs/agents/agent-runtime-enforcement.md`
- `docs/guides/agent-examples.md`
- `docs/guides/contributing.md`
