# Changelog

All notable changes to this repository should be recorded in this file.

## 0.6.0 - 2026-03-19

- Added `agents/backend-dev.agent.md`: designs and implements REST/GraphQL APIs, service layers, and data access patterns; files GitHub Issues with `tech-debt,backend` labels for N+1 risk, missing validation, unhandled error paths, hardcoded values, and missing auth
- Added `agents/frontend-dev.agent.md`: builds component-driven UIs with WCAG 2.1 AA accessibility, responsive layouts, and Core Web Vitals targets; files GitHub Issues with `tech-debt,frontend,accessibility` labels for missing ARIA, hardcoded colors, non-semantic markup, missing loading states, and inline styles
- Added `agents/middleware-dev.agent.md`: designs integration layers, message contracts, API gateways, and event-driven architectures with circuit breaker, retry, DLQ, and idempotency patterns; files GitHub Issues with `tech-debt,middleware,reliability` labels
- Added `agents/data-tier.agent.md`: designs schemas, writes reversible migrations, optimizes queries, and establishes data access patterns; files GitHub Issues with `tech-debt,data,performance` labels for N+1 queries, missing indexes, SELECT *, missing rollbacks, and hardcoded IDs
- Added `skills/backend-dev/SKILL.md`: skill overview, invocation guide, and template index
- Added `skills/backend-dev/api-spec-template.md`: OpenAPI 3.x-compatible API spec skeleton with example paths, components, pagination, and error schemas
- Added `skills/backend-dev/service-template.md`: service layer scaffold with dependency injection, structured error types, logging stubs, and testing expectations
- Added `skills/backend-dev/error-catalog-template.md`: structured error catalog with codes, messages, HTTP status codes, and resolution hints
- Added `skills/backend-dev/repository-pattern-template.md`: data access repository pattern boilerplate with parameterized queries, pagination, and soft delete support
- Added `skills/frontend-dev/SKILL.md`: skill overview, invocation guide, and template index
- Added `skills/frontend-dev/component-spec-template.md`: component specification covering props, events, slots, all UI states, accessibility requirements, and test plan
- Added `skills/frontend-dev/accessibility-checklist.md`: WCAG 2.1 AA checklist organized by perceivable, operable, understandable, and robust principles with issue-filing guidance
- Added `skills/frontend-dev/state-management-template.md`: state structure template covering local state, shared state, async lifecycle phases, error state, and derived state
- Added `skills/data-tier/SKILL.md`: skill overview, invocation guide, and template index
- Added `skills/data-tier/schema-design-template.md`: schema design document covering entities, columns, constraints, indexes, relationships, and ERD scaffold
- Added `skills/data-tier/migration-template.md`: migration scaffold with up/down blocks, pre-migration checklist, rollback plan, and zero-downtime strategies
- Added `skills/data-tier/query-review-checklist.md`: query review covering N+1 detection, index usage, pagination, SELECT * checks, and explain plan interpretation
- Added `skills/data-tier/data-dictionary-template.md`: data dictionary template covering table, column, type, nullable, description, and example values
- Added `instructions/development.instructions.md`: shared standards for all four dev core agents covering code style, error handling, security, logging, testing, issue filing, and agent collaboration handoff order

## 0.5.0 - 2026-03-19

- Added `agents/manual-test-strategy.agent.md`: produces decision rubric, exploratory charter, regression checklist, defect template, and automation backlog; files GitHub Issues for all automation candidates
- Added `agents/exploratory-charter.agent.md`: generates time-boxed exploratory sessions with mission, scope, evidence capture, and triage routing; files GitHub Issues for automation-worthy findings
- Added `agents/strategy-to-automation.agent.md`: converts manual paths into tiered automation candidates (smoke, regression, integration, agent spec); files a GitHub Issue for every candidate without exception
- Added `skills/manual-test-strategy/SKILL.md`: skill description, when to use, and agent invocation guide
- Added `skills/manual-test-strategy/rubric-template.md`: decision rubric template for manual-only, automate-now, and hybrid classification with risk scoring matrix
- Added `skills/manual-test-strategy/charter-template.md`: exploratory charter template with mission, time box, scope, evidence log, and triage routing
- Added `skills/manual-test-strategy/checklist-template.md`: regression checklist template with automation candidate flagging
- Added `skills/manual-test-strategy/defect-template.md`: defect evidence template with reproduction steps, impact, diagnostic context, and automation handoff section
- Updated `instructions/testing.instructions.md`: added Manual Test Strategy section referencing all three agents, the skill, the decision rubric, and automation handoff expectations

## 0.4.2 - 2026-03-19

- Fixed Windows PowerShell test runner to clear expected nonzero scanner exit codes
- Stabilized the tag-triggered packaging workflow so release validation can complete on both runners

## 0.4.1 - 2026-03-19

- Fixed commit-message scanner negative tests to scan the actual latest sensitive commit
- Stabilized GitHub Actions validation for packaging and release workflows

## 0.4.0 - 2026-03-19

- Added MCP standards guidance for server allowlisting, tool safety, and governance
- Added repository template standard for lock-based bootstrap and drift enforcement
- Added a sample repository template with bootstrap and enforcement workflows
- Added CI validation for the sample repository template assets
- Fixed PowerShell packaging and hook-install scripts to remove duplicated execution blocks

## 0.3.0 - 2026-03-19

- Added sample Azure, naming, Terraform, and Bicep instruction files
- Added authoring skills for creating new skills and instructions
- Added sample workflow agents for customization creation and repo rollout
- Added enterprise packaging and validation scripts for PowerShell and bash
- Added GitHub Actions workflows for validation and release packaging
- Added example consumer workflows and starter IaC examples for Azure with Bicep and Terraform

## 0.2.0 - 2026-03-19

- Added YAML frontmatter to starter customization files for better discovery and validity
- Expanded instructions with common best-practice sets for security, reliability, and documentation
- Added a refactoring skill and a bugfix prompt
- Updated inventory and README to reflect the broader base set

## 0.1.0 - 2026-03-19

- Initial repository scaffold
- Added sync scripts for PowerShell and bash consumers
- Added starter instructions, prompts, skills, and agent files
- Added inventory and version metadata
