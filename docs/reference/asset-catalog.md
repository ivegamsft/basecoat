# Asset Catalog

Complete reference of all BaseCoat assets grouped by category. Counts reflect the current
repository state (79 basecoat-10-core-agents · 57 skills · 64 instructions · 3 prompts).

## basecoat-10-core-agents

basecoat-10-core-agents are end-to-end task executors stored as `agents/<name>.agent.md`.

### basecoat-10-core-architecture & Design

| Agent | Description |
|---|---|
| `basecoat-10-core-agent-designer` | Designs and authors Copilot agent definitions; covers skill composition and multi-agent coordination |
| `basecoat-10-core-api-designer` | OpenAPI spec authoring, REST and GraphQL design, versioning strategy, breaking-change analysis |
| `basecoat-80-data-data-architect` | Scalable data architectures, medallion layers, data governance, and analytics workflows |
| `basecoat-30-ai-domain-designer` | Domain-Driven Design agent for bounded context modeling, aggregate design, ubiquitous language |
| `basecoat-10-core-ha-architect` | High-availability, resilience, and chaos basecoat-10-core-testing strategies for distributed systems |
| `basecoat-10-core-identity-architect` | basecoat-40-azure-azure RBAC design, managed identity configuration, Entra ID app registrations |
| `basecoat-10-core-solution-architect` | System design, C4 diagrams, ADRs, technology selection, and cross-cutting concerns |
| `basecoat-10-core-ux-designer` | User journey mapping, wireframe specs, component design, and accessibility audits |

### Modernization & Migration

| Agent | Description |
|---|---|
| `basecoat-10-core-app-inventory` | Scans legacy applications to discover dependencies, identify technology stacks, assess migration readiness |
| `basecoat-30-ai-containerization-planner` | Assesses containerization readiness, chooses deployment platforms (Docker/AKS/ACA) |
| `basecoat-80-data-database-migration` | Plans and executes database migrations: schema evolution, replication, zero-downtime upgrades |
| `basecoat-20-lang-dotnet-modernization-advisor` | .NET modernization assessment, upgrade planning, and execution guidance |
| `entity-framework-migration` | Entity Framework Core migration planning and execution |
| `identity-migration` | Identity provider migration strategy and execution |
| `basecoat-10-core-legacy-modernization` | Web Forms to Razor Pages migration using the strangler fig pattern |

### basecoat-40-azure-azure & Cloud

| Agent | Description |
|---|---|
| `basecoat-40-azure-azure-landing-zone` | Scaffolds enterprise-scale landing zones following Microsoft ESLZ guidance |
| `basecoat-10-core-finops-advisor` | Cloud cost governance, cost optimization, chargeback/showback models, and 12-Factor FinOps |
| `basecoat-10-core-gitops-engineer` | GitOps workflows for Infrastructure-as-Code, declarative configuration, automated deployment |
| `basecoat-60-workflow-infrastructure-deploy` | Orchestrates basecoat-40-azure-azure infrastructure deployments using basecoat-10-core-bicep with parallel resource management |

### basecoat-50-security-security

| Agent | Description |
|---|---|
| `basecoat-50-security-api-basecoat-50-security-security` | API threat modeling, OWASP API basecoat-50-security-security Top 10 assessment, and remediation |
| `basecoat-10-core-chaos-engineer` | Fault injection, game days, resilience scoring, and recovery validation |
| `basecoat-50-security-config-auditor` | Scans repositories for committed or unprotected configuration files containing secrets |
| `basecoat-50-security-container-basecoat-50-security-security` | Container image and runtime basecoat-50-security-security hardening |
| `basecoat-50-security-github-security-posture` | GitHub org and repository policy auditor |
| `basecoat-10-core-hardening-advisor` | basecoat-50-security-security hardening guidance for applications and infrastructure |
| `basecoat-90-quality-penetration-test` | basecoat-50-security-security assessments, vulnerability discovery, and remediation workflows |
| `basecoat-50-security-policy-as-code-compliance` | Validates code and configuration against organizational rules and compliance frameworks |
| `basecoat-50-security-secrets-manager` | Secrets lifecycle management and rotation |
| `basecoat-50-security-security-analyst` | Vulnerability assessment, threat modeling, and secure coding review |
| `basecoat-50-security-security-monitor` | basecoat-50-security-security monitoring and alerting strategy |
| `basecoat-50-security-security-operations` | SOC playbook guidance for threat detection, incident response, and basecoat-50-security-security operations |
| `basecoat-50-security-supply-chain-basecoat-50-security-security` | Artifact signing, SBOM generation, and provenance tracking |

