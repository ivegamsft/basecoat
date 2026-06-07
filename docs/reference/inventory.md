# Inventory

> **⚠️ Staleness notice:** This file is manually maintained and may not reflect recently
> added agents, skills, or instruction files. For a current machine-generated listing:
>
> - Agents: run `pwsh scripts/update-metadata.ps1` and see `basecoat-metadata.json`
> - Instructions and skills: browse the `instructions/` and `skills/` directories directly

This catalog helps teams discover what exists in Base Coat and when to use it.

Name collisions between instructions and skills are allowed. If an instruction
and skill share a name (for example, `basecoat-10-core-architecture` or `basecoat-50-security-security`), treat them
as distinct assets and disambiguate by source path (`instructions/` vs
`skills/`) and type.

## Instructions

| File                                         | Use For                                               | Keywords                                                           |
| -------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------ |
| `instructions/basecoat-10-core-agent-behavior.instructions.md` | anti-loop detection and agent behavioral guardrails | agent, behavior, loop, guardrail, anti-pattern |
| `instructions/basecoat-10-core-agents.instructions.md`        | agent authoring standards | agents, authoring, frontmatter, design |
| `instructions/basecoat-10-core-architecture.instructions.md`  | architecture, API, and design-diagram guidance | architecture, api, design, diagram, adr |
| `instructions/basecoat-40-azure-azure.instructions.md`         | basecoat-40-azure-azure application and service guidance                | azure, managed identity, key vault, app service                    |
| `instructions/basecoat-10-core-backend.instructions.md`       | API, services, data access, basecoat-10-core-backend guardrails        | backend, api, refactor, service, basecoat-10-core-reliability                       |
| `instructions/basecoat-10-core-bicep.instructions.md`         | basecoat-10-core-bicep authoring, parameters, and deployment hygiene   | bicep, bicepparam, module, symbolic name                           |
| `instructions/basecoat-10-core-config.instructions.md`        | basecoat-10-core-config file safety and secrets prevention | config, secrets, safety, environment |
| `instructions/basecoat-80-data-data-science.instructions.md`   | data science, ML workflows, notebooks, medallion lakehouse | data-science, ml, notebook, pipeline, medallion, bronze, silver, gold |
| `instructions/basecoat-10-core-development.instructions.md`   | shared standards for backend-dev, frontend-dev, middleware-dev, basecoat-80-data-data-tier basecoat-10-core-agents | development, code style, error handling, security, logging, testing, collaboration |
| `instructions/basecoat-10-core-documentation.instructions.md` | docs updates and operational notes                    | docs, readme, changelog, migration, usage                          |
| `instructions/basecoat-10-core-drift-monitor.instructions.md` | detect and prevent configuration drift across environments | drift, monitor, config, environment, consistency |
| `instructions/basecoat-10-core-error-kb.instructions.md`      | error knowledge base and resolution pattern guidance | error, knowledge-base, resolution, troubleshooting |
| `instructions/basecoat-10-core-frontend.instructions.md`      | UI, accessibility, responsiveness, basecoat-10-core-frontend changes   | frontend, ui, css, accessibility, react                            |
| `instructions/basecoat-20-lang-governance.instructions.md`    | repository-wide AI basecoat-20-lang-governance rules | governance, rules, compliance, standards |
| `instructions/basecoat-10-core-mcp.instructions.md`           | basecoat-10-core-mcp server/tool basecoat-20-lang-governance and safe integration rules | mcp, tools, server, governance, allowlist                          |
| `instructions/basecoat-10-core-model-routing.instructions.md` | cost-aware model selection and fleet dispatch | model, routing, cost, fleet, dispatch, tier |
| `instructions/basecoat-10-core-naming.instructions.md`        | consistent basecoat-10-core-naming across code and infrastructure      | naming, convention, style, files, resources                        |
| `instructions/basecoat-10-core-nextjs-react19.instructions.md` | Next.js and React 19 patterns and conventions | nextjs, react, react19, ssr, server-components |
| `instructions/basecoat-10-core-npm-workspaces.instructions.md` | npm workspaces and monorepo conventions | npm, workspaces, monorepo, packages |
| `instructions/basecoat-10-core-output-style.instructions.md`  | agent output formatting and style guidance | output, style, formatting, markdown |
| `instructions/basecoat-10-core-plan-first.instructions.md`    | basecoat-10-core-plan-first workflow for basecoat-10-core-agents — think before coding | plan, workflow, think, design, before-coding |
| `instructions/basecoat-10-core-process.instructions.md`       | delivery lifecycle, sprint, triage, and release basecoat-10-core-process | process, sprint, triage, release, delivery |
| `instructions/basecoat-90-quality-quality.instructions.md`       | PR review, security, performance, and coverage gates | quality, review, security, performance, coverage |
| `instructions/basecoat-10-core-reliability.instructions.md`   | resilience, failure modes, basecoat-10-core-observability              | reliability, retry, timeout, logging, resilience                   |
| `instructions/basecoat-50-security-security.instructions.md`      | secure coding, auth boundaries, secret handling       | security, auth, secrets, validation, unsafe                        |
| `instructions/basecoat-10-core-session-hygiene.instructions.md` | clean session context management for basecoat-10-core-agents | session, hygiene, context, cleanup, state |
| `instructions/basecoat-30-ai-tailwind-v4.instructions.md`   | Tailwind CSS v4 patterns and migration | tailwind, css, v4, utility, design-system |
| `instructions/basecoat-10-core-terraform.instructions.md`     | basecoat-10-core-terraform authoring for basecoat-40-azure-azure and shared IaC          | terraform, azurerm, modules, providers, state                      |
| `instructions/basecoat-10-core-testing.instructions.md`       | test expectations with positive and negative coverage | tests, unit test, integration test, regression, positive, negative |
| `instructions/basecoat-50-security-token-economics.instructions.md` | token budget awareness and cost-conscious model usage | token, economics, budget, cost, model, optimization |
| `instructions/basecoat-10-core-tool-minimization.instructions.md` | reduce unnecessary tool calls for efficiency | tool, minimization, efficiency, calls, overhead |
| `instructions/basecoat-10-core-ux.instructions.md`            | UX, accessibility, and design-system guidance | ux, accessibility, design, wcag |
| `instructions/basecoat-10-core-verification.instructions.md`  | verification-driven basecoat-10-core-development — test-first workflow | verification, tdd, test-first, validation |
| `instructions/basecoat-30-ai-ai-verification.instructions.md` | risk-tiered basecoat-10-core-verification protocol for AI-generated code | ai, verification, risk, trust, basecoat-90-quality-code-review |
| `instructions/basecoat-10-core-bootstrap-autodetect.instructions.md` | auto-detect values in bootstrap scripts without interactive prompts | bootstrap, autodetect, scripting, automation |
| `instructions/basecoat-50-security-bootstrap-github-secrets.instructions.md` | provision identity and GitHub Actions secrets in bootstrap scripts | bootstrap, secrets, github-actions, ci-cd |
| `instructions/basecoat-10-core-bootstrap-structure.instructions.md` | decomposition, idempotency, and cross-platform requirements for bootstrap scripts | bootstrap, structure, idempotency, cross-platform |
| `instructions/basecoat-60-workflow-ci-firewall.instructions.md`   | GitHub Actions workflows accessing firewalled basecoat-40-azure-azure resources with single-job runner IP | ci, firewall, azure, github-actions |
| `instructions/basecoat-10-core-cpp.instructions.md`           | memory safety, concurrency, undefined behavior, and sanitizer validation for C++ | cpp, c++, memory-safety, concurrency, sanitizers |
| `instructions/basecoat-10-core-data-workload-testing.instructions.md` | medallion pattern basecoat-10-core-testing and data basecoat-90-quality-quality validation for bronze/silver/gold layers | data, medallion, testing, bronze, silver, gold |
| `instructions/basecoat-20-lang-dotnet-dependency-analysis.instructions.md` | .NET dependency compatibility and remediation analysis | dotnet, dependency, compatibility, analysis |
| `instructions/basecoat-20-lang-dotnet-test-strategy.instructions.md` | .NET modernization test strategy and regression-gate guidance | dotnet, testing, modernization, regression |
| `instructions/basecoat-20-lang-dotnet-upgrade-planning.instructions.md` | phased .NET upgrade planning checklist and execution guidance | dotnet, upgrade, planning, migration |
| `instructions/basecoat-10-core-electron.instructions.md`      | secure basecoat-10-core-electron desktop apps: IPC, CSP, code signing, auto-updates, credential storage | electron, desktop, security, csp, signing |
| `instructions/basecoat-10-core-enterprise-configuration.instructions.md` | GitHub Copilot enterprise policy configuration, seat management, basecoat-50-security-security policies | enterprise, copilot, policy, configuration |
| `instructions/basecoat-10-core-fabric-notebooks.instructions.md` | Microsoft Fabric notebooks CI/CD, lakehouse integration, and production basecoat-20-lang-governance | fabric, notebooks, lakehouse, ci-cd |
| `instructions/basecoat-10-core-monolith.instructions.md`      | context scoping, dependency awareness, and safe decomposition for large basecoat-10-core-monolith codebases | monolith, decomposition, context, dependencies |
| `instructions/basecoat-10-core-mutation-testing.instructions.md` | mutation basecoat-10-core-testing standards for verifying test basecoat-90-quality-quality and mutation score interpretation | mutation, testing, quality, coverage |
| `instructions/basecoat-10-core-observability.instructions.md` | OpenTelemetry instrumentation, trace propagation, structured logging, metrics, and dashboards | observability, opentelemetry, tracing, metrics, logging |
| `instructions/basecoat-20-lang-python.instructions.md`        | basecoat-20-lang-python conventions for data science, ML pipelines, pandas, scikit-learn, DuckDB, Jupyter | python, data-science, ml, pandas, jupyter |
| `instructions/basecoat-50-security-rbac-authentication.instructions.md` | RBAC-only basecoat-40-azure-azure authentication — no shared keys, SAS tokens, or connection strings | rbac, azure, authentication, security, managed-identity |
| `instructions/basecoat-10-core-rest-client-resilience.instructions.md` | timeouts, retries, 429 handling, circuit breakers, and structured failure logging for HTTP clients | rest, resilience, retry, circuit-breaker, http |
| `instructions/basecoat-10-core-runtime-debugging.instructions.md` | AI-assisted debugging using crash dumps, logs, memory state, and production telemetry | debugging, runtime, crash-dump, telemetry, logs |
| `instructions/basecoat-50-security-secrets-management.instructions.md` | never commit secrets, use Vault solutions, implement rotation, and audit access | secrets, vault, rotation, audit, basecoat-50-security-security |
| `instructions/basecoat-50-security-security-monitoring.instructions.md` | SIEM integration, alert configuration, detection rules, and incident escalation | security, siem, monitoring, alerts, detection |
| `instructions/basecoat-10-core-terraform-init.instructions.md` | basecoat-10-core-terraform init in bootstrap scripts and CI/CD pipelines without blocking automation | terraform, init, bootstrap, ci-cd |

