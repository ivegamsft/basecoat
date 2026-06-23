# BaseCoat

**Enterprise-grade shared repository for GitHub Copilot customizations.**

BaseCoat provides a curated library of agents, skills, instructions, and prompts that teams adopt across repositories through a single sync command. Instead of every team writing Copilot customizations from scratch, BaseCoat gives you production-ready assets that enforce consistent standards, accelerate development workflows, and scale across an entire GitHub Enterprise organization.

The operating model combines **Guardrails** (BaseCoat assets and standards) with **Visibility** (issues, PRs, workflows, and milestones) so execution is both governed and observable.

**122 agents** · **120 skills** · **91 instruction files** · **11 prompt starters**

---

## Quick Start

### Method 1: Manual Copy (simplest)

```bash
# Download latest release
curl -L https://github.com/IBuySpy-Shared/basecoat/releases/latest/download/basecoat-ghcp.zip -o basecoat.zip
unzip basecoat.zip -d .github/base-coat/

# Copy Copilot-discoverable files
cp -r .github/base-coat/agents .github/agents
cp -r .github/base-coat/instructions .github/instructions
cp -r .github/base-coat/prompts .github/prompts
```

### Method 2: Sync Script (recommended for updates)

**macOS / Linux:**

```bash
BASECOAT_REPO=https://github.com/IBuySpy-Shared/basecoat.git ./sync.sh
```

**Windows PowerShell:**

```powershell
$env:BASECOAT_REPO = 'https://github.com/IBuySpy-Shared/basecoat.git'; .\sync.ps1
```

**Pin to a release tag (recommended for production):**

```powershell
$env:BASECOAT_REPO = 'https://github.com/IBuySpy-Shared/basecoat.git'
$env:BASECOAT_REF  = 'v1.0.0'
irm https://raw.githubusercontent.com/IBuySpy-Shared/basecoat/$env:BASECOAT_REF/sync.ps1 | iex
```

The sync script clones BaseCoat, copies the standard assets into `.github/base-coat/`, then copies agents, instructions, and prompts to `.github/agents/`, `.github/instructions/`, and `.github/prompts/` so that GitHub Copilot auto-discovers them. The whole process takes under a minute.

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `BASECOAT_REPO` | `https://github.com/YOUR-ORG/basecoat.git` | Source repository URL |
| `BASECOAT_REF` | `main` | Branch or tag to sync from |
| `BASECOAT_TARGET_DIR` | `.github/base-coat` | Target directory inside your repo (relative to repo root) |

### What Gets Synced

The sync script copies these items into `BASECOAT_TARGET_DIR`:

`README.md` · `CHANGELOG.md` · `inventory.md` · `version.json` · `instructions/` · `skills/` · `prompts/` · `agents/`

Everything else (tests, scripts, CI workflows, examples) stays in the source repo and is **not** copied into consumers.

### ⚠️ Do Not Copy Files Manually

Always use `sync.ps1` or `sync.sh`. Manual copying leads to stale assets, missing files, and incorrect target paths. The scripts handle cloning, copying, and cleanup in a single idempotent operation.

---

## 🏷️ Issue Labels

BaseCoat uses a consistent label taxonomy for issue triage, discovery, and sprint management.

### Label Categories

| Category | Labels | Purpose |
|---|---|---|
| **Asset Type** | `agent`, `skill`, `instruction`, `prompt` | Identifies the type of customization asset for filtering and discovery |
| **Issue Type** | `bug`, `enhancement`, `documentation`, `question`, `chore`, `security` | Classifies the issue by its primary type |
| **Priority** | `priority:high`, `priority:medium`, `priority:low` | Indicates urgency and SLA (high = 1hr, medium = 4hr, low = 1 week) |
| **Sprint** | `sprint-1`, `sprint-2`, `sprint-3`, `sprint-4` | Assigns issue to a sprint milestone |
| **Status** | `blocked`, `spec-required`, `governance` | Indicates blocking conditions or special handling |
| **Technology** | `azure`, `dotnet`, `kubernetes`, `python`, `terraform`, etc. | Domain or technology focus |
| **Approval** | `approved`, `copilot-agent` | Applied when issue is approved for agent implementation |

### Quick Discovery

- Find all agents: `is:issue label:agent`
- Find Sprint 3 skills: `is:issue label:sprint-3 label:skill`
- Find high-priority bugs: `is:issue label:priority:high label:bug`
- Find blocked issues: `is:issue label:blocked`