### basecoat-10-core-development

| Agent | Description |
|---|---|
| `basecoat-10-core-backend-dev` | APIs, services, and business logic; basecoat-10-core-architecture patterns and data access |
| `basecoat-10-core-frontend-dev` | UI components and applications; component-driven basecoat-10-core-development and state management |
| `basecoat-10-core-middleware-dev` | API gateways, message-passing, and integration layer design |
| `basecoat-10-core-mcp-developer` | basecoat-10-core-mcp server basecoat-10-core-development for building Model Context Protocol servers and tools |
| `basecoat-80-data-data-tier` | Schema design, migrations, query optimization, and data access patterns |

### basecoat-10-core-testing & basecoat-90-quality-quality

| Agent | Description |
|---|---|
| `basecoat-90-quality-code-review` | Structured multi-step code review with findings prioritized by severity |
| `basecoat-10-core-contract-basecoat-10-core-testing` | Consumer-driven contracts, E2E basecoat-10-core-testing strategy, and mutation basecoat-10-core-testing |
| `basecoat-90-quality-e2e-test-strategy` | End-to-end basecoat-10-core-testing orchestration, critical path identification, flakiness reduction |
| `basecoat-10-core-exploratory-charter` | Time-boxed exploratory basecoat-10-core-testing sessions with mission-driven charters |
| `basecoat-30-ai-guardrail` | Validates outputs against safety, quality, compliance, and formatting constraints |
| `basecoat-90-quality-manual-test-strategy` | Structured manual basecoat-10-core-testing strategy for a feature or risk inventory |
| `basecoat-10-core-performance-analyst` | Profiling, load testing, and optimization; evaluating application performance |
| `basecoat-10-core-strategy-to-automation` | Converts manual test paths into automation candidates |

### CI/CD & DevOps

| Agent | Description |
|---|---|
| `basecoat-10-core-agentops` | Agent versioning, rollout, health monitoring, rollback, and operational basecoat-20-lang-governance |
| `basecoat-10-core-dependency-lifecycle` | Manages dependency updates, tracks breaking changes, plans upgrade paths |
| `basecoat-10-core-dependency-update-advisor` | Reviews Dependabot PRs with structured risk assessment comments |
| `basecoat-10-core-devops-engineer` | CI/CD pipelines, infrastructure as code, container strategy, environment management |
| `basecoat-60-workflow-release-impact-advisor` | Release readiness assessment, change impact analysis, blast radius estimation |
| `basecoat-60-workflow-release-manager` | Automated versioned release workflow from merged PRs to GitHub releases |
| `basecoat-60-workflow-self-healing-ci` | CI failure analysis, log parsing, pipeline remediation, and retry strategies |
| `basecoat-10-core-sre-engineer` | SLOs, error budgets, incident response, chaos engineering for site basecoat-10-core-reliability |

### Memory & Knowledge

| Agent | Description |
|---|---|
| `basecoat-10-core-feedback-loop` | Continuous learning through user feedback collection and prompt effectiveness tracking |
| `basecoat-10-core-memory-curator` | Extracts, deduplicates, validates, and retrieves cross-session knowledge |
| `basecoat-10-core-memory-promoter` | Analyzes session transcripts to identify high-value patterns for promotion to BaseCoat memory |
| `basecoat-10-core-prompt-coach` | Interactive prompt optimization coach; reviews and scores prompt basecoat-90-quality-quality |
| `basecoat-10-core-prompt-engineer` | System prompt engineering; designing prompts, optimizing few-shot examples |

