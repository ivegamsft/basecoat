---
name: ci-audit
description: "Audits GitHub organization CI/CD settings and runner configurations. USE FOR: auditing CI/CD settings, analyzing runners, scanning dependencies, generating optimization recommendations, creating audit findings. DO NOT USE FOR: writing application code, code reviews, database schema design, creating GitHub Actions workflows, infrastructure-as-code development unrelated to CI/CD auditing."
compatibility:
  editors:
    - vscode
    - cursor
  platforms:
    - github
metadata:
  category: "DevOps & Infrastructure"
  tags: ["ci-cd", "audit", "performance", "cost-optimization", "devops"]
  maturity: "beta"
  audience: ["devops-engineers", "platform-teams", "ci-cd-engineers"]
allowed-tools: ["bash", "git", "gh", "grep", "find", "powershell"]
---

# CI/CD Audit Skill

Comprehensive auditing of GitHub organization CI/CD settings, runner configurations, and dependency health.

## USE FOR

- Auditing GitHub org CI/CD settings (runner allocation, concurrency, secret management)
- Analyzing enterprise settings (SSO, audit logs, IP allowlist, app policies)
- Scanning dependency health and identifying outdated packages
- Reviewing self-hosted runner profiles (sizing, capacity, labels)
- Assessing installed GitHub Apps and SDKs against project needs
- Generating optimization recommendations for cost and performance
- Creating structured audit findings and action plans

## DO NOT USE FOR

- Writing application code or feature implementations
- General code reviews of feature branches
- Database schema design or migration planning
- Creating GitHub Actions workflows from scratch (use `devops` skill instead)
- Infrastructure-as-code development unrelated to CI/CD auditing
- Personal developer environment configuration

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

## Audit Script

The `scripts/ci-audit.ps1` script provides automation for common audit operations:

- Query GitHub org settings via `gh` API
- Parse `.github/workflows/` for runner usage patterns
- Analyze `package.json`, lock files, and `requirements.txt` for dependencies
- Generate structured audit JSON with findings and recommendations

Example usage:

```powershell
./scripts/ci-audit.ps1 -OrgName my-org -OutputFormat json -OutputPath ./audit-report.json
```

Output format is fully compatible with the audit templates.
