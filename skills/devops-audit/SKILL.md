---
name: devops-audit
description: "Audits CI/CD pipelines, deployment configurations, and environment management. USE FOR: reviewing GitHub Actions workflows, analyzing deployment processes, validating environment configurations, assessing automation completeness, identifying workflow bottlenecks. DO NOT USE FOR: implementing CI/CD workflows from scratch, infrastructure provisioning, application code development, database administration."
compatibility:
  - GHCP
---
# DevOps Audit Skill

Comprehensive auditing of CI/CD pipelines, deployment configurations, environment management, and automation workflows.

## USE FOR

- Reviewing GitHub Actions workflows for effectiveness and best practices
- Analyzing build and test pipeline configurations
- Assessing deployment strategies and safety mechanisms
- Evaluating environment configuration management
- Identifying workflow inefficiencies and optimization opportunities
- Reviewing secrets and credential management practices
- Assessing artifact handling and dependency caching
- Analyzing rollout strategies and rollback procedures
- Evaluating observability and alerting in deployment processes
- Creating structured audit findings with remediation guidance

## DO NOT USE FOR

- Writing CI/CD workflows from scratch (use `devops` skill)
- Infrastructure provisioning (use `infrastructure-audit` skill)
- Application code development
- Database administration or migrations
- General code review (use `code-review` skill)

## Audit Checklist

- **Workflow Design**: Triggers, job structure, parallelization
- **Build Pipeline**: Build times, caching, artifact management
- **Testing**: Test execution, coverage, failure handling
- **Deployment**: Strategy, safety checks, rollback capability
- **Environments**: Configuration management, secrets, isolation
- **Secrets**: Storage, rotation, access control, exposure prevention
- **Monitoring**: Logs, metrics, alerting, debugging capability
- **Performance**: Pipeline duration, bottlenecks, resource usage
- **Reliability**: Error handling, retries, failure notification
- **Documentation**: Runbooks, troubleshooting, process clarity

## Related Skills

- `devops` — DevOps engineering and CI/CD implementation
- `infrastructure-audit` — Infrastructure and IaC assessment
- `ci-audit` — Organization-level CI/CD configuration audit