### Delivery & Planning

| Agent | Description |
|---|---|
| `basecoat-60-workflow-incident-responder` | Structured incident response: classification, mitigation coordination, post-mortem |
| `basecoat-10-core-issue-triage` | GitHub issue classification, priority assignment (P0-P3), label management |
| `basecoat-10-core-merge-coordinator` | Parallel branch merge coordination into a target branch |
| `basecoat-10-core-product-manager` | Requirements gathering, user stories, acceptance criteria, roadmap planning |
| `basecoat-10-core-production-readiness` | Ensures applications meet operational requirements before release |
| `basecoat-10-core-project-onboarding` | Single-invocation new repo setup with BaseCoat integration |
| `basecoat-60-workflow-retro-facilitator` | End-of-sprint retrospective from closed issues and merged PRs |
| `basecoat-60-workflow-rollout-basecoat` | Onboards a repository to BaseCoat in an enterprise setting with pinned versioning |
| `basecoat-10-core-sprint-planner` | Goal-to-issues decomposition and wave dependency mapping |
| `basecoat-10-core-sprint-retrospective` | Reconstructs repository history for sprint retrospectives |

### BaseCoat Authoring

| Agent | Description |
|---|---|
| `basecoat-50-security-guidance-author` | Drafts new BaseCoat guidance assets (instructions, skills, agents, prompts) |
| `basecoat-90-quality-guidance-reviewer` | Validates a BaseCoat guidance draft before committing |
| `basecoat-10-core-new-customization` | Creates or updates customization assets such as instructions, skills, prompts, or basecoat-10-core-agents |

### Data & ML

| Agent | Description |
|---|---|
| `basecoat-10-core-chaos-engineer` | Fault injection and resilience validation for distributed systems |
| `basecoat-80-data-data-integrity` | Data integrity validation and constraint enforcement |
| `basecoat-60-workflow-data-pipeline` | Medallion lakehouse architecture, data quality, ML pipeline orchestration |
| `basecoat-80-data-dataops` | Data quality, lineage, governance, orchestration, and data contracts |
| `basecoat-10-core-llmops` | Prompt deployment pipelines, model gateway configuration, inference monitoring |
| `basecoat-30-ai-mlops` | Model lifecycle, experiment tracking, model registry, deployment automation, drift detection |
| `basecoat-10-core-observability-engineer` | basecoat-10-core-observability strategy including metrics, traces, logs, and alerting |

---

## Skills

Skills are reusable domain capabilities stored as `skills/<name>/SKILL.md`.

### basecoat-40-azure-azure

| Skill | Description |
|---|---|
| `azure-container-apps` | basecoat-40-azure-azure Container Apps deployment patterns |
| `azure-devops-rest` | basecoat-40-azure-azure DevOps REST API integration |
| `azure-identity` | basecoat-40-azure-azure managed identity and Entra ID configuration |
| `basecoat-40-azure-azure-landing-zone` | Enterprise-scale landing zone scaffolding |
| `azure-linux-app-service` | basecoat-40-azure-azure App Service for Linbasecoat-10-core-ux deployment and configuration |
| `azure-networking` | basecoat-40-azure-azure virtual networks, NSGs, private endpoints |
| `azure-policy` | basecoat-40-azure-azure Policy definition and assignment |
| `azure-waf-review` | basecoat-40-azure-azure Well-Architected Framework review automation |

### Modernization

| Skill | Description |
|---|---|
| `basecoat-10-core-app-inventory` | Application inventory and dependency discovery |
| `cross-stack-modernization` | Cross-technology stack modernization patterns |
| `dotnet-modernization` | .NET upgrade and modernization execution |
| `entity-framework-migration` | EF Core migration generation and validation |
| `identity-migration` | Identity provider migration execution |

### basecoat-10-core-development Domains

