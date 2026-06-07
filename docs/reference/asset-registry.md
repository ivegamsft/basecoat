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

Machine-readable registry of all agents, skills, and instruction files.
Generated from the `main` branch. Keep this file in sync when adding or removing assets.

---

## basecoat-10-core-agents

| Name | File | Description | Paired Skills | Model Recommendation |
|---|---|---|---|---|
| | **🔨 Development** | | | |
| basecoat-10-core-backend-dev | `agents/basecoat-10-core-backend-dev.agent.md` | APIs, service layers, business logic, and data access | basecoat-10-core-backend-dev | GPT-4o / Claude Sonnet |
| basecoat-10-core-frontend-dev | `agents/basecoat-10-core-frontend-dev.agent.md` | UI components, responsive layouts, state, accessibility | basecoat-10-core-frontend-dev | GPT-4o / Claude Sonnet |
| basecoat-10-core-middleware-dev | `agents/basecoat-10-core-middleware-dev.agent.md` | API gateways, integration layers, event-driven architectures | — | GPT-4o / Claude Sonnet |
| basecoat-80-data-data-tier | `agents/basecoat-80-data-data-tier.agent.md` | Schema design, migrations, query optimization, data access | basecoat-80-data-data-tier | GPT-4o / Claude Sonnet |
| | **🏗️ Architecture** | | | |
| basecoat-10-core-solution-architect | `agents/basecoat-10-core-solution-architect.agent.md` | System design, C4 diagrams, ADRs, and technology selection | basecoat-10-core-architecture | GPT-4o / Claude Sonnet |
| basecoat-10-core-api-designer | `agents/basecoat-10-core-api-designer.agent.md` | API design for OpenAPI, REST, GraphQL, and basecoat-20-lang-governance | api-design | GPT-4o / Claude Sonnet |
| basecoat-10-core-ux-designer | `agents/basecoat-10-core-ux-designer.agent.md` | Journey mapping, wireframes, and accessibility audits | basecoat-10-core-ux | GPT-4o / Claude Sonnet |
| basecoat-10-core-app-inventory | `agents/basecoat-10-core-app-inventory.agent.md` | Scan legacy apps for project files, NuGet/npm dependencies, connection strings, framework versions, and migration complexity scores | basecoat-10-core-app-inventory | GPT-4o / Claude Sonnet |
| basecoat-10-core-legacy-modernization | `agents/basecoat-10-core-legacy-modernization.agent.md` | Guides Web Forms → Razor Pages migration using the strangler fig pattern | — | GPT-4o / Claude Sonnet |
| basecoat-40-azure-azure-landing-zone | `agents/basecoat-40-azure-azure-landing-zone.agent.md` | Enterprise-scale landing zone scaffolding following CAF/ESLZ: management groups, hub networking, policy baselines, and landing zone vending | basecoat-40-azure-azure-landing-zone | Claude Sonnet |
| | **🔍 Quality** | | | |
| basecoat-10-core-chaos-engineer | `agents/basecoat-10-core-chaos-engineer.agent.md` | Chaos engineering for fault injection, game days, resilience scoring, and recovery validation | — | GPT-4o / Claude Sonnet |
| basecoat-90-quality-code-review | `agents/basecoat-90-quality-code-review.agent.md` | Structured multi-step code review workflow | basecoat-90-quality-code-review | GPT-4o / Claude Sonnet |
| basecoat-50-security-config-auditor | `agents/basecoat-50-security-config-auditor.agent.md` | Scans for committed or unprotected basecoat-10-core-config secrets | basecoat-50-security-security | GPT-4o / Claude Sonnet |
| basecoat-50-security-github-security-posture | `agents/basecoat-50-security-github-security-posture.agent.md` | Audits GitHub org and repo basecoat-50-security-security settings: code basecoat-50-security-security configs, rulesets, secret scanning, Dependabot, and branch protection | basecoat-50-security-github-security-posture | Claude Sonnet |
| basecoat-10-core-exploratory-charter | `agents/basecoat-10-core-exploratory-charter.agent.md` | Time-boxed exploratory basecoat-10-core-testing charters with evidence capture | basecoat-90-quality-manual-test-strategy | GPT-4o / Claude Sonnet |
| basecoat-30-ai-guardrail | `agents/basecoat-30-ai-guardrail.agent.md` | Post-processing validation for safety, quality, compliance, and formatting | — | Claude Sonnet |
| basecoat-10-core-identity-architect | `agents/basecoat-10-core-identity-architect.agent.md` | basecoat-40-azure-azure RBAC, managed identities, Entra ID app registrations, conditional access, and workload identity federation | azure-identity | GPT-4o / Claude Sonnet |
| basecoat-90-quality-manual-test-strategy | `agents/basecoat-90-quality-manual-test-strategy.agent.md` | Manual basecoat-10-core-testing strategy with rubric, charter, checklist, and automation backlog | basecoat-90-quality-manual-test-strategy | GPT-4o / Claude Sonnet |
| basecoat-10-core-performance-analyst | `agents/basecoat-10-core-performance-analyst.agent.md` | Profiling, load testing, and performance optimization | performance-profiling | GPT-4o / Claude Sonnet |
| basecoat-50-security-policy-as-code-compliance | `agents/basecoat-50-security-policy-as-code-compliance.agent.md` | Policy-as-code compliance for validating code and basecoat-10-core-config against organizational rules and producing audit-ready reports | azure-policy | GPT-4o / Claude Sonnet |
| basecoat-50-security-security-analyst | `agents/basecoat-50-security-security-analyst.agent.md` | Vulnerability assessment, threat modeling, secure code review | basecoat-50-security-security | GPT-4o / Claude Sonnet |
| basecoat-10-core-strategy-to-automation | `agents/basecoat-10-core-strategy-to-automation.agent.md` | Converts manual test paths into tiered automation candidates | basecoat-90-quality-manual-test-strategy | GPT-4o / Claude Sonnet |
| | **🚀 DevOps** | | | |
| basecoat-10-core-agentops | `agents/basecoat-10-core-agentops.agent.md` | Agent lifecycle, versioning, rollout health, rollback, and retirement | — | GPT-4o / Claude Sonnet |
| basecoat-30-ai-containerization-planner | `agents/basecoat-30-ai-containerization-planner.agent.md` | Containerization readiness assessment, platform selection, Dockerfiles, multi-stage builds, and deployment manifests | — | GPT-4o / Claude Sonnet |
| basecoat-10-core-devops-engineer | `agents/basecoat-10-core-devops-engineer.agent.md` | CI/CD, IaC, deployment, rollback, and basecoat-10-core-observability | devops | GPT-4o / Claude Sonnet |
| basecoat-60-workflow-incident-responder | `agents/basecoat-60-workflow-incident-responder.agent.md` | Structured incident response and recovery for classifying, mitigating, coordinating, and post-incident learning | — | GPT-4o / Claude Sonnet |
| basecoat-60-workflow-infrastructure-deploy | `agents/basecoat-60-workflow-infrastructure-deploy.agent.md` | Orchestrates basecoat-40-azure-azure infrastructure deployments using basecoat-10-core-bicep with parameter validation and rollback strategies | — | GPT-4o / Claude Sonnet |
| basecoat-60-workflow-release-impact-advisor | `agents/basecoat-60-workflow-release-impact-advisor.agent.md` | Release readiness assessment, blast radius analysis, rollback planning, and safe deployment strategies | — | GPT-4o / Claude Sonnet |
| basecoat-60-workflow-release-manager | `agents/basecoat-60-workflow-release-manager.agent.md` | Versioned release workflow, changelog, tagging, and publishing | — | GPT-4o-mini / Claude Haiku |
| basecoat-60-workflow-rollout-basecoat | `agents/basecoat-60-workflow-rollout-basecoat.agent.md` | Enterprise Base Coat onboarding and rollout | — | GPT-4o-mini / Claude Haiku |
| basecoat-60-workflow-self-healing-ci | `agents/basecoat-60-workflow-self-healing-ci.agent.md` | Automated CI failure analysis, log parsing, flaky test detection, and pipeline remediation | — | GPT-4o / Claude Sonnet |
| basecoat-10-core-sre-engineer | `agents/basecoat-10-core-sre-engineer.agent.md` | Site basecoat-10-core-reliability engineering for SLOs, error budgets, incident response, chaos engineering, and toil reduction | — | GPT-4o / Claude Sonnet |
| | **📋 Process** | | | |
| basecoat-10-core-issue-triage | `agents/basecoat-10-core-issue-triage.agent.md` | Triage, classify, label, and prioritize GitHub issues | sprint-management | GPT-4o-mini / Claude Haiku |
| basecoat-10-core-product-manager | `agents/basecoat-10-core-product-manager.agent.md` | Requirements, user stories, acceptance criteria, roadmaps | sprint-management | GPT-4o / Claude Sonnet |
| basecoat-10-core-project-onboarding | `agents/basecoat-10-core-project-onboarding.agent.md` | Base Coat repository onboarding and setup | — | GPT-4o-mini / Claude Haiku |
| basecoat-60-workflow-retro-facilitator | `agents/basecoat-60-workflow-retro-facilitator.agent.md` | Sprint retrospective summary and improvement issue creation | sprint-management | GPT-4o / Claude Sonnet |
| basecoat-10-core-sprint-planner | `agents/basecoat-10-core-sprint-planner.agent.md` | Sprint goal-to-issues breakdown and wave planning | sprint-management | GPT-4o / Claude Sonnet |
| basecoat-10-core-sprint-retrospective | `agents/basecoat-10-core-sprint-retrospective.agent.md` | Reconstructs repository history for sprint retrospectives with metrics and actionable tips | basecoat-10-core-sprint-retrospective | GPT-4o / Claude Sonnet |
| | **🧰 Meta** | | | |
| basecoat-10-core-agent-designer | `agents/basecoat-10-core-agent-designer.agent.md` | Designs and authors Copilot agent definitions | agent-design | GPT-4o / Claude Sonnet |
| basecoat-10-core-dependency-lifecycle | `agents/basecoat-10-core-dependency-lifecycle.agent.md` | Dependency updates, breaking change tracking, upgrade paths, and migration guides | — | GPT-4o / Claude Sonnet |
| basecoat-10-core-feedback-loop | `agents/basecoat-10-core-feedback-loop.agent.md` | Continuous learning through feedback collection, prompt effectiveness tracking, and instruction refinement | — | GPT-4o / Claude Sonnet |
| basecoat-10-core-mcp-developer | `agents/basecoat-10-core-mcp-developer.agent.md` | basecoat-10-core-mcp servers, tools, and integrations | mcp-basecoat-10-core-development | GPT-4o / Claude Sonnet |
| basecoat-10-core-memory-curator | `agents/basecoat-10-core-memory-curator.agent.md` | Cross-session knowledge extraction, deduplication, validation, and context injection via SQLite memory layer | — | GPT-4o / Claude Sonnet |
| basecoat-10-core-merge-coordinator | `agents/basecoat-10-core-merge-coordinator.agent.md` | Parallel branch merge coordination | — | GPT-4o-mini / Claude Haiku |
| basecoat-10-core-new-customization | `agents/basecoat-10-core-new-customization.agent.md` | Creates or updates Base Coat customization assets | create-skill, create-instruction | GPT-4o / Claude Sonnet |
| basecoat-10-core-prompt-coach | `agents/basecoat-10-core-prompt-coach.agent.md` | Interactive prompt review, scoring, and refinement coaching | — | GPT-4o / Claude Sonnet |
| basecoat-10-core-prompt-engineer | `agents/basecoat-10-core-prompt-engineer.agent.md` | Prompt and system-prompt optimization | — | GPT-4o / Claude Sonnet |
| basecoat-10-core-tech-writer | `agents/basecoat-10-core-tech-writer.agent.md` | Technical docs, runbooks, tutorials, and changelogs | basecoat-10-core-documentation | GPT-4o / Claude Sonnet |
| | **⚙️ Ops** | | | |
| basecoat-60-workflow-data-pipeline | `agents/basecoat-60-workflow-data-pipeline.agent.md` | Medallion lakehouse pipelines (bronze/silver/gold), data quality, feature store integration, and ML pipeline orchestration | — | Claude Sonnet |
| basecoat-80-data-dataops | `agents/basecoat-80-data-dataops.agent.md` | basecoat-80-data-dataops for data quality, lineage, governance, orchestration, and drift detection across pipelines | — | GPT-4o / Claude Sonnet |
| basecoat-10-core-llmops | `agents/basecoat-10-core-llmops.agent.md` | basecoat-10-core-llmops for prompt deployment pipelines, model gateway configuration, inference monitoring, and cost optimization | — | GPT-4o / Claude Sonnet |
| basecoat-30-ai-mlops | `agents/basecoat-30-ai-mlops.agent.md` | basecoat-30-ai-mlops for model lifecycle, experiment tracking, model registry, deployment automation, and drift monitoring | — | GPT-4o / Claude Sonnet |

