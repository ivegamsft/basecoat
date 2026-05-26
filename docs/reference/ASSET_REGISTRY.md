# Base Coat — Asset Catalog

> **⚠️ Staleness notice:** This file is manually maintained and may lag behind the actual
> repository contents. For the authoritative, machine-generated agent list run:
>
> ```bash
> pwsh scripts/update-metadata.ps1
> ```
>
> The generated output in `basecoat-metadata.json` is the canonical source used by the
> router skill. Browse `agents/*.agent.md` directly for the current full list.

> Machine-readable registry of all agents, skills, and instruction files.
> Generated from the `main` branch. Keep this file in sync when adding or removing assets.

---

## Agents

| Name | File | Description | Paired Skills | Model Recommendation |
|---|---|---|---|---|
| | **🔨 Development** | | | |
| backend-dev | `agents/backend-dev.agent.md` | APIs, service layers, business logic, and data access | backend-dev | GPT-4o / Claude Sonnet |
| frontend-dev | `agents/frontend-dev.agent.md` | UI components, responsive layouts, state, accessibility | frontend-dev | GPT-4o / Claude Sonnet |
| middleware-dev | `agents/middleware-dev.agent.md` | API gateways, integration layers, event-driven architectures | — | GPT-4o / Claude Sonnet |
| data-tier | `agents/data-tier.agent.md` | Schema design, migrations, query optimization, data access | data-tier | GPT-4o / Claude Sonnet |
| | **🏗️ Architecture** | | | |
| solution-architect | `agents/solution-architect.agent.md` | System design, C4 diagrams, ADRs, and technology selection | architecture | GPT-4o / Claude Sonnet |
| api-designer | `agents/api-designer.agent.md` | API design for OpenAPI, REST, GraphQL, and governance | api-design | GPT-4o / Claude Sonnet |
| ux-designer | `agents/ux-designer.agent.md` | Journey mapping, wireframes, and accessibility audits | ux | GPT-4o / Claude Sonnet |
| app-inventory | `agents/app-inventory.agent.md` | Scan legacy apps for project files, NuGet/npm dependencies, connection strings, framework versions, and migration complexity scores | app-inventory | GPT-4o / Claude Sonnet |
| legacy-modernization | `agents/legacy-modernization.agent.md` | Guides Web Forms → Razor Pages migration using the strangler fig pattern | — | GPT-4o / Claude Sonnet |
| azure-landing-zone | `agents/azure-landing-zone.agent.md` | Enterprise-scale landing zone scaffolding following CAF/ESLZ: management groups, hub networking, policy baselines, and landing zone vending | azure-landing-zone | Claude Sonnet |
| | **🔍 Quality** | | | |
| chaos-engineer | `agents/chaos-engineer.agent.md` | Chaos engineering for fault injection, game days, resilience scoring, and recovery validation | — | GPT-4o / Claude Sonnet |
| code-review | `agents/code-review.agent.md` | Structured multi-step code review workflow | code-review | GPT-4o / Claude Sonnet |
| config-auditor | `agents/config-auditor.agent.md` | Scans for committed or unprotected config secrets | security | GPT-4o / Claude Sonnet |
| github-security-posture | `agents/github-security-posture.agent.md` | Audits GitHub org and repo security settings: code security configs, rulesets, secret scanning, Dependabot, and branch protection | github-security-posture | Claude Sonnet |
| exploratory-charter | `agents/exploratory-charter.agent.md` | Time-boxed exploratory testing charters with evidence capture | manual-test-strategy | GPT-4o / Claude Sonnet |
| guardrail | `agents/guardrail.agent.md` | Post-processing validation for safety, quality, compliance, and formatting | — | Claude Sonnet |
| identity-architect | `agents/identity-architect.agent.md` | Azure RBAC, managed identities, Entra ID app registrations, conditional access, and workload identity federation | azure-identity | GPT-4o / Claude Sonnet |
| manual-test-strategy | `agents/manual-test-strategy.agent.md` | Manual testing strategy with rubric, charter, checklist, and automation backlog | manual-test-strategy | GPT-4o / Claude Sonnet |
| performance-analyst | `agents/performance-analyst.agent.md` | Profiling, load testing, and performance optimization | performance-profiling | GPT-4o / Claude Sonnet |
| policy-as-code-compliance | `agents/policy-as-code-compliance.agent.md` | Policy-as-code compliance for validating code and config against organizational rules and producing audit-ready reports | azure-policy | GPT-4o / Claude Sonnet |
| security-analyst | `agents/security-analyst.agent.md` | Vulnerability assessment, threat modeling, secure code review | security | GPT-4o / Claude Sonnet |
| strategy-to-automation | `agents/strategy-to-automation.agent.md` | Converts manual test paths into tiered automation candidates | manual-test-strategy | GPT-4o / Claude Sonnet |
| | **🚀 DevOps** | | | |
| agentops | `agents/agentops.agent.md` | Agent lifecycle, versioning, rollout health, rollback, and retirement | — | GPT-4o / Claude Sonnet |
| containerization-planner | `agents/containerization-planner.agent.md` | Containerization readiness assessment, platform selection, Dockerfiles, multi-stage builds, and deployment manifests | — | GPT-4o / Claude Sonnet |
| devops-engineer | `agents/devops-engineer.agent.md` | CI/CD, IaC, deployment, rollback, and observability | devops | GPT-4o / Claude Sonnet |
| incident-responder | `agents/incident-responder.agent.md` | Structured incident response and recovery for classifying, mitigating, coordinating, and post-incident learning | — | GPT-4o / Claude Sonnet |
| infrastructure-deploy | `agents/infrastructure-deploy.agent.md` | Orchestrates Azure infrastructure deployments using Bicep with parameter validation and rollback strategies | — | GPT-4o / Claude Sonnet |
| release-impact-advisor | `agents/release-impact-advisor.agent.md` | Release readiness assessment, blast radius analysis, rollback planning, and safe deployment strategies | — | GPT-4o / Claude Sonnet |
| release-manager | `agents/release-manager.agent.md` | Versioned release workflow, changelog, tagging, and publishing | — | GPT-4o-mini / Claude Haiku |
| rollout-basecoat | `agents/rollout-basecoat.agent.md` | Enterprise Base Coat onboarding and rollout | — | GPT-4o-mini / Claude Haiku |
| self-healing-ci | `agents/self-healing-ci.agent.md` | Automated CI failure analysis, log parsing, flaky test detection, and pipeline remediation | — | GPT-4o / Claude Sonnet |
| sre-engineer | `agents/sre-engineer.agent.md` | Site reliability engineering for SLOs, error budgets, incident response, chaos engineering, and toil reduction | — | GPT-4o / Claude Sonnet |
| | **📋 Process** | | | |
| issue-triage | `agents/issue-triage.agent.md` | Triage, classify, label, and prioritize GitHub issues | sprint-management | GPT-4o-mini / Claude Haiku |
| product-manager | `agents/product-manager.agent.md` | Requirements, user stories, acceptance criteria, roadmaps | sprint-management | GPT-4o / Claude Sonnet |
| project-onboarding | `agents/project-onboarding.agent.md` | Base Coat repository onboarding and setup | — | GPT-4o-mini / Claude Haiku |
| retro-facilitator | `agents/retro-facilitator.agent.md` | Sprint retrospective summary and improvement issue creation | sprint-management | GPT-4o / Claude Sonnet |
| sprint-planner | `agents/sprint-planner.agent.md` | Sprint goal-to-issues breakdown and wave planning | sprint-management | GPT-4o / Claude Sonnet |
| sprint-retrospective | `agents/sprint-retrospective.agent.md` | Reconstructs repository history for sprint retrospectives with metrics and actionable tips | sprint-retrospective | GPT-4o / Claude Sonnet |
| | **🧰 Meta** | | | |
| agent-designer | `agents/agent-designer.agent.md` | Designs and authors Copilot agent definitions | agent-design | GPT-4o / Claude Sonnet |
| dependency-lifecycle | `agents/dependency-lifecycle.agent.md` | Dependency updates, breaking change tracking, upgrade paths, and migration guides | — | GPT-4o / Claude Sonnet |
| feedback-loop | `agents/feedback-loop.agent.md` | Continuous learning through feedback collection, prompt effectiveness tracking, and instruction refinement | — | GPT-4o / Claude Sonnet |
| mcp-developer | `agents/mcp-developer.agent.md` | MCP servers, tools, and integrations | mcp-development | GPT-4o / Claude Sonnet |
| memory-curator | `agents/memory-curator.agent.md` | Cross-session knowledge extraction, deduplication, validation, and context injection via SQLite memory layer | — | GPT-4o / Claude Sonnet |
| merge-coordinator | `agents/merge-coordinator.agent.md` | Parallel branch merge coordination | — | GPT-4o-mini / Claude Haiku |
| new-customization | `agents/new-customization.agent.md` | Creates or updates Base Coat customization assets | create-skill, create-instruction | GPT-4o / Claude Sonnet |
| prompt-coach | `agents/prompt-coach.agent.md` | Interactive prompt review, scoring, and refinement coaching | — | GPT-4o / Claude Sonnet |
| prompt-engineer | `agents/prompt-engineer.agent.md` | Prompt and system-prompt optimization | — | GPT-4o / Claude Sonnet |
| tech-writer | `agents/tech-writer.agent.md` | Technical docs, runbooks, tutorials, and changelogs | documentation | GPT-4o / Claude Sonnet |
| | **⚙️ Ops** | | | |
| data-pipeline | `agents/data-pipeline.agent.md` | Medallion lakehouse pipelines (bronze/silver/gold), data quality, feature store integration, and ML pipeline orchestration | — | Claude Sonnet |
| dataops | `agents/dataops.agent.md` | DataOps for data quality, lineage, governance, orchestration, and drift detection across pipelines | — | GPT-4o / Claude Sonnet |
| llmops | `agents/llmops.agent.md` | LLMOps for prompt deployment pipelines, model gateway configuration, inference monitoring, and cost optimization | — | GPT-4o / Claude Sonnet |
| mlops | `agents/mlops.agent.md` | MLOps for model lifecycle, experiment tracking, model registry, deployment automation, and drift monitoring | — | GPT-4o / Claude Sonnet |