**For complete label reference:** [`docs/reference/LABEL_taxonomy.md`](docs/reference/LABEL_taxonomy.md) · [`governance.md`](docs/reference/governance.md#labels)

---

## Architecture Overview

BaseCoat is built on four GitHub Copilot customization primitives:

```text
┌─────────────────────────────────────────────────────┐
│                    BaseCoat                         │
├──────────┬──────────┬───────────────┬───────────────┤
│  Agents  │  Skills  │ Instructions  │   Prompts     │
│ (73)     │ (55)     │ (56)          │   (8)         │
│          │          │               │               │
│ Multi-   │ Reusable │ Coding        │ Quick task    │
│ step     │ workflow │ standards &   │ entry points  │
│ flows    │ recipes  │ guardrails    │               │
└──────────┴──────────┴───────────────┴───────────────┘
        ▲                    ▲
        │   Agents reference │ Instructions are
        │   skills for       │ auto-loaded by
        │   templates        │ Copilot in every
        └────────────────────┘ conversation
```

- **Agents** (`agents/`) — Multi-step workflow definitions for complex tasks like backend development, code review, sprint planning, and security analysis. Each agent has a defined role, instructions, and often references paired skills.
- **Skills** (`skills/`) — Reusable workflow recipes with templates. A skill contains a `SKILL.md` workflow definition plus template files (checklists, specs, scaffolds) that agents and users invoke during work.
- **Instructions** (`instructions/`) — Coding standards and guardrails that Copilot loads automatically. These govern how code is written, reviewed, tested, and deployed across every conversation.
- **Prompts** (`prompts/`) — Quick-start entry points for common tasks like architecture planning, code review, and bugfixing.

- **Operating model reference:** [`docs/reference/ai-sdlc-operating-model.md`](docs/reference/ai-sdlc-operating-model.md)

---

## Agent Catalog

| Agent | Description |
|---|---|
| [agent-designer](agents/basecoat-10-core-agent-designer.agent.md) | Designs and authors Copilot agent definitions |
| [agentops](agents/basecoat-10-core-agentops.agent.md) | Agent lifecycle, versioning, rollout, health monitoring, and rollback |
| [api-designer](agents/basecoat-10-core-api-designer.agent.md) | API design for OpenAPI, REST, GraphQL, and governance |
| [app-inventory](agents/basecoat-10-core-app-inventory.agent.md) | Legacy app scanning for dependencies, tech stacks, and migration complexity |
| [azure-landing-zone](agents/basecoat-40-azure-azure-landing-zone.agent.md) | Azure Landing Zone scaffolding following Cloud Adoption Framework |
| [backend-dev](agents/basecoat-10-core-backend-dev.agent.md) | APIs, service layers, business logic, and data access |
| [chaos-engineer](agents/basecoat-10-core-chaos-engineer.agent.md) | Fault injection, game days, resilience scoring, and recovery validation |
| [code-review](agents/basecoat-90-quality-code-review.agent.md) | Structured multi-step code review workflow |
| [config-auditor](agents/basecoat-50-security-config-auditor.agent.md) | Scans for committed or unprotected config secrets |
| [containerization-planner](agents/basecoat-30-ai-containerization-planner.agent.md) | Containerization readiness assessment and deployment configuration |
| [data-tier](agents/basecoat-80-data-data-tier.agent.md) | Schema design, migrations, query optimization, data access |
| [dataops](agents/basecoat-80-data-dataops.agent.md) | Data quality, lineage, governance, orchestration, and drift detection |
| [dependency-lifecycle](agents/basecoat-10-core-dependency-lifecycle.agent.md) | Dependency updates, breaking changes, upgrade paths, and migration guides |
| [devops-engineer](agents/basecoat-10-core-devops-engineer.agent.md) | CI/CD, IaC, deployment, rollback, and observability |
| [exploratory-charter](agents/basecoat-10-core-exploratory-charter.agent.md) | Time-boxed exploratory testing charters with evidence capture |
| [feedback-loop](agents/basecoat-10-core-feedback-loop.agent.md) | User feedback collection, prompt effectiveness tracking, and A/B testing |
| [frontend-dev](agents/basecoat-10-core-frontend-dev.agent.md) | UI components, responsive layouts, state, accessibility |
| [github-security-posture](agents/basecoat-50-security-github-security-posture.agent.md) | GitHub org and repo security posture auditing: code security configs, rulesets, secret scanning, Dependabot, and branch protection |
| [guardrail](agents/basecoat-30-ai-guardrail.agent.md) | Post-processing validation for safety, quality, compliance, and formatting |
| [identity-architect](agents/basecoat-10-core-identity-architect.agent.md) | Azure RBAC, managed identities, Entra ID app registrations, conditional access, and workload identity federation |
| [incident-responder](agents/basecoat-60-workflow-incident-responder.agent.md) | Incident classification, mitigation, communications, and post-incident learning |
| [infrastructure-deploy](agents/basecoat-60-workflow-infrastructure-deploy.agent.md) | Azure infrastructure deployments using Bicep with rollback strategies |
| [issue-triage](agents/basecoat-10-core-issue-triage.agent.md) | Triage, classify, label, and prioritize GitHub issues |
| [legacy-modernization](agents/basecoat-10-core-legacy-modernization.agent.md) | Web Forms to Razor Pages migration using the strangler fig pattern |
| [llmops](agents/basecoat-10-core-llmops.agent.md) | Prompt deployment pipelines, model gateway configuration, and inference monitoring |
| [manual-test-strategy](agents/basecoat-90-quality-manual-test-strategy.agent.md) | Manual testing strategy with rubric, charter, checklist, and automation backlog |
| [mcp-developer](agents/basecoat-10-core-mcp-developer.agent.md) | MCP servers, tools, and integrations |
| [memory-curator](agents/basecoat-10-core-memory-curator.agent.md) | Cross-session knowledge extraction, deduplication, and retrieval |
| [merge-coordinator](agents/basecoat-10-core-merge-coordinator.agent.md) | Parallel branch merge coordination |
| [middleware-dev](agents/basecoat-10-core-middleware-dev.agent.md) | API gateways, integration layers, event-driven architectures |
| [mlops](agents/basecoat-30-ai-mlops.agent.md) | Model lifecycle, experiment tracking, deployment automation, and drift monitoring |
| [new-customization](agents/basecoat-10-core-new-customization.agent.md) | Creates or updates BaseCoat customization assets |
| [performance-analyst](agents/basecoat-10-core-performance-analyst.agent.md) | Profiling, load testing, and performance optimization |
| [policy-as-code-compliance](agents/basecoat-50-security-policy-as-code-compliance.agent.md) | Policy-as-code validation, exception management, and audit-ready compliance reports |
| [product-manager](agents/basecoat-10-core-product-manager.agent.md) | Requirements, user stories, acceptance criteria, roadmaps |
| [project-onboarding](agents/basecoat-10-core-project-onboarding.agent.md) | BaseCoat repository onboarding and setup |
| [prompt-coach](agents/basecoat-10-core-prompt-coach.agent.md) | Interactive prompt review, scoring, and refinement coaching |
| [prompt-engineer](agents/basecoat-10-core-prompt-engineer.agent.md) | Prompt and system-prompt optimization |
| [release-impact-advisor](agents/basecoat-60-workflow-release-impact-advisor.agent.md) | Release readiness assessment, blast radius analysis, and rollback planning |
| [release-manager](agents/basecoat-60-workflow-release-manager.agent.md) | Versioned release workflow, changelog, tagging, and publishing |
| [retro-facilitator](agents/basecoat-60-workflow-retro-facilitator.agent.md) | Sprint retrospective summary and improvement issue creation |
| [rollout-basecoat](agents/basecoat-60-workflow-rollout-basecoat.agent.md) | Enterprise BaseCoat onboarding and rollout |
| [security-analyst](agents/basecoat-50-security-security-analyst.agent.md) | Vulnerability assessment, threat modeling, secure code review |
| [self-healing-ci](agents/basecoat-60-workflow-self-healing-ci.agent.md) | CI failure analysis, log parsing, flaky test detection, and pipeline remediation |
| [solution-architect](agents/basecoat-10-core-solution-architect.agent.md) | System design, C4 diagrams, ADRs, and technology selection |
| [sprint-planner](agents/basecoat-10-core-sprint-planner.agent.md) | Sprint goal-to-issues breakdown and wave planning |
| [sprint-retrospective](agents/basecoat-10-core-sprint-retrospective.agent.md) | Reconstructs repo history for sprint retrospectives with metrics and tips |
| [sre-engineer](agents/basecoat-10-core-sre-engineer.agent.md) | SLOs, error budgets, incident response, chaos engineering, and toil reduction |
| [strategy-to-automation](agents/basecoat-10-core-strategy-to-automation.agent.md) | Converts manual test paths into tiered automation candidates |
| [tech-writer](agents/basecoat-10-core-tech-writer.agent.md) | Technical docs, runbooks, tutorials, and changelogs |
| [ux-designer](agents/basecoat-10-core-ux-designer.agent.md) | Journey mapping, wireframes, and accessibility audits |

> Full machine-readable catalog with skill pairings and model recommendations: [`docs/reference/asset-catalog.md`](docs/reference/asset-catalog.md)

---

## Skill Catalog

| Skill | Templates | Paired Agent(s) |
|---|---|---|
| [agent-design](skills/agent-design/) | agent-template, instruction-template, skill-template | agent-designer |
| [api-design](skills/api-design/) | openapi-template, governance-checklist, breaking-change-checklist, versioning-decision-tree | api-designer |
| [app-inventory](skills/app-inventory/) | inventory-report-template, complexity-scoring-template | app-inventory |
| [architecture](skills/architecture/) | adr-template, c4-diagram-template, risk-register-template, tech-selection-matrix-template | solution-architect |
| [azure-container-apps](skills/azure-container-apps/) | SKILL.md workflow | devops-engineer |
| [azure-identity](skills/azure-identity/) | rbac-role-assignment-template, managed-identity-mapping-template, app-registration-checklist, workload-identity-federation-template, conditional-access-policy-template | identity-architect |
| [azure-landing-zone](skills/azure-landing-zone/) | adr-template, hub-networking-template, landing-zone-vending-template, platform-subscription-template, policy-assignment-template, policy-exemption-template | azure-landing-zone |
| [azure-networking](skills/azure-networking/) | hub-spoke-topology, cidr-allocation, private-endpoint-dns-zones, nsg-rule-matrix | solution-architect, devops-engineer |
| [azure-policy](skills/azure-policy/) | policy-definition-template, initiative-definition-template, remediation-task-template, compliance-report-template | policy-as-code-compliance |
| [azure-waf-review](skills/azure-waf-review/) | waf-assessment-report-template, pillar-scoring-rubric, remediation-action-plan-template | solution-architect, security-analyst, devops-engineer |
| [backend-dev](skills/backend-dev/) | api-spec-template, error-catalog-template, repository-pattern-template, service-template | backend-dev |
| [basecoat](skills/basecoat/) | SKILL.md workflow | — |
| [code-review](skills/code-review/) | SKILL.md workflow | code-review |
| [create-instruction](skills/create-instruction/) | SKILL.md workflow | new-customization |
| [create-skill](skills/create-skill/) | SKILL.md workflow | new-customization |
| [data-tier](skills/data-tier/) | schema-design-template, migration-template, query-review-checklist, data-dictionary-template | data-tier |
| [devops](skills/devops/) | deployment-checklist, environment-promotion-template, github-actions-template, rollback-runbook-template | devops-engineer |
| [documentation](skills/documentation/) | readme-template, runbook-template, adr-template | tech-writer |
| [environment-bootstrap](skills/environment-bootstrap/) | SKILL.md workflow | devops-engineer |
| [frontend-dev](skills/frontend-dev/) | component-spec-template, accessibility-checklist, state-management-template | frontend-dev |
| [handoff](skills/handoff/) | handoff-template | — |
| [human-in-the-loop](skills/human-in-the-loop/) | SKILL.md workflow | — |
| [identity-migration](skills/identity-migration/) | SKILL.md workflow | legacy-modernization |
| [manual-test-strategy](skills/manual-test-strategy/) | charter-template, checklist-template, defect-template, rubric-template | manual-test-strategy, exploratory-charter |
| [mcp-development](skills/mcp-development/) | mcp-server-template, tool-definition-template, transport-config-template | mcp-developer |
| [performance-profiling](skills/performance-profiling/) | SKILL.md workflow | performance-analyst |
| [refactoring](skills/refactoring/) | SKILL.md workflow | — |
| [rollout-basecoat](skills/rollout-basecoat/) | SKILL.md workflow | rollout-basecoat |
| [security](skills/security/) | owasp-checklist, stride-threat-model-template, vulnerability-report-template, dependency-audit-template | security-analyst |
| [github-security-posture](skills/github-security-posture/) | posture-report-template | github-security-posture |
| [service-bus-migration](skills/service-bus-migration/) | SKILL.md workflow | middleware-dev |
| [sprint-management](skills/sprint-management/) | sprint-planning-template, backlog-grooming-template, retrospective-template | sprint-planner, retro-facilitator |
| [ux](skills/ux/) | user-journey-template, wireframe-spec-template, component-spec-template, accessibility-audit-checklist | ux-designer |

---

## Instruction Files

Instructions are automatically loaded by GitHub Copilot to enforce standards across every conversation.

| Instruction | Scope |
|---|---|
| [agent-behavior](instructions/basecoat-10-core-agent-behavior.instructions.md) | Retry loops, edit thrashing, and escalation guardrails |
| [agents](instructions/basecoat-10-core-agents.instructions.md) | Agent authoring standards |
| [architecture](instructions/basecoat-10-core-architecture.instructions.md) | Architecture, API, and design-diagram guidance |
| [azure](instructions/basecoat-40-azure-azure.instructions.md) | Azure service, SDK, and deployment guidance |
| [backend](instructions/basecoat-10-core-backend.instructions.md) | Backend APIs, services, workers, and data access |
| [bicep](instructions/basecoat-10-core-bicep.instructions.md) | Azure Bicep authoring and validation |
| [config](instructions/basecoat-10-core-config.instructions.md) | Config file safety and secrets prevention |
| [development](instructions/basecoat-10-core-development.instructions.md) | Shared dev standards for all dev-core agents |
| [documentation](instructions/basecoat-10-core-documentation.instructions.md) | Documentation and change-note expectations |
| [drift-monitor](instructions/basecoat-10-core-drift-monitor.instructions.md) | Infrastructure-as-Code drift detection and remediation |
| [error-kb](instructions/basecoat-10-core-error-kb.instructions.md) | Error knowledge base classification and pattern reuse |
| [frontend](instructions/basecoat-10-core-frontend.instructions.md) | Frontend, UI, state management, and accessibility |
| [governance](instructions/basecoat-20-lang-governance.instructions.md) | Repository-wide AI governance rules |
| [mcp](instructions/basecoat-10-core-mcp.instructions.md) | MCP server, tooling, and trust-boundary guidance |
| [naming](instructions/basecoat-10-core-naming.instructions.md) | Naming conventions across repos, code, and infrastructure |
| [nextjs-react19](instructions/basecoat-10-core-nextjs-react19.instructions.md) | Next.js and React 19 Server Components and App Router patterns |
| [npm-workspaces](instructions/basecoat-10-core-npm-workspaces.instructions.md) | npm workspaces and monorepo management |
| [output-style](instructions/basecoat-10-core-output-style.instructions.md) | Concise agent responses with full-fidelity code output |
| [plan-first](instructions/basecoat-10-core-plan-first.instructions.md) | Explore-plan-implement-verify workflow for multi-step tasks |
| [process](instructions/basecoat-10-core-process.instructions.md) | Delivery lifecycle, sprint, triage, and release process |
| [quality](instructions/basecoat-90-quality-quality.instructions.md) | PR review, security, performance, and coverage gates |
| [reliability](instructions/basecoat-10-core-reliability.instructions.md) | Retries, uptime, background work, and dependency failure |
| [security](instructions/basecoat-50-security-security.instructions.md) | Secure coding, auth, authz, secrets, and input handling |
| [session-hygiene](instructions/basecoat-10-core-session-hygiene.instructions.md) | Context hygiene, session rotation, and clean-state practices |
| [tailwind-v4](instructions/basecoat-30-ai-tailwind-v4.instructions.md) | Tailwind CSS v4 patterns and migration guidance |
| [terraform](instructions/basecoat-10-core-terraform.instructions.md) | Terraform guidance for Azure-oriented IaC |
| [testing](instructions/basecoat-10-core-testing.instructions.md) | Testing best practices and validation expectations |
| [token-economics](instructions/basecoat-50-security-token-economics.instructions.md) | Cost-aware model routing and token budget discipline |
| [tool-minimization](instructions/basecoat-10-core-tool-minimization.instructions.md) | Selective tool enablement and MCP server discipline |
| [ux](instructions/basecoat-10-core-ux.instructions.md) | UX, accessibility, and design-system guidance |
| [verification](instructions/basecoat-10-core-verification.instructions.md) | Success criteria before coding and verification before done |

---

## Guardrails

Guardrail policies in [`docs/reference/guardrails/`](docs/reference/guardrails/) enforce non-negotiable standards:

| Guardrail | Purpose |
|---|---|
| [caf-naming](docs/reference/guardrails/caf-naming.md) | CAF naming conventions for Azure resources |
| [container-image-tags](docs/reference/guardrails/container-image-tags.md) | Container image tags must include Git SHA |
| [db-deployment-concurrency](docs/reference/guardrails/db-deployment-concurrency.md) | Database deployment concurrency rules |
| [env-example](docs/reference/guardrails/env-example.md) | `.env.example` required for every repo |
| [oidc-federation](docs/reference/guardrails/oidc-federation.md) | GitHub Actions to Azure OIDC federation |
| [secrets-in-workflows](docs/reference/guardrails/secrets-in-workflows.md) | No hardcoded secrets in workflow files |

Additional security docs: [`docs/operations/security/BRANCH_PROTECTION.md`](docs/operations/security/BRANCH_PROTECTION.md) · [`docs/operations/security/SECRET_SCANNING.md`](docs/operations/security/SECRET_SCANNING.md)

---

## Governance

BaseCoat operates under a lightweight enterprise governance framework:

- **Issue-first**: All changes must be backed by a logged GitHub issue.
- **PRs only**: Never commit directly to `main`. Open a pull request; self-approval is permitted.
- **No secrets**: Never commit credentials, tokens, API keys, or sensitive data.
- **Branch naming**: `feature/<issue-number>-<short-description>` or `fix/<issue-number>-<short-description>`

Full reference: [`docs/reference/governance.md`](docs/reference/governance.md) · Contributing: [`CONTRIBUTING.md`](CONTRIBUTING.md)

---

## Repository Layout

```text
basecoat/
├── agents/              # 30 agent definitions
├── skills/              # 19 skill directories with templates
├── instructions/        # 19 instruction files (auto-loaded)
├── prompts/             # 3 prompt starters
├── docs/                # Governance, guardrails, security, guides
│   ├── guardrails/      # 6 guardrail policies
│   └── security/        # Branch protection, secret scanning
├── examples/            # IaC samples, workflows, repo templates
├── scripts/             # Packaging, validation, hook installers
├── tests/               # Smoke tests
├── .github/workflows/   # CI/CD pipelines
├── sync.ps1             # Windows sync script
├── sync.sh              # macOS/Linux sync script
├── docs/reference/asset-catalog.md  # Machine-readable asset registry
├── CHANGELOG.md         # Release history
├── CONTRIBUTING.md      # Contribution guidelines
├── inventory.md         # Asset inventory
└── version.json         # Current version metadata
```

---

## Adoption Options

### Option 1 — Sync Script (Recommended)

```bash
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/YOUR-ORG/basecoat/main/sync.sh | bash

# Windows PowerShell
irm https://raw.githubusercontent.com/YOUR-ORG/basecoat/main/sync.ps1 | iex
```

### Option 2 — Pinned Release (Enterprise)

```bash
tag=v1.0.0
curl -fsSL https://raw.githubusercontent.com/YOUR-ORG/basecoat/${tag}/sync.sh | bash
```

### Option 3 — Git Submodule

```bash
git submodule add https://github.com/YOUR-ORG/basecoat.git .github/base-coat
```

After adding the submodule, copy the assets to the Copilot-discoverable paths:

```bash
# macOS / Linux
rm -rf .github/agents .github/instructions .github/prompts
cp -r .github/base-coat/agents .github/agents
cp -r .github/base-coat/instructions .github/instructions
cp -r .github/base-coat/prompts .github/prompts
```

```powershell
# Windows PowerShell
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue .github/agents, .github/instructions, .github/prompts
Copy-Item -Recurse .github/base-coat/agents .github/agents
Copy-Item -Recurse .github/base-coat/instructions .github/instructions
Copy-Item -Recurse .github/base-coat/prompts .github/prompts
```

Repeat the copy step whenever you update the submodule, or use the sync scripts instead to automate this.

---

## Copilot CLI Plugin

The `basecoat` CLI plugin routes natural-language commands to the best-matching Basecoat agent.

```bash
npx basecoat "review this code for security vulnerabilities"
```

See [plugins/copilot-cli-plugin/](plugins/copilot-cli-plugin/) for installation and usage.

---

## Enterprise Setup

For GitHub Enterprise onboarding, organization-level configuration, and custom agent development, see the **[Enterprise Setup Guide](docs/guides/enterprise-setup.md)**.

---

## Test Suite

```powershell
./tests/run-tests.ps1          # Windows
bash tests/run-tests.sh        # macOS / Linux
```

---

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for guidelines on adding agents, skills, instructions, and prompts.

## License

This project is for internal use. Contact your organization's open-source program office for licensing terms.
