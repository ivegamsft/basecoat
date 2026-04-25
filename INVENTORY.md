# Inventory

This catalog helps teams discover what exists in Base Coat and when to use it.

## Instructions

| File                                         | Use For                                               | Keywords                                                           |
| -------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------ |
| `instructions/backend.instructions.md`       | API, services, data access, backend guardrails        | backend, api, refactor, service, reliability                       |
| `instructions/frontend.instructions.md`      | UI, accessibility, responsiveness, frontend changes   | frontend, ui, css, accessibility, react                            |
| `instructions/testing.instructions.md`       | test expectations with positive and negative coverage | tests, unit test, integration test, regression, positive, negative |
| `instructions/security.instructions.md`      | secure coding, auth boundaries, secret handling       | security, auth, secrets, validation, unsafe                        |
| `instructions/reliability.instructions.md`   | resilience, failure modes, observability              | reliability, retry, timeout, logging, resilience                   |
| `instructions/documentation.instructions.md` | docs updates and operational notes                    | docs, readme, changelog, migration, usage                          |
| `instructions/development.instructions.md`   | shared standards for backend-dev, frontend-dev, middleware-dev, data-tier agents | development, code style, error handling, security, logging, testing, collaboration |
| `instructions/azure.instructions.md`         | Azure application and service guidance                | azure, managed identity, key vault, app service                    |
| `instructions/terraform.instructions.md`     | Terraform authoring for Azure and shared IaC          | terraform, azurerm, modules, providers, state                      |
| `instructions/bicep.instructions.md`         | Bicep authoring, parameters, and deployment hygiene   | bicep, bicepparam, module, symbolic name                           |
| `instructions/naming.instructions.md`        | consistent naming across code and infrastructure      | naming, convention, style, files, resources                        |
| `instructions/mcp.instructions.md`           | MCP server/tool governance and safe integration rules | mcp, tools, server, governance, allowlist                          |

## Skills

| File                                    | Use For                                                 | Keywords                                     |
| --------------------------------------- | ------------------------------------------------------- | -------------------------------------------- |
| `skills/backend-dev/SKILL.md`           | design and implement APIs, service layers, and data access repositories | backend, api, service, repository, error catalog                     |
| `skills/frontend-dev/SKILL.md`          | build accessible, responsive UI components and manage client state       | frontend, ui, component, accessibility, state management             |
| `skills/data-tier/SKILL.md`             | design schemas, write migrations, review queries, build data dictionaries | data, schema, migration, query, indexing                            |
| `skills/manual-test-strategy/SKILL.md`  | define manual scope, produce charters, checklists, and handoff artifacts | manual testing, exploratory, charter, regression, defect, automation handoff |
| `skills/performance-profiling/SKILL.md` | isolate and measure slow code paths                     | profiling, performance, latency, hot path    |
| `skills/code-review/SKILL.md`           | review changes for risk, regressions, and missing tests | review, bug risk, regression, findings       |
| `skills/refactoring/SKILL.md`           | restructure code without changing behavior              | refactor, cleanup, simplify, extract, rename |
| `skills/create-skill/SKILL.md`          | create a new reusable skill with proper frontmatter     | create skill, skill template, customization  |
| `skills/create-instruction/SKILL.md`    | create a new instruction file for a domain              | create instruction, applyTo, frontmatter     |

## Prompts

| File                            | Use For                                              | Keywords                              |
| ------------------------------- | ---------------------------------------------------- | ------------------------------------- |
| `prompts/architect.prompt.md`   | break down a system or feature before implementation | architecture, design, tradeoffs, plan |
| `prompts/code-review.prompt.md` | initiate a focused code review workflow              | review, pull request, findings        |
| `prompts/bugfix.prompt.md`      | investigate and fix a bug at the root cause          | bugfix, incident, regression, failure |

## Agents

| File                                | Use For                                        | Keywords                                  |
| ----------------------------------- | ---------------------------------------------- | ----------------------------------------- |
| `agents/backend-dev.agent.md`           | design and implement APIs, service layers, and data access patterns    | agent, backend, api, service, rest, graphql, repository, error handling |
| `agents/frontend-dev.agent.md`          | build accessible component-driven UIs with Core Web Vitals targets     | agent, frontend, ui, component, accessibility, wcag, state, performance |
| `agents/middleware-dev.agent.md`        | design integration layers, message contracts, and resilience patterns   | agent, middleware, integration, message, event-driven, circuit breaker, retry |
| `agents/data-tier.agent.md`             | design schemas, write migrations, optimize queries, and define data access | agent, data, schema, migration, query, indexing, repository         |
| `agents/manual-test-strategy.agent.md`  | produce a full manual test strategy with rubric, charter, checklist, defect template, and automation backlog | agent, manual testing, strategy, exploratory, automation candidate |
| `agents/exploratory-charter.agent.md`   | generate time-boxed exploratory sessions with scope, evidence capture, and GitHub Issue filing              | agent, exploratory, charter, session, findings |
| `agents/strategy-to-automation.agent.md`| convert manual paths into tiered automation candidates and file GitHub Issues for every one                | agent, automation, smoke, regression, integration, candidate |
| `agents/code-review.agent.md`       | multi-step repository review process           | agent, review, repo scan, risk            |
| `agents/new-customization.agent.md` | choose and create the right customization type | agent, customization, instruction, prompt |
| `agents/rollout-basecoat.agent.md`  | onboard a repo to a pinned Base Coat release   | agent, rollout, bootstrap, enterprise     |
| `agents/merge-coordinator.agent.md` | merge multiple feature branches into a target without interactive git editor hangs | agent, merge, conflict, parallel, branches, rebase, no-edit |

