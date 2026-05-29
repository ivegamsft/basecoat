---
description: "Use when reviewing PRs, evaluating security posture, measuring performance, or enforcing coverage thresholds. Covers quality gates that every change must pass and how review agents collaborate."
applyTo: "**/*"
---

# Quality Gates and Security Standards

Use this instruction to enforce the minimum quality bar on every pull request and to coordinate the code-reviewer, security-analyst, performance-analyst, and devops agents.

## PR Review Minimum Bar

Every pull request must pass before merge:

- **Correctness** — change does what it claims; verify against the linked issue
- **Test coverage** — new logic has tests; bug fixes include a regression test
- **Error handling** — no swallowed exceptions, no generic error types
- **Security scan** — no new static analysis or dependency audit warnings; pre-existing warnings touched by the diff must be resolved or tracked
- **Documentation** — public API changes update docs; config changes update README
- **Naming and style** — descriptive names; no commented-out code
- **No secrets** — no credentials, tokens, PII, or connection strings in the diff
- **Changelog** — breaking changes and user-facing features have a changelog entry

"LGTM" without specifics is not a valid approval.

## Security Review Gate Triggers

Label PR `security-review` and require `security-analyst` approval when:

- Authentication or authorization logic changes
- New trust boundaries (API endpoints, service-to-service calls, external integrations)
- New dependencies handling cryptography, parsing, deserialization, or network I/O
- Secrets management, token handling, or credential storage modified
- CI/CD pipeline permissions or workflow secrets changed
- New user-facing input processed server-side

Findings: `critical`/`high` block merge; `medium` require a tracking issue; `low` are advisory.

## Performance Budgets

| Metric | Budget |
|---|---|
| LCP | ≤ 2.5 s |
| FID | ≤ 100 ms |
| CLS | ≤ 0.1 |
| API p95 | ≤ 500 ms |
| API p99 | ≤ 1,000 ms |
| JS bundle (gzip) | ≤ 250 KB |
| CSS bundle (gzip) | ≤ 50 KB |
| Docker image | ≤ 500 MB |

Regressions require justification and a tracking issue.

## Coverage Thresholds

| Scope | Minimum |
|---|---|
| Overall project | ≥ 80% line coverage |
| New / changed files | ≥ 90% line coverage |
| Critical paths (auth, payment, data) | ≥ 95% branch coverage |

## Agent Collaboration

Four agents collaborate on every qualifying PR: **code-reviewer** (all PRs), **security-analyst** (security gate triggers), **performance-analyst** (bundle/API/container changes), **devops** (workflow/IaC/deployment changes). No agent merges alone.

See [`references/quality/agent-handoffs.md`](references/quality/agent-handoffs.md) for agent scopes and handoff protocol.

## References

| Topic | File |
|---|---|
| Full PR checklist, security gate triggers, performance budgets table, coverage rules | [`references/quality/pr-review-checklist.md`](references/quality/pr-review-checklist.md) |
| Agent scopes, handoff rules, escalation path | [`references/quality/agent-handoffs.md`](references/quality/agent-handoffs.md) |
