---
name: e2e-testing
compatibility: [github-copilot-cli]
title: E2E Testing - Playwright, Cypress, and Cross-Browser Patterns
description: "Use when designing or hardening production E2E tests with Playwright or Cypress, including flake reduction, CI strategy, and browser coverage. USE FOR: choose between Playwright and Cypress, reduce flaky browser tests, test login or checkout journeys, set up cross-browser CI coverage, plan E2E fixtures and mocks. DO NOT USE FOR: unit test design, API-only load testing, visual brand design."
category: testing
---
# E2E Testing Skill

Design reliable, maintainable end-to-end coverage for critical user journeys. Choose the right
framework, define resilient selectors and waits, and connect browser tests to CI pipelines
without creating brittle suites.

**See also:** [E2E Validation Lifecycle diagrams](../../docs/diagrams/e2e-validation-lifecycle.md)
for visual guidance on gate preconditions, pass/fail branching, and test scope decisions.

## Reference Files

| File | Contents |
|------|----------|
| [`references/playwright-patterns.md`](references/playwright-patterns.md) | Setup, test structure, waits, fixtures, mocking, accessibility, performance |
| [`references/cypress-patterns.md`](references/cypress-patterns.md) | Cypress config, test patterns, custom commands |
| [`references/ci-integration.md`](references/ci-integration.md) | CI matrix, flakiness prevention, test data management |

## Framework Decision (Quick Reference)

| Criterion | Playwright | Cypress |
|-----------|-----------|---------|
| Browser support | Chromium, Firefox, WebKit | Chromium, Firefox, Electron |
| Language | JS/TS, Python, Java, C# | JS/TS only |
| Parallel execution | Native, multi-process | Paid (Cypress Cloud) |
| **Best for** | Cross-browser, multi-language | JS-first teams, quick setup |

See [`references/ci-integration.md`](references/ci-integration.md) for core principles, CI matrix patterns, and flakiness prevention.
