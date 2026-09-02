# Terraform Plan Destroy Guardrail

Optional, config-driven template that inspects Terraform plan JSON for
deletes and replaces before apply.

Use this when identity or other protected resources can be destroyed by
state reconciliation even though the PR diff has no `terraform destroy`
keyword. The template lives at `templates/terraform-plan-destroy-guardrail/`
and syncs with BaseCoat (`templates/` is part of the managed overlay).

## Why plan inspection

Diff-based risk classifiers only see changed text. Moving a resource
between files, reusing an address, or gating recreate with `count` can
plan a destroy that never appears as a keyword. `terraform show -json`
is the control that carries those actions.

## Config contract

Consumer repository root:

- Policy file: `terraform-plan-destroy-guardrail-policy.json` (copy from
  `templates/terraform-plan-destroy-guardrail/terraform-plan-destroy-guardrail-policy.example.json`)
- Plan file: `tfplan.json` from `terraform show -json tfplan`
- Protected types: `protectedResourceTypeGlobs` (default `azuread_*`,
  `azurerm_role_assignment`, `azurerm_key_vault*`)
- Override label: `override.label` (default `terraform-destroy-ack`)

The script always reads the protected glob list from `--base-ref`
(typically `origin/<base>`). A policy that exists only on the PR branch
is not a control.

## Bootstrap

When the policy file is absent on the base branch, the check fails closed.

Land the first policy on the default branch, then produce `tfplan.json`
in CI after plan. Ordinary PRs with no deletes stay no-op.

## Override semantics

The `terraform-destroy-ack` label is the auditable exception path. The job
warns and passes. Do not delete the workflow to skip a destroy.

## Portability limits

Terraform and OpenTofu `show -json` only. Bicep and ARM need a what-if
adapter because the plan schema differs.

## Related

- Template: `templates/terraform-plan-destroy-guardrail/`
- Downstream incident: IBuySpy-Dev/COECheck#771