| Skill | Description |
|---|---|
| `agent-design` | Copilot agent definition authoring |
| `api-design` | OpenAPI/REST/GraphQL API specification authoring |
| `basecoat-50-security-api-basecoat-50-security-security` | API basecoat-50-security-security assessment and hardening |
| `basecoat-10-core-backend-dev` | basecoat-10-core-backend service and API basecoat-10-core-development patterns |
| `basecoat-90-quality-code-review` | Structured code review workflow |
| `basecoat-10-core-contract-basecoat-10-core-testing` | Consumer-driven contract test generation |
| `cqrs-event-sourcing` | CQRS and event sourcing implementation patterns |
| `basecoat-80-data-data-tier` | Data schema design and access patterns |
| `basecoat-80-data-database-migration` | Database migration planning and execution |
| `domain-driven-design` | Bounded context and aggregate modeling |
| `e2e-basecoat-10-core-testing` | End-to-end test strategy and implementation |
| `electron-apps` | basecoat-10-core-electron desktop application basecoat-50-security-security patterns |
| `basecoat-10-core-frontend-dev` | basecoat-10-core-frontend component and state management patterns |
| `basecoat-90-quality-manual-test-strategy` | Manual test plan and exploratory charter creation |
| `mcp-basecoat-10-core-development` | Model Context Protocol server basecoat-10-core-development |
| `performance-profiling` | Application profiling and load basecoat-10-core-testing |
| `refactoring` | Safe refactoring techniques and patterns |

### DevOps & Operations

| Skill | Description |
|---|---|
| `basecoat` | BaseCoat sync, version management, and asset authoring |
| `create-instruction` | Creates new instruction files following BaseCoat conventions |
| `create-skill` | Creates new skill directories following BaseCoat conventions |
| `dev-containers` | Dev container configuration and optimization |
| `devops` | CI/CD pipeline design and implementation |
| `environment-bootstrap` | Environment provisioning and bootstrap automation |
| `gitops` | GitOps workflow implementation with declarative configuration |
| `ha-resilience` | High-availability and resilience pattern implementation |
| `handoff` | Session and task handoff basecoat-10-core-documentation |
| `human-in-the-loop` | Human review checkpoints and escalation workflows |
| `basecoat-10-core-observability` | Metrics, tracing, logging, and alerting setup |
| `basecoat-10-core-production-readiness` | Pre-release operational readiness validation |
| `sprint-management` | Sprint planning, issue decomposition, and wave mapping |
| `basecoat-10-core-sprint-retrospective` | Sprint retrospective generation from repository history |
| `basecoat-50-security-supply-chain-basecoat-50-security-security` | SBOM, artifact signing, and provenance |
| `tech-debt` | Technical debt identification and remediation planning |
| `twelve-factor` | Twelve-factor app compliance review |

### basecoat-50-security-security

| Skill | Description |
|---|---|
| `basecoat-50-security-github-security-posture` | GitHub organization and repository basecoat-50-security-security posture audit |
| `penetration-basecoat-10-core-testing` | basecoat-50-security-security assessment and penetration basecoat-10-core-testing execution |
| `basecoat-50-security-security` | General basecoat-50-security-security review and hardening |
| `basecoat-50-security-security-operations` | SOC playbook and threat response guidance |

### Memory & Intelligence

| Skill | Description |
|---|---|
| `basecoat-10-core-architecture` | Architectural decision recording and system design |
| `copilot-usage-analytics` | GitHub Copilot usage metrics and adoption reporting |
| `basecoat-10-core-documentation` | Technical basecoat-10-core-documentation authoring and review |
| `basecoat-10-core-ux` | User experience design and accessibility patterns |

---

## Instructions

Instructions are Copilot behavior rules stored as `instructions/<name>.instructions.md`,
applied automatically based on `applyTo` glob patterns.

### basecoat-20-lang-governance & Safety

