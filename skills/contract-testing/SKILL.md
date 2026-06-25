---
name: contract-testing
compatibility: [github-copilot-cli]
title: Contract Testing & Integration Patterns
description: "Use when implementing consumer-driven contracts, Pact verification, provider states, or integration test orchestration across services. USE FOR: add Pact contract tests between services, verify provider won't break consumers, set up Pact Broker in CI, orchestrate multi-service integration tests with Docker Compose, add mutation testing gate for APIs. DO NOT USE FOR: unit testing a single function, load testing production traffic, frontend visual regression testing."
---
# Contract Testing Skill

Consumer-driven contract tests, Pact broker workflows, provider verification, and Docker Compose integration orchestration.

## Quick Start

1. Define consumer contracts using Pact — one per consumer/provider pair.
2. Write provider states for every contract interaction.
3. Run provider verification in CI against the Pact broker or local files.
4. Orchestrate full integration suites with Docker Compose.
5. Target >85% mutation score; block deployment if contract verification fails.

## Reference Files

| File | Contents |
|------|----------|
| [`references/pact-patterns.md`](references/pact-patterns.md) | Consumer contract definition, provider verification, provider states setup |
| [`references/e2e-orchestration.md`](references/e2e-orchestration.md) | Selenium E2E, Docker Compose orchestration, mutation testing, report template |

## Key Patterns

| Pattern | Rule |
|---------|------|
| Consumer-driven | Consumer writes the contract; provider must satisfy it |
| Provider states | `/provider-states` endpoint seeds DB before each interaction |
| Mutation gate | >85% mutation score required before merging |
| Deployment gate | BLOCKED if any contract fails verification |