## Skills

| File                                    | Use For                                                 | Keywords                                     |
| --------------------------------------- | ------------------------------------------------------- | -------------------------------------------- |
| `skills/agent-design/SKILL.md`          | agent, instruction, and skill authoring templates | agent, design, authoring, template |
| `skills/api-design/SKILL.md`            | OpenAPI spec, API governance, and versioning templates | api, openapi, governance, versioning |
| `skills/api-security/SKILL.md`          | API authentication, authorization, input validation, and rate limiting patterns | skill, api-security, owasp, authentication |
| `skills/app-inventory/SKILL.md`         | legacy app inventory reports and complexity scoring | inventory, legacy, scanning, complexity |
| `skills/architecture/SKILL.md`          | ADR, C4 diagram, and tech selection templates | architecture, adr, c4, diagram, tech-selection |
| `skills/azure-container-apps/SKILL.md`  | deploy, scale, and manage containers on basecoat-40-azure-azure Container Apps with managed identity, health probes, and traffic splitting | azure, container apps, aca, ingress, scale, revision, health probes, managed identity |
| `skills/azure-devops-rest/SKILL.md`     | basecoat-40-azure-azure DevOps REST API patterns — auth, scopes, pagination, and endpoint taxonomy | skill, azure-devops, rest-api, authentication |
| `skills/azure-identity/SKILL.md`        | design RBAC hierarchies, managed identities, app registrations, conditional access, and workload identity federation | azure, identity, rbac, managed identity, entra, zero trust, oidc |
| `skills/azure-landing-zone/SKILL.md`    | enterprise-scale landing zone scaffolding with basecoat-10-core-bicep templates | azure, landing-zone, eslz, caf, basecoat-10-core-bicep |
| `skills/azure-networking/SKILL.md`      | design basecoat-40-azure-azure hub-spoke topologies, private endpoints, DNS zones, NSG rules, and firewall policies | azure, networking, hub-spoke, vnet, private endpoint, dns, nsg, firewall, cidr, udr |
| `skills/azure-policy/SKILL.md`          | author custom basecoat-40-azure-azure Policy definitions, initiatives, remediation tasks, and compliance KQL queries | basecoat-40-azure-azure policy, governance, compliance, initiative, remediation, KQL, CIS, NIST, ISO 27001 |
| `skills/azure-waf-review/SKILL.md`      | assess basecoat-40-azure-azure workloads against the five WAF pillars and produce scored findings with remediation templates | azure, well-architected, WAF, reliability, security, cost, performance, operations |
| `skills/backend-dev/SKILL.md`           | design and implement APIs, service layers, and data access repositories | backend, api, service, repository, error catalog                     |
| `skills/basecoat/SKILL.md`              | /basecoat router — discovery and delegation entry point | basecoat, router, discovery, delegation |
| `skills/code-review/SKILL.md`           | review changes for risk, regressions, and missing tests | review, bug risk, regression, findings       |
| `skills/contract-testing/SKILL.md`      | Consumer-driven contracts, Pact, E2E testing, and mutation basecoat-10-core-testing patterns | skill, contract-testing, pact, cdc |
| `skills/copilot-usage-analytics/SKILL.md` | Per-session Copilot CLI cost estimation and basecoat-10-core-model-routing efficiency analysis | skill, copilot, usage, analytics |
| `skills/cqrs-event-sourcing/SKILL.md`   | CQRS and Event Sourcing for scalable, auditable distributed systems patterns | skill, cqrs, event-sourcing, distributed |
| `skills/create-instruction/SKILL.md`    | create a new instruction file for a domain              | create instruction, applyTo, frontmatter     |
| `skills/create-skill/SKILL.md`          | create a new reusable skill with proper frontmatter     | create skill, skill template, customization  |
| `skills/data-tier/SKILL.md`             | design schemas, write migrations, review queries, build data dictionaries | data, schema, migration, query, indexing                            |
| `skills/database-migration/SKILL.md`    | Zero-downtime database migrations, blue-green deployments, and rollback | skill, database-migration, zero-downtime, rollback |
| `skills/dev-containers/SKILL.md`        | VS Code Dev Containers for reproducible dev environments and Codespaces setup | skill, dev-containers, codespaces, reproducible |
| `skills/devops/SKILL.md`                | CI/CD pipeline, deployment, and rollback templates | devops, cicd, deployment, rollback, github-actions |
| `skills/documentation/SKILL.md`         | README, runbook, and ADR templates | documentation, readme, runbook, adr |
| `skills/domain-driven-design/SKILL.md`  | Aggregate patterns, bounded contexts, CQRS, and distributed systems design | skill, ddd, bounded-context, aggregates |
| `skills/dotnet-modernization/SKILL.md`  | Structured guidance for .NET modernization from assessment through execution | skill, dotnet, modernization, upgrade |
| `skills/e2e-testing/SKILL.md`           | Production E2E basecoat-10-core-testing with Playwright and Cypress, flakiness prevention, CI/CD | skill, e2e-testing, playwright, cypress |
| `skills/electron-apps/SKILL.md`         | Build secure basecoat-10-core-electron desktop apps with IPC, CSP, packaging, and auto-updates | skill, electron, desktop, basecoat-50-security-security |
| `skills/entity-framework-migration/SKILL.md` | Migrate Entity Framework legacy codebases to modern EF Core patterns | skill, entity-framework, ef-core, migration |
| `skills/environment-bootstrap/SKILL.md` | environment setup and bootstrap configuration | environment, bootstrap, setup, configuration |
| `skills/frontend-dev/SKILL.md`          | build accessible, responsive UI components and manage client state       | frontend, ui, component, accessibility, state management             |
| `skills/gitops/SKILL.md`               | GitOps with Flux/ArgoCD, desired-state reconciliation, multi-cluster topology | skill, gitops, flux, argocd |
| `skills/ha-resilience/SKILL.md`        | Multi-AZ/region architectures, circuit breakers, and SRE chaos practices | skill, high-availability, resilience, chaos-basecoat-10-core-testing |
| `skills/handoff/SKILL.md`               | structured agent-to-agent handoff protocols | handoff, agent, protocol, transition |
| `skills/human-in-the-loop/SKILL.md`     | human approval gates and intervention patterns | human, approval, gate, intervention, review |
| `skills/identity-migration/SKILL.md`    | identity and authentication migration patterns | identity, migration, auth, entra, modernization |
| `skills/manual-test-strategy/SKILL.md`  | define manual scope, produce charters, checklists, and handoff artifacts | manual testing, exploratory, charter, regression, defect, automation handoff |
| `skills/mcp-development/SKILL.md`       | basecoat-10-core-mcp server, tool definition, and transport templates | mcp, server, tool, transport, integration |
| `skills/observability/SKILL.md`         | Guidance for instrumentation, telemetry design, and operational visibility | skill, observability, instrumentation, telemetry |
| `skills/penetration-testing/SKILL.md`   | OWASP Top 10 coverage, exploitation techniques, and finding reporting patterns | skill, penetration-testing, owasp, vulnerability |
| `skills/performance-profiling/SKILL.md` | isolate and measure slow code paths                     | profiling, performance, latency, hot path    |
| `skills/production-readiness/SKILL.md`  | PRR gates, business continuity planning, disaster recovery, and FMEA templates | skill, production-readiness, bcp, drp |
| `skills/refactoring/SKILL.md`           | restructure code without changing behavior              | refactor, cleanup, simplify, extract, rename |
| `skills/security/SKILL.md`              | OWASP checklist, STRIDE threat model, and vulnerability templates | security, owasp, stride, threat-model, vulnerability |
| `skills/security-operations/SKILL.md`   | Threat detection, SIEM rules, and incident response automation patterns | skill, security-operations, siem, detection |
| `skills/github-security-posture/SKILL.md` | audit GitHub org and repo basecoat-50-security-security configurations with traffic-light scoring and remediation commands | github, security, posture, audit, rulesets, secret-scanning, dependabot, branch-protection, codeowners |
| `skills/service-bus-migration/SKILL.md` | basecoat-40-azure-azure Service Bus migration patterns and guidance | service-bus, migration, messaging, basecoat-40-azure-azure |
| `skills/sprint-management/SKILL.md`     | sprint planning, backlog grooming, and retrospective templates | sprint, planning, backlog, retrospective |
| `skills/sprint-retrospective/SKILL.md`  | repo history reconstruction and sprint retrospective templates | sprint, retrospective, history, metrics, tips |
| `skills/supply-chain-security/SKILL.md` | Artifact signing, SBOM generation, provenance tracking, and vuln scanning | skill, supply-chain, sbom, signing |
| `skills/tech-debt/SKILL.md`             | Technical debt management, RICE prioritization, debt budgets, and visualization | skill, tech-debt, prioritization, rice |
| `skills/twelve-factor/SKILL.md`         | 12-Factor App methodology for codebase, config, backing services, and processes | skill, twelve-factor, methodology, cloud-native |
| `skills/ux/SKILL.md`                    | user journey, wireframe, and accessibility audit templates | ux, journey, wireframe, accessibility, audit |

