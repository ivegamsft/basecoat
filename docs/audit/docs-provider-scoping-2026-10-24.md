# Docs Audit: Provider and Implementation Scoping (2026-10-24)

Tracking issue: #3934. Baseline: `origin/main` `d9904cba`.

BaseCoat is intended to be generic. Guidance for a specific cloud provider, IaC
tool, or deployment must be called out explicitly so readers know when it
applies. This audit checks whether the docs meet that bar.

## Method

- Scanned all 559 Markdown files under `docs/` for AWS, Azure, GCP, and Terraform
  terms (service names, CLI verbs such as `aws` and `az`, `.tf`, `tfstate`).
- For each active (non-archive) doc with three or more matches, compared the title
  and opening lines with the provider content in the body.
- Searched `docs/`, `README.md`, `instructions/`, and `.github/instructions/` for an
  existing neutrality or scope rule.
- Checked which implementations the repository ships: `infra/aws/` (Terraform,
  legacy Portal), `portal/app/iac/`, `infra/mcp/`, and `infra/extension/` (Bicep).

## Summary

| Measure | Result |
|---|---|
| Docs with any provider or IaC term | 146 of 559 |
| Active docs with three or more matches | 56 |
| Written scope or neutrality rule | None before this audit |
| Unscoped implementation runbooks | 3 (legacy Portal on AWS) |
| Generic title, Azure-only content | 11 |
| Archive docs without a historical notice | 66 of 69 |

## Findings

### F1: No written rule (#3929)

No instruction or guide said that docs must be provider-neutral or must declare
their scope. Some authors scoped their docs well and others did not. This
change adds a "Provider and Implementation Scope" section to
`.github/instructions/repo-structure.instructions.md`.

### F2: AWS Portal runbooks presented as generic operations docs (#3930)

| Doc | Provider terms | What it really covers |
|---|---|---|
| `docs/operations/operational-runbook.md` | 63 AWS, 5 Terraform | `aws autoscaling`, `elbv2`, `rds` commands for the legacy Portal |
| `docs/operations/disaster-recovery.md` | 45 AWS | RDS and CloudWatch failover for the legacy Portal |
| `docs/operations/cost-optimization.md` | 13 AWS | AWS RDS and S3 list prices for the legacy Portal |

None named AWS or the Portal in its title, and two never mentioned them in the
opening lines. The repository also ships an Azure Bicep Portal under
`portal/app/iac/`, so readers could not tell which deployment these docs describe.

The issue also spreads. Five generic docs cite `operational-runbook.md` as the runbook
or runbook template for BaseCoat workflows:

- `docs/operations/aidl-portfolio-operator-playbook.md`
- `docs/operations/keep-fix-throttle-model.md`
- `docs/reference/risk-tier-policy.md`
- `docs/reference/ai-sdlc-operating-model.md`
- `docs/operations/fleet-dispatch-policy.md`

Outside `docs/`, `infra/aws/README.md` claims AWS, Azure, and GCP support but
contains AWS modules only.

This change retitles the three docs, adds a `Scope:` banner to each, and labels
them in `docs/index.md`. Repointing the generic references and deciding whether to
archive or relocate the Portal docs stays on #3930.

### F3: Generic titles with Azure-only content (#3931)

Each of these docs either states Azure only in its first paragraph or never states
it, while its title reads as provider-neutral:

- `docs/operations/enterprise-security-hardening.md`
- `docs/integrations/enterprise-identity-access.md`
- `docs/integrations/rbac-only-authentication-patterns.md`
- `docs/integrations/enterprise-kubernetes-patterns.md`
- `docs/integrations/legacy-modernization-guidance.md`
- `docs/reference/treatment-matrix.md`
- `docs/reference/guardrails/deployment-cancellation.md`
- `docs/reference/guardrails/deployment-rca.md`
- `docs/reference/guardrails/runner-routing.md`
- `docs/guides/config-pattern.md`
- `docs/security/SECRETS_ROTATION_POLICY.md`

### F4: Archive docs without a historical notice (#3932)

The archive holds the densest provider content. The wave3 staging and Portal IaC
docs each have 100 to 160 AWS and Terraform matches, yet 66 of 69 archive
files have no historical or superseded notice in their first 12 lines.

### F5: No regression check (#3933)

Nothing prevents new unscoped provider guidance. A warning-level check in
`scripts/validate-basecoat.ps1` should flag dense provider terms in docs that
have neither a provider in the title nor a `Scope:` line.

## Docs that already meet the bar

These are good models for remediation:

- Provider in title and intro: `docs/guides/windows-server-azure-guidance.md`,
  `docs/integrations/azure-sql-migration-guidance.md`,
  `docs/examples/iac/azure-iac-examples.md`
- Explicit `Applies to` or `Scope` line: `docs/reference/guardrails/caf-naming.md`,
  `docs/reference/guardrails/oidc-federation.md`
- Scoped section in a generic doc: `docs/reference/guardrails/env-example.md`
  ("Minimum Variables for Azure Repos")
- Provider-agnostic framing with labeled provider rows:
  `docs/guides/token-optimization.md`, `docs/operations/security/secret-scanning.md`
- Platform banner: `docs/guides/model-optimization.md` (`GHCP-specific`)

Generated catalogs such as `asset-catalog.md`, `asset-registry.md`, `inventory.md`,
and `prompt-library.md` match because asset names contain `azure` or `terraform`;
they need no change. `docs/architecture/factory-foundation.md` matches only
because it has a stage named `S3`.

## Plan

| Order | Issue | Change | Size |
|---|---|---|---|
| 1 | #3929, #3930 | Scope standard, Portal banners, index labels, this report | S |
| 2 | #3930 | Repoint five generic runbook references; decide archive or relocation; fix the `infra/aws/README.md` claim | S |
| 3 | #3931 | Scope or split 11 Azure-only docs | M |
| 4 | #3932 | Historical notice on 66 archive docs | M, mechanical |
| 5 | #3933 | Warning-level scope check, promoted to an error after steps 3 and 4 | S |

Out of scope: distributed `instructions/`, `agents/`, and `skills/` assets. These
should get the same scan after the docs are clean.