---

## Skills

| Name | Directory | Templates Included | Paired basecoat-10-core-agents |
|---|---|---|---|
| **basecoat** | `skills/basecoat/` | *(router — discovery + delegation)* | **all agents** |
| agent-design | `skills/agent-design/` | `agent-template.md`, `instruction-template.md`, `skill-template.md` | basecoat-10-core-agent-designer |
| basecoat-10-core-app-inventory | `skills/app-inventory/` | `inventory-report-template.md`, `complexity-scoring-template.md` | basecoat-10-core-app-inventory |
| basecoat-40-azure-azure-landing-zone | `skills/azure-landing-zone/` | `adr-template.md`, `platform-subscription-template.basecoat-10-core-bicep`, `hub-networking-template.basecoat-10-core-bicep`, `policy-assignment-template.json`, `policy-exemption-template.json`, `landing-zone-vending-template.basecoat-10-core-bicep` | basecoat-40-azure-azure-landing-zone |
| api-design | `skills/api-design/` | `openapi-template.md`, `api-governance-checklist.md`, `breaking-change-checklist.md`, `versioning-decision-tree.md` | basecoat-10-core-api-designer |
| azure-waf-review | `skills/azure-waf-review/` | `waf-assessment-report-template.md`, `pillar-scoring-rubric.md`, `remediation-action-plan-template.md` | solution-architect, security-analyst, basecoat-10-core-devops-engineer |
| azure-policy | `skills/azure-policy/` | `policy-definition-template.md`, `initiative-definition-template.md`, `remediation-task-template.md`, `compliance-report-template.md` | basecoat-50-security-policy-as-code-compliance |
| basecoat-10-core-architecture | `skills/architecture/` | `adr-template.md`, `c4-diagram-template.md`, `risk-register-template.md`, `tech-selection-matrix-template.md` | basecoat-10-core-solution-architect |
| azure-container-apps | `skills/azure-container-apps/` | *(workflow only)* | basecoat-10-core-devops-engineer |
| azure-networking | `skills/azure-networking/` | `hub-spoke-topology.md`, `cidr-allocation.md`, `private-endpoint-dns-zones.md`, `nsg-rule-matrix.md` | solution-architect, basecoat-10-core-devops-engineer |
| azure-identity | `skills/azure-identity/` | `rbac-role-assignment-template.md`, `managed-identity-mapping-template.md`, `app-registration-checklist.md`, `workload-identity-federation-template.md`, `conditional-access-policy-template.md` | basecoat-10-core-identity-architect |
| basecoat-10-core-backend-dev | `skills/backend-dev/` | `api-spec-template.md`, `error-catalog-template.md`, `repository-pattern-template.md`, `service-template.md` | basecoat-10-core-backend-dev |
| basecoat-90-quality-code-review | `skills/code-review/` | *(workflow only)* | basecoat-90-quality-code-review |
| create-instruction | `skills/create-instruction/` | *(workflow only)* | basecoat-10-core-new-customization |
| create-skill | `skills/create-skill/` | *(workflow only)* | basecoat-10-core-new-customization |
| basecoat-80-data-data-tier | `skills/data-tier/` | `schema-design-template.md`, `migration-template.md`, `query-review-checklist.md`, `data-dictionary-template.md` | basecoat-80-data-data-tier |
| devops | `skills/devops/` | `deployment-checklist.md`, `environment-promotion-template.md`, `github-actions-template.md`, `rollback-runbook-template.md` | basecoat-10-core-devops-engineer |
| basecoat-10-core-documentation | `skills/documentation/` | `readme-template.md`, `runbook-template.md`, `adr-template.md` | basecoat-10-core-tech-writer |
| environment-bootstrap | `skills/environment-bootstrap/` | *(workflow only)* | basecoat-10-core-devops-engineer |
| basecoat-10-core-frontend-dev | `skills/frontend-dev/` | `component-spec-template.md`, `accessibility-checklist.md`, `state-management-template.md` | basecoat-10-core-frontend-dev |
| handoff | `skills/handoff/` | *(workflow only)* | — |
| human-in-the-loop | `skills/human-in-the-loop/` | *(workflow only)* | — |
| identity-migration | `skills/identity-migration/` | *(workflow only)* | basecoat-10-core-identity-architect |
| basecoat-90-quality-manual-test-strategy | `skills/manual-test-strategy/` | `charter-template.md`, `checklist-template.md`, `defect-template.md`, `rubric-template.md` | manual-test-strategy, exploratory-charter, basecoat-10-core-strategy-to-automation |
| mcp-basecoat-10-core-development | `skills/mcp-development/` | `mcp-server-template.md`, `tool-definition-template.md`, `transport-config-template.md` | basecoat-10-core-mcp-developer |
| performance-profiling | `skills/performance-profiling/` | *(workflow only)* | basecoat-10-core-performance-analyst |
| refactoring | `skills/refactoring/` | *(workflow only)* | — |
| basecoat-50-security-security | `skills/security/` | `owasp-checklist.md`, `stride-threat-model-template.md`, `vulnerability-report-template.md`, `dependency-audit-template.md` | security-analyst, basecoat-50-security-config-auditor |
| basecoat-50-security-github-security-posture | `skills/github-security-posture/` | `posture-report-template.md` | basecoat-50-security-github-security-posture |
| service-bus-migration | `skills/service-bus-migration/` | *(workflow only)* | — |
| sprint-management | `skills/sprint-management/` | `sprint-planning-template.md`, `backlog-grooming-template.md`, `retrospective-template.md` | sprint-planner, retro-facilitator, product-manager, basecoat-10-core-issue-triage |
| basecoat-10-core-sprint-retrospective | `skills/sprint-retrospective/` | *(workflow only)* | basecoat-10-core-sprint-retrospective |
| task-decomposition | `skills/task-decomposition/` | `complex-task-breakdown-template.md`, `automation-fitness-matrix.md`, `prompt-validation-checklist.md`, `examples/` | — |
| basecoat-10-core-ux | `skills/ux/` | `user-journey-template.md`, `wireframe-spec-template.md`, `component-spec-template.md`, `accessibility-audit-checklist.md` | basecoat-10-core-ux-designer |
| copilot-usage-analytics | `skills/copilot-usage-analytics/` | `templates/session-cost-estimate-template.md`, `templates/model-routing-recommendation-template.md`, `templates/api-landscape.md` | agentops, performance-analyst, basecoat-10-core-sprint-planner |