## Prompts

| File                            | Use For                                              | Keywords                              |
| ------------------------------- | ---------------------------------------------------- | ------------------------------------- |
| `prompts/architect.prompt.md`   | break down a system or feature before implementation | architecture, design, tradeoffs, plan |
| `prompts/code-review.prompt.md` | initiate a focused code review workflow              | review, pull request, findings        |
| `prompts/bugfix.prompt.md`      | investigate and fix a bug at the root cause          | bugfix, incident, regression, failure |

### Portal Prompts

> Portal-specific prompts live in `portal/prompts/` and are not synced to consumer repos.

| File                                                           | Use For                                                       | Keywords                                       |
| -------------------------------------------------------------- | ------------------------------------------------------------- | ---------------------------------------------- |
| `portal/prompts/portal-audit-risk-analysis.prompt.md`         | analyze audit findings and surface risk themes                | audit, risk, compliance, portal                |
| `portal/prompts/portal-compliance-mapping.prompt.md`          | map controls to compliance frameworks (SOC 2, GDPR, HIPAA)   | compliance, mapping, controls, portal          |
| `portal/prompts/portal-plain-language.prompt.md`              | rewrite technical content in plain language                   | plain-language, accessibility, portal          |
| `portal/prompts/portal-remediation-planning.prompt.md`        | create a prioritized remediation plan from audit results      | remediation, planning, priority, portal        |
| `portal/prompts/portal-threat-analysis.prompt.md`             | perform threat analysis using STRIDE / OWASP                  | threat, analysis, stride, owasp, basecoat-50-security-security      |