---

## Skills

| Name | Directory | Templates Included | Paired Agents |
|---|---|---|---|
| **basecoat** | `skills/basecoat/` | *(router — discovery + delegation)* | **all agents** |
| agent-design | `skills/agent-design/` | `agent-template.md`, `instruction-template.md`, `skill-template.md` | agent-designer |
| app-inventory | `skills/app-inventory/` | `inventory-report-template.md`, `complexity-scoring-template.md` | app-inventory |
| azure-landing-zone | `skills/azure-landing-zone/` | `adr-template.md`, `platform-subscription-template.bicep`, `hub-networking-template.bicep`, `policy-assignment-template.json`, `policy-exemption-template.json`, `landing-zone-vending-template.bicep` | azure-landing-zone |
| api-design | `skills/api-design/` | `openapi-template.md`, `api-governance-checklist.md`, `breaking-change-checklist.md`, `versioning-decision-tree.md` | api-designer |
| azure-waf-review | `skills/azure-waf-review/` | `waf-assessment-report-template.md`, `pillar-scoring-rubric.md`, `remediation-action-plan-template.md` | solution-architect, security-analyst, devops-engineer |
| azure-policy | `skills/azure-policy/` | `policy-definition-template.md`, `initiative-definition-template.md`, `remediation-task-template.md`, `compliance-report-template.md` | policy-as-code-compliance |
| architecture | `skills/architecture/` | `adr-template.md`, `c4-diagram-template.md`, `risk-register-template.md`, `tech-selection-matrix-template.md` | solution-architect |
| azure-container-apps | `skills/azure-container-apps/` | *(workflow only)* | devops-engineer |
| azure-networking | `skills/azure-networking/` | `hub-spoke-topology.md`, `cidr-allocation.md`, `private-endpoint-dns-zones.md`, `nsg-rule-matrix.md` | solution-architect, devops-engineer |
| azure-identity | `skills/azure-identity/` | `rbac-role-assignment-template.md`, `managed-identity-mapping-template.md`, `app-registration-checklist.md`, `workload-identity-federation-template.md`, `conditional-access-policy-template.md` | identity-architect |
| backend-dev | `skills/backend-dev/` | `api-spec-template.md`, `error-catalog-template.md`, `repository-pattern-template.md`, `service-template.md` | backend-dev |
| code-review | `skills/code-review/` | *(workflow only)* | code-review |
| create-instruction | `skills/create-instruction/` | *(workflow only)* | new-customization |
| create-skill | `skills/create-skill/` | *(workflow only)* | new-customization |
| data-tier | `skills/data-tier/` | `schema-design-template.md`, `migration-template.md`, `query-review-checklist.md`, `data-dictionary-template.md` | data-tier |
| devops | `skills/devops/` | `deployment-checklist.md`, `environment-promotion-template.md`, `github-actions-template.md`, `rollback-runbook-template.md` | devops-engineer |
| documentation | `skills/documentation/` | `readme-template.md`, `runbook-template.md`, `adr-template.md` | tech-writer |
| environment-bootstrap | `skills/environment-bootstrap/` | *(workflow only)* | devops-engineer |
| frontend-dev | `skills/frontend-dev/` | `component-spec-template.md`, `accessibility-checklist.md`, `state-management-template.md` | frontend-dev |
| handoff | `skills/handoff/` | *(workflow only)* | — |
| human-in-the-loop | `skills/human-in-the-loop/` | *(workflow only)* | — |
| identity-migration | `skills/identity-migration/` | *(workflow only)* | identity-architect |
| manual-test-strategy | `skills/manual-test-strategy/` | `charter-template.md`, `checklist-template.md`, `defect-template.md`, `rubric-template.md` | manual-test-strategy, exploratory-charter, strategy-to-automation |
| mcp-development | `skills/mcp-development/` | `mcp-server-template.md`, `tool-definition-template.md`, `transport-config-template.md` | mcp-developer |
| performance-profiling | `skills/performance-profiling/` | *(workflow only)* | performance-analyst |
| refactoring | `skills/refactoring/` | *(workflow only)* | — |
| security | `skills/security/` | `owasp-checklist.md`, `stride-threat-model-template.md`, `vulnerability-report-template.md`, `dependency-audit-template.md` | security-analyst, config-auditor |
| github-security-posture | `skills/github-security-posture/` | `posture-report-template.md` | github-security-posture |
| service-bus-migration | `skills/service-bus-migration/` | *(workflow only)* | — |
| sprint-management | `skills/sprint-management/` | `sprint-planning-template.md`, `backlog-grooming-template.md`, `retrospective-template.md` | sprint-planner, retro-facilitator, product-manager, issue-triage |
| sprint-retrospective | `skills/sprint-retrospective/` | *(workflow only)* | sprint-retrospective |
| task-decomposition | `skills/task-decomposition/` | `complex-task-breakdown-template.md`, `automation-fitness-matrix.md`, `prompt-validation-checklist.md`, `examples/` | — |
| ux | `skills/ux/` | `user-journey-template.md`, `wireframe-spec-template.md`, `component-spec-template.md`, `accessibility-audit-checklist.md` | ux-designer |
| copilot-usage-analytics | `skills/copilot-usage-analytics/` | `templates/session-cost-estimate-template.md`, `templates/model-routing-recommendation-template.md`, `templates/api-landscape.md` | agentops, performance-analyst, sprint-planner |

