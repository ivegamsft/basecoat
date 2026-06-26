---
name: api-security
compatibility: [github-copilot-cli]
title: OWASP API Security Top 10 Patterns
description: "Use when securing REST or GraphQL APIs against common auth, authorization, validation, and abuse risks. USE FOR: secure JWT authentication for an API, add rate limiting to endpoints, review API authorization flaws, harden GraphQL queries and mutations, prevent SQL injection in API handlers. DO NOT USE FOR: network firewall design, frontend styling work, general cloud cost reviews."
category: security
---
# API Security Skill

Production patterns for securing REST and GraphQL APIs against OWASP API Security Top 10.

## Reference Files

| File | Contents |
|------|----------|
| [`references/threat-model.md`](references/threat-model.md) | OWASP Top 10 table, JWT auth, RBAC, input validation/XSS, SQL injection prevention, GraphQL security, security logging |
| [`references/controls.md`](references/controls.md) | Rate limiting, API key verification, CORS configuration, security headers, controls checklist |

## Core Controls (Quick Reference)

| Control | Pattern |
|---------|---------|
| Authentication | JWT with short expiry (≤1 hr); rotate refresh tokens |
| Authorization | RBAC via `require_role()` on every endpoint |
| Input validation | Pydantic/Zod schema + HTML escape on user content |
| Injection prevention | Parameterized queries only — no string concatenation |
| Rate limiting | `slowapi` — 5/min on auth, 100/hr on search |
| CORS | Explicit `allow_origins` list — never `["*"]` in production |
| Transport | HTTPS + security headers (HSTS, CSP, X-Frame-Options) |

## Security Logging

Log all auth events (success + failure) with username, IP, and timestamp.
Never log passwords or tokens.

## References

- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)
- [OWASP Top 10 2021](https://owasp.org/Top10/)
