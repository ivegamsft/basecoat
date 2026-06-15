---
name: infrastructure-audit
description: "Audits Infrastructure-as-Code (Bicep/Terraform), resource configurations, and networking. USE FOR: reviewing IaC code quality, validating resource configurations, assessing networking architecture, identifying security misconfigurations, analyzing cost optimization opportunities. DO NOT USE FOR: writing IaC from scratch, provisioning infrastructure, network architecture design, application development, DevOps workflow creation."
compatibility:
  - GHCP
---
# Infrastructure Audit Skill

Comprehensive auditing of Infrastructure-as-Code implementations, resource configurations, networking architecture, and cloud deployment configurations.

## USE FOR

- Reviewing Bicep and Terraform code for best practices
- Validating resource configurations and compliance
- Assessing networking architecture and security group rules
- Identifying security misconfigurations and compliance violations
- Analyzing resource sizing and cost optimization opportunities
- Evaluating high-availability and disaster recovery configurations
- Reviewing secrets and credential handling in IaC
- Assessing tagging strategies and resource organization
- Identifying dependencies and deployment order issues
- Creating structured audit findings with remediation guidance

## DO NOT USE FOR

- Writing IaC from scratch (use `infrastructure` or `infrastructure-design` skills)
- Provisioning infrastructure
- Network architecture design
- Application development
- CI/CD workflow creation (use `devops-audit` skill)

## Audit Checklist

- **Code Quality**: Modularity, reusability, clarity, documentation
- **Best Practices**: Naming conventions, resource organization, consistency
- **Security**: Encryption, access control, secrets management, compliance
- **Performance**: Resource sizing, scalability, throughput configuration
- **Reliability**: Redundancy, failover, disaster recovery, backup strategy
- **Cost**: Right-sizing, reserved capacity, resource elimination
- **Monitoring**: Alerting, logging, diagnostic settings, observability
- **Networking**: Security groups, network policies, routing, isolation
- **Compliance**: Standards adherence, audit logging, regulatory requirements
- **Dependencies**: Module dependencies, deployment order, state management

## Related Skills

- `azure-infrastructure` — Azure infrastructure design and IaC
- `terraform` — Terraform-specific development (if available)
- `devops-audit` — CI/CD pipeline and deployment process audit
- `security` — Security vulnerability assessment