---

## Instruction Files

| Name | File | Scope |
|---|---|---|
| basecoat-10-core-agent-behavior | `instructions/basecoat-10-core-agent-behavior.instructions.md` | Retry loop prevention, edit thrashing, and escalation decisions |
| basecoat-10-core-agents | `instructions/basecoat-10-core-agents.instructions.md` | Agent authoring standards |
| basecoat-10-core-architecture | `instructions/basecoat-10-core-architecture.instructions.md` | Architecture, API, and design-diagram guidance |
| basecoat-40-azure-azure | `instructions/basecoat-40-azure-azure.instructions.md` | basecoat-40-azure-azure service, SDK, and deployment guidance |
| basecoat-10-core-backend | `instructions/basecoat-10-core-backend.instructions.md` | basecoat-10-core-backend APIs, services, workers, and data access |
| basecoat-10-core-bicep | `instructions/basecoat-10-core-bicep.instructions.md` | basecoat-40-azure-azure basecoat-10-core-bicep authoring and validation |
| basecoat-10-core-config | `instructions/basecoat-10-core-config.instructions.md` | basecoat-10-core-config file safety and secrets prevention |
| basecoat-80-data-data-science | `instructions/basecoat-80-data-data-science.instructions.md` | Data science, ML, notebook, and medallion lakehouse patterns |
| basecoat-10-core-development | `instructions/basecoat-10-core-development.instructions.md` | Shared dev standards for all dev-core basecoat-10-core-agents |
| basecoat-10-core-documentation | `instructions/basecoat-10-core-documentation.instructions.md` | basecoat-10-core-documentation and change-note expectations |
| basecoat-10-core-drift-monitor | `instructions/basecoat-10-core-drift-monitor.instructions.md` | Infrastructure-as-Code drift detection and remediation strategies |
| basecoat-10-core-error-kb | `instructions/basecoat-10-core-error-kb.instructions.md` | Building and consulting error knowledge bases for failure classification and proven fixes |
| basecoat-10-core-frontend | `instructions/basecoat-10-core-frontend.instructions.md` | Frontend, UI, state management, and accessibility |
| basecoat-20-lang-governance | `instructions/basecoat-20-lang-governance.instructions.md` | Repository-wide AI basecoat-20-lang-governance rules |
| basecoat-10-core-mcp | `instructions/basecoat-10-core-mcp.instructions.md` | basecoat-10-core-mcp server, tooling, and trust-boundary guidance |
| basecoat-10-core-model-routing | `instructions/basecoat-10-core-model-routing.instructions.md` | Cost-aware model routing to avoid over-spending on premium models |
| basecoat-10-core-naming | `instructions/basecoat-10-core-naming.instructions.md` | basecoat-10-core-naming conventions across repos, code, and infrastructure |
| basecoat-10-core-nextjs-react19 | `instructions/basecoat-10-core-nextjs-react19.instructions.md` | Next.js and React 19 Server Components, App Router, and modern patterns |
| basecoat-10-core-npm-workspaces | `instructions/basecoat-10-core-npm-workspaces.instructions.md` | npm workspaces and monorepo management best practices |
| basecoat-10-core-output-style | `instructions/basecoat-10-core-output-style.instructions.md` | Concise agent responses while preserving clarity and full-fidelity code |
| basecoat-10-core-plan-first | `instructions/basecoat-10-core-plan-first.instructions.md` | Explore-plan-implement-verify workflow for multi-step tasks |
| basecoat-10-core-process | `instructions/basecoat-10-core-process.instructions.md` | Delivery lifecycle, sprint, triage, and release basecoat-10-core-process |
| basecoat-90-quality-quality | `instructions/basecoat-90-quality-quality.instructions.md` | PR review, security, performance, and coverage gates |
| basecoat-10-core-reliability | `instructions/basecoat-10-core-reliability.instructions.md` | Retries, uptime, background work, and dependency failure |
| basecoat-50-security-security | `instructions/basecoat-50-security-security.instructions.md` | Secure coding, auth, authz, secrets, and input handling |
| basecoat-10-core-session-hygiene | `instructions/basecoat-10-core-session-hygiene.instructions.md` | Context hygiene, session rotation, and clean-state working practices |
| basecoat-30-ai-tailwind-v4 | `instructions/basecoat-30-ai-tailwind-v4.instructions.md` | Tailwind CSS v4 patterns, CSS-first configuration, and migration guidance |
| basecoat-10-core-terraform | `instructions/basecoat-10-core-terraform.instructions.md` | basecoat-10-core-terraform guidance for Azure-oriented IaC |
| basecoat-10-core-testing | `instructions/basecoat-10-core-testing.instructions.md` | basecoat-10-core-testing best practices and validation expectations |
| basecoat-50-security-token-economics | `instructions/basecoat-50-security-token-economics.instructions.md` | Cost-aware model routing and token budget discipline |
| basecoat-10-core-tool-minimization | `instructions/basecoat-10-core-tool-minimization.instructions.md` | Selective tool enablement and disciplined basecoat-10-core-mcp server usage |
| basecoat-10-core-ux | `instructions/basecoat-10-core-ux.instructions.md` | UX, accessibility, and design-system guidance |
| basecoat-10-core-verification | `instructions/basecoat-10-core-verification.instructions.md` | Explicit success criteria before coding and basecoat-10-core-verification with evidence before completion |

---

## Prompts

| Name | File | Description |
|---|---|---|
| architect | `prompts/architect.prompt.md` | basecoat-10-core-architecture planning and implementation starter |
| bugfix | `prompts/bugfix.prompt.md` | Root-cause analysis and minimal safe fix workflow |
| basecoat-90-quality-code-review | `prompts/code-review.prompt.md` | Risk-focused code review workflow |

---

## Guardrails

| Name | File | Purpose |
|---|---|---|
| caf-basecoat-10-core-naming | `docs/guardrails/caf-naming.md` | CAF basecoat-10-core-naming conventions for basecoat-40-azure-azure resources |
| container-image-tags | `docs/guardrails/container-image-tags.md` | Container image tags must include Git SHA |
| db-deployment-concurrency | `docs/guardrails/db-deployment-concurrency.md` | Database deployment concurrency rules |
| env-example | `docs/guardrails/env-example.md` | `.env.example` required for every repo |
| oidc-federation | `docs/guardrails/oidc-federation.md` | GitHub Actions to basecoat-40-azure-azure OIDC federation |
| secrets-in-workflows | `docs/guardrails/secrets-in-workflows.md` | No hardcoded secrets in workflow files |