## basecoat-10-core-agents

| File                                | Use For                                        | Keywords                                  |
| ----------------------------------- | ---------------------------------------------- | ----------------------------------------- |
| `agents/basecoat-10-core-agent-designer.agent.md`        | design and author Copilot agent definitions | agent, design, authoring, copilot |
| `agents/basecoat-10-core-agentops.agent.md`          | manage agent lifecycle, versioning, rollout health, rollback, and retirement | agent, operations, versioning, canary, blue-green, rollback, telemetry |
| `agents/basecoat-10-core-api-designer.agent.md`      | API design for OpenAPI, REST, GraphQL, and basecoat-20-lang-governance | agent, api, openapi, rest, graphql, versioning |
| `agents/basecoat-50-security-api-security.agent.md`      | API threat modeling, OWASP API basecoat-50-security-security Top 10 assessment, and secure API design | agent, api-security, owasp, threat-modeling |
| `agents/basecoat-10-core-app-inventory.agent.md` | scan legacy apps for project files, NuGet/npm/maven packages, connection strings, external services, framework versions, and migration complexity scores | agent, inventory, legacy, migration, dependencies, csproj, packages, scanning |
| `agents/basecoat-40-azure-azure-landing-zone.agent.md` | scaffold enterprise-scale basecoat-40-azure-azure landing zones following CAF/ESLZ | agent, azure, landing-zone, eslz, caf, bicep, terraform, management-groups, hub-networking, policy |
| `agents/basecoat-10-core-backend-dev.agent.md`           | design and implement APIs, service layers, and data access patterns    | agent, backend, api, service, rest, graphql, repository, error handling |
| `agents/basecoat-10-core-chaos-engineer.agent.md`    | fault injection, game days, resilience scoring, and recovery validation | agent, chaos, resilience, fault-injection, game-day |
| `agents/basecoat-90-quality-code-review.agent.md`       | multi-step repository review basecoat-10-core-process           | agent, review, repo scan, risk            |
| `agents/basecoat-50-security-config-auditor.agent.md`    | scan for committed or unprotected basecoat-10-core-config secrets | agent, config, secrets, audit, basecoat-50-security-security |
| `agents/basecoat-50-security-container-security.agent.md` | Container and Kubernetes basecoat-50-security-security — Pod basecoat-50-security-security Standards and runtime basecoat-50-security-security | agent, container, kubernetes, basecoat-50-security-security |
| `agents/basecoat-30-ai-containerization-planner.agent.md` | containerization readiness assessment and deployment configuration | agent, container, docker, kubernetes, migration |
| `agents/basecoat-10-core-contract-testing.agent.md`  | Consumer-driven contracts, E2E basecoat-10-core-testing strategy, and mutation basecoat-10-core-testing | agent, contract-testing, cdc, integration |
| `agents/basecoat-80-data-data-architect.agent.md`    | Design scalable data architectures, medallion layers, governance, and ETL workflows | agent, data-architecture, medallion, basecoat-20-lang-governance |
| `agents/basecoat-80-data-data-integrity.agent.md`    | Distributed data integrity — eventual consistency, ACID compliance, and recovery | agent, data-integrity, consistency, recovery |
| `agents/basecoat-80-data-data-tier.agent.md`             | design schemas, write migrations, optimize queries, and define data access | agent, data, schema, migration, query, indexing, repository         |
| `agents/basecoat-60-workflow-data-pipeline.agent.md`     | medallion lakehouse pipelines (bronze/silver/gold), data basecoat-90-quality-quality gates, feature store integration, and ML pipeline orchestration | agent, data-pipeline, medallion, bronze, silver, gold, delta-lake, feature-store, ml-pipeline, notebook |
| `agents/basecoat-80-data-database-migration.agent.md` | Database migrations: schema evolution, zero-downtime upgrades, and modernization | agent, database-migration, schema, zero-downtime |
| `agents/basecoat-80-data-dataops.agent.md`           | data quality, lineage, governance, orchestration, and drift detection | agent, data, quality, lineage, governance, pipeline |
| `agents/basecoat-10-core-dependency-lifecycle.agent.md` | dependency updates, breaking changes, upgrade paths, and migration guides | agent, dependency, update, upgrade, breaking-change |
| `agents/basecoat-10-core-devops-engineer.agent.md`   | CI/CD, IaC, deployment, rollback, and basecoat-10-core-observability | agent, devops, cicd, iac, deployment, basecoat-10-core-observability |
| `agents/basecoat-30-ai-domain-designer.agent.md`   | Domain-Driven Design: bounded contexts, aggregate design, and DDD patterns | agent, ddd, bounded-context, aggregates |
| `agents/basecoat-20-lang-dotnet-modernization-advisor.agent.md` | .NET modernization assessment, upgrade planning, and execution guidance | agent, dotnet, modernization, upgrade |
| `agents/basecoat-90-quality-e2e-test-strategy.agent.md` | E2E basecoat-10-core-testing orchestration, critical paths, and flakiness prevention | agent, e2e-testing, playwright, cypress |
| `agents/basecoat-10-core-exploratory-charter.agent.md`   | generate time-boxed exploratory sessions with scope, evidence capture, and GitHub Issue filing              | agent, exploratory, charter, session, findings |
| `agents/basecoat-10-core-feedback-loop.agent.md`     | user feedback collection, prompt effectiveness tracking, and A/B basecoat-10-core-testing | agent, feedback, effectiveness, tracking, a-b-basecoat-10-core-testing |
| `agents/basecoat-10-core-finops-advisor.agent.md`    | FinOps advisor for cloud cost governance, optimization, and chargeback/showback | agent, finops, cost-optimization, cloud-cost |
| `agents/basecoat-10-core-frontend-dev.agent.md`          | build accessible component-driven UIs with Core Web Vitals targets     | agent, frontend, ui, component, accessibility, wcag, state, performance |
| `agents/basecoat-50-security-github-security-posture.agent.md` | audit GitHub org and repo basecoat-50-security-security settings: code basecoat-50-security-security configs, rulesets, secret scanning, Dependabot alerts, and branch protection | agent, security, github, posture, audit, rulesets, secret-scanning, dependabot, branch-protection |
| `agents/basecoat-10-core-gitops-engineer.agent.md`   | Design GitOps workflows for IaC, declarative config, and automated deployment | agent, gitops, argo-cd, flbasecoat-10-core-ux |
| `agents/basecoat-30-ai-guardrail.agent.md`         | validate outputs against safety, quality, compliance, and formatting rules before delivery | agent, guardrail, validation, safety, compliance, basecoat-90-quality-quality |
| `agents/basecoat-10-core-ha-architect.agent.md`      | Design high-availability, resilience, and chaos basecoat-10-core-testing for distributed systems | agent, high-availability, resilience, disaster-recovery |
| `agents/basecoat-10-core-hardening-advisor.agent.md` | CIS Benchmarks and STIG hardening for Dockerfiles and Kubernetes manifests | agent, hardening, cis, stig |
| `agents/basecoat-10-core-identity-architect.agent.md` | basecoat-40-azure-azure RBAC, managed identities, Entra ID app registrations, conditional access, and workload identity federation | agent, identity, rbac, entra, managed-identity, zero-trust |
| `agents/basecoat-60-workflow-incident-responder.agent.md` | incident classification, mitigation, communications, and post-incident learning | agent, incident, response, mitigation, postmortem |
| `agents/basecoat-60-workflow-infrastructure-deploy.agent.md` | basecoat-40-azure-azure infrastructure deployments using basecoat-10-core-bicep with rollback strategies | agent, infrastructure, deploy, bicep, basecoat-40-azure-azure |
| `agents/basecoat-10-core-issue-triage.agent.md`      | triage, classify, label, and prioritize GitHub issues | agent, triage, issues, labels, prioritization |
| `agents/basecoat-10-core-legacy-modernization.agent.md` | guide Web Forms to Razor Pages migration using the strangler fig pattern for incremental modernization | agent, legacy, modernization, web forms, razor pages, strangler fig, migration |
| `agents/basecoat-10-core-llmops.agent.md`            | prompt deployment pipelines, model gateway configuration, and inference monitoring | agent, llm, inference, gateway, prompt-deployment |
| `agents/basecoat-90-quality-manual-test-strategy.agent.md`  | produce a full manual test strategy with rubric, charter, checklist, defect template, and automation backlog | agent, manual testing, strategy, exploratory, automation candidate |
| `agents/basecoat-10-core-mcp-developer.agent.md`     | basecoat-10-core-mcp servers, tools, and integrations | agent, mcp, tools, server, integration |
| `agents/basecoat-10-core-memory-curator.agent.md`    | cross-session knowledge extraction, deduplication, and retrieval | agent, memory, knowledge, cross-session, curation |
| `agents/basecoat-10-core-merge-coordinator.agent.md` | merge multiple feature branches into a target without interactive git editor hangs | agent, merge, conflict, parallel, branches, rebase, no-edit |
| `agents/basecoat-10-core-middleware-dev.agent.md`        | design integration layers, message contracts, and resilience patterns   | agent, middleware, integration, message, event-driven, circuit breaker, retry |
| `agents/basecoat-30-ai-mlops.agent.md`             | model lifecycle, experiment tracking, deployment automation, and drift monitoring | agent, mlops, model, experiment, deployment, drift |
| `agents/basecoat-10-core-new-customization.agent.md` | choose and create the right customization type | agent, customization, instruction, prompt |
| `agents/basecoat-10-core-observability-engineer.agent.md` | OpenTelemetry instrumentation, distributed tracing, and metrics taxonomy | agent, observability, opentelemetry, tracing |
| `agents/basecoat-90-quality-penetration-test.agent.md`  | basecoat-50-security-security assessments, vulnerability discovery, and remediation workflows (OWASP) | agent, penetration-testing, vulnerability, owasp |
| `agents/basecoat-10-core-performance-analyst.agent.md` | profiling, load testing, and performance optimization | agent, performance, profiling, load-test, optimization |
| `agents/basecoat-50-security-policy-as-code-compliance.agent.md` | validate policy-as-code rules, automated compliance checks, exceptions, and audit-ready evidence | agent, compliance, policy-as-code, governance, audit, exceptions |
| `agents/basecoat-10-core-product-manager.agent.md`   | requirements, user stories, acceptance criteria, roadmaps | agent, product, requirements, stories, roadmap |
| `agents/basecoat-10-core-production-readiness.agent.md` | Ensure apps meet operational requirements before release; coordinates BCP/DRP | agent, production-readiness, bcp, drp |
| `agents/basecoat-10-core-project-onboarding.agent.md` | Base Coat repository onboarding and setup | agent, onboarding, bootstrap, setup |
| `agents/basecoat-10-core-prompt-coach.agent.md` | iteratively score, critique, and improve prompts through coaching and revision comparison | agent, prompt, coaching, scoring, critique, token efficiency, iteration |
| `agents/basecoat-10-core-prompt-engineer.agent.md`   | prompt and system-prompt optimization | agent, prompt, optimization, system-prompt |
| `agents/basecoat-60-workflow-release-impact-advisor.agent.md` | release readiness assessment, blast radius analysis, and rollback planning | agent, release, impact, readiness, rollback |
| `agents/basecoat-60-workflow-release-manager.agent.md`   | versioned release workflow, changelog, tagging, and publishing | agent, release, version, changelog, tag |
| `agents/basecoat-90-quality-resilience-reviewer.agent.md` | Code-level resilience: circuit breakers, timeouts, bulkhead, and retry logic | agent, resilience, circuit-breaker, retry |
| `agents/basecoat-60-workflow-retro-facilitator.agent.md` | sprint retrospective summary and improvement issue creation | agent, retro, sprint, retrospective, improvement |
| `agents/basecoat-60-workflow-rollout-basecoat.agent.md`  | onboard a repo to a pinned Base Coat release   | agent, rollout, bootstrap, enterprise     |
| `agents/basecoat-50-security-secrets-manager.agent.md`   | Secrets lifecycle: discovery, rotation, expiry scanning, and Vault patterns | agent, secrets, rotation, vault |
| `agents/basecoat-50-security-security-analyst.agent.md`  | vulnerability assessment, threat modeling, secure code review | agent, security, vulnerability, threat-model |
| `agents/basecoat-50-security-security-monitor.agent.md`  | Detection engineering and SIEM config; maps MITRE ATT&CK to detection rules | agent, security-monitor, siem, detection |
| `agents/basecoat-50-security-security-operations.agent.md` | SOC playbook for threat detection, incident response, and operational basecoat-50-security-security | agent, soc, threat-detection, incident-response |
| `agents/basecoat-60-workflow-self-healing-ci.agent.md`   | CI failure analysis, log parsing, flaky test detection, and pipeline remediation | agent, ci, failure, flaky-test, remediation |
| `agents/basecoat-10-core-solution-architect.agent.md` | system design, C4 diagrams, ADRs, and technology selection | agent, architecture, c4, adr, design |
| `agents/basecoat-10-core-sprint-planner.agent.md`    | sprint goal-to-issues breakdown and wave planning | agent, sprint, planning, issues, waves |
| `agents/basecoat-10-core-sprint-retrospective.agent.md` | reconstruct repo history for sprint retrospectives with metrics and tips | agent, sprint, retrospective, history, metrics |
| `agents/basecoat-10-core-sre-engineer.agent.md`      | SLOs, error budgets, incident response, chaos engineering, and toil reduction | agent, sre, slo, error-budget, toil |
| `agents/basecoat-10-core-strategy-to-automation.agent.md`| convert manual paths into tiered automation candidates and file GitHub Issues for every one                | agent, automation, smoke, regression, integration, candidate |
| `agents/basecoat-50-security-supply-chain-security.agent.md` | Secure software supply chain with artifact signing, SBOM, and provenance tracking | agent, supply-chain, sbom, signing |
| `agents/basecoat-10-core-tech-writer.agent.md`       | technical docs, runbooks, tutorials, and changelogs | agent, docs, runbook, tutorial, changelog |
| `agents/basecoat-10-core-ux-designer.agent.md`       | journey mapping, wireframes, and accessibility audits | agent, ux, journey, wireframe, accessibility |

