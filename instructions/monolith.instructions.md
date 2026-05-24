---
description: "Use when AI agents work on large monolith codebases with tightly coupled modules. Covers context scoping, dependency awareness, and safe decomposition strategies."
applyTo: "src/**,lib/**,app/**,packages/**"
---

# Monolith Decomposition Strategy

Use this instruction when AI is assisting with changes in a large, tightly-coupled codebase where cross-module dependencies make isolated reasoning risky.

## Context Boundary Mapping

- Identify natural seams in the codebase: module boundaries, service interfaces, data access layers, or feature flags.
- Document which modules own which responsibilities. When a change touches shared code, enumerate the callers.
- Prefer changes scoped to a single module boundary. If a change must cross boundaries, explicitly list every affected module.

## Dependency Awareness

- Before modifying shared code, map the dependency graph outward one level: who calls this, who inherits from this, who imports this.
- State the blast radius explicitly: "This change affects modules A, B, and C because they depend on interface X."
- If the dependency graph is unclear, say so. Do not assume isolation.
- Treat header files, base classes, shared utilities, and configuration as high-blast-radius by default.

## Prompt Scoping for Large Codebases

- Include interfaces and contracts of adjacent modules, but not their full implementations.
- Provide a brief architectural summary (2-3 sentences) describing how the target module fits into the larger system.
- When context is insufficient, state what additional information would reduce risk rather than guessing.
- Prefer multiple small, focused changes over one large cross-cutting change.

## Incremental Decomposition

- Use the Strangler Fig pattern: wrap legacy behavior behind a new interface before replacing it.
- Introduce anti-corruption layers when integrating new code with legacy modules that have implicit contracts.
- Validate each incremental step independently before proceeding to the next.
- Never remove old code paths until the new path is proven in production or by comprehensive tests.

## Architecture Decision Records

- Reference existing ADRs when they constrain the design space. If no ADR exists for a critical decision, note that one should be created.
- Use ADRs as compressed context: they explain why the system is shaped the way it is without requiring full code review.

## Guardrails

- Do not refactor across module boundaries in the same change that adds new behavior.
- Do not assume a function is only called from the file where it is defined.
- When modifying shared state, identify all readers and writers.
- If a change requires understanding more context than is available, stop and request it rather than inferring.