| Instruction | Description |
|---|---|
| `basecoat-20-lang-governance` | **Read first.** basecoat-20-lang-governance rules for all AI basecoat-10-core-agents in this repository |
| `basecoat-30-ai-ai-basecoat-10-core-verification` | Risk-tiered basecoat-10-core-verification protocol for reviewing or accepting AI-generated code |
| `basecoat-10-core-config` | Safety rules for creating, modifying, or staging configuration files |
| `basecoat-10-core-output-style` | Keeps agent responses concise while preserving clarity and full-fidelity detail |
| `basecoat-10-core-plan-first` | Enforces planning before execution for multi-step or cross-file tasks |
| `basecoat-10-core-tool-minimization` | Selective tool enablement to reduce surface area during agent execution |
| `basecoat-10-core-verification` | Requires explicit success criteria before planning, implementing, or reviewing |

### Agent Behavior

| Instruction | Description |
|---|---|
| `basecoat-10-core-agent-behavior` | Prevents infinite retry loops, edit thrashing, and repeated failed actions |
| `basecoat-10-core-agents` | Naming, structure, required sections, skill pairing, and multi-agent coordination |
| `basecoat-10-core-model-routing` | Cost-aware model routing for sub-agent dispatch and model selection |
| `basecoat-10-core-session-hygiene` | Long-running session management, task switching, and handoff coordination |
| `basecoat-50-security-token-economics` | Cost-aware context loading; model escalation cost control |

### basecoat-10-core-architecture & Design

| Instruction | Description |
|---|---|
| `basecoat-10-core-architecture` | Architectural decisions, API design, system diagrams, and cross-cutting standards |
| `basecoat-10-core-naming` | Repository, file, type, variable, test, infrastructure, and basecoat-40-azure-azure resource basecoat-10-core-naming |
| `basecoat-10-core-hrm-execution` | Formal layer contracts, two-dimensional routing matrix, and guidance signals |
| `basecoat-10-core-trm-reflexion` | TRM Reflexion loop for intent classification and turn budget estimation |

### basecoat-10-core-development

| Instruction | Description |
|---|---|
| `basecoat-10-core-backend` | APIs, services, workers, integrations, and data access layer best practices |
| `basecoat-10-core-development` | Shared conventions when using backend-dev, frontend-dev, basecoat-10-core-middleware-dev basecoat-10-core-agents |
| `basecoat-10-core-frontend` | UI, client-side state, styling, forms, and interaction best practices |
| `basecoat-10-core-nextjs-react19` | Next.js and React 19: Server Components, App Router, streaming, forms |
| `basecoat-10-core-npm-workspaces` | npm workspaces and monorepo management setup and best practices |
| `basecoat-20-lang-python` | basecoat-20-lang-python conventions for data science and ML pipelines |
| `basecoat-10-core-cpp` | Memory safety, concurrency, and undefined behavior for C++ and native code |
| `basecoat-10-core-electron` | Secure basecoat-10-core-electron desktop application patterns |
| `basecoat-30-ai-tailwind-v4` | Tailwind CSS v4 patterns and CSS-first configuration |
| `basecoat-10-core-monolith` | Context management for large basecoat-10-core-monolith codebases with tightly coupled modules |

### basecoat-40-azure-azure & Cloud

| Instruction | Description |
|---|---|
| `basecoat-40-azure-azure` | basecoat-40-azure-azure services, basecoat-40-azure-azure SDK integrations, and deployment configuration |
| `basecoat-40-azure-azure-app-configuration` | basecoat-40-azure-azure App Configuration for feature flags and centralized settings |
| `basecoat-40-azure-azure-service-connector` | basecoat-40-azure-azure Service Connector for App Service, Container Apps, AKS |
| `basecoat-10-core-bicep` | basecoat-10-core-bicep file authoring: symbolic names, parameters, and module patterns |
| `basecoat-10-core-bootstrap-autodetect` | Bootstrap scripts that auto-detect values from existing infrastructure |
| `basecoat-50-security-bootstrap-github-secrets` | Bootstrap scripts provisioning identity or infrastructure for GitHub Actions |
| `basecoat-10-core-bootstrap-structure` | Bootstrap script decomposition, idempotency, and basecoat-10-core-documentation |
| `basecoat-60-workflow-ci-firewall` | GitHub Actions workflows accessing firewalled basecoat-40-azure-azure resources |
| `basecoat-50-security-rbac-authentication` | RBAC-only authentication enforcement — no shared keys or connection strings |
| `basecoat-10-core-terraform` | basecoat-10-core-terraform for Azure: provider pinning and shared infrastructure patterns |
| `basecoat-10-core-terraform-init` | Running `basecoat-10-core-terraform init` in bootstrap scripts and CI/CD pipelines |
| `basecoat-10-core-drift-monitor` | Infrastructure-as-Code drift detection and remediation strategies |