## basecoat-10-core-documentation Assets

| File                                      | Use For                                                         | Keywords                                 |
| ----------------------------------------- | --------------------------------------------------------------- | ---------------------------------------- |
| `docs/documentation-heading-scaffolds.md` | shared heading templates for common basecoat-10-core-documentation types         | docs, headings, template, scaffold       |
| `docs/prd-and-spec-guidance.md`           | guidance and templates for PRDs and technical specs             | prd, spec, requirements, design          |
| `docs/repo-template-standard.md`          | standard for bootstrapping and enforcing Base Coat in templates | template, governance, drift, enforcement |
| `docs/MULTI_AGENT_WORKFLOWS.md`           | structure parallel agent sprints to minimize merge conflicts; branch naming; merge order; fresh clone principle | multi-agent, parallel, sprint, merge, conflict, branch |
| `docs/app-inventory.md`                   | conceptual guide for legacy app scanning: parameters, complexity scoring, output formats, and downstream integration | inventory, legacy, scanning, dependencies, complexity, migration |
| `docs/treatment-matrix.md`                | decision framework mapping complexity scores and strategic value to Retire/Rehost/Replatform/Refactor/Rebuild/Replace treatment paths | treatment, migration, retire, rehost, replatform, refactor, rebuild, replace |

## Operational Assets

