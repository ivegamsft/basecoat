# Terraform plan destroy guardrail (optional)

Opt-in guardrail that reads `terraform show -json` output and surfaces
deletes and replaces before apply. Downstream origin: example-org/COECheck#771.

This template is not enabled by default. Copy the workflow (or its inspect
step) into the consumer repository after a plan job writes `tfplan.json`.

Static PR-diff classifiers cannot see destroys that come from state and
resource-address semantics. Only the plan carries that signal.

## What it enforces

1. Parse `resource_changes` whose actions include `delete` (delete or replace).
2. Load the protected resource-type glob list from the PR **base ref**.
3. Fail if a protected type would be destroyed and the acknowledgement
   label is absent.
4. Fail if the PR removes globs from the protected list (anti-bypass).
5. Post a PR comment listing every destroy when at least one exists.
6. No-op (pass, no comment) when the plan has zero deletes or replaces.

## Bootstrap (first adoption)

The gate fails closed when the policy file is missing on the base branch.

1. Commit `terraform-plan-destroy-guardrail-policy.json` to the default
   branch (copy from the example in this directory).
2. After `terraform plan -out=tfplan`, run
   `terraform show -json tfplan > tfplan.json`.
3. Copy `terraform-plan-destroy-guardrail.yml` or splice the inspect step
   into the existing Terraform workflow.

Do not shrink `protectedResourceTypeGlobs` in the same PR as a destroy.
That is the bypass the base-ref check exists to stop.

## Override

Apply the `terraform-destroy-ack` label. The check records a warning and
passes. Keep the label attributable in the PR record; do not disable the job.

## Portability

| Layer | Reusable |
|---|---|
| Plan JSON parse, delete/replace detection, glob match, override | Yes |
| Default globs (`azuread_*`, `azurerm_role_assignment`, `azurerm_key_vault*`) | Azure identity defaults; override per consumer |
| Label name, plan JSON path, CI wiring | Consumer config |
| OpenTofu `show -json` | Compatible |
| Bicep / ARM what-if | Needs a separate adapter |

## Files

- `inspect-terraform-plan-destroys.js` — plan inspector
- `terraform-plan-destroy-guardrail-policy.example.json` — policy schema
- `terraform-plan-destroy-guardrail.yml` — reference CI job