### basecoat-50-security-security

| Instruction | Description |
|---|---|
| `basecoat-50-security-security` | Authentication, authorization, secrets, input handling, and security-sensitive changes |
| `basecoat-50-security-secrets-management` | Secrets lifecycle, rotation, and storage basecoat-20-lang-governance |
| `basecoat-50-security-security-monitoring` | basecoat-50-security-security monitoring, alerting, and incident detection |
| `basecoat-60-workflow-workflow-integrity` | GitHub Actions security: script injection, credential exposure prevention |
| `basecoat-60-workflow-workflow-file-integrity` | Silent GitHub Actions workflow file corruption prevention and checksum validation |

### basecoat-10-core-testing & basecoat-90-quality-quality

| Instruction | Description |
|---|---|
| `basecoat-10-core-testing` | Common basecoat-10-core-testing best practices for regression, unit, integration tests |
| `basecoat-90-quality-quality` | PR review, basecoat-50-security-security posture, performance measurement, and coverage enforcement |
| `basecoat-10-core-data-workload-basecoat-10-core-testing` | Medallion data patterns, data basecoat-90-quality-quality validation, and contract basecoat-10-core-testing |
| `basecoat-20-lang-dotnet-dependency-analysis` | .NET dependency compatibility and remediation analysis |
| `basecoat-20-lang-dotnet-test-strategy` | .NET modernization test strategy and regression-gate guidance |
| `basecoat-20-lang-dotnet-upgrade-planning` | .NET upgrade planning checklist and phased execution |
| `basecoat-10-core-mutation-basecoat-10-core-testing` | Mutation basecoat-10-core-testing strategy and tooling integration |

### Data & ML

| Instruction | Description |
|---|---|
| `basecoat-80-data-data-science` | Data science and ML conventions: Jupyter, pandas, scikit-learn |
| `basecoat-10-core-fabric-notebooks` | Microsoft Fabric notebooks with CI/CD, lakehouse integration, and basecoat-20-lang-governance |
| `basecoat-10-core-observability` | Metrics, traces, logs, and alerting configuration guidance |

### basecoat-10-core-reliability

| Instruction | Description |
|---|---|
| `basecoat-10-core-reliability` | Uptime, retries, background work, and dependency failure handling |
| `basecoat-10-core-rest-client-resilience` | HTTP client resilience: timeouts, retries, circuit breakers |
| `basecoat-10-core-runtime-debugging` | Debugging with crash dumps, logs, memory state, and production diagnostics |
| `basecoat-10-core-error-kb` | Building and consulting an error knowledge base for agent failure classification |

### Memory & Knowledge

| Instruction | Description |
|---|---|
| `basecoat-10-core-memory-index` | L2 memory index loaded at session start to prime fast pattern recall |
| `basecoat-10-core-enterprise-configuration` | GitHub Copilot policy configuration, usage metrics, and seat management |
| `basecoat-10-core-documentation` | basecoat-10-core-documentation standards for setup, workflows, public contracts, and runbooks |
| `basecoat-10-core-process` | Sprint planning, issue triage, PR management, and release evaluation |

---

## Prompts

Prompts are structured templates stored as `prompts/<name>.prompt.md`.

| Prompt | Description |
|---|---|
| `architect` | Break down a feature or system change into options, tradeoffs, and execution steps before editing code |
| `bugfix` | Root-cause analysis, minimal safe fix, and validation for a bug, regression, or production failure |
| `basecoat-90-quality-code-review` | Risk-focused code review of a diff, branch, or set of files; returns findings, open questions, summary |