| File                                                                       | Use For                                                     | Keywords                               |
| -------------------------------------------------------------------------- | ----------------------------------------------------------- | -------------------------------------- |
| `scripts/validate-basecoat.sh`                                             | local and CI validation on macOS and Linbasecoat-10-core-ux                  | validate, bash, ci, frontmatter        |
| `scripts/validate-basecoat.ps1`                                            | local and CI validation on Windows                          | validate, powershell, ci, frontmatter  |
| `scripts/install-git-hooks.sh`                                             | configure local git hooks for basecoat-30-ai-guardrail enforcement         | hooks, git, security, pre-commit       |
| `scripts/install-git-hooks.ps1`                                            | configure local git hooks for basecoat-30-ai-guardrail enforcement         | hooks, git, security, pre-commit       |
| `scripts/scan-commit-messages.sh`                                          | scan commit messages for secrets and PII patterns           | commit-msg, security, secrets, pii     |
| `.githooks/commit-msg`                                                     | block commits when message contains sensitive data          | hook, commit-msg, security, pii        |
| `scripts/package-basecoat.sh`                                              | create release artifacts on macOS and Linbasecoat-10-core-ux                 | package, tar.gz, zip, checksum         |
| `scripts/package-basecoat.ps1`                                             | create release artifacts on Windows                         | package, zip, checksum, powershell     |
| `scripts/audit-assets.ps1`                                                 | basecoat-90-quality-quality scoring rubric for all assets; outputs table/markdown/JSON; grades A–F; max 10 pts per asset | audit, quality, scoring, grade, powershell |
| `scripts/check-coherence.ps1`                                              | cross-asset conflict detection: orphaned skill refs, keyword contradictions, scope overlaps, deprecated refs, duplicate descriptions; non-blocking CI warning | coherence, conflict, orphaned, contradiction, powershell |
| `scripts/adoption/detect-basecoat.ps1`                                     | per-repo adoption detection; `-AssetDetail` flag enables per-asset adoption rate across consumer repos | adoption, detect, consumer, asset-detail, powershell |
| `.github/workflows/validate-basecoat.yml`                                  | validate repo structure on push and pull request            | workflow, ci, validation               |
| `.github/workflows/validate-repo-template-sample.yml`                      | validate sample repository template assets and contracts    | workflow, template, governance, ci     |
| `.github/workflows/prd-spec-gate.yml`                                      | enforce PRD/spec references on risky or large pull requests | workflow, prd, spec, basecoat-20-lang-governance        |
| `.github/workflows/asset-health.yml`                                       | weekly Monday 08:00 UTC health report; posts to GitHub Step Summary; opens issue if any asset grades F | workflow, health, weekly, grade, issue |
| `.github/workflows/package-basecoat.yml`                                   | package and publish release artifacts                       | workflow, release, package, artifact   |
| `.github/workflows/stale-asset-alerts.yml`                                 | alert consumer repos when their synced BaseCoat assets go stale after a new release; opens issues in stale consumer repos on tag push | workflow, alerts, consumer, stale, drift, release |
| `.github/PULL_REQUEST_TEMPLATE.md`                                         | pull request template with PRD/spec reference fields        | pull request, template, prd, spec      |
| `examples/workflows/bootstrap-from-release.yml`                            | install a pinned Base Coat release into a new repo          | workflow, bootstrap, pinned release    |
| `examples/workflows/validate-basecoat-consumer.yml`                        | validate a consumer repo keeps Base Coat present            | workflow, consumer, drift, validation  |
| `examples/repo-template/.github/base-coat.lock.json`                       | lock file contract for template-based Base Coat pinning     | template, lock, pinned version         |
| `examples/repo-template/.github/workflows/bootstrap-basecoat-template.yml` | bootstrap Base Coat in a new repo from lock file            | template, bootstrap, release, checksum |
| `examples/repo-template/.github/workflows/enforce-basecoat-template.yml`   | enforce lock/version consistency and block unsafe drift     | template, enforcement, drift, policy   |

## Test Assets

| File                  | Use For                                                                                      | Keywords                           |
| --------------------- | -------------------------------------------------------------------------------------------- | ---------------------------------- |
| `tests/run-tests.ps1`          | smoke tests for validation, packaging, hooks, and commit-message scanning on Windows         | test, powershell, smoke, packaging |
| `tests/run-tests.sh`           | smoke tests for validation, packaging, hooks, and commit-message scanning on macOS and Linbasecoat-10-core-ux | test, bash, smoke, packaging       |
| `tests/quality-gate-tests.ps1` | CI-blocking basecoat-90-quality-quality gate: enforces avg score ≥ 5.0, red% ≤ 50%, no zero-score assets, all category avgs ≥ 4.0 | test, quality-gate, ci, powershell, scoring |
| `tests/README.md`              | test suite scope and execution commands                                                      | tests, docs, usage                 |