## Documentation Assets

| File                                      | Use For                                                         | Keywords                                 |
| ----------------------------------------- | --------------------------------------------------------------- | ---------------------------------------- |
| `docs/documentation-heading-scaffolds.md` | shared heading templates for common documentation types         | docs, headings, template, scaffold       |
| `docs/prd-and-spec-guidance.md`           | guidance and templates for PRDs and technical specs             | prd, spec, requirements, design          |
| `docs/repo-template-standard.md`          | standard for bootstrapping and enforcing Base Coat in templates | template, governance, drift, enforcement |
| `docs/MULTI_AGENT_WORKFLOWS.md`           | structure parallel agent sprints to minimize merge conflicts; branch naming; merge order; fresh clone principle | multi-agent, parallel, sprint, merge, conflict, branch |

## Operational Assets

| File                                                                       | Use For                                                     | Keywords                               |
| -------------------------------------------------------------------------- | ----------------------------------------------------------- | -------------------------------------- |
| `scripts/validate-basecoat.sh`                                             | local and CI validation on macOS and Linux                  | validate, bash, ci, frontmatter        |
| `scripts/validate-basecoat.ps1`                                            | local and CI validation on Windows                          | validate, powershell, ci, frontmatter  |
| `scripts/install-git-hooks.sh`                                             | configure local git hooks for guardrail enforcement         | hooks, git, security, pre-commit       |
| `scripts/install-git-hooks.ps1`                                            | configure local git hooks for guardrail enforcement         | hooks, git, security, pre-commit       |
| `scripts/scan-commit-messages.sh`                                          | scan commit messages for secrets and PII patterns           | commit-msg, security, secrets, pii     |
| `.githooks/commit-msg`                                                     | block commits when message contains sensitive data          | hook, commit-msg, security, pii        |
| `scripts/package-basecoat.sh`                                              | create release artifacts on macOS and Linux                 | package, tar.gz, zip, checksum         |
| `scripts/package-basecoat.ps1`                                             | create release artifacts on Windows                         | package, zip, checksum, powershell     |
| `.github/workflows/validate-basecoat.yml`                                  | validate repo structure on push and pull request            | workflow, ci, validation               |
| `.github/workflows/validate-repo-template-sample.yml`                      | validate sample repository template assets and contracts    | workflow, template, governance, ci     |
| `.github/workflows/prd-spec-gate.yml`                                      | enforce PRD/spec references on risky or large pull requests | workflow, prd, spec, governance        |
| `.github/workflows/package-basecoat.yml`                                   | package and publish release artifacts                       | workflow, release, package, artifact   |
| `.github/PULL_REQUEST_TEMPLATE.md`                                         | pull request template with PRD/spec reference fields        | pull request, template, prd, spec      |
| `examples/workflows/bootstrap-from-release.yml`                            | install a pinned Base Coat release into a new repo          | workflow, bootstrap, pinned release    |
| `examples/workflows/validate-basecoat-consumer.yml`                        | validate a consumer repo keeps Base Coat present            | workflow, consumer, drift, validation  |
| `examples/repo-template/.github/base-coat.lock.json`                       | lock file contract for template-based Base Coat pinning     | template, lock, pinned version         |
| `examples/repo-template/.github/workflows/bootstrap-basecoat-template.yml` | bootstrap Base Coat in a new repo from lock file            | template, bootstrap, release, checksum |
| `examples/repo-template/.github/workflows/enforce-basecoat-template.yml`   | enforce lock/version consistency and block unsafe drift     | template, enforcement, drift, policy   |

## Test Assets

| File                  | Use For                                                                                      | Keywords                           |
| --------------------- | -------------------------------------------------------------------------------------------- | ---------------------------------- |
| `tests/run-tests.ps1` | smoke tests for validation, packaging, hooks, and commit-message scanning on Windows         | test, powershell, smoke, packaging |
| `tests/run-tests.sh`  | smoke tests for validation, packaging, hooks, and commit-message scanning on macOS and Linux | test, bash, smoke, packaging       |
| `tests/README.md`     | test suite scope and execution commands                                                      | tests, docs, usage                 |
