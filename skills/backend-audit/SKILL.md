---
name: backend-audit
description: "Audits generated or implemented backend code output. Evaluates code quality, testing coverage, performance, security, and maintainability. USE FOR: reviewing backend implementations, analyzing code quality, assessing test coverage, identifying performance bottlenecks, security vulnerabilities, structural debt. DO NOT USE FOR: writing backend code from scratch, database schema design, API contract design, frontend code review, infrastructure provisioning."
---

# Backend Audit Skill

Comprehensive auditing of backend implementations, including code quality, testing coverage, performance characteristics, security practices, and maintainability.

## USE FOR

- Reviewing backend service implementations for code quality
- Assessing test coverage and test strategy effectiveness
- Identifying performance bottlenecks and optimization opportunities
- Detecting security vulnerabilities and insecure patterns
- Evaluating code organization, maintainability, and technical debt
- Analyzing logging, error handling, and observability
- Reviewing database interaction patterns and query performance
- Assessing dependency health and supply chain risk
- Creating structured audit findings with severity ratings

## DO NOT USE FOR

- Writing backend code from scratch (use `backend-dev` skill)
- Designing database schemas (use related schema skills)
- API contract design (use `api-design` skill)
- Frontend code review (use appropriate frontend skills)
- Infrastructure provisioning (use `infrastructure-audit` skill)
- General code reviews (use `code-review` skill)

## Audit Checklist

- **Code Quality**: Complexity, duplication, naming, structure
- **Testing**: Unit, integration, e2e coverage; test quality and maintainability
- **Security**: Input validation, authentication, authorization, secrets management
- **Performance**: Query efficiency, caching, connection pooling, async patterns
- **Error Handling**: Exception handling, logging, graceful degradation
- **Dependencies**: Versions, vulnerabilities, necessity, supply chain
- **Observability**: Logging, tracing, metrics, debugging capability
- **Maintainability**: Documentation, comments, architectural clarity

## Related Skills

- `code-review` — General code review for bugs and regressions
- `api-audit` — API endpoint and contract auditing
- `backend-dev` — Backend development and implementation
- `security` — Security vulnerability assessment
