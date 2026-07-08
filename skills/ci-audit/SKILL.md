---
name: ci-audit
compatibility: [github-copilot-cli]
description: "Audits live GitHub repository governance controls and produces a markdown evidence pack. USE FOR: exporting branch protection and required checks, verifying merge queue and environment protections, auditing runners and security gates, and reporting policy-vs-live gaps. DO NOT USE FOR: writing application code, creating workflows, infrastructure implementation, or making repo-setting changes."
category: operations
metadata:
  category: operations
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# CI/CD Audit Skill

Repository governance auditing for CI/CD controls using GitHub API/CLI evidence.

## USE FOR

- Exporting branch protection for `main`/`master`
- Exporting required status checks
- Reporting merge queue enabled/disabled state
- Exporting GitHub Environment protection rules and production reviewers
- Exporting allowed workflow-dispatch actors
- Exporting runner groups and runner labels
- Verifying required security scanning gates
- Determining whether `CODEOWNERS` enforcement is active
- Producing policy-vs-live gap analysis with remediation priorities

## DO NOT USE FOR

- Writing application code or feature implementations
- Creating GitHub Actions workflows from scratch
- Infrastructure-as-code implementation tasks
- Changing repository settings or files during audit
- General code review tasks unrelated to governance evidence

## Templates in This Skill

| Template | Purpose |
|---|---|
| `audit-findings-template.md` | Structured template for documenting audit findings with severity, category, and evidence |
| `recommendations-template.md` | Template for audit recommendations with priority, effort estimate, and expected ROI |

## References in This Skill

| Reference | When to use |
|---|---|
| `ci-audit-checklist.md` | Comprehensive checklist covering all audit categories; use to validate audit completeness |

## Related Agents

Use with `ci-audit` agent for end-to-end auditing workflows. Route remediation to `devops-engineer` agent for implementation guidance.

## Output contract

Produce markdown only:

1. Scope and timestamp
2. Evidence table for the 10 required governance sections
3. Gap matrix: policy expectation vs live setting
4. Prioritized remediation recommendations
5. Appendix with commands/endpoints used
