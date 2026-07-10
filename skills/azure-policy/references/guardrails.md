# Azure Policy — Guardrails and Agent Pairing

## Guardrails

- Always include a `displayName`, `description`, `category`, and `version` in policy
  metadata — anonymous or undocumented policies cannot be audited.
- Prefer `Audit` or `AuditIfNotExists` over `Deny` for the first deployment of a new
  control; escalate to `Deny` after a burn-in period.
- `DeployIfNotExists` policies require a managed identity with the minimum necessary
  role assignment — do not grant `Owner` or `Contributor` at the subscription scope
  unless explicitly justified.
- Parameter names must be stable across versions — renaming a parameter is a breaking
  change for existing assignments.
- Every policy definition must include at least one framework mapping annotation
  (`CIS`, `NIST_800_53`, or `ISO_27001`) to enable compliance reporting.
- Do not use `enforcementMode: DoNotEnforce` in production assignments without a
  documented review date and owner.

## Agent Pairing

This skill is designed to be used alongside the `policy-as-code-compliance` agent,
which drives validation, exception management, and audit-ready reporting. The agent
executes the governance workflow; this skill provides the reference templates and
authoring standards.

For IaC-level enforcement, pair with the `devops-engineer` agent using `skills/devops/`
templates to integrate policy assignments into CI/CD pipelines. For Bicep-authored
assignments, refer to `instructions/basecoat-10-core-bicep.instructions.md`.