---

## Instruction Files

| Name | File | Scope |
|---|---|---|
| agent-behavior | `instructions/agent-behavior.instructions.md` | Retry loop prevention, edit thrashing, and escalation decisions |
| agents | `instructions/agents.instructions.md` | Agent authoring standards |
| architecture | `instructions/architecture.instructions.md` | Architecture, API, and design-diagram guidance |
| azure | `instructions/azure.instructions.md` | Azure service, SDK, and deployment guidance |
| backend | `instructions/backend.instructions.md` | Backend APIs, services, workers, and data access |
| bicep | `instructions/bicep.instructions.md` | Azure Bicep authoring and validation |
| config | `instructions/config.instructions.md` | Config file safety and secrets prevention |
| data-science | `instructions/data-science.instructions.md` | Data science, ML, notebook, and medallion lakehouse patterns |
| development | `instructions/development.instructions.md` | Shared dev standards for all dev-core agents |
| documentation | `instructions/documentation.instructions.md` | Documentation and change-note expectations |
| drift-monitor | `instructions/drift-monitor.instructions.md` | Infrastructure-as-Code drift detection and remediation strategies |
| error-kb | `instructions/error-kb.instructions.md` | Building and consulting error knowledge bases for failure classification and proven fixes |
| frontend | `instructions/frontend.instructions.md` | Frontend, UI, state management, and accessibility |
| governance | `instructions/governance.instructions.md` | Repository-wide AI governance rules |
| mcp | `instructions/mcp.instructions.md` | MCP server, tooling, and trust-boundary guidance |
| model-routing | `instructions/model-routing.instructions.md` | Cost-aware model routing to avoid over-spending on premium models |
| naming | `instructions/naming.instructions.md` | Naming conventions across repos, code, and infrastructure |
| nextjs-react19 | `instructions/nextjs-react19.instructions.md` | Next.js and React 19 Server Components, App Router, and modern patterns |
| npm-workspaces | `instructions/npm-workspaces.instructions.md` | npm workspaces and monorepo management best practices |
| output-style | `instructions/output-style.instructions.md` | Concise agent responses while preserving clarity and full-fidelity code |
| plan-first | `instructions/plan-first.instructions.md` | Explore-plan-implement-verify workflow for multi-step tasks |
| process | `instructions/process.instructions.md` | Delivery lifecycle, sprint, triage, and release process |
| quality | `instructions/quality.instructions.md` | PR review, security, performance, and coverage gates |
| reliability | `instructions/reliability.instructions.md` | Retries, uptime, background work, and dependency failure |
| security | `instructions/security.instructions.md` | Secure coding, auth, authz, secrets, and input handling |
| session-hygiene | `instructions/session-hygiene.instructions.md` | Context hygiene, session rotation, and clean-state working practices |
| tailwind-v4 | `instructions/tailwind-v4.instructions.md` | Tailwind CSS v4 patterns, CSS-first configuration, and migration guidance |
| terraform | `instructions/terraform.instructions.md` | Terraform guidance for Azure-oriented IaC |
| testing | `instructions/testing.instructions.md` | Testing best practices and validation expectations |
| token-economics | `instructions/token-economics.instructions.md` | Cost-aware model routing and token budget discipline |
| tool-minimization | `instructions/tool-minimization.instructions.md` | Selective tool enablement and disciplined MCP server usage |
| ux | `instructions/ux.instructions.md` | UX, accessibility, and design-system guidance |
| verification | `instructions/verification.instructions.md` | Explicit success criteria before coding and verification with evidence before completion |

---

## Prompts

| Name | File | Description |
|---|---|---|
| architect | `prompts/architect.prompt.md` | Architecture planning and implementation starter |
| bugfix | `prompts/bugfix.prompt.md` | Root-cause analysis and minimal safe fix workflow |
| code-review | `prompts/code-review.prompt.md` | Risk-focused code review workflow |

---

## Guardrails

| Name | File | Purpose |
|---|---|---|
| caf-naming | `docs/guardrails/caf-naming.md` | CAF naming conventions for Azure resources |
| container-image-tags | `docs/guardrails/container-image-tags.md` | Container image tags must include Git SHA |
| db-deployment-concurrency | `docs/guardrails/db-deployment-concurrency.md` | Database deployment concurrency rules |
| env-example | `docs/guardrails/env-example.md` | `.env.example` required for every repo |
| oidc-federation | `docs/guardrails/oidc-federation.md` | GitHub Actions to Azure OIDC federation |
| secrets-in-workflows | `docs/guardrails/secrets-in-workflows.md` | No hardcoded secrets in workflow files |
