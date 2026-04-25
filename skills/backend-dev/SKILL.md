---
name: backend-dev
description: "Use when implementing APIs, service layers, or data access patterns. Provides API spec templates, service scaffolds, error catalog structure, and repository pattern boilerplate."
---

# Backend Development Skill

Use this skill when the task involves designing or implementing backend services, REST or GraphQL APIs, business logic layers, or database access patterns.

## When to Use

- Designing a new API endpoint or resource
- Scaffolding a service layer for a feature
- Defining error codes and structured error responses
- Implementing a data access repository
- Reviewing a backend implementation for correctness, security, or performance

## How to Invoke

Reference this skill by attaching `skills/backend-dev/SKILL.md` to your agent context, or instruct the agent:

> Use the backend-dev skill. Apply the API spec template, service template, and error catalog template to the feature being built.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `api-spec-template.md` | OpenAPI 3.x-compatible skeleton for a new API resource |
| `service-template.md` | Service layer scaffold with dependency injection, error handling, and logging stubs |
| `error-catalog-template.md` | Structured error catalog with codes, messages, HTTP status codes, and resolution hints |
| `repository-pattern-template.md` | Data access repository pattern boilerplate, adaptable to any ORM or query builder |

## Agent Pairing

This skill is designed to be used alongside the `backend-dev` agent. The agent drives the workflow; this skill provides the reference templates and standards.

For full-stack features, the backend-dev agent defines contracts that the `frontend-dev` agent consumes. Route data persistence requirements to the `data-tier` agent.
