---
description: "Use when working on APIs, services, workers, integrations, or data access layers. Covers backend best practices for contracts, failure handling, and testability."
applyTo: "src/**,lib/**,app/**,packages/**,api/**,server/**"
---

# Backend Standards

Use this instruction for backend-heavy work such as APIs, services, workers, or data access layers.

## Expectations

- Fix root causes instead of layering workarounds.
- Preserve public contracts unless the change explicitly allows breaking them.
- Add or update tests for behavior changes.
- Treat logging, error handling, and configuration as part of the feature.
- Keep changes small enough to review clearly.
- Keep external boundaries explicit: request parsing, validation, persistence, messaging, and caching.
- Prefer idempotent operations and safe retries where duplicate execution is plausible.
- Avoid hiding important behavior in framework magic when a clear function boundary would be easier to test.

## Review Lens

- Are failure modes explicit?
- Are inputs validated at boundaries?
- Are persistence and network calls observable and testable?
- Does the change introduce hidden coupling or state leakage?
- Are timeouts, retries, and error translation appropriate for downstream dependencies?
